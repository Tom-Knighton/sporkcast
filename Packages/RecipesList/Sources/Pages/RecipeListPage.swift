//
//  RecipeListPage.swift
//  RecipesList
//
//  Created by Tom Knighton on 19/09/2025.
//

import SwiftUI
import Environment
import API
import Design
import Models
import Persistence
import RecipeImporting

public struct RecipeListPage: View {

    @Environment(ZoomManager.self) private var zoomManager
    @Environment(\.homeServices) private var homes
    @Environment(AppRouter.self) private var router
    @Environment(\.networkClient) private var client
    @Environment(\.appSettings) private var appSettings
    @Environment(\.flagKit) private var flagKit

    @Binding private var pendingSharedImportURL: URL?
    private let initialFolderID: UUID?
    private let recipeOrganizationFeatureAccessFallback: Bool
    private let socialRecipeImportFeatureAccessFallback: Bool
    @State private var importState = RecipeListImportState()
    @State private var importSuccessFeedbackToken: Int = 0
    @State private var importFailureFeedbackToken: Int = 0
    @State private var repository = RecipesRepository()
    @State private var organizationRepository = RecipeOrganizationRepository()
    @State private var showDeleteConfirmId: UUID?
    @State private var searchText: String = ""
    @State private var isFilterSheetPresented = false
    @State private var isProPaywallPresented = false
    @State private var organizationRecipe: Recipe?
    @State private var filters = RecipeFilters()

    private var searchTokens: [String] {
        searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedLowercase
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }

    private var filteredRecipes: [Recipe] {
        let tokens = searchTokens
        let filtered = repository.recipes
            .filter { recipe in
                matchesSearchText(recipe, searchTokens: tokens) && matchesFilters(recipe)
            }
        return sortedRecipes(filtered)
    }

    private var navigationTitle: String {
        guard hasRecipeOrganizationProAccess,
              let folderName = organizationRepository.folder(id: filters.selectedFolderID)?.name else {
            return "Recipes"
        }

        return folderName
    }

    public init(
        pendingSharedImportURL: Binding<URL?> = .constant(nil),
        initialFolderID: UUID? = nil,
        recipeOrganizationFeatureAccessFallback: Bool = false,
        socialRecipeImportFeatureAccessFallback: Bool = false
    ) {
        self._pendingSharedImportURL = pendingSharedImportURL
        self.initialFolderID = initialFolderID
        self.recipeOrganizationFeatureAccessFallback = recipeOrganizationFeatureAccessFallback
        self.socialRecipeImportFeatureAccessFallback = socialRecipeImportFeatureAccessFallback
        self._filters = State(initialValue: RecipeFilters(selectedFolderID: initialFolderID))
    }

