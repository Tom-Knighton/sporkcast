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
import UniformTypeIdentifiers

public struct RecipeListPage: View {

    @Environment(ZoomManager.self) private var zoomManager
    @Environment(\.homeServices) private var homes
    @Environment(AppRouter.self) private var router
    @Environment(\.networkClient) private var client
    @Environment(\.appSettings) private var appSettings

    @State private var importState = RecipeListImportState()
    @State private var importSuccessFeedbackToken: Int = 0
    @State private var importFailureFeedbackToken: Int = 0
    @State private var repository = RecipesRepository()
    @State private var showDeleteConfirmId: UUID?

    public init() {}

    public var body: some View {
        ZStack {
            @Bindable var zm = zoomManager
            Color.layer1.ignoresSafeArea()

            RecipeCardsListView(
                recipes: repository.recipes,
                zoomNamespace: zm.zoomNamespace,
                onOpen: { recipe in
                    router.navigateTo(.recipe(recipe: recipe))
                },
                onDelete: { id in
                    Task {
                        await deleteRecipe(id: id)
                    }
                },
                showDeleteConfirmId: $showDeleteConfirmId
            )
        }
        .navigationTitle("Recipes")
        .toolbar { toolbarContent }
        .sheet(isPresented: $importState.isAddRecipeSheetPresented) {
            AddRecipeSheet(options: addRecipeOptions) { action in
                handleAddAction(action)
            }
            .presentationDetents([.height(390)])
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
                        await processCandidates(candidates)
                    }
                }
            )
        }
        .sheet(isPresented: $importState.isDuplicateResolutionPresented) {
            RecipeDuplicateResolutionSheet(
                candidates: importState.preparedCandidates,
                duplicates: importState.duplicateMatches,
                onConfirm: { decisions in
                    Task {
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
    }
}

private extension RecipeListPage {

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Button {
                importState.isAddRecipeSheetPresented = true
            } label: {
                Label("Add Recipe", systemImage: "plus")
            }
        }

        ToolbarSpacer(.fixed)

        ToolbarItem {
            Button {
                Task {
                    try await repository.deleteAll()
                }
            } label: {
                Image(systemName: "xmark")
            }
            .tint(.red)
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

    @MainActor
    func startWebURLImport() -> Bool {
        guard let url = URL(string: importURLToParse) else {
            importState.presentFailure("That URL doesn't look valid.")
            importFailureFeedbackToken += 1
            return false
        }

        startImport(from: .webURL(url))
        return true
    }

    @MainActor
    func startImport(from source: RecipeImportSource) {
        importState.beginImport(from: source)

        Task {
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
        importState.closeImportStatus()
    }

    @MainActor
    func runImportPreparation(from source: RecipeImportSource) async {
        do {
            let coordinator = RecipeImportCoordinator(client: client)
            let result = try await coordinator.prepareImport(from: source, homeId: homes.home?.id)

            importState.isImportStatusSheetPresented = false
            let candidates = result.candidates

            if candidates.count > 1 {
                importState.prepareSelection(with: candidates)
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
        let duplicates = coordinator.detectDuplicates(for: candidates, existing: repository.recipes)

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
            let coordinator = RecipeImportCoordinator(client: client)
            try await coordinator.persist(candidates: candidates, decisions: decisions, repository: repository)

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
