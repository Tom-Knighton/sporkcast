//
//  RecipeDiscoveryPage.swift
//  RecipesList
//

import API
import Design
import Environment
import Models
import RecipeImporting
import SwiftUI

public struct RecipeDiscoveryPage: View {
    @Environment(\.networkClient) private var client
    @Environment(\.homeServices) private var homes
    @Environment(\.flagKit) private var flagKit
    @Environment(\.proAccess) private var proAccess
    @Environment(\.calendar) private var calendar
    @Environment(\.openURL) private var openURL

    @State private var repository = RecipesRepository()
    @State private var importState = RecipeListImportState()
    @State private var feedState: RecipeDiscoveryFeedState = .loading
    @State private var hiddenItemIDs: Set<String> = []
    @State private var identity: DiscoveryIdentity?
    @State private var activeImportContext: RecipeDiscoveryImportContext?
    @State private var isProPaywallPresented = false
    @State private var mealplanWeather = MealplanWeatherService.shared
    @State private var importSuccessFeedbackToken = 0
    @State private var importFailureFeedbackToken = 0

    private var discoveryRepository: RecipeDiscoveryRepository {
        RecipeDiscoveryRepository(client: client)
    }

    private var hasDiscoveryAccess: Bool {
        flagKit.isEnabled(.recipeDiscoveryPro, default: proAccess.hasProAccess)
    }

    private var hasWeatherAccess: Bool {
        flagKit.isEnabled(.mealplanWeatherPro, default: proAccess.hasProAccess)
    }

    private var visibleSections: [DiscoveryFeedSection] {
        guard case .loaded(let response) = feedState else { return [] }

        return response.sections.compactMap { section in
            let items = section.items.filter { !hiddenItemIDs.contains($0.id) }
            guard !items.isEmpty else { return nil }
            return DiscoveryFeedSection(id: section.id, title: section.title, items: items)
        }
    }

    public init() {}

    public var body: some View {
        ZStack {
            Color.layer1.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    RecipeDiscoveryHeader(hasAccess: hasDiscoveryAccess)

                    if hasDiscoveryAccess {
                        feedContent
                    } else {
                        RecipeDiscoveryLockedView(action: showPaywall)
                            .padding(.horizontal, 18)
                    }
                }
                .padding(.vertical, 18)
            }
            .refreshable {
                await reloadFeed()
            }
        }
        .navigationTitle("Discover")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !hasDiscoveryAccess {
                ToolbarItem {
                    Button("Unlock", systemImage: "sparkles", action: showPaywall)
                }
            }
        }
        .task {
            await loadFeedIfNeeded()
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
        .sheet(isPresented: $importState.isSelectionSheetPresented) {
            RecipeImportSelectionSheet(
                candidates: importState.preparedCandidates,
                selectedIDs: $importState.selectedCandidateIDs,
                onImportSelected: importSelectedCandidates
            )
        }
        .sheet(isPresented: $importState.isPreviewEditSheetPresented) {
            if let candidate = importState.previewCandidate {
                RecipeImportPreviewEditSheet(
                    candidate: candidate,
                    onCancel: {
                        importState.clearPreviewEdit()
                        activeImportContext = nil
                    },
                    onSave: savePreviewCandidate
                )
            }
        }
        .sheet(isPresented: $importState.isDuplicateResolutionPresented) {
            RecipeDuplicateResolutionSheet(
                candidates: importState.preparedCandidates,
                duplicates: importState.duplicateMatches,
                onConfirm: persistDuplicateDecisions
            )
        }
        .sheet(isPresented: $isProPaywallPresented) {
            ProPaywallView()
        }
        .sensoryFeedback(.success, trigger: importSuccessFeedbackToken)
        .sensoryFeedback(.error, trigger: importFailureFeedbackToken)
    }

    @ViewBuilder
    private var feedContent: some View {
        switch feedState {
        case .loading:
            RecipeDiscoveryLoadingView()
                .padding(.horizontal, 18)
        case .loaded:
            if visibleSections.isEmpty {
                RecipeDiscoveryEmptyView(action: {
                    Task { await reloadFeed() }
                })
                .padding(.horizontal, 18)
            } else {
                LazyVStack(alignment: .leading, spacing: 26) {
                    ForEach(visibleSections) { section in
                        RecipeDiscoverySectionView(
                            section: section,
                            importingItemID: activeImportContext?.item.id,
                            onOpen: open,
                            onAdd: add,
                            onHide: hide
                        )
                    }
                }
            }
        case .failed(let message):
            RecipeDiscoveryErrorView(message: message) {
                Task { await reloadFeed() }
            }
            .padding(.horizontal, 18)
        }
    }
}

