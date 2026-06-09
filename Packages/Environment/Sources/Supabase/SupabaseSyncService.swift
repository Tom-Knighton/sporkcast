//
//  SupabaseSyncService.swift
//  Environment
//
//  Created by Tom Knighton on 01/06/2026.
//

import Dependencies
import Foundation
import Persistence
import SQLiteData
import Supabase

public actor SupabaseSyncService {
    public static let shared = SupabaseSyncService()

    private let client: SupabaseClient
    private let schema = "sporkast-mobile"
    private let realtimeDecoder = PostgrestClient.Configuration.jsonDecoder

    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTasks: [Task<Void, Never>] = []
    private var realtimeStartInProgress = false
    private var realtimeSubscribed = false
    private var startInProgress = false
    private var currentUserId: UUID?
    private var pendingRecipeHydrationIds: Set<UUID> = []
    private var recipeHydrationTask: Task<Void, Never>?
    private let recipeBootstrapChunkSize = 25
    private let recipeUploadChunkSize = 25
    private let detailLookupChunkSize = 100

    @Dependency(\.defaultDatabase) private var database

    public init(client: SupabaseClient = SporkastSupabase.client) {
        self.client = client
    }

    private nonisolated func logRealtime(_ message: String) {
        let fullMessage = "supabase realtime \(message)"
        print(fullMessage)
        RecipeDebugDiagnostics.logAppEvent(fullMessage)
    }

    @discardableResult
    public func bootstrapAnonymousSessionIfNeeded() async -> Bool {

        do {
            let session = try await client.auth.session
            currentUserId = session.user.id
            return true
        } catch {
            do {
                let session = try await client.auth.signInAnonymously()
                currentUserId = session.user.id
                return true
            } catch {
                RecipeDebugDiagnostics.logAppEvent("supabase anonymous sign-in failed error=\(error)")
                return false
            }
        }
    }

    private func shouldIgnoreSelfOriginated(_ updatedBy: UUID?) async -> Bool {
        guard let updatedBy else { return false }
        if currentUserId == nil {
            _ = await bootstrapAnonymousSessionIfNeeded()
        }
        return updatedBy == currentUserId
    }

    public func start() async {
        guard !startInProgress else {
            RecipeDebugDiagnostics.logAppEvent("supabase start skipped already in progress")
            return
        }

        startInProgress = true
        defer { startInProgress = false }

        guard await bootstrapAnonymousSessionIfNeeded() else { return }
        await drainOutbox()
        await pullHomesAndRecipes(startRealtime: true)
    }

    public func pushCurrentHomeSnapshot() async {
        RecipeDebugDiagnostics.logAppEvent("supabase legacy home snapshot request ignored")
        await drainOutbox()
    }

    public func enqueueSnapshot(homeId: UUID? = nil) async {
        RecipeDebugDiagnostics.logAppEvent("supabase legacy home snapshot enqueue ignored homeId=\(homeId?.uuidString ?? "personal")")
    }

    public func enqueueMealplanSnapshot(homeId: UUID? = nil) async {
        await enqueueSnapshot(kind: "mealplan_snapshot", homeId: homeId)
    }

    public func enqueueShoppingSnapshot(homeId: UUID? = nil) async {
        await enqueueSnapshot(kind: "shopping_snapshot", homeId: homeId)
    }

    public func enqueueRecipeOrganizationSnapshot(homeId: UUID? = nil) async {
        await enqueueSnapshot(kind: "recipe_organization_snapshot", homeId: homeId)
    }

    public func pushShoppingListsSnapshot(homeId: UUID?) async {
        guard await bootstrapAnonymousSessionIfNeeded() else {
            RecipeDebugDiagnostics.logAppEvent("supabase shopping direct push skipped auth unavailable")
            return
        }

        do {
            try await pushShoppingLists(homeId: homeId)
        } catch {
            RecipeDebugDiagnostics.logAppEvent("supabase shopping direct push failed homeId=\(homeId?.uuidString ?? "personal") error=\(error)")
        }
    }

    public func enqueueRecipeUpsert(recipeId: UUID, homeId: UUID?) async {
        await enqueueMutation(kind: "recipe", entityId: recipeId, homeId: homeId, operation: "push")
    }

    private func enqueueSnapshot(kind: String, homeId: UUID? = nil) async {
        await enqueueMutation(kind: kind, entityId: homeId, homeId: homeId, operation: "push")
    }

    private func enqueueMutation(kind: String, entityId: UUID?, homeId: UUID?, operation: String) async {

        do {
            try await database.write { db in
                try DBSupabaseOutboxMutation.insert {
                    DBSupabaseOutboxMutation(
                        id: UUID(),
                        kind: kind,
                        entityId: entityId,
                        homeId: homeId,
                        operation: operation,
                        createdAt: Date(),
                        attemptCount: 0,
                        lastAttemptAt: nil,
                        lastError: nil
                    )
                }
                .execute(db)
            }
        } catch {
            RecipeDebugDiagnostics.logAppEvent("supabase enqueue \(kind) \(operation) failed entityId=\(entityId?.uuidString ?? "nil") error=\(error)")
        }
    }

    public func drainOutbox(limit: Int = 20) async {
        guard await bootstrapAnonymousSessionIfNeeded() else { return }

        do {
            let mutations = try await database.read { db in
                try DBSupabaseOutboxMutation
                    .order(by: \.createdAt)
                    .limit(limit)
                    .fetchAll(db)
            }

            for mutation in mutations {
                do {
                    try await process(mutation)
                    try await database.write { db in
                        try DBSupabaseOutboxMutation.find(mutation.id).delete().execute(db)
                    }
                } catch {
                    let message = String(describing: error)
                    try await database.write { db in
                        let attemptedAt = Date()
                        try DBSupabaseOutboxMutation.find(mutation.id).update {
                            $0.attemptCount = mutation.attemptCount + 1
                            $0.lastAttemptAt = #bind(attemptedAt)
                            $0.lastError = #bind(message)
                        }
                        .execute(db)
                    }
                    RecipeDebugDiagnostics.logAppEvent("supabase outbox drain failed id=\(mutation.id) error=\(error)")
                }
            }
        } catch {
            RecipeDebugDiagnostics.logAppEvent("supabase drain outbox failed error=\(error)")
        }
    }

    public func pullHomesAndRecipes() async {
        await pullHomesAndRecipes(startRealtime: true)
    }

    private func pullHomesAndRecipes(startRealtime: Bool) async {

        guard await bootstrapAnonymousSessionIfNeeded() else { return }

        do {
            let homes: [SupabaseHomeRow] = try await client
                .from("homes")
                .select()
                .execute()
                .value

            try await database.write { db in
                for home in homes {
                    try DBHome
                        .upsert { DBHome(id: home.id, name: home.name) }
                        .execute(db)
                }
            }

            await pullScope(homeId: nil)

            for home in homes {
                await pullScope(homeId: home.id)
            }

            if startRealtime {
                await startRealtimeForCurrentHomes()
            }
        } catch {
            RecipeDebugDiagnostics.logAppEvent("supabase pull failed error=\(error)")
        }
    }

    public func resumeRealtimeSync() async {
        logRealtime("resume requested")
        guard await bootstrapAnonymousSessionIfNeeded() else {
            logRealtime("resume skipped auth unavailable")
            return
        }

        await drainOutbox()
        await startRealtimeForCurrentHomes()
    }

    private func pullScope(homeId: UUID?) async {
        do {
            try await pullRecipes(homeId: homeId)
        } catch {
            RecipeDebugDiagnostics.logAppEvent("supabase recipe pull failed homeId=\(homeId?.uuidString ?? "personal") error=\(error)")
        }

        do {
            try await pullMealplan(homeId: homeId)
        } catch {
            RecipeDebugDiagnostics.logAppEvent("supabase mealplan pull failed homeId=\(homeId?.uuidString ?? "personal") error=\(error)")
        }

        do {
            try await pullShoppingLists(homeId: homeId)
        } catch {
            RecipeDebugDiagnostics.logAppEvent("supabase shopping list pull failed homeId=\(homeId?.uuidString ?? "personal") error=\(error)")
        }

        do {
            try await pullRecipeOrganization(homeId: homeId)
        } catch {
            RecipeDebugDiagnostics.logAppEvent("supabase organization pull failed homeId=\(homeId?.uuidString ?? "personal") error=\(error)")
        }
    }

    public func createInviteToken(homeId: UUID, expiresAt: Date? = nil) async throws -> String {
        guard await bootstrapAnonymousSessionIfNeeded() else { throw SupabaseSyncError.authUnavailable }

        let rows: [SupabaseHomeInviteRow] = try await client
            .from("home_invites")
            .insert(SupabaseCreateInvitePayload(homeId: homeId, expiresAt: expiresAt))
            .select()
            .execute()
            .value

        guard let token = rows.first?.token else { throw SupabaseSyncError.missingInviteToken }
        return token
    }

    public func syncHomeImmediately(_ home: DBHome) async throws {
        try await upsert(home)
    }

    public func homeResidents(homeId: UUID) async throws -> [HomeResident] {
        guard await bootstrapAnonymousSessionIfNeeded() else { throw SupabaseSyncError.authUnavailable }

        let currentUserId = try await client.auth.session.user.id
        let members: [SupabaseHomeMemberRow] = try await client
            .from("home_members")
            .select()
            .eq("home_id", value: homeId.uuidString)
            .execute()
            .value

        return members
            .sorted { lhs, rhs in
                if lhs.role == rhs.role { return lhs.userId.uuidString < rhs.userId.uuidString }
                return lhs.role == "owner"
            }
            .enumerated()
            .map { index, member in
                let isCurrentUser = member.userId == currentUserId
                let role = member.role == "owner" ? "Owner" : "Member"
                let name = isCurrentUser ? "You" : "\(role) \(index + 1)"
                return HomeResident(name: "\(name) - \(role)", role: role, isUser: isCurrentUser)
            }
    }

    public func acceptInviteToken(_ token: String) async throws -> UUID {
        guard await bootstrapAnonymousSessionIfNeeded() else { throw SupabaseSyncError.authUnavailable }

        let homeId: UUID = try await client
            .rpc("accept_home_invite", params: ["invite_token": token])
            .execute()
            .value

        let home: SupabaseHomeRow = try await client
            .from("homes")
            .select()
            .eq("id", value: homeId.uuidString)
            .single()
            .execute()
            .value

        try await database.write { db in
            try DBHome
                .upsert { DBHome(id: home.id, name: home.name) }
                .execute(db)
        }

        await pullScope(homeId: homeId)
        await startRealtimeForCurrentHomes()
        return homeId
    }

    public func leaveHome(homeId: UUID, disbandIfOwner: Bool) async throws {
        guard await bootstrapAnonymousSessionIfNeeded() else { throw SupabaseSyncError.authUnavailable }

        try await client
            .rpc(
                "leave_home",
                params: SupabaseLeaveHomeParams(homeId: homeId, disbandIfOwner: disbandIfOwner)
            )
            .execute()

        await stopRealtime()
        await startRealtimeForCurrentHomes()
    }

    public func upsert(_ home: DBHome) async throws {
        guard await bootstrapAnonymousSessionIfNeeded() else { throw SupabaseSyncError.authUnavailable }

        try await client
            .rpc(
                "upsert_home",
                params: [
                    "p_home_id": home.id.uuidString,
                    "p_home_name": home.name,
                ]
            )
            .execute()
    }

    public func deleteRecipe(_ recipeId: UUID, homeId: UUID?) async {

        guard await bootstrapAnonymousSessionIfNeeded() else { return }

        do {
            try await softDeleteRecipe(recipeId)
        } catch {
            await enqueueRecipeDeletion(recipeId, homeId: homeId)
            RecipeDebugDiagnostics.logAppEvent("supabase delete recipe queued recipeId=\(recipeId) error=\(error)")
        }
    }

    public func startRealtimeForCurrentHomes() async {
        logRealtime("start requested")
        guard !realtimeStartInProgress else {
            logRealtime("start skipped already in progress")
            return
        }
        guard realtimeChannel == nil || !realtimeSubscribed else {
            logRealtime("start skipped already subscribed")
            return
        }

        realtimeStartInProgress = true
        defer { realtimeStartInProgress = false }

        guard await bootstrapAnonymousSessionIfNeeded() else {
            logRealtime("start skipped auth unavailable")
            return
        }
        do {
            try await refreshRealtimeAuth()
        } catch {
            logRealtime("auth refresh failed error=\(error)")
        }
        await stopRealtime()

        let channel = client.channel("sporkast-mobile")
        realtimeChannel = channel

        realtimeTasks.append(Task { [client] in
            for await status in client.realtimeV2.statusChange {
                print("supabase realtime socket status=\(status)")
                RecipeDebugDiagnostics.logAppEvent("supabase realtime socket status=\(status)")
            }
        })

        realtimeTasks.append(Task {
            for await status in channel.statusChange {
                print("supabase realtime channel status=\(status)")
                RecipeDebugDiagnostics.logAppEvent("supabase realtime channel status=\(status)")
            }
        })

        listenForRecipeChanges(channel)
        listenForRecipeImageChanges(channel)
        listenForRecipeDetailChanges(channel)
        listenForMealplanChanges(channel)
        listenForShoppingListChanges(channel)
        listenForRecipeOrganizationChanges(channel)

        do {
            try await channel.subscribeWithError()
            realtimeSubscribed = true
            logRealtime("subscribed channel=sporkast-mobile")
        } catch {
            realtimeSubscribed = false
            logRealtime("subscribe failed error=\(error)")
        }
    }

    private func refreshRealtimeAuth() async throws {
        let session = try await client.auth.session
        await client.realtimeV2.setAuth(session.accessToken)
    }

    public func stopRealtime() async {
        realtimeSubscribed = false
        for task in realtimeTasks {
            task.cancel()
        }
        realtimeTasks = []

        recipeHydrationTask?.cancel()
        recipeHydrationTask = nil
        pendingRecipeHydrationIds = []

        if let realtimeChannel {
            await client.removeChannel(realtimeChannel)
        }
        realtimeChannel = nil
    }

    private func process(_ mutation: DBSupabaseOutboxMutation) async throws {
        switch (mutation.kind, mutation.operation) {
        case ("home_snapshot", "push"):
            RecipeDebugDiagnostics.logAppEvent("supabase legacy home_snapshot outbox ignored id=\(mutation.id) homeId=\(mutation.homeId?.uuidString ?? "personal")")
        case ("mealplan_snapshot", "push"):
            try await pushMealplan(homeId: mutation.homeId)
        case ("shopping_snapshot", "push"):
            try await pushShoppingLists(homeId: mutation.homeId)
        case ("recipe_organization_snapshot", "push"):
            try await pushRecipeOrganization(homeId: mutation.homeId)
        case ("recipe", "push"):
            guard let recipeId = mutation.entityId else { throw SupabaseSyncError.missingEntityId }
            try await pushRecipe(recipeId: recipeId)
        case ("recipe", "delete"):
            guard let recipeId = mutation.entityId else { throw SupabaseSyncError.missingEntityId }
            try await softDeleteRecipe(recipeId)
        case ("mealplan", "delete"):
            guard let entryId = mutation.entityId else { throw SupabaseSyncError.missingEntityId }
            try await softDeleteMealplanEntry(entryId)
        default:
            RecipeDebugDiagnostics.logAppEvent("supabase unknown outbox ignored id=\(mutation.id) kind=\(mutation.kind) operation=\(mutation.operation)")
        }
    }

    private func pushLocalSnapshot(homeId requestedHomeId: UUID?) async throws {
        if let requestedHomeId {
            let home = try await database.read { db in
                try DBHome.find(requestedHomeId).fetchOne(db)
            }
            if let home {
                try await upsert(home)
            }
            try await pushRecipes(homeId: requestedHomeId)
            try await pushMealplan(homeId: requestedHomeId)
            try await pushShoppingLists(homeId: requestedHomeId)
            try await pushRecipeOrganization(homeId: requestedHomeId)
        } else {
            try await pushRecipes(homeId: nil)
            try await pushMealplan(homeId: nil)
            try await pushShoppingLists(homeId: nil)
            try await pushRecipeOrganization(homeId: nil)
        }
    }

    private func enqueueRecipeDeletion(_ recipeId: UUID, homeId: UUID?) async {
        await enqueueDeletion(kind: "recipe", entityId: recipeId, homeId: homeId)
    }

    private func enqueueDeletion(kind: String, entityId: UUID, homeId: UUID?) async {
        do {
            try await database.write { db in
                try DBSupabaseOutboxMutation.insert {
                    DBSupabaseOutboxMutation(
                        id: UUID(),
                        kind: kind,
                        entityId: entityId,
                        homeId: homeId,
                        operation: "delete",
                        createdAt: Date(),
                        attemptCount: 0,
                        lastAttemptAt: nil,
                        lastError: nil
                    )
                }
                .execute(db)
            }
        } catch {
            RecipeDebugDiagnostics.logAppEvent("supabase enqueue \(kind) delete failed entityId=\(entityId) error=\(error)")
        }
    }

    private func hasPendingOutboxMutations() async throws -> Bool {
        try await database.read { db in
            try DBSupabaseOutboxMutation.all.limit(1).fetchAll(db).isEmpty == false
        }
    }

    private func softDeleteRecipe(_ recipeId: UUID) async throws {
        try await client
            .from("recipes")
            .update(["deleted_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: recipeId.uuidString)
            .execute()
    }

    public func deleteMealplanEntry(_ entryId: UUID, homeId: UUID?) async {

        guard await bootstrapAnonymousSessionIfNeeded() else { return }

        do {
            try await softDeleteMealplanEntry(entryId)
        } catch {
            await enqueueDeletion(kind: "mealplan", entityId: entryId, homeId: homeId)
            RecipeDebugDiagnostics.logAppEvent("supabase delete mealplan queued entryId=\(entryId) error=\(error)")
        }
    }

    private func softDeleteMealplanEntry(_ entryId: UUID) async throws {
        try await client
            .from("mealplan_entries")
            .update(["deleted_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: entryId.uuidString)
            .execute()
    }

    public func pushMealplanEntries(entryIds: [UUID]) async throws {
        guard await bootstrapAnonymousSessionIfNeeded() else { throw SupabaseSyncError.authUnavailable }

        let entryIdSet = Set(entryIds)
        guard !entryIdSet.isEmpty else { return }

        var entries = try await database.read { db in
            try DBMealplanEntry.all
                .fetchAll(db)
                .filter { entryIdSet.contains($0.id) }
                .map(SupabaseMealplanEntryRow.init)
        }
        if let currentUserId {
            entries = entries.map {
                var row = $0
                row.updatedBy = currentUserId
                return row
            }
        }

        let localEntryIds = Set(entries.map(\.id))
        for deletedEntryId in entryIdSet.subtracting(localEntryIds) {
            try await softDeleteMealplanEntry(deletedEntryId)
        }

        guard !entries.isEmpty else { return }

        try await client
            .from("mealplan_entries")
            .upsert(entries)
            .execute()
    }

    public func pushRecipes(homeId: UUID?) async throws {

        let recipes = try await database.read { db in
            try DBRecipe.full.fetchAll(db)
        }
        .filter { $0.recipe.homeId == homeId }

        try await softDeleteRemoteStaleRecipes(homeId: homeId, localRecipeIds: Set(recipes.map(\.recipe.id)))

        for chunk in recipes.chunked(into: recipeUploadChunkSize) {
            do {
                try await upsertRecipes(chunk)
            } catch {
                RecipeDebugDiagnostics.logAppEvent("supabase recipe batch push failed count=\(chunk.count) homeId=\(homeId?.uuidString ?? "personal") error=\(error)")
                throw error
            }
        }
    }

    public func pushRecipes(recipeIds: [UUID]) async throws {
        guard await bootstrapAnonymousSessionIfNeeded() else { throw SupabaseSyncError.authUnavailable }

        let recipeIdSet = Set(recipeIds)
        guard !recipeIdSet.isEmpty else { return }

        let recipes = try await database.read { db in
            try DBRecipe.full
                .fetchAll(db)
                .filter { recipeIdSet.contains($0.recipe.id) }
        }
        let localRecipeIds = Set(recipes.map(\.recipe.id))
        for deletedRecipeId in recipeIdSet.subtracting(localRecipeIds) {
            try await softDeleteRecipe(deletedRecipeId)
        }

        for chunk in recipes.chunked(into: recipeUploadChunkSize) {
            do {
                try await upsertRecipes(chunk)
            } catch {
                RecipeDebugDiagnostics.logAppEvent("supabase recipe id batch push failed count=\(chunk.count) error=\(error)")
                throw error
            }
        }
    }

    public func deleteRecipes(in scopes: Set<UUID?>) async {
        guard await bootstrapAnonymousSessionIfNeeded() else { return }

        for scope in scopes {
            do {
                try await softDeleteRemoteStaleRecipes(homeId: scope, localRecipeIds: [])
            } catch {
                RecipeDebugDiagnostics.logAppEvent("supabase recipe scope delete failed homeId=\(scope?.uuidString ?? "personal") error=\(error)")
            }
        }
    }

    public func pushRecipeImages(recipeIds: [UUID]) async throws {
        guard await bootstrapAnonymousSessionIfNeeded() else { throw SupabaseSyncError.authUnavailable }

        let recipeIdSet = Set(recipeIds)
        guard !recipeIdSet.isEmpty else { return }

        let images = try await database.read { db in
            try DBRecipeImage.all
                .fetchAll(db)
                .filter { recipeIdSet.contains($0.recipeId) }
                .map(SupabaseRecipeImageRow.init)
        }

        guard !images.isEmpty else { return }

        for chunk in images.chunked(into: recipeUploadChunkSize) {
            try await client
                .from("recipe_images")
                .upsert(chunk)
                .execute()
        }
    }

    private func softDeleteRemoteStaleRecipes(homeId: UUID?, localRecipeIds: Set<UUID>) async throws {
        var query = client
            .from("recipes")
            .select()

        if let homeId {
            query = query.eq("home_id", value: homeId.uuidString)
        } else {
            query = query.is("home_id", value: nil)
        }

        let remoteRecipes: [SupabaseRecipeRow] = try await query
            .is("deleted_at", value: nil)
            .execute()
            .value

        let staleRecipeIds = Set(remoteRecipes.map(\.id)).subtracting(localRecipeIds)
        try await softDeleteRemoteRows(table: "recipes", ids: staleRecipeIds)
    }

    private func pushRecipe(recipeId: UUID) async throws {

        guard let recipe = try await database.read({ db in
            try DBRecipe.full.fetchAll(db).first { $0.recipe.id == recipeId }
        }) else {
            try await softDeleteRecipe(recipeId)
            return
        }

        try await upsertRecipes([recipe])
    }

    public func upsert(_ fullRecipe: FullDBRecipe) async throws {

        try await upsertRecipes([fullRecipe])
    }

    private func upsertRecipes(_ fullRecipes: [FullDBRecipe]) async throws {
        guard !fullRecipes.isEmpty else { return }
        let payloads = fullRecipes.map(SupabaseFullRecipePayload.init)
        var recipes = payloads.map(\.recipe)
        let images = payloads.compactMap(\.image)
        let ingredientSections = payloads.flatMap(\.ingredientSections)
        let ingredients = payloads.flatMap(\.ingredients)
        let stepSections = payloads.flatMap(\.stepSections)
        let steps = payloads.flatMap(\.steps)
        let stepTimings = payloads.flatMap(\.stepTimings)
        let stepTemperatures = payloads.flatMap(\.stepTemperatures)
        let stepLinkedIngredients = payloads.flatMap(\.stepLinkedIngredients)

        guard !recipes.isEmpty else { return }
        if currentUserId == nil {
            _ = await bootstrapAnonymousSessionIfNeeded()
        }
        if let currentUserId {
            recipes = recipes.map {
                var row = $0
                row.updatedBy = currentUserId
                return row
            }
        }
        try await deleteRemoteStaleRecipeDetails(for: payloads)
        let recipesToUpsert = try await changedRecipeRows(recipes)

        if !recipesToUpsert.isEmpty {
            try await client
                .from("recipes")
                .upsert(recipesToUpsert)
                .execute()
        }

        if !images.isEmpty {
            try await client
                .from("recipe_images")
                .upsert(images)
                .execute()
        }

        if !ingredientSections.isEmpty {
            try await client
                .from("recipe_ingredient_sections")
                .upsert(ingredientSections)
                .execute()
        }
        if !ingredients.isEmpty {
            try await client
                .from("recipe_ingredients")
                .upsert(ingredients)
                .execute()
        }

        if !stepSections.isEmpty {
            try await client
                .from("recipe_step_sections")
                .upsert(stepSections)
                .execute()
        }
        if !steps.isEmpty {
            try await client
                .from("recipe_steps")
                .upsert(steps)
                .execute()
        }
        if !stepTimings.isEmpty {
            try await client
                .from("recipe_step_timings")
                .upsert(stepTimings)
                .execute()
        }
        if !stepTemperatures.isEmpty {
            try await client
                .from("recipe_step_temperatures")
                .upsert(stepTemperatures)
                .execute()
        }
        if !stepLinkedIngredients.isEmpty {
            try await client
                .from("recipe_step_linked_ingredients")
                .upsert(stepLinkedIngredients)
                .execute()
        }
    }

    private func changedRecipeRows(_ rows: [SupabaseRecipeRow]) async throws -> [SupabaseRecipeRow] {
        let ids = rows.map(\.id.uuidString)
        guard !ids.isEmpty else { return [] }

        var remoteRows: [SupabaseRecipeRow] = []
        for chunk in ids.chunked(into: detailLookupChunkSize) {
            let chunkRows: [SupabaseRecipeRow] = try await client
                .from("recipes")
                .select()
                .in("id", values: chunk)
                .execute()
                .value
            remoteRows.append(contentsOf: chunkRows)
        }

        let remoteById = Dictionary(uniqueKeysWithValues: remoteRows.map { ($0.id, $0.localRow()) })
        return rows.filter { row in
            guard let remote = remoteById[row.id] else { return true }
            return remote != row.localRow()
        }
    }

    private func deleteRemoteStaleRecipeDetails(for payloads: [SupabaseFullRecipePayload]) async throws {
        let recipeIdValues = payloads.map(\.recipe.id).map(\.uuidString)
        guard !recipeIdValues.isEmpty else { return }

        var existingIngredientSections: [SupabaseRecipeIngredientSectionRow] = []
        var existingStepSections: [SupabaseRecipeStepSectionRow] = []
        for chunk in recipeIdValues.chunked(into: detailLookupChunkSize) {
            let ingredientSectionRows: [SupabaseRecipeIngredientSectionRow] = try await client
                .from("recipe_ingredient_sections")
                .select()
                .in("recipe_id", values: chunk)
                .execute()
                .value
            existingIngredientSections.append(contentsOf: ingredientSectionRows)

            let stepSectionRows: [SupabaseRecipeStepSectionRow] = try await client
                .from("recipe_step_sections")
                .select()
                .in("recipe_id", values: chunk)
                .execute()
                .value
            existingStepSections.append(contentsOf: stepSectionRows)
        }

        var existingIngredients: [SupabaseRecipeIngredientRow] = []
        for chunk in existingIngredientSections.map(\.id).map(\.uuidString).chunked(into: detailLookupChunkSize) {
            let rows: [SupabaseRecipeIngredientRow] = try await client
                .from("recipe_ingredients")
                .select()
                .in("ingredient_group_id", values: chunk)
                .execute()
                .value
            existingIngredients.append(contentsOf: rows)
        }

        var existingSteps: [SupabaseRecipeStepRow] = []
        for chunk in existingStepSections.map(\.id).map(\.uuidString).chunked(into: detailLookupChunkSize) {
            let rows: [SupabaseRecipeStepRow] = try await client
                .from("recipe_steps")
                .select()
                .in("group_id", values: chunk)
                .execute()
                .value
            existingSteps.append(contentsOf: rows)
        }

        var existingTimings: [SupabaseRecipeStepTimingRow] = []
        var existingTemperatures: [SupabaseRecipeStepTemperatureRow] = []
        var existingLinkedIngredients: [SupabaseRecipeStepLinkedIngredientRow] = []
        for chunk in existingSteps.map(\.id).map(\.uuidString).chunked(into: detailLookupChunkSize) {
            let timingRows: [SupabaseRecipeStepTimingRow] = try await client
                .from("recipe_step_timings")
                .select()
                .in("recipe_step_id", values: chunk)
                .execute()
                .value
            existingTimings.append(contentsOf: timingRows)

            let temperatureRows: [SupabaseRecipeStepTemperatureRow] = try await client
                .from("recipe_step_temperatures")
                .select()
                .in("recipe_step_id", values: chunk)
                .execute()
                .value
            existingTemperatures.append(contentsOf: temperatureRows)

            let linkedIngredientRows: [SupabaseRecipeStepLinkedIngredientRow] = try await client
                .from("recipe_step_linked_ingredients")
                .select()
                .in("recipe_step_id", values: chunk)
                .execute()
                .value
            existingLinkedIngredients.append(contentsOf: linkedIngredientRows)
        }

        let payloadIngredientSectionIds = Set(payloads.flatMap(\.ingredientSections).map(\.id))
        let payloadIngredientIds = Set(payloads.flatMap(\.ingredients).map(\.id))
        let payloadStepSectionIds = Set(payloads.flatMap(\.stepSections).map(\.id))
        let payloadStepIds = Set(payloads.flatMap(\.steps).map(\.id))
        let payloadTimingIds = Set(payloads.flatMap(\.stepTimings).map(\.id))
        let payloadTemperatureIds = Set(payloads.flatMap(\.stepTemperatures).map(\.id))
        let payloadLinkedIngredientIds = Set(payloads.flatMap(\.stepLinkedIngredients).map(\.id))

        try await deleteRemoteRows(
            table: "recipe_step_linked_ingredients",
            ids: Set(existingLinkedIngredients.map(\.id)).subtracting(payloadLinkedIngredientIds)
        )
        try await deleteRemoteRows(
            table: "recipe_step_temperatures",
            ids: Set(existingTemperatures.map(\.id)).subtracting(payloadTemperatureIds)
        )
        try await deleteRemoteRows(
            table: "recipe_step_timings",
            ids: Set(existingTimings.map(\.id)).subtracting(payloadTimingIds)
        )
        try await deleteRemoteRows(
            table: "recipe_ingredients",
            ids: Set(existingIngredients.map(\.id)).subtracting(payloadIngredientIds)
        )
        try await deleteRemoteRows(
            table: "recipe_steps",
            ids: Set(existingSteps.map(\.id)).subtracting(payloadStepIds)
        )
        try await deleteRemoteRows(
            table: "recipe_step_sections",
            ids: Set(existingStepSections.map(\.id)).subtracting(payloadStepSectionIds)
        )
        try await deleteRemoteRows(
            table: "recipe_ingredient_sections",
            ids: Set(existingIngredientSections.map(\.id)).subtracting(payloadIngredientSectionIds)
        )
    }

    private func deleteRemoteRows(table: String, ids: Set<UUID>) async throws {
        guard !ids.isEmpty else { return }

        for chunk in ids.map(\.uuidString).chunked(into: detailLookupChunkSize) {
            try await client
                .from(table)
                .delete()
                .in("id", values: chunk)
                .execute()
        }
    }

    private func softDeleteRemoteRows(table: String, ids: Set<UUID>) async throws {
        guard !ids.isEmpty else { return }
        let timestamp = ISO8601DateFormatter().string(from: Date())

        for chunk in ids.map(\.uuidString).chunked(into: detailLookupChunkSize) {
            try await client
                .from(table)
                .update(["deleted_at": timestamp])
                .in("id", values: chunk)
                .execute()
        }
    }

    public func pushRecipeIngredients(_ ingredientIds: [UUID]) async throws {
        guard await bootstrapAnonymousSessionIfNeeded() else { return }

        let ingredientIdSet = Set(ingredientIds)
        let rows = try await database.read { db in
            try DBRecipeIngredient.all
                .fetchAll(db)
                .filter { ingredientIdSet.contains($0.id) }
                .map(SupabaseRecipeIngredientRow.init)
        }

        guard !rows.isEmpty else { return }

        try await client
            .from("recipe_ingredients")
            .upsert(rows)
            .execute()
    }

    private func pushMealplan(homeId: UUID?) async throws {
        var entries = try await database.read { db in
            try DBMealplanEntry.all.fetchAll(db)
        }
        .filter { $0.homeId == homeId }
        .map(SupabaseMealplanEntryRow.init)
        if currentUserId == nil {
            _ = await bootstrapAnonymousSessionIfNeeded()
        }
        if let currentUserId {
            entries = entries.map {
                var row = $0
                row.updatedBy = currentUserId
                return row
            }
        }

        try await softDeleteRemoteStaleMealplanEntries(homeId: homeId, localEntryIds: Set(entries.map(\.id)))

        if !entries.isEmpty {
            try await client
                .from("mealplan_entries")
                .upsert(entries)
                .execute()
        }
    }

    private func softDeleteRemoteStaleMealplanEntries(homeId: UUID?, localEntryIds: Set<UUID>) async throws {
        var query = client
            .from("mealplan_entries")
            .select()

        if let homeId {
            query = query.eq("home_id", value: homeId.uuidString)
        } else {
            query = query.is("home_id", value: nil)
        }

        let remoteEntries: [SupabaseMealplanEntryRow] = try await query
            .is("deleted_at", value: nil)
            .execute()
            .value

        let staleEntryIds = Set(remoteEntries.map(\.id)).subtracting(localEntryIds)
        try await softDeleteRemoteRows(table: "mealplan_entries", ids: staleEntryIds)
    }

    private func pushShoppingLists(homeId: UUID?) async throws {
        var payload = try await database.read { db in
            let lists = try DBShoppingList.all.fetchAll(db).filter { $0.homeId == homeId }
            let listIds = Set(lists.map(\.id))
            let items = try DBShoppingListItem.all.fetchAll(db).filter { listIds.contains($0.listId) }
            let homeIdByItemId = Dictionary(uniqueKeysWithValues: items.map { ($0.id, homeId as UUID?) })
            let itemIds = Set(items.map(\.id))
            let ingredientLinks = try DBShoppingListItemIngredientLink.all.fetchAll(db).filter { itemIds.contains($0.shoppingListItemId) }
            let mealplanLinks = try DBShoppingListItemMealplanLink.all.fetchAll(db).filter { itemIds.contains($0.shoppingListItemId) }

            return (
                lists: lists.map(SupabaseShoppingListRow.init),
                items: items.map { SupabaseShoppingListItemRow($0, homeId: homeId) },
                ingredientLinks: ingredientLinks.map { SupabaseShoppingListItemIngredientLinkRow($0, homeId: homeIdByItemId[$0.shoppingListItemId] ?? nil) },
                mealplanLinks: mealplanLinks.map { SupabaseShoppingListItemMealplanLinkRow($0, homeId: homeIdByItemId[$0.shoppingListItemId] ?? nil) }
            )
        }
        if currentUserId == nil {
            _ = await bootstrapAnonymousSessionIfNeeded()
        }
        if let currentUserId {
            payload.lists = payload.lists.map {
                var row = $0
                row.updatedBy = currentUserId
                return row
            }
            payload.items = payload.items.map {
                var row = $0
                row.updatedBy = currentUserId
                return row
            }
        }

        RecipeDebugDiagnostics.logAppEvent(
            "supabase shopping push homeId=\(homeId?.uuidString ?? "personal") lists=\(payload.lists.count) items=\(payload.items.count) ingredientLinks=\(payload.ingredientLinks.count) mealplanLinks=\(payload.mealplanLinks.count)"
        )

        if !payload.lists.isEmpty {
            do {
                try await client.from("shopping_lists").upsert(payload.lists).execute()
            } catch {
                RecipeDebugDiagnostics.logAppEvent("supabase shopping_lists upsert failed count=\(payload.lists.count) error=\(error)")
                throw error
            }
        }
        if !payload.items.isEmpty {
            do {
                try await client.from("shopping_list_items").upsert(payload.items).execute()
            } catch {
                RecipeDebugDiagnostics.logAppEvent("supabase shopping_list_items upsert failed count=\(payload.items.count) error=\(error)")
                throw error
            }
        }
        if !payload.ingredientLinks.isEmpty {
            do {
                try await client.from("shopping_list_item_ingredient_links").upsert(payload.ingredientLinks).execute()
            } catch {
                RecipeDebugDiagnostics.logAppEvent("supabase shopping_list_item_ingredient_links upsert failed count=\(payload.ingredientLinks.count) error=\(error)")
                throw error
            }
        }
        if !payload.mealplanLinks.isEmpty {
            do {
                try await client.from("shopping_list_item_mealplan_links").upsert(payload.mealplanLinks).execute()
            } catch {
                RecipeDebugDiagnostics.logAppEvent("supabase shopping_list_item_mealplan_links upsert failed count=\(payload.mealplanLinks.count) error=\(error)")
                throw error
            }
        }
    }

    public func deleteShoppingListItems(_ itemIds: [UUID]) async {
        guard !itemIds.isEmpty else { return }
        guard await bootstrapAnonymousSessionIfNeeded() else { return }

        do {
            try await deleteRemoteRows(table: "shopping_list_items", ids: Set(itemIds))
        } catch {
            RecipeDebugDiagnostics.logAppEvent("supabase shopping_list_items explicit delete failed count=\(itemIds.count) error=\(error)")
        }
    }

    public func hydrateRecipeDetails(recipeIds: [UUID]) async {
        let uniqueRecipeIds = Array(Set(recipeIds))
        guard !uniqueRecipeIds.isEmpty else { return }
        guard await bootstrapAnonymousSessionIfNeeded() else { return }

        RecipeDebugDiagnostics.logAppEvent("supabase recipe detail hydrate requested count=\(uniqueRecipeIds.count)")
        for chunk in uniqueRecipeIds.chunked(into: recipeBootstrapChunkSize) {
            do {
                try await pullRecipeDetails(recipeIds: chunk)
            } catch {
                RecipeDebugDiagnostics.logAppEvent("supabase recipe detail hydrate failed count=\(chunk.count) error=\(error)")
            }
        }
    }

    private func deleteRemoteStaleShoppingLists(
        homeId: UUID?,
        payload: (
            lists: [SupabaseShoppingListRow],
            items: [SupabaseShoppingListItemRow],
            ingredientLinks: [SupabaseShoppingListItemIngredientLinkRow],
            mealplanLinks: [SupabaseShoppingListItemMealplanLinkRow]
        )
    ) async throws {
        let remoteLists: [SupabaseShoppingListRow] = try await scopedHomeQuery(table: "shopping_lists", homeId: homeId)
        let remoteItems: [SupabaseShoppingListItemRow] = try await scopedHomeQuery(table: "shopping_list_items", homeId: homeId)
        let remoteIngredientLinks: [SupabaseShoppingListItemIngredientLinkRow] = try await scopedHomeQuery(table: "shopping_list_item_ingredient_links", homeId: homeId)
        let remoteMealplanLinks: [SupabaseShoppingListItemMealplanLinkRow] = try await scopedHomeQuery(table: "shopping_list_item_mealplan_links", homeId: homeId)

        try await deleteRemoteRows(
            table: "shopping_list_item_ingredient_links",
            ids: Set(remoteIngredientLinks.map(\.id)).subtracting(Set(payload.ingredientLinks.map(\.id)))
        )
        try await deleteRemoteRows(
            table: "shopping_list_item_mealplan_links",
            ids: Set(remoteMealplanLinks.map(\.id)).subtracting(Set(payload.mealplanLinks.map(\.id)))
        )
        try await deleteRemoteRows(
            table: "shopping_list_items",
            ids: Set(remoteItems.map(\.id)).subtracting(Set(payload.items.map(\.id)))
        )
        try await deleteRemoteRows(
            table: "shopping_lists",
            ids: Set(remoteLists.map(\.id)).subtracting(Set(payload.lists.map(\.id)))
        )
    }

    private func pushRecipeOrganization(homeId: UUID?) async throws {
        var payload = try await database.read { db in
            let folders = try DBRecipeFolder.all.fetchAll(db).filter { $0.homeId == homeId }
            let folderIds = Set(folders.map(\.id))
            let hierarchy = try DBRecipeFolderHierarchy.all.fetchAll(db).filter {
                folderIds.contains($0.parentFolderId) || folderIds.contains($0.childFolderId)
            }
            let folderAssignments = try DBRecipeFolderAssignment.all.fetchAll(db).filter { folderIds.contains($0.folderId) }
            let tags = try DBRecipeTag.all.fetchAll(db).filter { $0.homeId == homeId }
            let tagIds = Set(tags.map(\.id))
            let tagAssignments = try DBRecipeTagAssignment.all.fetchAll(db).filter { tagIds.contains($0.tagId) }

            return (
                folders: folders.map(SupabaseRecipeFolderRow.init),
                hierarchy: hierarchy.map(SupabaseRecipeFolderHierarchyRow.init),
                folderAssignments: folderAssignments.map(SupabaseRecipeFolderAssignmentRow.init),
                tags: tags.map(SupabaseRecipeTagRow.init),
                tagAssignments: tagAssignments.map(SupabaseRecipeTagAssignmentRow.init)
            )
        }
        if currentUserId == nil {
            _ = await bootstrapAnonymousSessionIfNeeded()
        }
        if let currentUserId {
            payload.folders = payload.folders.map {
                var row = $0
                row.updatedBy = currentUserId
                return row
            }
            payload.tags = payload.tags.map {
                var row = $0
                row.updatedBy = currentUserId
                return row
            }
        }

        try await deleteRemoteStaleRecipeOrganization(homeId: homeId, payload: payload)

        if !payload.folders.isEmpty {
            try await client.from("recipe_folders").upsert(payload.folders).execute()
        }
        if !payload.hierarchy.isEmpty {
            try await client.from("recipe_folder_hierarchy").upsert(payload.hierarchy).execute()
        }
        if !payload.folderAssignments.isEmpty {
            try await client.from("recipe_folder_assignments").upsert(payload.folderAssignments).execute()
        }
        if !payload.tags.isEmpty {
            try await client.from("recipe_tags").upsert(payload.tags).execute()
        }
        if !payload.tagAssignments.isEmpty {
            try await client.from("recipe_tag_assignments").upsert(payload.tagAssignments).execute()
        }
    }

    private func deleteRemoteStaleRecipeOrganization(
        homeId: UUID?,
        payload: (
            folders: [SupabaseRecipeFolderRow],
            hierarchy: [SupabaseRecipeFolderHierarchyRow],
            folderAssignments: [SupabaseRecipeFolderAssignmentRow],
            tags: [SupabaseRecipeTagRow],
            tagAssignments: [SupabaseRecipeTagAssignmentRow]
        )
    ) async throws {
        let remoteFolders: [SupabaseRecipeFolderRow] = try await scopedHomeQuery(table: "recipe_folders", homeId: homeId)
        let remoteTags: [SupabaseRecipeTagRow] = try await scopedHomeQuery(table: "recipe_tags", homeId: homeId)
        let remoteFolderIds = Set(remoteFolders.map(\.id))
        let remoteTagIds = Set(remoteTags.map(\.id))

        let remoteHierarchy: [SupabaseRecipeFolderHierarchyRow] = try await rowsForFolderHierarchyScope(folderIds: remoteFolderIds)
        let remoteFolderAssignments: [SupabaseRecipeFolderAssignmentRow] = try await rowsForFolderScope(
            table: "recipe_folder_assignments",
            folderIds: remoteFolderIds
        )
        let remoteTagAssignments: [SupabaseRecipeTagAssignmentRow] = try await rowsForTagScope(
            table: "recipe_tag_assignments",
            tagIds: remoteTagIds
        )

        try await deleteRemoteRows(table: "recipe_tag_assignments", ids: Set(remoteTagAssignments.map(\.id)).subtracting(Set(payload.tagAssignments.map(\.id))))
        try await deleteRemoteRows(table: "recipe_folder_assignments", ids: Set(remoteFolderAssignments.map(\.id)).subtracting(Set(payload.folderAssignments.map(\.id))))
        try await deleteRemoteRows(table: "recipe_folder_hierarchy", ids: Set(remoteHierarchy.map(\.id)).subtracting(Set(payload.hierarchy.map(\.id))))
        try await deleteRemoteRows(table: "recipe_tags", ids: remoteTagIds.subtracting(Set(payload.tags.map(\.id))))
        try await deleteRemoteRows(table: "recipe_folders", ids: remoteFolderIds.subtracting(Set(payload.folders.map(\.id))))
    }

    private func scopedHomeQuery<Row: Decodable & Sendable>(table: String, homeId: UUID?) async throws -> [Row] {
        var query = client.from(table).select()
        if let homeId {
            query = query.eq("home_id", value: homeId.uuidString)
        } else {
            query = query.is("home_id", value: nil)
        }
        return try await query.execute().value
    }

    private func rowsForFolderScope<Row: Decodable & Sendable>(table: String, folderIds: Set<UUID>) async throws -> [Row] {
        guard !folderIds.isEmpty else { return [] }
        var rows: [Row] = []
        for chunk in folderIds.map(\.uuidString).chunked(into: detailLookupChunkSize) {
            let chunkRows: [Row] = try await client
                .from(table)
                .select()
                .in("folder_id", values: chunk)
                .execute()
                .value
            rows.append(contentsOf: chunkRows)
        }
        return rows
    }

    private func rowsForFolderHierarchyScope(folderIds: Set<UUID>) async throws -> [SupabaseRecipeFolderHierarchyRow] {
        guard !folderIds.isEmpty else { return [] }
        var rows: [SupabaseRecipeFolderHierarchyRow] = []
        for chunk in folderIds.map(\.uuidString).chunked(into: detailLookupChunkSize) {
            let chunkRows: [SupabaseRecipeFolderHierarchyRow] = try await client
                .from("recipe_folder_hierarchy")
                .select()
                .in("parent_folder_id", values: chunk)
                .execute()
                .value
            rows.append(contentsOf: chunkRows)
        }
        return rows
    }

    private func rowsForTagScope<Row: Decodable & Sendable>(table: String, tagIds: Set<UUID>) async throws -> [Row] {
        guard !tagIds.isEmpty else { return [] }
        var rows: [Row] = []
        for chunk in tagIds.map(\.uuidString).chunked(into: detailLookupChunkSize) {
            let chunkRows: [Row] = try await client
                .from(table)
                .select()
                .in("tag_id", values: chunk)
                .execute()
                .value
            rows.append(contentsOf: chunkRows)
        }
        return rows
    }

    private func pullRecipes(homeId: UUID?) async throws {
        var query = client
            .from("recipes")
            .select()

        if let homeId {
            query = query.eq("home_id", value: homeId.uuidString)
        } else {
            query = query.is("home_id", value: nil)
        }

        let remoteRecipes: [SupabaseRecipeRow] = try await query
            .is("deleted_at", value: nil)
            .execute()
            .value

        let remoteLocalRows = remoteRecipes.map { $0.localRow() }
        let localRecipesById = try await database.read { db in
            Dictionary(
                uniqueKeysWithValues: try DBRecipe.all
                    .fetchAll(db)
                    .map { ($0.id, $0) }
            )
        }
        let changedRecipeIds = remoteLocalRows.compactMap { remoteRecipe in
            localRecipesById[remoteRecipe.id] == remoteRecipe ? nil : remoteRecipe.id
        }

        try await database.write { db in
            for recipe in remoteLocalRows {
                try upsertIfChanged(recipe, in: db)
            }
        }

        try await pullRecipeImages(recipeIds: changedRecipeIds)

        for chunk in changedRecipeIds.chunked(into: recipeBootstrapChunkSize) {
            do {
                try await pullRecipeDetails(recipeIds: chunk)
            } catch {
                RecipeDebugDiagnostics.logAppEvent("supabase recipe detail batch pull failed count=\(chunk.count) error=\(error)")
            }
        }
    }

    private func pullRecipeDetails(recipeId: UUID) async throws {
        try await pullRecipeDetails(recipeIds: [recipeId])
    }

    private func pullRecipeImages(recipeIds: [UUID]) async throws {
        guard !recipeIds.isEmpty else { return }

        var images: [SupabaseRecipeImageRow] = []
        for chunk in recipeIds.map(\.uuidString).chunked(into: detailLookupChunkSize) {
            let rows: [SupabaseRecipeImageRow] = try await client
                .from("recipe_images")
                .select()
                .in("recipe_id", values: chunk)
                .execute()
                .value
            images.append(contentsOf: rows)
        }

        let localImages = images.map { $0.localRow() }
        try await database.write { db in
            for image in localImages {
                try upsertIfChanged(image, in: db)
            }
        }
    }

    private func pullRecipeDetails(recipeIds: [UUID]) async throws {
        guard !recipeIds.isEmpty else { return }
        let recipeIdValues = recipeIds.map(\.uuidString)

        let ingredientSections: [SupabaseRecipeIngredientSectionRow] = try await client
            .from("recipe_ingredient_sections")
            .select()
            .in("recipe_id", values: recipeIdValues)
            .order("sort_index", ascending: true)
            .execute()
            .value

        let stepSections: [SupabaseRecipeStepSectionRow] = try await client
            .from("recipe_step_sections")
            .select()
            .in("recipe_id", values: recipeIdValues)
            .order("sort_index", ascending: true)
            .execute()
            .value

        let ingredientGroupIds = ingredientSections.map(\.id).map(\.uuidString)
        let stepGroupIds = stepSections.map(\.id).map(\.uuidString)

        var ingredients: [SupabaseRecipeIngredientRow] = []
        for chunk in ingredientGroupIds.chunked(into: detailLookupChunkSize) {
            let rows: [SupabaseRecipeIngredientRow] = try await client
                .from("recipe_ingredients")
                .select()
                .in("ingredient_group_id", values: chunk)
                .order("sort_index", ascending: true)
                .execute()
                .value
            ingredients.append(contentsOf: rows)
        }

        var steps: [SupabaseRecipeStepRow] = []
        for chunk in stepGroupIds.chunked(into: detailLookupChunkSize) {
            let rows: [SupabaseRecipeStepRow] = try await client
                .from("recipe_steps")
                .select()
                .in("group_id", values: chunk)
                .order("sort_index", ascending: true)
                .execute()
                .value
            steps.append(contentsOf: rows)
        }

        let stepIds = steps.map(\.id).map(\.uuidString)
        var timings: [SupabaseRecipeStepTimingRow] = []
        var temperatures: [SupabaseRecipeStepTemperatureRow] = []
        var linkedIngredients: [SupabaseRecipeStepLinkedIngredientRow] = []
        for chunk in stepIds.chunked(into: detailLookupChunkSize) {
            let timingRows: [SupabaseRecipeStepTimingRow] = try await client
                .from("recipe_step_timings")
                .select()
                .in("recipe_step_id", values: chunk)
                .execute()
                .value
            timings.append(contentsOf: timingRows)

            let temperatureRows: [SupabaseRecipeStepTemperatureRow] = try await client
                .from("recipe_step_temperatures")
                .select()
                .in("recipe_step_id", values: chunk)
                .execute()
                .value
            temperatures.append(contentsOf: temperatureRows)

            let linkedIngredientRows: [SupabaseRecipeStepLinkedIngredientRow] = try await client
                .from("recipe_step_linked_ingredients")
                .select()
                .in("recipe_step_id", values: chunk)
                .order("sort_index", ascending: true)
                .execute()
                .value
            linkedIngredients.append(contentsOf: linkedIngredientRows)
        }

        let sortedIngredientSections = ingredientSections.sorted(by: { $0.sortIndex < $1.sortIndex })
        let sortedIngredients = ingredients.sorted(by: { $0.sortIndex < $1.sortIndex })
        let sortedStepSections = stepSections.sorted(by: { $0.sortIndex < $1.sortIndex })
        let sortedSteps = steps.sorted(by: { $0.sortIndex < $1.sortIndex })
        let fetchedTimings = timings
        let fetchedTemperatures = temperatures
        let sortedLinkedIngredients = linkedIngredients.sorted(by: { $0.sortIndex < $1.sortIndex })

        try await database.write { db in
            let remoteIngredientSectionIds = Set(sortedIngredientSections.map(\.id))
            let remoteIngredientIds = Set(sortedIngredients.map(\.id))
            let remoteStepSectionIds = Set(sortedStepSections.map(\.id))
            let remoteStepIds = Set(sortedSteps.map(\.id))
            let remoteTimingIds = Set(fetchedTimings.map(\.id))
            let remoteTemperatureIds = Set(fetchedTemperatures.map(\.id))
            let remoteLinkedIngredientIds = Set(sortedLinkedIngredients.map(\.id))

            for recipeId in recipeIds {
                let localIngredientGroupIds = Set(
                    try DBRecipeIngredientGroup
                        .where { $0.recipeId.eq(recipeId) }
                        .select(\.id)
                        .fetchAll(db)
                )
                let localStepGroupIds = Set(
                    try DBRecipeStepGroup
                        .where { $0.recipeId.eq(recipeId) }
                        .select(\.id)
                        .fetchAll(db)
                )
                let staleIngredientGroupIds = localIngredientGroupIds.subtracting(remoteIngredientSectionIds)
                let staleStepGroupIds = localStepGroupIds.subtracting(remoteStepSectionIds)

                if !staleIngredientGroupIds.isEmpty {
                    try DBRecipeIngredient
                        .where { staleIngredientGroupIds.contains($0.ingredientGroupId) }
                        .delete()
                        .execute(db)
                    try DBRecipeIngredientGroup
                        .where { staleIngredientGroupIds.contains($0.id) }
                        .delete()
                        .execute(db)
                }

                if !staleStepGroupIds.isEmpty {
                    let staleStepIds = Set(
                        try DBRecipeStep
                            .where { staleStepGroupIds.contains($0.groupId) }
                            .select(\.id)
                            .fetchAll(db)
                    )
                    if !staleStepIds.isEmpty {
                        try DBRecipeStepTiming
                            .where { staleStepIds.contains($0.recipeStepId) }
                            .delete()
                            .execute(db)
                        try DBRecipeStepTemperature
                            .where { staleStepIds.contains($0.recipeStepId) }
                            .delete()
                            .execute(db)
                        try DBRecipeStepLinkedIngredient
                            .where { staleStepIds.contains($0.recipeStepId) }
                            .delete()
                            .execute(db)
                    }
                    try DBRecipeStep
                        .where { staleStepGroupIds.contains($0.groupId) }
                        .delete()
                        .execute(db)
                    try DBRecipeStepGroup
                        .where { staleStepGroupIds.contains($0.id) }
                        .delete()
                        .execute(db)
                }

                let currentIngredientGroupIds = localIngredientGroupIds.intersection(remoteIngredientSectionIds)
                let currentStepGroupIds = localStepGroupIds.intersection(remoteStepSectionIds)

                if !currentIngredientGroupIds.isEmpty {
                    try DBRecipeIngredient
                        .where { currentIngredientGroupIds.contains($0.ingredientGroupId) && !remoteIngredientIds.contains($0.id) }
                        .delete()
                        .execute(db)
                }

                if !currentStepGroupIds.isEmpty {
                    let currentStepIds = Set(
                        try DBRecipeStep
                            .where { currentStepGroupIds.contains($0.groupId) }
                            .select(\.id)
                            .fetchAll(db)
                    )
                    let staleStepIds = currentStepIds.subtracting(remoteStepIds)
                    if !staleStepIds.isEmpty {
                        try DBRecipeStepTiming
                            .where { staleStepIds.contains($0.recipeStepId) }
                            .delete()
                            .execute(db)
                        try DBRecipeStepTemperature
                            .where { staleStepIds.contains($0.recipeStepId) }
                            .delete()
                            .execute(db)
                        try DBRecipeStepLinkedIngredient
                            .where { staleStepIds.contains($0.recipeStepId) }
                            .delete()
                            .execute(db)
                        try DBRecipeStep
                            .where { staleStepIds.contains($0.id) }
                            .delete()
                            .execute(db)
                    }
                    if !currentStepIds.isEmpty {
                        try DBRecipeStepTiming
                            .where { currentStepIds.contains($0.recipeStepId) && !remoteTimingIds.contains($0.id) }
                            .delete()
                            .execute(db)
                        try DBRecipeStepTemperature
                            .where { currentStepIds.contains($0.recipeStepId) && !remoteTemperatureIds.contains($0.id) }
                            .delete()
                            .execute(db)
                        try DBRecipeStepLinkedIngredient
                            .where { currentStepIds.contains($0.recipeStepId) && !remoteLinkedIngredientIds.contains($0.id) }
                            .delete()
                            .execute(db)
                    }
                }
            }

            for section in sortedIngredientSections {
                try upsertIfChanged(section.ingredientGroup, in: db)
            }

            for ingredient in sortedIngredients {
                try upsertIfChanged(ingredient.localRow(), in: db)
            }

            for section in sortedStepSections {
                try upsertIfChanged(section.stepGroup, in: db)
            }

            for step in sortedSteps {
                try upsertIfChanged(step.localRow(), in: db)
            }
            for timing in fetchedTimings {
                try upsertIfChanged(timing.localRow(), in: db)
            }
            for temperature in fetchedTemperatures {
                try upsertIfChanged(temperature.localRow(), in: db)
            }
            for linkedIngredient in sortedLinkedIngredients {
                try upsertIfChanged(linkedIngredient.localRow(), in: db)
            }
        }
    }

    private func pullMealplan(homeId: UUID?) async throws {
        var query = client
            .from("mealplan_entries")
            .select()

        if let homeId {
            query = query.eq("home_id", value: homeId.uuidString)
        } else {
            query = query.is("home_id", value: nil)
        }

        let entries: [SupabaseMealplanEntryRow] = try await query
            .is("deleted_at", value: nil)
            .execute()
            .value

        try await database.write { db in
            for entry in entries {
                try upsertIfChanged(entry.localRow(), in: db)
            }
        }
    }

    private func pullShoppingLists(homeId: UUID?) async throws {
        let shouldPruneLocalRows = try await hasPendingOutboxMutations() == false
        var listsQuery = client.from("shopping_lists").select()
        var itemsQuery = client.from("shopping_list_items").select()
        var ingredientLinksQuery = client.from("shopping_list_item_ingredient_links").select()
        var mealplanLinksQuery = client.from("shopping_list_item_mealplan_links").select()

        if let homeId {
            listsQuery = listsQuery.eq("home_id", value: homeId.uuidString)
            itemsQuery = itemsQuery.eq("home_id", value: homeId.uuidString)
            ingredientLinksQuery = ingredientLinksQuery.eq("home_id", value: homeId.uuidString)
            mealplanLinksQuery = mealplanLinksQuery.eq("home_id", value: homeId.uuidString)
        } else {
            listsQuery = listsQuery.is("home_id", value: nil)
            itemsQuery = itemsQuery.is("home_id", value: nil)
            ingredientLinksQuery = ingredientLinksQuery.is("home_id", value: nil)
            mealplanLinksQuery = mealplanLinksQuery.is("home_id", value: nil)
        }

        let lists: [SupabaseShoppingListRow] = try await listsQuery
            .is("deleted_at", value: nil)
            .execute()
            .value
        let items: [SupabaseShoppingListItemRow] = try await itemsQuery
            .is("deleted_at", value: nil)
            .execute()
            .value
        let ingredientLinks: [SupabaseShoppingListItemIngredientLinkRow] = try await ingredientLinksQuery
            .execute()
            .value
        let mealplanLinks: [SupabaseShoppingListItemMealplanLinkRow] = try await mealplanLinksQuery
            .execute()
            .value

        try await database.write { db in
            if shouldPruneLocalRows {
                let remoteListIds = Set(lists.map(\.id))
                let remoteItemIds = Set(items.map(\.id))
                let remoteIngredientLinkIds = Set(ingredientLinks.map(\.id))
                let remoteMealplanLinkIds = Set(mealplanLinks.map(\.id))

                let localListIds: Set<UUID>
                if let homeId {
                    localListIds = Set(
                        try DBShoppingList
                            .where { $0.homeId.eq(homeId) }
                            .select(\.id)
                            .fetchAll(db)
                    )
                } else {
                    localListIds = Set(
                        try DBShoppingList
                            .where { $0.homeId.is(nil) }
                            .select(\.id)
                            .fetchAll(db)
                    )
                }
                let localItems = try DBShoppingListItem.all.fetchAll(db).filter { localListIds.contains($0.listId) }
                let localItemIds = Set(localItems.map(\.id))
                let localIngredientLinkIds = Set(
                    try DBShoppingListItemIngredientLink.all.fetchAll(db)
                        .filter { localItemIds.contains($0.shoppingListItemId) }
                        .map(\.id)
                )
                let localMealplanLinkIds = Set(
                    try DBShoppingListItemMealplanLink.all.fetchAll(db)
                        .filter { localItemIds.contains($0.shoppingListItemId) }
                        .map(\.id)
                )

                let staleIngredientLinkIds = localIngredientLinkIds.subtracting(remoteIngredientLinkIds)
                if !staleIngredientLinkIds.isEmpty {
                    try DBShoppingListItemIngredientLink
                        .where { staleIngredientLinkIds.contains($0.id) }
                        .delete()
                        .execute(db)
                }
                let staleMealplanLinkIds = localMealplanLinkIds.subtracting(remoteMealplanLinkIds)
                if !staleMealplanLinkIds.isEmpty {
                    try DBShoppingListItemMealplanLink
                        .where { staleMealplanLinkIds.contains($0.id) }
                        .delete()
                        .execute(db)
                }
                let staleItemIds = localItemIds.subtracting(remoteItemIds)
                if !staleItemIds.isEmpty {
                    try DBShoppingListItem
                        .where { staleItemIds.contains($0.id) }
                        .delete()
                        .execute(db)
                }
                let staleListIds = localListIds.subtracting(remoteListIds)
                if !staleListIds.isEmpty {
                    try DBShoppingList
                        .where { staleListIds.contains($0.id) }
                        .delete()
                        .execute(db)
                }
            }

            for list in lists {
                try upsertIfChanged(list.localRow(), in: db)
            }
            for item in items {
                try upsertIfChanged(item.localRow(), in: db)
            }
            for link in ingredientLinks {
                try upsertIfChanged(link.localRow(), in: db)
            }
            for link in mealplanLinks {
                try upsertIfChanged(link.localRow(), in: db)
            }
        }
    }

    private func pullRecipeOrganization(homeId: UUID?) async throws {
        let shouldPruneLocalRows = try await hasPendingOutboxMutations() == false
        let folders: [SupabaseRecipeFolderRow] = try await scopedHomeQuery(table: "recipe_folders", homeId: homeId)
        let tags: [SupabaseRecipeTagRow] = try await scopedHomeQuery(table: "recipe_tags", homeId: homeId)
        let folderIds = Set(folders.map(\.id))
        let tagIds = Set(tags.map(\.id))

        let hierarchy = try await rowsForFolderHierarchyScope(folderIds: folderIds)
        let folderAssignments: [SupabaseRecipeFolderAssignmentRow] = try await rowsForFolderScope(
            table: "recipe_folder_assignments",
            folderIds: folderIds
        )
        let tagAssignments: [SupabaseRecipeTagAssignmentRow] = try await rowsForTagScope(
            table: "recipe_tag_assignments",
            tagIds: tagIds
        )

        try await database.write { db in
            if shouldPruneLocalRows {
                let remoteFolderIds = Set(folders.map(\.id))
                let remoteTagIds = Set(tags.map(\.id))
                let remoteHierarchyIds = Set(hierarchy.map(\.id))
                let remoteFolderAssignmentIds = Set(folderAssignments.map(\.id))
                let remoteTagAssignmentIds = Set(tagAssignments.map(\.id))

                let localFolderIds: Set<UUID>
                let localTagIds: Set<UUID>
                if let homeId {
                    localFolderIds = Set(
                        try DBRecipeFolder
                            .where { $0.homeId.eq(homeId) }
                            .select(\.id)
                            .fetchAll(db)
                    )
                    localTagIds = Set(
                        try DBRecipeTag
                            .where { $0.homeId.eq(homeId) }
                            .select(\.id)
                            .fetchAll(db)
                    )
                } else {
                    localFolderIds = Set(
                        try DBRecipeFolder
                            .where { $0.homeId.is(nil) }
                            .select(\.id)
                            .fetchAll(db)
                    )
                    localTagIds = Set(
                        try DBRecipeTag
                            .where { $0.homeId.is(nil) }
                            .select(\.id)
                            .fetchAll(db)
                    )
                }
                let localHierarchyIds = Set(
                    try DBRecipeFolderHierarchy.all.fetchAll(db)
                        .filter { localFolderIds.contains($0.parentFolderId) || localFolderIds.contains($0.childFolderId) }
                        .map(\.id)
                )
                let localFolderAssignmentIds = Set(
                    try DBRecipeFolderAssignment.all.fetchAll(db)
                        .filter { localFolderIds.contains($0.folderId) }
                        .map(\.id)
                )
                let localTagAssignmentIds = Set(
                    try DBRecipeTagAssignment.all.fetchAll(db)
                        .filter { localTagIds.contains($0.tagId) }
                        .map(\.id)
                )

                let staleTagAssignmentIds = localTagAssignmentIds.subtracting(remoteTagAssignmentIds)
                if !staleTagAssignmentIds.isEmpty {
                    try DBRecipeTagAssignment.where { staleTagAssignmentIds.contains($0.id) }.delete().execute(db)
                }
                let staleFolderAssignmentIds = localFolderAssignmentIds.subtracting(remoteFolderAssignmentIds)
                if !staleFolderAssignmentIds.isEmpty {
                    try DBRecipeFolderAssignment.where { staleFolderAssignmentIds.contains($0.id) }.delete().execute(db)
                }
                let staleHierarchyIds = localHierarchyIds.subtracting(remoteHierarchyIds)
                if !staleHierarchyIds.isEmpty {
                    try DBRecipeFolderHierarchy.where { staleHierarchyIds.contains($0.id) }.delete().execute(db)
                }
                let staleTagIds = localTagIds.subtracting(remoteTagIds)
                if !staleTagIds.isEmpty {
                    try DBRecipeTag.where { staleTagIds.contains($0.id) }.delete().execute(db)
                }
                let staleFolderIds = localFolderIds.subtracting(remoteFolderIds)
                if !staleFolderIds.isEmpty {
                    try DBRecipeFolder.where { staleFolderIds.contains($0.id) }.delete().execute(db)
                }
            }

            for folder in folders {
                try upsertIfChanged(folder.localRow(), in: db)
            }
            for row in hierarchy {
                try upsertIfChanged(row.localRow(), in: db)
            }
            for assignment in folderAssignments {
                try upsertIfChanged(assignment.localRow(), in: db)
            }
            for tag in tags {
                try upsertIfChanged(tag.localRow(), in: db)
            }
            for assignment in tagAssignments {
                try upsertIfChanged(assignment.localRow(), in: db)
            }
        }
    }

    nonisolated private func upsertIfChanged(_ row: DBRecipe, in db: Database) throws {
        guard try DBRecipe.find(row.id).fetchOne(db) != row else { return }
        try DBRecipe.upsert { row }.execute(db)
    }

    nonisolated private func upsertIfChanged(_ row: DBRecipeImage, in db: Database) throws {
        guard try DBRecipeImage.find(row.id).fetchOne(db) != row else { return }
        try DBRecipeImage.upsert { row }.execute(db)
    }

    nonisolated private func upsertIfChanged(_ row: DBRecipeIngredientGroup, in db: Database) throws {
        guard try DBRecipeIngredientGroup.find(row.id).fetchOne(db) != row else { return }
        try DBRecipeIngredientGroup.upsert { row }.execute(db)
    }

    nonisolated private func upsertIfChanged(_ row: DBRecipeIngredient, in db: Database) throws {
        guard try DBRecipeIngredient.find(row.id).fetchOne(db) != row else { return }
        try DBRecipeIngredient.upsert { row }.execute(db)
    }

    nonisolated private func upsertIfChanged(_ row: DBRecipeStepGroup, in db: Database) throws {
        guard try DBRecipeStepGroup.find(row.id).fetchOne(db) != row else { return }
        try DBRecipeStepGroup.upsert { row }.execute(db)
    }

    nonisolated private func upsertIfChanged(_ row: DBRecipeStep, in db: Database) throws {
        guard try DBRecipeStep.find(row.id).fetchOne(db) != row else { return }
        try DBRecipeStep.upsert { row }.execute(db)
    }

    nonisolated private func upsertIfChanged(_ row: DBRecipeStepTiming, in db: Database) throws {
        guard try DBRecipeStepTiming.find(row.id).fetchOne(db) != row else { return }
        try DBRecipeStepTiming.upsert { row }.execute(db)
    }

    nonisolated private func upsertIfChanged(_ row: DBRecipeStepTemperature, in db: Database) throws {
        guard try DBRecipeStepTemperature.find(row.id).fetchOne(db) != row else { return }
        try DBRecipeStepTemperature.upsert { row }.execute(db)
    }

    nonisolated private func upsertIfChanged(_ row: DBRecipeStepLinkedIngredient, in db: Database) throws {
        guard try DBRecipeStepLinkedIngredient.find(row.id).fetchOne(db) != row else { return }
        try DBRecipeStepLinkedIngredient.upsert { row }.execute(db)
    }

    nonisolated private func upsertIfChanged(_ row: DBRecipeFolder, in db: Database) throws {
        guard try DBRecipeFolder.find(row.id).fetchOne(db) != row else { return }
        try DBRecipeFolder.upsert { row }.execute(db)
    }

    nonisolated private func upsertIfChanged(_ row: DBRecipeFolderHierarchy, in db: Database) throws {
        guard try DBRecipeFolderHierarchy.find(row.id).fetchOne(db) != row else { return }
        try DBRecipeFolderHierarchy.upsert { row }.execute(db)
    }

    nonisolated private func upsertIfChanged(_ row: DBRecipeFolderAssignment, in db: Database) throws {
        guard try DBRecipeFolderAssignment.find(row.id).fetchOne(db) != row else { return }
        try DBRecipeFolderAssignment.upsert { row }.execute(db)
    }

    nonisolated private func upsertIfChanged(_ row: DBRecipeTag, in db: Database) throws {
        guard try DBRecipeTag.find(row.id).fetchOne(db) != row else { return }
        try DBRecipeTag.upsert { row }.execute(db)
    }

    nonisolated private func upsertIfChanged(_ row: DBRecipeTagAssignment, in db: Database) throws {
        guard try DBRecipeTagAssignment.find(row.id).fetchOne(db) != row else { return }
        try DBRecipeTagAssignment.upsert { row }.execute(db)
    }

    nonisolated private func upsertIfChanged(_ row: DBMealplanEntry, in db: Database) throws {
        guard try DBMealplanEntry.find(row.id).fetchOne(db) != row else { return }
        try DBMealplanEntry.upsert { row }.execute(db)
    }

    nonisolated private func upsertIfChanged(_ row: DBShoppingList, in db: Database) throws {
        guard try DBShoppingList.find(row.id).fetchOne(db) != row else { return }
        try DBShoppingList.upsert { row }.execute(db)
    }

    nonisolated private func upsertIfChanged(_ row: DBShoppingListItem, in db: Database) throws {
        if let existing = try DBShoppingListItem.find(row.id).fetchOne(db) {
            guard existing != row else { return }
            guard row.modifiedAt >= existing.modifiedAt else {
                RecipeDebugDiagnostics.logAppEvent(
                    "supabase shopping item stale apply skipped id=\(row.id.uuidString) remoteModifiedAt=\(row.modifiedAt) localModifiedAt=\(existing.modifiedAt)"
                )
                return
            }
        }
        try DBShoppingListItem.upsert { row }.execute(db)
    }

    nonisolated private func upsertIfChanged(_ row: DBShoppingListItemIngredientLink, in db: Database) throws {
        guard try DBShoppingListItemIngredientLink.find(row.id).fetchOne(db) != row else { return }
        try DBShoppingListItemIngredientLink.upsert { row }.execute(db)
    }

    nonisolated private func upsertIfChanged(_ row: DBShoppingListItemMealplanLink, in db: Database) throws {
        guard try DBShoppingListItemMealplanLink.find(row.id).fetchOne(db) != row else { return }
        try DBShoppingListItemMealplanLink.upsert { row }.execute(db)
    }

    private func apply(_ row: SupabaseRecipeRow) async throws {
        try await database.write { db in
            if row.deletedAt != nil {
                try DBRecipe.find(row.id).delete().execute(db)
            } else {
                try upsertIfChanged(row.localRow(), in: db)
            }
        }
    }

    private func apply(_ row: SupabaseRecipeImageRow) async throws {
        try await database.write { db in
            try upsertIfChanged(row.localRow(), in: db)
        }
    }

    private func apply(_ row: SupabaseRecipeIngredientSectionRow) async throws {
        try await database.write { db in
            try upsertIfChanged(row.ingredientGroup, in: db)
        }
    }

    private func apply(_ row: SupabaseRecipeIngredientRow) async throws {
        try await database.write { db in
            try upsertIfChanged(row.localRow(), in: db)
        }
    }

    private func apply(_ row: SupabaseRecipeStepSectionRow) async throws {
        try await database.write { db in
            try upsertIfChanged(row.stepGroup, in: db)
        }
    }

    private func apply(_ row: SupabaseRecipeStepRow) async throws {
        try await database.write { db in
            try upsertIfChanged(row.localRow(), in: db)
        }
    }

    private func apply(_ row: SupabaseRecipeStepTimingRow) async throws {
        try await database.write { db in
            try upsertIfChanged(row.localRow(), in: db)
        }
    }

    private func apply(_ row: SupabaseRecipeStepTemperatureRow) async throws {
        try await database.write { db in
            try upsertIfChanged(row.localRow(), in: db)
        }
    }

    private func apply(_ row: SupabaseRecipeStepLinkedIngredientRow) async throws {
        try await database.write { db in
            try upsertIfChanged(row.localRow(), in: db)
        }
    }

    private func apply(_ row: SupabaseRecipeFolderRow) async throws {
        try await database.write { db in
            try upsertIfChanged(row.localRow(), in: db)
        }
    }

    private func apply(_ row: SupabaseRecipeFolderHierarchyRow) async throws {
        try await database.write { db in
            try upsertIfChanged(row.localRow(), in: db)
        }
    }

    private func apply(_ row: SupabaseRecipeFolderAssignmentRow) async throws {
        try await database.write { db in
            try upsertIfChanged(row.localRow(), in: db)
        }
    }

    private func apply(_ row: SupabaseRecipeTagRow) async throws {
        try await database.write { db in
            try upsertIfChanged(row.localRow(), in: db)
        }
    }

    private func apply(_ row: SupabaseRecipeTagAssignmentRow) async throws {
        try await database.write { db in
            try upsertIfChanged(row.localRow(), in: db)
        }
    }

    private func deleteRecipeImageLocally(_ recipeId: UUID) async throws {
        try await database.write { db in
            try DBRecipeImage.find(recipeId).delete().execute(db)
        }
    }

    private func deleteRecipeIngredientSectionLocally(_ id: UUID) async throws {
        try await database.write { db in
            try DBRecipeIngredientGroup.find(id).delete().execute(db)
        }
    }

    private func deleteRecipeIngredientLocally(_ id: UUID) async throws {
        try await database.write { db in
            try DBRecipeIngredient.find(id).delete().execute(db)
        }
    }

    private func deleteRecipeStepSectionLocally(_ id: UUID) async throws {
        try await database.write { db in
            try DBRecipeStepGroup.find(id).delete().execute(db)
        }
    }

    private func deleteRecipeStepLocally(_ id: UUID) async throws {
        try await database.write { db in
            try DBRecipeStep.find(id).delete().execute(db)
        }
    }

    private func deleteRecipeStepTimingLocally(_ id: UUID) async throws {
        try await database.write { db in
            try DBRecipeStepTiming.find(id).delete().execute(db)
        }
    }

    private func deleteRecipeStepTemperatureLocally(_ id: UUID) async throws {
        try await database.write { db in
            try DBRecipeStepTemperature.find(id).delete().execute(db)
        }
    }

    private func deleteRecipeStepLinkedIngredientLocally(_ id: UUID) async throws {
        try await database.write { db in
            try DBRecipeStepLinkedIngredient.find(id).delete().execute(db)
        }
    }

    private func deleteRecipeFolderLocally(_ id: UUID) async throws {
        try await database.write { db in
            try DBRecipeFolder.find(id).delete().execute(db)
        }
    }

    private func deleteRecipeFolderHierarchyLocally(_ id: UUID) async throws {
        try await database.write { db in
            try DBRecipeFolderHierarchy.find(id).delete().execute(db)
        }
    }

    private func deleteRecipeFolderAssignmentLocally(_ id: UUID) async throws {
        try await database.write { db in
            try DBRecipeFolderAssignment.find(id).delete().execute(db)
        }
    }

    private func deleteRecipeTagLocally(_ id: UUID) async throws {
        try await database.write { db in
            try DBRecipeTag.find(id).delete().execute(db)
        }
    }

    private func deleteRecipeTagAssignmentLocally(_ id: UUID) async throws {
        try await database.write { db in
            try DBRecipeTagAssignment.find(id).delete().execute(db)
        }
    }

    private func apply(_ row: SupabaseMealplanEntryRow) async throws {
        try await database.write { db in
            if row.deletedAt != nil {
                try DBMealplanEntry.find(row.id).delete().execute(db)
            } else {
                try upsertIfChanged(row.localRow(), in: db)
            }
        }
    }

    private func deleteMealplanEntryLocally(_ id: UUID) async throws {
        try await database.write { db in

            try DBMealplanEntry.find(id).delete().execute(db)
        }
    }

    private func apply(_ row: SupabaseShoppingListRow) async throws {
        try await database.write { db in
            if row.deletedAt != nil {
                try DBShoppingList.find(row.id).delete().execute(db)
            } else {
                try upsertIfChanged(row.localRow(), in: db)
            }
        }
    }

    private func apply(_ row: SupabaseShoppingListItemRow) async throws {
        try await database.write { db in
            if row.deletedAt != nil {
                try DBShoppingListItem.find(row.id).delete().execute(db)
            } else {
                try upsertIfChanged(row.localRow(), in: db)
            }
        }
    }

    private func apply(_ row: SupabaseShoppingListItemIngredientLinkRow) async throws {
        try await database.write { db in
            try upsertIfChanged(row.localRow(), in: db)
        }
    }

    private func apply(_ row: SupabaseShoppingListItemMealplanLinkRow) async throws {
        try await database.write { db in
            try upsertIfChanged(row.localRow(), in: db)
        }
    }

    private func deleteRecipeLocally(_ id: UUID) async throws {
        try await database.write { db in
            try DBRecipe.find(id).delete().execute(db)
        }
    }

    private func deleteShoppingListLocally(_ id: UUID) async throws {
        try await database.write { db in
            try DBShoppingList.find(id).delete().execute(db)
        }
    }

    private func deleteShoppingListItemLocally(_ id: UUID) async throws {
        try await database.write { db in
            try DBShoppingListItem.find(id).delete().execute(db)
        }
    }

    private func deleteShoppingListItemIngredientLinkLocally(_ id: UUID) async throws {
        try await database.write { db in
            try DBShoppingListItemIngredientLink.find(id).delete().execute(db)
        }
    }

    private func deleteShoppingListItemMealplanLinkLocally(_ id: UUID) async throws {
        try await database.write { db in
            try DBShoppingListItemMealplanLink.find(id).delete().execute(db)
        }
    }

    private func scheduleRecipeHydration(recipeId: UUID) {
        pendingRecipeHydrationIds.insert(recipeId)
        guard recipeHydrationTask == nil else { return }

        recipeHydrationTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(350))
                await self.flushPendingRecipeHydrations()
            } catch is CancellationError {
            } catch {
                RecipeDebugDiagnostics.logAppEvent("supabase recipe detail hydration task failed error=\(error)")
            }
        }
    }

    private func flushPendingRecipeHydrations() async {
        let recipeIds = Array(pendingRecipeHydrationIds)
        pendingRecipeHydrationIds = []
        recipeHydrationTask = nil

        for chunk in recipeIds.chunked(into: recipeBootstrapChunkSize) {
            do {
                try await pullRecipeDetails(recipeIds: chunk)
            } catch {
                RecipeDebugDiagnostics.logAppEvent("supabase recipe detail hydration batch failed count=\(chunk.count) error=\(error)")
            }
        }
    }

    private func listenForRecipeChanges(_ channel: RealtimeChannelV2) {
        let decoder = realtimeDecoder
        let inserts = channel.postgresChange(InsertAction.self, schema: schema, table: "recipes")
        let updates = channel.postgresChange(UpdateAction.self, schema: schema, table: "recipes")
        let deletes = channel.postgresChange(DeleteAction.self, schema: schema, table: "recipes")

        realtimeTasks.append(Task {
            for await action in inserts {
                do {
                    let row = try action.decodeRecord(as: SupabaseRecipeRow.self, decoder: decoder)
                    guard await self.shouldIgnoreSelfOriginated(row.updatedBy) == false else { continue }
                    self.logRealtime("recipe insert id=\(row.id) homeId=\(row.homeId?.uuidString ?? "personal")")
                    try await self.apply(row)
                    if row.deletedAt == nil {
                        self.scheduleRecipeHydration(recipeId: row.id)
                    }
                } catch {
                    RecipeDebugDiagnostics.logAppEvent("supabase recipe insert apply failed error=\(error)")
                }
            }
        })

        realtimeTasks.append(Task {
            for await action in updates {
                do {
                    let row = try action.decodeRecord(as: SupabaseRecipeRow.self, decoder: decoder)
                    guard await self.shouldIgnoreSelfOriginated(row.updatedBy) == false else { continue }
                    self.logRealtime("recipe update id=\(row.id) homeId=\(row.homeId?.uuidString ?? "personal") deleted=\(row.deletedAt != nil)")
                    try await self.apply(row)
                } catch {
                    RecipeDebugDiagnostics.logAppEvent("supabase recipe update apply failed error=\(error)")
                }
            }
        })

        realtimeTasks.append(Task {
            for await action in deletes {
                do {
                    guard let id = self.decodeUUID(action.oldRecord["id"]) else { continue }
                    self.logRealtime("recipe delete id=\(id)")
                    try await self.deleteRecipeLocally(id)
                } catch {
                    RecipeDebugDiagnostics.logAppEvent("supabase recipe delete apply failed error=\(error)")
                }
            }
        })
    }

    private func listenForRecipeDetailChanges(_ channel: RealtimeChannelV2) {
        listenForModelChanges(channel, table: "recipe_ingredient_sections", type: SupabaseRecipeIngredientSectionRow.self) { row in
            try await self.apply(row)
        } delete: { record in
            guard let id = await self.decodeUUID(record["id"]) else { return }
            try await self.deleteRecipeIngredientSectionLocally(id)
        }

        listenForModelChanges(channel, table: "recipe_ingredients", type: SupabaseRecipeIngredientRow.self) { row in
            try await self.apply(row)
        } delete: { record in
            guard let id = await self.decodeUUID(record["id"]) else { return }
            try await self.deleteRecipeIngredientLocally(id)
        }

        listenForModelChanges(channel, table: "recipe_step_sections", type: SupabaseRecipeStepSectionRow.self) { row in
            try await self.apply(row)
        } delete: { record in
            guard let id = await self.decodeUUID(record["id"]) else { return }
            try await self.deleteRecipeStepSectionLocally(id)
        }

        listenForModelChanges(channel, table: "recipe_steps", type: SupabaseRecipeStepRow.self) { row in
            try await self.apply(row)
        } delete: { record in
            guard let id = await self.decodeUUID(record["id"]) else { return }
            try await self.deleteRecipeStepLocally(id)
        }

        listenForModelChanges(channel, table: "recipe_step_timings", type: SupabaseRecipeStepTimingRow.self) { row in
            try await self.apply(row)
        } delete: { record in
            guard let id = await self.decodeUUID(record["id"]) else { return }
            try await self.deleteRecipeStepTimingLocally(id)
        }

        listenForModelChanges(channel, table: "recipe_step_temperatures", type: SupabaseRecipeStepTemperatureRow.self) { row in
            try await self.apply(row)
        } delete: { record in
            guard let id = await self.decodeUUID(record["id"]) else { return }
            try await self.deleteRecipeStepTemperatureLocally(id)
        }

        listenForModelChanges(channel, table: "recipe_step_linked_ingredients", type: SupabaseRecipeStepLinkedIngredientRow.self) { row in
            try await self.apply(row)
        } delete: { record in
            guard let id = await self.decodeUUID(record["id"]) else { return }
            try await self.deleteRecipeStepLinkedIngredientLocally(id)
        }
    }

    private func listenForRecipeImageChanges(_ channel: RealtimeChannelV2) {
        listenForModelChanges(channel, table: "recipe_images", type: SupabaseRecipeImageRow.self) { row in
            try await self.apply(row)
        } delete: { record in
            guard let recipeId = await self.decodeUUID(record["recipe_id"]) else { return }
            try await self.deleteRecipeImageLocally(recipeId)
        }
    }

    private func listenForRecipeDetailScopeChanges(_ channel: RealtimeChannelV2, table: String, recipeIdKey: String) {
        let inserts = channel.postgresChange(InsertAction.self, schema: schema, table: table)
        let updates = channel.postgresChange(UpdateAction.self, schema: schema, table: table)
        let deletes = channel.postgresChange(DeleteAction.self, schema: schema, table: table)

        realtimeTasks.append(Task {
            for await action in inserts {
                self.scheduleRecipeHydrationFromRecord(action.record, recipeIdKey: recipeIdKey)
            }
        })
        realtimeTasks.append(Task {
            for await action in updates {
                self.scheduleRecipeHydrationFromRecord(action.record, recipeIdKey: recipeIdKey)
            }
        })
        realtimeTasks.append(Task {
            for await action in deletes {
                self.scheduleRecipeHydrationFromRecord(action.oldRecord, recipeIdKey: recipeIdKey)
            }
        })
    }

    private func listenForIngredientChanges(_ channel: RealtimeChannelV2) {
        let table = "recipe_ingredients"
        let inserts = channel.postgresChange(InsertAction.self, schema: schema, table: table)
        let updates = channel.postgresChange(UpdateAction.self, schema: schema, table: table)
        let deletes = channel.postgresChange(DeleteAction.self, schema: schema, table: table)

        realtimeTasks.append(Task {
            for await action in inserts {
                await self.scheduleRecipeHydrationForIngredient(action.record)
            }
        })
        realtimeTasks.append(Task {
            for await action in updates {
                await self.scheduleRecipeHydrationForIngredient(action.record)
            }
        })
        realtimeTasks.append(Task {
            for await action in deletes {
                await self.scheduleRecipeHydrationForIngredient(action.oldRecord)
            }
        })
    }

    private func listenForStepChanges(_ channel: RealtimeChannelV2) {
        let table = "recipe_steps"
        let inserts = channel.postgresChange(InsertAction.self, schema: schema, table: table)
        let updates = channel.postgresChange(UpdateAction.self, schema: schema, table: table)
        let deletes = channel.postgresChange(DeleteAction.self, schema: schema, table: table)

        realtimeTasks.append(Task {
            for await action in inserts {
                await self.scheduleRecipeHydrationForStep(action.record)
            }
        })
        realtimeTasks.append(Task {
            for await action in updates {
                await self.scheduleRecipeHydrationForStep(action.record)
            }
        })
        realtimeTasks.append(Task {
            for await action in deletes {
                await self.scheduleRecipeHydrationForStep(action.oldRecord)
            }
        })
    }

    private func listenForStepChildChanges(_ channel: RealtimeChannelV2, table: String) {
        let inserts = channel.postgresChange(InsertAction.self, schema: schema, table: table)
        let updates = channel.postgresChange(UpdateAction.self, schema: schema, table: table)
        let deletes = channel.postgresChange(DeleteAction.self, schema: schema, table: table)

        realtimeTasks.append(Task {
            for await action in inserts {
                await self.scheduleRecipeHydrationForStepChild(action.record)
            }
        })
        realtimeTasks.append(Task {
            for await action in updates {
                await self.scheduleRecipeHydrationForStepChild(action.record)
            }
        })
        realtimeTasks.append(Task {
            for await action in deletes {
                await self.scheduleRecipeHydrationForStepChild(action.oldRecord)
            }
        })
    }

    private func scheduleRecipeHydrationFromRecord(_ record: [String: AnyJSON], recipeIdKey: String) {
        guard let recipeIdValue = record[recipeIdKey] else { return }
        do {
            let recipeId = try recipeIdValue.decode(as: UUID.self, decoder: realtimeDecoder)
            scheduleRecipeHydration(recipeId: recipeId)
        } catch {
            RecipeDebugDiagnostics.logAppEvent("supabase recipe detail record decode failed error=\(error)")
        }
    }

    private func scheduleRecipeHydrationForIngredient(_ record: [String: AnyJSON]) async {
        guard let groupId = decodeUUID(record["ingredient_group_id"]) else { return }
        await scheduleRecipeHydrationForIngredientGroup(groupId)
    }

    private func scheduleRecipeHydrationForStep(_ record: [String: AnyJSON]) async {
        guard let groupId = decodeUUID(record["group_id"]) else { return }
        await scheduleRecipeHydrationForStepGroup(groupId)
    }

    private func scheduleRecipeHydrationForStepChild(_ record: [String: AnyJSON]) async {
        guard let stepId = decodeUUID(record["recipe_step_id"]) else { return }
        await scheduleRecipeHydrationForStepChild(stepId: stepId)
    }

    private func scheduleRecipeHydrationForStepChild(stepId: UUID) async {
        do {
            let step: SupabaseRecipeStepRow = try await client
                .from("recipe_steps")
                .select()
                .eq("id", value: stepId.uuidString)
                .single()
                .execute()
                .value
            await scheduleRecipeHydrationForStepGroup(step.groupId)
        } catch {
            RecipeDebugDiagnostics.logAppEvent("supabase recipe step child hydration lookup failed error=\(error)")
        }
    }

    private func scheduleRecipeHydrationForIngredientGroup(_ groupId: UUID) async {
        do {
            let section: SupabaseRecipeIngredientSectionRow = try await client
                .from("recipe_ingredient_sections")
                .select()
                .eq("id", value: groupId.uuidString)
                .single()
                .execute()
                .value
            scheduleRecipeHydration(recipeId: section.recipeId)
        } catch {
            RecipeDebugDiagnostics.logAppEvent("supabase ingredient hydration lookup failed error=\(error)")
        }
    }

    private func scheduleRecipeHydrationForStepGroup(_ groupId: UUID) async {
        do {
            let section: SupabaseRecipeStepSectionRow = try await client
                .from("recipe_step_sections")
                .select()
                .eq("id", value: groupId.uuidString)
                .single()
                .execute()
                .value
            scheduleRecipeHydration(recipeId: section.recipeId)
        } catch {
            RecipeDebugDiagnostics.logAppEvent("supabase step hydration lookup failed error=\(error)")
        }
    }

    private func decodeUUID(_ value: AnyJSON?) -> UUID? {
        guard let value else { return nil }
        return try? value.decode(as: UUID.self, decoder: realtimeDecoder)
    }

    private func listenForMealplanChanges(_ channel: RealtimeChannelV2) {
        let decoder = realtimeDecoder
        let inserts = channel.postgresChange(InsertAction.self, schema: schema, table: "mealplan_entries")
        let updates = channel.postgresChange(UpdateAction.self, schema: schema, table: "mealplan_entries")
        let deletes = channel.postgresChange(DeleteAction.self, schema: schema, table: "mealplan_entries")

        realtimeTasks.append(Task {
            for await action in inserts {
                do {
                    let row = try action.decodeRecord(as: SupabaseMealplanEntryRow.self, decoder: decoder)
                    guard await self.shouldIgnoreSelfOriginated(row.updatedBy) == false else { continue }
                    self.logRealtime("mealplan insert id=\(row.id) homeId=\(row.homeId?.uuidString ?? "personal")")
                    try await self.apply(row)
                } catch {
                    RecipeDebugDiagnostics.logAppEvent("supabase mealplan insert apply failed error=\(error)")
                }
            }
        })

        realtimeTasks.append(Task {
            for await action in updates {
                do {
                    let row = try action.decodeRecord(as: SupabaseMealplanEntryRow.self, decoder: decoder)
                    guard await self.shouldIgnoreSelfOriginated(row.updatedBy) == false else { continue }
                    self.logRealtime("mealplan update id=\(row.id) homeId=\(row.homeId?.uuidString ?? "personal") deleted=\(row.deletedAt != nil)")
                    try await self.apply(row)
                } catch {
                    RecipeDebugDiagnostics.logAppEvent("supabase mealplan update apply failed error=\(error)")
                }
            }
        })

        realtimeTasks.append(Task {
            for await action in deletes {
                do {
                    guard let id = self.decodeUUID(action.oldRecord["id"]) else { continue }
                    self.logRealtime("mealplan delete id=\(id)")
                    try await self.deleteMealplanEntryLocally(id)
                } catch {
                    RecipeDebugDiagnostics.logAppEvent("supabase mealplan delete apply failed error=\(error)")
                }
            }
        })
    }

    private func listenForShoppingListChanges(_ channel: RealtimeChannelV2) {
        listenForModelChanges(channel, table: "shopping_lists", type: SupabaseShoppingListRow.self) { row in
            try await self.apply(row)
        } delete: { record in
            guard let id = await self.decodeUUID(record["id"]) else { return }
            try await self.deleteShoppingListLocally(id)
        }
        listenForModelChanges(channel, table: "shopping_list_items", type: SupabaseShoppingListItemRow.self) { row in
            try await self.apply(row)
        } delete: { record in
            guard let id = await self.decodeUUID(record["id"]) else { return }
            try await self.deleteShoppingListItemLocally(id)
        }
        listenForModelChanges(channel, table: "shopping_list_item_ingredient_links", type: SupabaseShoppingListItemIngredientLinkRow.self) { row in
            try await self.apply(row)
        } delete: { record in
            guard let id = await self.decodeUUID(record["id"]) else { return }
            try await self.deleteShoppingListItemIngredientLinkLocally(id)
        }
        listenForModelChanges(channel, table: "shopping_list_item_mealplan_links", type: SupabaseShoppingListItemMealplanLinkRow.self) { row in
            try await self.apply(row)
        } delete: { record in
            guard let id = await self.decodeUUID(record["id"]) else { return }
            try await self.deleteShoppingListItemMealplanLinkLocally(id)
        }
    }

    private func listenForRecipeOrganizationChanges(_ channel: RealtimeChannelV2) {
        listenForModelChanges(channel, table: "recipe_folders", type: SupabaseRecipeFolderRow.self) { row in
            try await self.apply(row)
        } delete: { record in
            guard let id = await self.decodeUUID(record["id"]) else { return }
            try await self.deleteRecipeFolderLocally(id)
        }
        listenForModelChanges(channel, table: "recipe_folder_hierarchy", type: SupabaseRecipeFolderHierarchyRow.self) { row in
            try await self.apply(row)
        } delete: { record in
            guard let id = await self.decodeUUID(record["id"]) else { return }
            try await self.deleteRecipeFolderHierarchyLocally(id)
        }
        listenForModelChanges(channel, table: "recipe_folder_assignments", type: SupabaseRecipeFolderAssignmentRow.self) { row in
            try await self.apply(row)
        } delete: { record in
            guard let id = await self.decodeUUID(record["id"]) else { return }
            try await self.deleteRecipeFolderAssignmentLocally(id)
        }
        listenForModelChanges(channel, table: "recipe_tags", type: SupabaseRecipeTagRow.self) { row in
            try await self.apply(row)
        } delete: { record in
            guard let id = await self.decodeUUID(record["id"]) else { return }
            try await self.deleteRecipeTagLocally(id)
        }
        listenForModelChanges(channel, table: "recipe_tag_assignments", type: SupabaseRecipeTagAssignmentRow.self) { row in
            try await self.apply(row)
        } delete: { record in
            guard let id = await self.decodeUUID(record["id"]) else { return }
            try await self.deleteRecipeTagAssignmentLocally(id)
        }
    }

    private func listenForUpserts<Row: Decodable & Sendable>(
        _ channel: RealtimeChannelV2,
        table: String,
        type: Row.Type,
        apply: @escaping @Sendable (Row) async throws -> Void
    ) {
        let decoder = realtimeDecoder
        let inserts = channel.postgresChange(InsertAction.self, schema: schema, table: table)
        let updates = channel.postgresChange(UpdateAction.self, schema: schema, table: table)

        realtimeTasks.append(Task {
            for await action in inserts {
                do {
                    let row = try action.decodeRecord(as: type, decoder: decoder)
                    if let originTracked = row as? any SupabaseOriginTracked,
                       await self.shouldIgnoreSelfOriginated(originTracked.updatedBy) {
                        continue
                    }
                    try await apply(row)
                } catch {
                    RecipeDebugDiagnostics.logAppEvent("supabase \(table) insert apply failed error=\(error)")
                }
            }
        })

        realtimeTasks.append(Task {
            for await action in updates {
                do {
                    let row = try action.decodeRecord(as: type, decoder: decoder)
                    if let originTracked = row as? any SupabaseOriginTracked,
                       await self.shouldIgnoreSelfOriginated(originTracked.updatedBy) {
                        continue
                    }
                    try await apply(row)
                } catch {
                    RecipeDebugDiagnostics.logAppEvent("supabase \(table) update apply failed error=\(error)")
                }
            }
        })
    }

    private func listenForModelChanges<Row: Decodable & Sendable>(
        _ channel: RealtimeChannelV2,
        table: String,
        type: Row.Type,
        apply: @escaping @Sendable (Row) async throws -> Void,
        delete: @escaping @Sendable ([String: AnyJSON]) async throws -> Void
    ) {
        let decoder = realtimeDecoder
        let inserts = channel.postgresChange(InsertAction.self, schema: schema, table: table)
        let updates = channel.postgresChange(UpdateAction.self, schema: schema, table: table)
        let deletes = channel.postgresChange(DeleteAction.self, schema: schema, table: table)

        realtimeTasks.append(Task {
            for await action in inserts {
                do {
                    let row = try action.decodeRecord(as: type, decoder: decoder)
                    if let originTracked = row as? any SupabaseOriginTracked,
                       await self.shouldIgnoreSelfOriginated(originTracked.updatedBy) {
                        continue
                    }
                    try await apply(row)
                } catch {
                    RecipeDebugDiagnostics.logAppEvent("supabase \(table) insert apply failed error=\(error)")
                }
            }
        })

        realtimeTasks.append(Task {
            for await action in updates {
                do {
                    let row = try action.decodeRecord(as: type, decoder: decoder)
                    if let originTracked = row as? any SupabaseOriginTracked,
                       await self.shouldIgnoreSelfOriginated(originTracked.updatedBy) {
                        continue
                    }
                    try await apply(row)
                } catch {
                    RecipeDebugDiagnostics.logAppEvent("supabase \(table) update apply failed error=\(error)")
                }
            }
        })

        realtimeTasks.append(Task {
            for await action in deletes {
                do {
                    try await delete(action.oldRecord)
                } catch {
                    RecipeDebugDiagnostics.logAppEvent("supabase \(table) delete apply failed error=\(error)")
                }
            }
        })
    }
}

private enum SupabaseSyncError: Error {
    case authUnavailable
    case missingEntityId
    case missingInviteToken
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map { start in
            Array(self[start..<Swift.min(start + size, count)])
        }
    }
}