    public var body: some View {
        ZStack {
            @Bindable var zm = zoomManager
            Color.layer1.ignoresSafeArea()

            RecipeCardsListView(
                recipes: filteredRecipes,
                zoomNamespace: zm.zoomNamespace,
                onOpen: { recipe in
                    router.navigateTo(.recipe(recipe: recipe))
                },
                onDelete: { id in
                    Task {
                        await deleteRecipe(id: id)
                    }
                },
                canOrganize: hasRecipeOrganizationProAccess,
                canShowOrganizeUpsell: !hasRecipeOrganizationProAccess,
                onOrganize: { recipe in
                    organizationRecipe = recipe
                },
                onOrganizeUpsell: {
                    isProPaywallPresented = true
                },
                showDeleteConfirmId: $showDeleteConfirmId
            )
        }
        .navigationTitle(navigationTitle)
        .toolbar { toolbarContent }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: Text("Search recipes, ingredients..."))
        .sheet(isPresented: $importState.isAddRecipeSheetPresented) {
            AddRecipeSheet(options: addRecipeOptions, hasProAccess: hasSocialRecipeImportProAccess) { action in
                handleAddAction(action)
            }
            .presentationDetents([.height(hasSocialRecipeImportProAccess ? 340 : 430)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $importState.isURLAddSheetPresented) {
            AddRecipeURLSheet(urlText: $importState.webURLInput) {
                startWebURLImport()
            }
            .presentationDetents([.height(260)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $importState.isImportAppSelectionPresented) {
            ImportAppSelectionSheet { source in
                importState.beginFileImport(for: source)
            }
            .presentationDetents([.height(390)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $importState.isImportStatusSheetPresented, onDismiss: dismissImportSheet) {
            RecipeImportStatusSheet(
                startedAt: importState.importStartedAt,
                statusTitle: importState.importStatusTitle,
                statusSubtitle: importState.importStatusSubtitle,
                failureMessage: importState.importFailureMessage,
                onRetry: retryRecipeImport,
                onDismiss: dismissImportSheet
            )
            .interactiveDismissDisabled(importState.importFailureMessage == nil)
            .presentationDetents(importState.importFailureMessage == nil ? [.height(250)] : [.height(330)])
            .presentationDragIndicator(importState.importFailureMessage == nil ? .hidden : .visible)
        }
        .sheet(isPresented: $importState.isMarkdownImportPresented) {
            MarkdownImportSheet(text: $importState.markdownInput) {
                startImport(from: .markdownText(importState.markdownInput))
            }
        }
        .sheet(isPresented: $importState.isWebSelectionImportPresented) {
            TextRecipeImportSheet(
                title: "Import Web Selection",
                description: "Paste the highlighted recipe text from the website.",
                actionTitle: "Import",
                text: $importState.webSelectionInput,
                onSubmit: {
                    startImport(from: .webSelection(text: importState.webSelectionInput, sourceURL: nil))
                }
            )
        }
        .sheet(isPresented: $importState.isOCRImportPresented) {
            OCRImportSheet { extractedText in
                startImport(from: .ocrText(extractedText))
            }
        }
        .sheet(isPresented: $importState.isSelectionSheetPresented) {
            RecipeImportSelectionSheet(
                candidates: importState.preparedCandidates,
                selectedIDs: $importState.selectedCandidateIDs,
                onImportSelected: {
                    let candidates = importState.preparedCandidates.filter { importState.selectedCandidateIDs.contains($0.id) }
                    Task {
                        await Task.yield()
                        await processCandidates(candidates)
                    }
                }
            )
        }
        .sheet(isPresented: $importState.isPreviewEditSheetPresented) {
            if let candidate = importState.previewCandidate {
                RecipeImportPreviewEditSheet(
                    candidate: candidate,
                    onCancel: {
                        importState.clearPreviewEdit()
                    },
                    onSave: { editedCandidate in
                        importState.clearPreviewEdit()
                        Task {
                            await Task.yield()
                            await processCandidates([editedCandidate])
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $importState.isDuplicateResolutionPresented) {
            RecipeDuplicateResolutionSheet(
                candidates: importState.preparedCandidates,
                duplicates: importState.duplicateMatches,
                onConfirm: { decisions in
                    Task {
                        await Task.yield()
                        await persistCandidates(importState.preparedCandidates, decisions: decisions)
                    }
                }
            )
        }
        .fileImporter(
            isPresented: $importState.isFileImporterPresented,
            allowedContentTypes: importState.fileImporterContentTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let first = urls.first else {
                    importState.clearSelectedImportAppSource()
                    return
                }
                startImport(from: .fileURL(first, vendorHint: importState.selectedFileVendorHint))
                importState.clearSelectedImportAppSource()
            case .failure(let error):
                importState.clearSelectedImportAppSource()
                importState.presentFailure(mapImportError(error))
                importFailureFeedbackToken += 1
            }
        }
        .sensoryFeedback(.success, trigger: importSuccessFeedbackToken)
        .sensoryFeedback(.error, trigger: importFailureFeedbackToken)
        .sheet(isPresented: $isFilterSheetPresented) {
            RecipeFiltersSheet(
                filters: $filters,
                folderSummaries: organizationRepository.folderSummaries(homeId: homes.home?.id),
                tagSummaries: organizationRepository.tagSummaries(homeId: homes.home?.id),
                isRecipeOrganizationEnabled: hasRecipeOrganizationProAccess
            )
        }
        .sheet(item: $organizationRecipe) { recipe in
            RecipeOrganizationAssignmentSheet(
                recipe: recipe,
                repository: organizationRepository,
                homeId: homes.home?.id
            )
        }
        .sheet(isPresented: $isProPaywallPresented) {
            ProPaywallView()
        }
        .task(id: pendingSharedImportURL) {
            importPendingSharedURLIfNeeded()
        }
        .onChange(of: hasRecipeOrganizationProAccess) { _, isEnabled in
            guard !isEnabled else { return }
            filters.selectedFolderID = nil
            filters.selectedTagIDs = []
            organizationRecipe = nil
        }
    }
}

private extension RecipeListPage {

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Button(action: presentFilters) {
                Image(systemName: filters.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
            }
        }
        
        if hasRecipeOrganizationProAccess {
            ToolbarItem {
                NavigationLink {
                    RecipeOrganizationManagePage(
                        repository: organizationRepository,
                        homeId: homes.home?.id
                    )
                } label: {
                    Label("Folders & Tags", systemImage: "folder.badge.gearshape")
                }
            }
        } else {
            ToolbarItem {
                NavigationLink {
                    RecipeOrganizationLockedPage()
                } label: {
                    Label("Folders & Tags", systemImage: "folder.badge.gearshape")
                }
            }
        }
        
        ToolbarSpacer(.fixed)

        if !isRecipeDiscoverySeparateTabEnabled {
            ToolbarItem {
                NavigationLink {
                    RecipeDiscoveryPage()
                } label: {
                    Label("Discover Recipes", systemImage: "sparkles")
                }
            }
        }

        ToolbarItem {
            Button {
                importState.isAddRecipeSheetPresented = true
            } label: {
                Label("Add Recipe", systemImage: "plus")
            }
        }
    }

    var addRecipeOptions: [AddRecipeAction] {
        var options: [AddRecipeAction] = [.webURL, .fileArchive, .markdown]

        if appSettings.settings.enableWebSelectionImport {
            options.append(.webSelection)
        }

        if appSettings.settings.enableOcrImport {
            options.append(.photoOCR)
        }

        return options
    }

    var importURLToParse: String {
        importState.webURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func handleAddAction(_ action: AddRecipeAction) {
        switch action {
        case .webURL:
            importState.isURLAddSheetPresented = true
        case .fileArchive:
            importState.isImportAppSelectionPresented = true
        case .markdown:
            importState.isMarkdownImportPresented = true
        case .webSelection:
            importState.isWebSelectionImportPresented = true
        case .photoOCR:
            importState.isOCRImportPresented = true
        }
    }

    func deleteRecipe(id: UUID) async {
        do {
            try await repository.delete(id)
        } catch {
            print(error)
        }
    }

    func presentFilters() {
        isFilterSheetPresented = true
    }

    func matchesSearchText(_ recipe: Recipe, searchTokens: [String]) -> Bool {
        guard !searchTokens.isEmpty else { return true }
        let searchableText = recipe.searchableText
        return searchTokens.allSatisfy { searchableText.contains($0) }
    }

    func matchesFilters(_ recipe: Recipe) -> Bool {
        if filters.minimumRating > 0 {
            guard let rating = recipe.filterRating, rating >= filters.minimumRating else { return false }
        }

        if filters.minimumComments > 0, recipe.filterCommentCount < filters.minimumComments {
            return false
        }

        if filters.maximumTimeMinutes > 0 {
            guard let time = recipe.filterTimeMinutes, time <= Double(filters.maximumTimeMinutes) else { return false }
        }

        if hasRecipeOrganizationProAccess {
            if let selectedFolderID = filters.selectedFolderID, !recipe.folders.contains(where: { $0.id == selectedFolderID }) {
                let descendantIDs = organizationRepository.descendantFolderIDs(for: selectedFolderID, homeId: homes.home?.id)
                guard recipe.folders.contains(where: { $0.id == selectedFolderID || descendantIDs.contains($0.id) }) else {
                    return false
                }
            }

            if !filters.selectedTagIDs.isEmpty {
                let recipeTagIDs = Set(recipe.tags.map(\.id))
                guard filters.selectedTagIDs.isSubset(of: recipeTagIDs) else { return false }
            }
        }

        return true
    }

    var hasRecipeOrganizationProAccess: Bool {
        flagKit.isEnabled(.recipeOrganizationPro, default: recipeOrganizationFeatureAccessFallback)
    }

    var hasSocialRecipeImportProAccess: Bool {
        flagKit.isEnabled(.recipeSocialImportPro, default: socialRecipeImportFeatureAccessFallback)
    }

    var isRecipeDiscoverySeparateTabEnabled: Bool {
        flagKit.isEnabled(.recipeDiscoverySeparateTab, default: false)
    }

    func sortedRecipes(_ recipes: [Recipe]) -> [Recipe] {
        switch filters.sort {
        case .nameAZ:
            return recipes.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case .nameZA:
            return recipes.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending
            }
        case .dateAdded:
            return recipes.sorted { $0.dateAdded > $1.dateAdded }
        case .dateModified:
            return recipes.sorted { $0.dateModified > $1.dateModified }
        case .time:
            return recipes.sorted { lhs, rhs in
                switch (lhs.filterTimeMinutes, rhs.filterTimeMinutes) {
                case let (left?, right?):
                    return left < right
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
            }
        }
    }

    @MainActor
    func startWebURLImport() -> Bool {
        guard let url = URL(string: importURLToParse) else {
            importState.presentFailure("That URL doesn't look valid.")
            importFailureFeedbackToken += 1
            return false
        }

        guard !isBlockedSocialImport(url) else {
            importState.isURLAddSheetPresented = false
            presentSocialImportPaywall()
            return false
        }

        return startImport(from: .webURL(url))
    }

    @MainActor
    @discardableResult
    func startImport(from source: RecipeImportSource) -> Bool {
        guard canStartImport(from: source) else { return false }

        Task {
            await Task.yield()
            importState.beginImport(from: source)
            await runImportPreparation(from: source)
        }

        return true
    }

    @MainActor
    func retryRecipeImport() {
        guard let activeImportSource = importState.activeImportSource else { return }
        importState.clearFailure()
        importState.importStartedAt = .now

        Task {
            await runImportPreparation(from: activeImportSource)
        }
    }

    @MainActor
    func dismissImportSheet() {
        importState.closeImportStatus()
    }

    @MainActor
    func runImportPreparation(from source: RecipeImportSource) async {
        do {
            let coordinator = RecipeImportCoordinator(client: client)
            let result = try await coordinator.prepareImport(from: source, homeId: homes.home?.id)

            importState.closeImportStatus()
            let candidates = result.candidates

            if candidates.count > 1 {
                importState.prepareSelection(with: candidates)
            } else if shouldPreviewBeforeSaving(source: source), let candidate = candidates.first {
                importState.preparePreviewEdit(with: candidate)
            } else {
                await processCandidates(candidates)
            }
        } catch {
            importState.presentFailure(mapImportError(error))
            importFailureFeedbackToken += 1
            print(error)
        }
    }

    @MainActor
    func processCandidates(_ candidates: [RecipeImportCandidate]) async {
        guard !candidates.isEmpty else {
            importState.presentFailure("No recipes were detected from this import source.")
            importFailureFeedbackToken += 1
            return
        }

        let coordinator = RecipeImportCoordinator(client: client)
        let existingRecipes = await repository.recipesForDuplicateMatching()
        let duplicates = coordinator.detectDuplicates(for: candidates, existing: existingRecipes)

        if duplicates.isEmpty {
            await persistCandidates(candidates, decisions: [:])
        } else {
            importState.prepareDuplicateResolution(candidates: candidates, duplicates: duplicates)
        }
    }

    @MainActor
    func persistCandidates(
        _ candidates: [RecipeImportCandidate],
        decisions: [UUID: DuplicateResolutionDecision]
    ) async {
        do {
            importState.beginPersisting(recipesCount: candidates.count)

            let coordinator = RecipeImportCoordinator(client: client)
            try await coordinator.persist(candidates: candidates, decisions: decisions, repository: repository)

            importState.closeImportStatus()
            importState.clearImportArtifactsAfterSuccess()
            importSuccessFeedbackToken += 1
        } catch {
            importState.presentFailure(mapImportError(error))
            importFailureFeedbackToken += 1
            print(error)
        }
    }

    func mapImportError(_ error: Error) -> String {
        if error is DecodingError {
            return "The recipe data was returned in an unexpected format. Please try another page."
        }

        if let importError = error as? RecipeImportError,
           let message = importError.errorDescription {
            return message
        }

        let description = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "We couldn't import that recipe right now. Please try again."
        }
        return description
    }

    @MainActor
    func importPendingSharedURLIfNeeded() {
        guard let sharedURL = pendingSharedImportURL else { return }
        if startImport(from: .webURL(sharedURL)) {
            pendingSharedImportURL = nil
        }
    }

    func canStartImport(from source: RecipeImportSource) -> Bool {
        switch source {
        case .webURL(let url):
            if isBlockedSocialImport(url) {
                presentSocialImportPaywall()
                return false
            }
            return true
        case .fileURL, .markdownText, .webSelection, .ocrText:
            return true
        }
    }

    func shouldPreviewBeforeSaving(source: RecipeImportSource) -> Bool {
        guard case .webURL(let url) = source else { return false }
        return SocialRecipeSource.isSupported(url)
    }

    func isBlockedSocialImport(_ url: URL) -> Bool {
        SocialRecipeSource.isSupported(url) && !hasSocialRecipeImportProAccess
    }

    @MainActor
    func presentSocialImportPaywall() {
        Task {
            await Task.yield()
            isProPaywallPresented = true
        }
    }
}

#Preview {
    @Previewable @Namespace var zm
    let recipeId = UUID()

    let _ = PreviewSupport.preparePreviewDatabase(seed: { db in
        let now = Date()
        let recipe = DBRecipe(
            id: recipeId,
            title: "Preview Stir Fry",
            description: "Colourful veggies with noodles and peanut sauce.",
            author: "Preview Kitchen",
            sourceUrl: "https://example.com/stirfry",
            dominantColorHex: nil,
            minutesToPrepare: 10,
            minutesToCook: 15,
            totalMins: 25,
            serves: "2",
            overallRating: 4.7,
            totalRatings: 12,
            summarisedRating: "Quick comfort food",
            summarisedSuggestion: nil,
            dateAdded: now,
            dateModified: now,
            homeId: nil
        )

        do {
            try db.write { db in
                try DBRecipe.insert { recipe }.execute(db)
                try DBRecipeImage.insert { DBRecipeImage(recipeId: recipeId, imageSourceUrl: "https://www.allrecipes.com/thmb/xcOdImFBdut09lTsPnOxIjnv-2E=/0x512/filters:no_upscale():max_bytes(150000):strip_icc()/228823-quick-beef-stir-fry-DDMFS-4x3-1f79b031d3134f02ac27d79e967dfef5.jpg", imageData: nil) }.execute(db)
            }
        } catch {
            print("Preview DB setup failed: \(error)")
        }
    })

    NavigationStack {
        RecipeListPage()
    }
    .environment(AppRouter(initialTab: .mealplan))
    .environment(ZoomManager(zm))
    .environment(\.homeServices, MockHouseholdService())
}