private extension RecipeDiscoveryPage {
    func loadFeedIfNeeded() async {
        guard hasDiscoveryAccess, case .loading = feedState else { return }
        await reloadFeed()
    }

    func reloadFeed() async {
        guard hasDiscoveryAccess else { return }

        feedState = .loading
        do {
            let identity = await DiscoveryIdentityProvider.identity(homeId: homes.home?.id)
            self.identity = identity

            let signals = RecipeDiscoverySourceSignalBuilder.build(from: repository.recipes)
            let weather = hasWeatherAccess
                ? await mealplanWeather.discoveryWeatherContext(calendar: calendar)
                : DiscoveryWeatherContext(season: RecipeDiscoverySeason.current())
            let response = try await discoveryRepository.feed(
                DiscoveryFeedRequest(
                    installationId: identity.installationId,
                    homeId: identity.homeId?.uuidString,
                    locale: Locale.current.identifier,
                    sourceDomains: signals.sourceDomains,
                    existingRecipeUrls: signals.existingRecipeUrls,
                    weather: weather,
                    iCloudUserRecordNameHash: identity.iCloudUserRecordNameHash,
                    limit: 36
                )
            )

            feedState = .loaded(response)
        } catch {
            feedState = .failed(mapDiscoveryError(error))
        }
    }

    func open(_ item: DiscoveryFeedItem) {
        guard let url = URL(string: item.sourceUrl) else { return }
        Task {
            await recordFeedback(for: item, eventType: .open)
        }
        openURL(url)
    }

    func add(_ item: DiscoveryFeedItem) {
        guard let url = URL(string: item.sourceUrl) else { return }

        Task {
            let identity = await currentIdentity()
            self.identity = identity
            activeImportContext = RecipeDiscoveryImportContext(item: item, identity: identity)
            await recordFeedback(for: item, identity: identity, eventType: .importStarted)
            startImport(from: .webURL(url))
        }
    }

    func hide(_ item: DiscoveryFeedItem) {
        hiddenItemIDs.insert(item.id)
        Task {
            await recordFeedback(for: item, eventType: .hidden)
        }
    }

    func showPaywall() {
        isProPaywallPresented = true
    }
}

private extension RecipeDiscoveryPage {
    @MainActor
    func startImport(from source: RecipeImportSource) {
        Task {
            await Task.yield()
            importState.beginImport(from: source)
            await runImportPreparation(from: source)
        }
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
        let hadFailure = importState.importFailureMessage != nil
        importState.closeImportStatus()
        if hadFailure {
            activeImportContext = nil
        }
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
            } else if let candidate = candidates.first {
                importState.preparePreviewEdit(with: candidate)
            } else {
                await processCandidates(candidates)
            }
        } catch {
            importState.presentFailure(mapImportError(error))
            importFailureFeedbackToken += 1
            activeImportContext = nil
        }
    }

    @MainActor
    func importSelectedCandidates() {
        let candidates = importState.preparedCandidates.filter {
            importState.selectedCandidateIDs.contains($0.id)
        }
        Task {
            await Task.yield()
            await processCandidates(candidates)
        }
    }

    @MainActor
    func savePreviewCandidate(_ candidate: RecipeImportCandidate) {
        importState.clearPreviewEdit()
        Task {
            await Task.yield()
            await processCandidates([candidate])
        }
    }

    @MainActor
    func processCandidates(_ candidates: [RecipeImportCandidate]) async {
        guard !candidates.isEmpty else {
            importState.presentFailure("No recipes were detected from this discovery card.")
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
    func persistDuplicateDecisions(_ decisions: [UUID: DuplicateResolutionDecision]) {
        Task {
            await Task.yield()
            await persistCandidates(importState.preparedCandidates, decisions: decisions)
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

            if let context = activeImportContext {
                await recordFeedback(for: context.item, identity: context.identity, eventType: .importSucceeded)
                activeImportContext = nil
            }
        } catch {
            importState.presentFailure(mapImportError(error))
            importFailureFeedbackToken += 1
        }
    }

    func recordFeedback(
        for item: DiscoveryFeedItem,
        identity providedIdentity: DiscoveryIdentity? = nil,
        eventType: DiscoveryFeedbackEventType
    ) async {
        let identity: DiscoveryIdentity
        if let providedIdentity {
            identity = providedIdentity
        } else {
            identity = await currentIdentity()
        }

        try? await discoveryRepository.recordFeedback(
            DiscoveryFeedbackRequest(
                installationId: identity.installationId,
                homeId: identity.homeId?.uuidString,
                candidateId: item.id,
                iCloudUserRecordNameHash: identity.iCloudUserRecordNameHash,
                sourceUrl: item.sourceUrl,
                eventType: eventType
            )
        )
    }

    func currentIdentity() async -> DiscoveryIdentity {
        if let identity {
            return identity
        }

        let identity = await DiscoveryIdentityProvider.identity(homeId: homes.home?.id)
        self.identity = identity
        return identity
    }
}

private extension RecipeDiscoveryPage {
    func mapDiscoveryError(_ error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return description
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return description.isEmpty ? "Discovery is unavailable right now." : description
    }

    func mapImportError(_ error: Error) -> String {
        if error is DecodingError {
            return "The recipe data was returned in an unexpected format. Try opening the source or choose another card."
        }

        if let importError = error as? RecipeImportError,
           let message = importError.errorDescription {
            return message
        }

        let description = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "We couldn't import that recipe right now. Please try another card."
        }
        return description
    }
}

private enum RecipeDiscoveryFeedState {
    case loading
    case loaded(DiscoveryFeedResponse)
    case failed(String)
}

private struct RecipeDiscoveryHeader: View {
    let hasAccess: Bool

    var body: some View {
        HStack {
            Image(systemName: hasAccess ? "sparkles" : "lock.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(hasAccess ? .yellow : .secondary)
                .accessibilityHidden(true)
            Text(hasAccess ? "New ideas from sources that fit your cookbook." : "Recipe discovery is included with Sporkast Pro.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
    }
}

private struct RecipeDiscoveryLoadingView: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)

            Text("Finding recipes")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .modifier(DiscoveryGlassSurface())
    }
}

private struct RecipeDiscoveryEmptyView: View {
    let action: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Discoveries Yet", systemImage: "sparkles")
        } description: {
            Text("Check back after adding a few recipes or refresh for popular picks.")
        } actions: {
            Button("Refresh", systemImage: "arrow.clockwise", action: action)
                .buttonStyle(.glassProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .modifier(DiscoveryGlassSurface())
    }
}

private struct RecipeDiscoveryErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Discovery Unavailable", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again", systemImage: "arrow.clockwise", action: retry)
                .buttonStyle(.glassProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .modifier(DiscoveryGlassSurface())
    }
}

private struct RecipeDiscoveryLockedView: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Fresh ideas for your cookbook")
                    .font(.title2.bold())

                Text("Discover recipes from trusted sources, add them in one tap, and use weather context when it helps. Pro also includes organization, social imports, widgets, and Calendar sync.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Unlock Discovery", systemImage: "sparkles", action: action)
                .buttonStyle(.glassProminent)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(DiscoveryGlassSurface())
    }
}
