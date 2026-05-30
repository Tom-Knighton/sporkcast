//
//  RecipePage.swift
//  Recipe
//
//  Created by Tom Knighton on 24/08/2025.
//

import SwiftUI
import Design
import Models
import SwiftData
import API
import SQLiteData
import Environment
import NukeUI
import Persistence
import RecipeImporting

private struct RecipePageAIGenerationTaskID: Equatable {
    let scenePhase: ScenePhase
    let segment: Int
    let recipeID: UUID
    let summary: String?
}

private struct ReimportAlertContent: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private enum RecipeReimportPlan {
    case webURL(URL)
    case unavailable(reason: String)
}

private struct RecipeReimportStatusSheet: View {
    let statusTitle: String
    let statusSubtitle: String
    let failureMessage: String?
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            if let failureMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)

                Text("This recipe didn't re-import")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(failureMessage)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button("Try Again", systemImage: "arrow.clockwise", action: onRetry)
                        .buttonStyle(.borderedProminent)

                    Button("Dismiss", role: .cancel, action: onDismiss)
                        .buttonStyle(.bordered)
                }
                .padding(.top, 8)
            } else {
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.14))
                            .frame(width: 54, height: 54)

                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                    .accessibilityHidden(true)

                    ProgressView()
                        .controlSize(.large)
                        .accessibilityLabel("Recipe re-import in progress")

                    Text(statusTitle)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)

                    Text(statusSubtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.12),
                            Color.cyan.opacity(0.07),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }
}

public struct RecipePage: View {
    
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var scheme
    @Environment(\.networkClient) private var client
    @Environment(\.displayScale) private var displayScale
    @Environment(\.flagKit) private var flagKit
    @Environment(\.proAccess) private var proAccess
    @Environment(\.appSettings) private var appSettings
    @Dependency(\.defaultDatabase) private var db
    
    @State private var viewModel: RecipeViewModel
    @State private var allowDismissalGesture: AllowedNavigationDismissalGestures = .none
    @State private var commentsSnapshot: UIImage?
    @State private var completedMealplanIngredientIDs: Set<UUID> = []
    @State private var showingAddToShoppingSheet = false
    @State private var inlinePickerVisible = true
    @State private var showingIngredientScaleControls = false
    @State private var showingIngredientUnitControls = false
    @State private var showReimportConfirmation = false
    @State private var isReimporting = false
    @State private var reimportAlert: ReimportAlertContent?
    @State private var showReimportStatusSheet = false
    @State private var isProPaywallPresented = false
    @State private var reimportFailureMessage: String?
    @State private var reimportSuccessFeedbackToken: Int = 0
    @State private var reimportFailureFeedbackToken: Int = 0
    private let mealplanEntryId: UUID?
    
    
    public init(_ recipe: Recipe, mealplanEntryId: UUID? = nil) {
        self.mealplanEntryId = mealplanEntryId
        self.viewModel = .init(recipe: recipe)
        self.viewModel.dominantColour = Color(hex: recipe.dominantColorHex ?? "") ?? .clear
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    RecipeHeadingView {
                        image()
                            .mask(Rectangle().ignoresSafeArea(edges: .top))
                    }
                    .stretchy()
                    .ignoresSafeArea()
                    
                    RecipeTitleView(showNavTitle: $viewModel.showNavTitle)
                    
                    VStack {
                        
                        Spacer().frame(height: 20)
                        
                        HStack(spacing: 24) {
                            if let totalTime = viewModel.recipe.timing.totalTime {
                                VStack(alignment: .leading) {
                                    Text("Total Time")
                                        .font(.caption.weight(.heavy))
                                        .opacity(0.7)
                                        .textCase(.uppercase)
                                        .fixedSize(horizontal: true, vertical: false)
                                    Text("\(totalTime, specifier: "%.0f") mins")
                                        .bold()
                                        .fixedSize(horizontal: true, vertical: false)
                                    
                                }
                                Divider()
                            }
                            
                            if let cookingMins = viewModel.recipe.timing.cookTime {
                                VStack(alignment: .leading) {
                                    Text("Cooking Time")
                                        .font(.caption.weight(.heavy))
                                        .opacity(0.7)
                                        .textCase(.uppercase)
                                        .fixedSize(horizontal: true, vertical: false)
                                    Text("\(cookingMins, specifier: "%.0f") mins")
                                        .bold()
                                        .fixedSize(horizontal: true, vertical: false)
                                    
                                }
                                Divider()
                                    .overlay(Material.bar)
                                    .opacity(0.68)
                            }
                            
                            if let serves = viewModel.recipe.serves {
                                VStack(alignment: .leading) {
                                    Text("Serves")
                                        .font(.caption.weight(.heavy))
                                        .opacity(0.7)
                                        .textCase(.uppercase)
                                        .fixedSize(horizontal: true, vertical: false)
                                    Text(serves)
                                        .bold()
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                            }
                            
                            Spacer()
                        }
                        
                        Spacer().frame(height: 20)
                        
                        if viewModel.recipe.hasUsableSource {
                            RecipeSourceButton(with: viewModel.dominantColour) {
                                image()
                            }
                        }
                        
                        Spacer().frame(height: 20)
                        HStack {
                            Picker("", selection: $viewModel.segment) {
                                Text("Ingredients")
                                    .tag(1)
                                Text("Steps").tag(2)
                                
                                if shouldShowRecipeChatInline, let commentsUIImage = commentsSnapshot {
                                    Image(uiImage: commentsUIImage)
                                        .tag(3)
                                } else {
                                    Text("Comments")
                                        .tag(3)
                                }
                                
                                if shouldShowRecipeChatTab {
                                    Text("Chat")
                                        .tag(4)
                                }
                            }
                            .pickerStyle(.segmented)
                            Spacer()
                        }
                        .onScrollVisibilityChange { visible in
                            inlinePickerVisible = visible
                        }
                        
                        if viewModel.segment == 1 {
                            HStack(spacing: 10) {
                                ingredientScaleToggleButton
                                ingredientUnitToggleButton
                                
                                Spacer()
                            }
                            .padding(.top, 8)
                            
                            if showingIngredientScaleControls {
                                RecipeIngredientScaleControl(
                                    scale: viewModel.recipe.ingredientScale,
                                    tint: viewModel.dominantColour
                                ) { newScale in
                                    saveIngredientScale(newScale)
                                } onReset: {
                                    resetIngredientScale()
                                } onClose: {
                                    toggleIngredientScaleControls()
                                }
                                .padding(.top, 8)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                            
                            if showingIngredientUnitControls {
                                RecipeIngredientUnitControl(
                                    selectedUnitSystem: viewModel.recipe.ingredientUnitSystem,
                                    tint: viewModel.dominantColour
                                ) { newUnitSystem in
                                    saveIngredientUnitSystem(newUnitSystem)
                                } onReset: {
                                    resetIngredientUnitSystem()
                                } onClose: {
                                    toggleIngredientUnitControls()
                                }
                                .padding(.top, 8)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                        
                        Spacer().frame(height: 24)
                        
                        switch viewModel.segment {
                        case 1:
                            RecipeIngredientsListView(
                                tint: viewModel.dominantColour,
                                completedIngredientIDs: completedMealplanIngredientIDs,
                                showMealplanShoppingTicks: mealplanEntryId != nil,
                                showIngredientEmojis: appSettings.settings.showIngredientEmojis
                            )
                            .tint(viewModel.dominantColour)
                        case 2:
                            RecipeStepsView(
                                tint: viewModel.dominantColour,
                                completedIngredientIDs: completedMealplanIngredientIDs,
                                showMealplanShoppingTicks: mealplanEntryId != nil,
                                showIngredientEmojis: appSettings.settings.showIngredientEmojis
                            )
                        case 3:
                            RecipeCommentsView(showRecipeChat: shouldShowRecipeChatInline)
                        case 4:
                            if shouldShowRecipeChatTab {
                                RecipeChatView()
                            } else {
                                EmptyView()
                            }
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal)
                    .scrollTargetLayout()
                }
            }
            .scrollClipDisabled(true)
            .fontDesign(.rounded)
            .tabBarMinimizeBehavior(shouldCollapseTab ? .onScrollDown : .automatic)
            .scrollBounceBehavior(.always, axes: .vertical)
            .coordinateSpace(name: "recipeScroll")
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { newValue, _ in
                viewModel.scrollOffset = newValue
            }
        }
        .navigationAllowDismissalGestures(allowDismissalGesture)
        .task {
            Task {
                try? await Task.sleep(for: .seconds(1))
                allowDismissalGesture = .all
            }
        }
        .edgesIgnoringSafeArea(.top)
        .ignoresSafeArea(.all, edges: .all.subtracting(.bottom))
        .environment(viewModel)
        .colorScheme(.dark)
        .background(
            image()
                .aspectRatio(contentMode: .fill)
                .scaleEffect(2)
                .blur(radius: scheme == .dark ? 100 : 64)
                .ignoresSafeArea()
                .overlay(Material.ultraThin.opacity(0.2))
        )
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(viewModel.recipe.title)
                    .font(.headline)
                    .transition(.opacity)
                    .accessibilityHidden(!viewModel.showNavTitle)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.showNavTitle)
                    .opacity(viewModel.showNavTitle ? 1 : 0)
            }
            ToolbarItem {
                Menu {
                    Button(action: {
                        Task {
                            await presentEditRecipeSheet()
                        }
                    }) {
                        Label("Edit Recipe", systemImage: "pencil")
                    }
                    Button(action: { showingAddToShoppingSheet = true }) {
                        Label("Add Ingredients To Shopping", systemImage: "cart.badge.plus")
                    }
                    Button(action: { presentIngredientScaleControls() }) {
                        Label("Scale Ingredients", systemImage: "slider.horizontal.3")
                    }
                    if recipeHasScaledIngredients {
                        Button(action: { resetIngredientScale() }) {
                            Label("Reset Ingredient Scale", systemImage: "arrow.counterclockwise")
                        }
                    }
                    Button(action: { presentIngredientUnitControls() }) {
                        Label("Convert Ingredient Units", systemImage: "scalemass")
                    }
                    if recipeHasConvertedUnits {
                        Button(action: { resetIngredientUnitSystem() }) {
                            Label("Reset Ingredient Units", systemImage: "arrow.counterclockwise")
                        }
                    }
                    if mealplanEntryId != nil {
                        Button(action: { Task { await clearMealplanIngredientStates() }}) {
                            Label("Clear Ingredient Status", systemImage: "cart.badge.minus.fill")
                        }
                    }
                    Divider()
                    Button(role: .destructive, action: presentReimportConfirmationDialog) {
                        Label(isReimporting ? "Re-importing Recipe..." : "Re-import Recipe", systemImage: "arrow.clockwise")
                    }
                    .disabled(isReimporting)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .confirmationDialog(
                    "Re-import this recipe?",
                    isPresented: $showReimportConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Re-import", role: .destructive) {
                        Task {
                            await performRecipeReimport()
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will overwrite your edits with a fresh import from the original source.")
                }
            }
        }
        .safeAreaBar(edge: .top) {
            if !inlinePickerVisible {
                Picker("", selection: $viewModel.segment) {
                    Text("Ingredients")
                        .tag(1)
                    Text("Steps").tag(2)
                    
                    if shouldShowRecipeChatInline, let commentsUIImage = commentsSnapshot {
                        Image(uiImage: commentsUIImage)
                            .tag(3)
                    } else {
                        Text("Comments")
                            .tag(3)
                    }
                    
                    if shouldShowRecipeChatTab {
                        Text("Chat")
                            .tag(4)
                    }
                }
                .pickerStyle(.segmented)
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.horizontal)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: inlinePickerVisible)
        .onChange(of: self.viewModel.recipe, initial: true) { _, newValue in
            if let domC = newValue.dominantColorHex {
                viewModel.dominantColour = Color(hex: domC) ?? .clear
            }
        }
        .onChange(of: viewModel.segment) { _, newValue in
            if newValue != 1 {
                showingIngredientScaleControls = false
                showingIngredientUnitControls = false
            }
        }
        .onChange(of: shouldShowRecipeChatTab, initial: true) { _, isShown in
            if isShown == false, viewModel.segment == 4 {
                viewModel.segment = 3
            }
        }
        .task(id: RecipePageAIGenerationTaskID(
            scenePhase: scenePhase,
            segment: viewModel.segment,
            recipeID: viewModel.recipe.id,
            summary: viewModel.recipe.summarisedTip
        )) {
            guard scenePhase == .active else { return }
            if appSettings.settings.showIngredientEmojis {
                try? await viewModel.generateEmojis()
            }
            try? await viewModel.generateTipsAndSummary()
        }
        .task(id: viewModel.recipe.summarisedTip) {
            generateCommentsLabel()
        }
        .task(id: mealplanEntryId) {
            await loadMealplanIngredientCompletionState()
        }
        .sensoryFeedback(.success, trigger: viewModel.recipe.summarisedTip)
        .sensoryFeedback(.success, trigger: reimportSuccessFeedbackToken)
        .sensoryFeedback(.error, trigger: reimportFailureFeedbackToken)
        .alert(item: $reimportAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showingAddToShoppingSheet) {
            RecipeToShoppingListFlowView(recipe: viewModel.recipe)
        }
        .sheet(isPresented: $isProPaywallPresented) {
            ProPaywallView()
        }
        .sheet(isPresented: $showReimportStatusSheet, onDismiss: dismissReimportStatusSheet) {
            RecipeReimportStatusSheet(
                statusTitle: "Re-importing your recipe",
                statusSubtitle: "Fetching the original source and replacing your edits.",
                failureMessage: reimportFailureMessage
            ) {
                Task {
                    await performRecipeReimport()
                }
            } onDismiss: {
                dismissReimportStatusSheet()
            }
            .interactiveDismissDisabled(reimportFailureMessage == nil)
            .presentationDetents(reimportFailureMessage == nil ? [.height(250)] : [.height(340)])
            .presentationDragIndicator(reimportFailureMessage == nil ? .hidden : .visible)
        }
    }
    
    @ViewBuilder
    private func image() -> some View {
        
        if let data = viewModel.recipe.image.imageThumbnailData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .task {
                    if viewModel.recipe.dominantColorHex == nil, let dom = await Image(uiImage: uiImage).getDominantColor() {
                        await viewModel.setDominantColour(to: dom)
                    }
                }
        } else {
            LazyImage(url: URL(string: viewModel.recipe.image.imageUrl ?? "")) { state in
                if let img = state.image {
                    img
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .task {
                            if viewModel.recipe.dominantColorHex == nil, let dom = await img.getDominantColor() {
                                await viewModel.setDominantColour(to: dom)
                            }
                        }
                } else {
                    Rectangle().opacity(0.1)
                }
            }
        }
    }
}

extension RecipePage {
    @ViewBuilder
    private func buildPickerLabel(title: String, systemImage: String? = nil) -> some View {
        Label(title, systemImage: systemImage ?? "")
            .font(.footnote)
            .labelIconToTitleSpacing(2)
    }
    
    @ViewBuilder
    private var ingredientScaleToggleButton: some View {
        Button(action: { toggleIngredientScaleControls() }) {
            Label(ingredientScaleLabel, systemImage: "slider.horizontal.3")
        }
        .buttonStyle(.glass)
    }
    
    @ViewBuilder
    private var ingredientUnitToggleButton: some View {
        Button(action: { toggleIngredientUnitControls() }) {
            Label(ingredientUnitLabel, systemImage: "scalemass")
        }
        .buttonStyle(.glass)
    }
    
    private func saveIngredientScale(_ value: Double) {
        Task {
            await viewModel.setIngredientScale(to: value)
        }
    }
    
    private func resetIngredientScale() {
        Task {
            await viewModel.resetIngredientScale()
        }
    }
    
    private func saveIngredientUnitSystem(_ unitSystem: RecipeIngredientUnitSystem) {
        Task {
            await viewModel.setIngredientUnitSystem(to: unitSystem)
        }
    }
    
    private func resetIngredientUnitSystem() {
        Task {
            await viewModel.resetIngredientUnitSystem()
        }
    }
    
    private func toggleIngredientScaleControls() {
        withAnimation(.easeInOut(duration: 0.2)) {
            let shouldShowScale = !showingIngredientScaleControls
            showingIngredientScaleControls = shouldShowScale
            if shouldShowScale {
                showingIngredientUnitControls = false
            }
        }
    }
    
    private func toggleIngredientUnitControls() {
        withAnimation(.easeInOut(duration: 0.2)) {
            let shouldShowUnits = !showingIngredientUnitControls
            showingIngredientUnitControls = shouldShowUnits
            if shouldShowUnits {
                showingIngredientScaleControls = false
            }
        }
    }
    
    private func presentIngredientScaleControls() {
        if viewModel.segment != 1 {
            viewModel.segment = 1
        }
        
        guard !showingIngredientScaleControls else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            showingIngredientScaleControls = true
            showingIngredientUnitControls = false
        }
    }
    
    private func presentIngredientUnitControls() {
        if viewModel.segment != 1 {
            viewModel.segment = 1
        }
        
        guard !showingIngredientUnitControls else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            showingIngredientUnitControls = true
            showingIngredientScaleControls = false
        }
    }

    @MainActor
    private func presentReimportConfirmationDialog() {
        switch reimportPlan {
        case .webURL(let sourceURL):
            if SocialRecipeSource.isSupported(sourceURL) && !hasSocialRecipeImportProAccess {
                isProPaywallPresented = true
                return
            }
            showReimportConfirmation = true
        case .unavailable(let reason):
            reimportFailureFeedbackToken += 1
            presentReimportAlert(
                title: "Re-import Unavailable",
                message: reason
            )
        }
    }

    @MainActor
    private func performRecipeReimport() async {
        guard !isReimporting else { return }
        guard case .webURL(let sourceURL) = reimportPlan else { return }

        reimportFailureMessage = nil
        showReimportStatusSheet = true
        isReimporting = true
        defer { isReimporting = false }

        do {
            let coordinator = RecipeImportCoordinator(client: client)
            let importResult = try await coordinator.prepareImport(
                from: .webURL(sourceURL),
                homeId: viewModel.recipe.homeId
            )

            guard let selected = selectReimportCandidate(
                from: importResult.candidates,
                matching: viewModel.recipe
            ) else {
                throw RecipeImportError.noRecipesDetected
            }

            let repository = RecipesRepository()
            try await repository.replaceImportedRecipe(
                existingRecipeId: viewModel.recipe.id,
                with: selected.recipe
            )
            showReimportStatusSheet = false
            reimportSuccessFeedbackToken += 1
        } catch {
            reimportFailureFeedbackToken += 1
            reimportFailureMessage = mapReimportError(error, sourceURL: sourceURL)
            print(error)
        }
    }

    private func selectReimportCandidate(
        from candidates: [RecipeImportCandidate],
        matching existingRecipe: Recipe
    ) -> RecipeImportCandidate? {
        guard !candidates.isEmpty else { return nil }

        return candidates.max { lhs, rhs in
            let lhsSimilarity = lhs.recipe.duplicateSimilarity(with: existingRecipe).score
            let rhsSimilarity = rhs.recipe.duplicateSimilarity(with: existingRecipe).score
            if abs(lhsSimilarity - rhsSimilarity) > 0.0001 {
                return lhsSimilarity < rhsSimilarity
            }

            if abs(lhs.quality.score - rhs.quality.score) > 0.0001 {
                return lhs.quality.score < rhs.quality.score
            }

            let lhsIngredientCount = lhs.recipe.ingredientSections.flatMap(\.ingredients).count
            let rhsIngredientCount = rhs.recipe.ingredientSections.flatMap(\.ingredients).count
            return lhsIngredientCount < rhsIngredientCount
        }
    }

    private func presentReimportAlert(title: String, message: String) {
        reimportAlert = ReimportAlertContent(title: title, message: message)
    }

    @MainActor
    private func dismissReimportStatusSheet() {
        showReimportStatusSheet = false
        reimportFailureMessage = nil
    }

    func generateCommentsLabel() {
        Task {
            let renderer = ImageRenderer(
                content: buildPickerLabel(title: "Suggestions", systemImage: viewModel.recipe.summarisedTip == nil ? "" : "sparkles"), scale: self.displayScale)
            if let image = renderer.uiImage {
                self.commentsSnapshot = image
            }
        }
    }
    
    func loadMealplanIngredientCompletionState() async {
        guard let mealplanEntryId else {
            await MainActor.run { completedMealplanIngredientIDs = [] }
            return
        }
        
        let recipeIngredientIDs = Set(viewModel.recipe.ingredientSections.flatMap(\.ingredients).map(\.id))
        guard !recipeIngredientIDs.isEmpty else {
            await MainActor.run { completedMealplanIngredientIDs = [] }
            return
        }
        
        do {
            let completedIngredientIDs = try await db.read { db in
                let itemIDsForMealplanEntry = Set(
                    try DBShoppingListItemMealplanLink
                        .where { $0.mealplanEntryId.eq(mealplanEntryId) }
                        .select(\.shoppingListItemId)
                        .fetchAll(db)
                )
                guard !itemIDsForMealplanEntry.isEmpty else { return Set<UUID>() }
                
                let completedItemIDs = Set(
                    try DBShoppingListItem
                        .where {
                            itemIDsForMealplanEntry.contains($0.id) && $0.isComplete
                        }
                        .select(\.id)
                        .fetchAll(db)
                )
                guard !completedItemIDs.isEmpty else { return Set<UUID>() }
                
                return Set(
                    try DBShoppingListItemIngredientLink
                        .where {
                            completedItemIDs.contains($0.shoppingListItemId)
                            && recipeIngredientIDs.contains($0.ingredientId)
                        }
                        .select(\.ingredientId)
                        .fetchAll(db)
                )
            }
            
            await MainActor.run {
                completedMealplanIngredientIDs = completedIngredientIDs
            }
        } catch {
            await MainActor.run {
                completedMealplanIngredientIDs = []
            }
            print("Failed loading mealplan shopping completion state: \(error)")
        }
    }
    
    func clearMealplanIngredientStates() async {
        do {
            guard let mealplanEntryId else { return }
            
            try await db.write { db in
                try DBShoppingListItemMealplanLink
                    .where { $0.mealplanEntryId.eq(mealplanEntryId) }
                    .delete()
                    .execute(db)
            }
            await loadMealplanIngredientCompletionState()
        } catch {
            print(error)
        }
    }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public extension ImageRenderer {
    
    @MainActor
    convenience init(content: Content, scale: CGFloat) {
        self.init(content: content)
        self.scale = scale
    }
}

#Preview {
    let _ = PreviewSupport.preparePreviewDatabase()
    
    let recipe = Recipe(
        id: UUID(),
        title: "Preview Carbonara",
        description: "Creamy pasta with crispy pancetta and pecorino.",
        summarisedTip: "Users tend to recommend adding less salt than recommended - but comment that you may need to add spices to taste as it's a bit bland. Overall positive reviews.",
        author: "Preview Chef",
        sourceUrl: "https://example.com/carbonara",
        image: .init(imageThumbnailData: nil, imageUrl: "https://ichef.bbci.co.uk/food/ic/food_16x9_1600/recipes/sausage_and_mash_pie_94920_16x9.jpg"),
        timing: .init(totalTime: 30, prepTime: 10, cookTime: 20),
        serves: "4",
        ratingInfo: .init(overallRating: 4.5, totalRatings: 3, summarisedRating: "Rich and comforting", ratings: [
            .init(id: UUID(), rating: 5, comment: "A bit salty but overall very nice!"),
            .init(id: UUID(), rating: 5, comment: "The perfect authentic carbonarra"),
            .init(id: UUID(), rating: 1, comment: "Missing too many ingredients!"),
        ]),
        dateAdded: .now,
        dateModified: .now,
        ingredientSections: [
            .init(
                id: UUID(),
                title: "Main Ingredients",
                sortIndex: 0,
                ingredients: [
                    .init(id: UUID(), sortIndex: 0, ingredientText: "200g pancetta", ingredientPart: "pancetta", extraInformation: nil, quantity: .init(quantity: 200, quantityText: "200"), unit: .init(unit: "g", unitText: "g"), emoji: "🥓", owned: false),
                    .init(id: UUID(), sortIndex: 1, ingredientText: "3 large eggs", ingredientPart: "eggs", extraInformation: nil, quantity: .init(quantity: 3, quantityText: "3"), unit: nil, emoji: "🥚", owned: true),
                    .init(id: UUID(), sortIndex: 0, ingredientText: "200g pancetta", ingredientPart: "pancetta", extraInformation: nil, quantity: .init(quantity: 200, quantityText: "200"), unit: .init(unit: "g", unitText: "g"), emoji: "🥓", owned: false),
                    .init(id: UUID(), sortIndex: 1, ingredientText: "3 large eggs", ingredientPart: "eggs", extraInformation: nil, quantity: .init(quantity: 3, quantityText: "3"), unit: nil, emoji: "🥚", owned: true),
                    .init(id: UUID(), sortIndex: 0, ingredientText: "200g pancetta", ingredientPart: "pancetta", extraInformation: nil, quantity: .init(quantity: 200, quantityText: "200"), unit: .init(unit: "g", unitText: "g"), emoji: "🥓", owned: false),
                    .init(id: UUID(), sortIndex: 1, ingredientText: "3 large eggs", ingredientPart: "eggs", extraInformation: nil, quantity: .init(quantity: 3, quantityText: "3"), unit: nil, emoji: "🥚", owned: true),
                    .init(id: UUID(), sortIndex: 0, ingredientText: "200g pancetta", ingredientPart: "pancetta", extraInformation: nil, quantity: .init(quantity: 200, quantityText: "200"), unit: .init(unit: "g", unitText: "g"), emoji: "🥓", owned: false),
                    .init(id: UUID(), sortIndex: 1, ingredientText: "3 large eggs", ingredientPart: "eggs", extraInformation: nil, quantity: .init(quantity: 3, quantityText: "3"), unit: nil, emoji: "🥚", owned: true),
                    .init(id: UUID(), sortIndex: 0, ingredientText: "200g pancetta", ingredientPart: "pancetta", extraInformation: nil, quantity: .init(quantity: 200, quantityText: "200"), unit: .init(unit: "g", unitText: "g"), emoji: "🥓", owned: false),
                    .init(id: UUID(), sortIndex: 1, ingredientText: "3 large eggs", ingredientPart: "eggs", extraInformation: nil, quantity: .init(quantity: 3, quantityText: "3"), unit: nil, emoji: "🥚", owned: true),
                    .init(id: UUID(), sortIndex: 0, ingredientText: "200g pancetta", ingredientPart: "pancetta", extraInformation: nil, quantity: .init(quantity: 200, quantityText: "200"), unit: .init(unit: "g", unitText: "g"), emoji: "🥓", owned: false),
                    .init(id: UUID(), sortIndex: 1, ingredientText: "3 large eggs", ingredientPart: "eggs", extraInformation: nil, quantity: .init(quantity: 3, quantityText: "3"), unit: nil, emoji: "🥚", owned: true),
                    .init(id: UUID(), sortIndex: 0, ingredientText: "200g pancetta", ingredientPart: "pancetta", extraInformation: nil, quantity: .init(quantity: 200, quantityText: "200"), unit: .init(unit: "g", unitText: "g"), emoji: "🥓", owned: false),
                    .init(id: UUID(), sortIndex: 1, ingredientText: "3 large eggs", ingredientPart: "eggs", extraInformation: nil, quantity: .init(quantity: 3, quantityText: "3"), unit: nil, emoji: "🥚", owned: true),
                    .init(id: UUID(), sortIndex: 0, ingredientText: "200g pancetta", ingredientPart: "pancetta", extraInformation: nil, quantity: .init(quantity: 200, quantityText: "200"), unit: .init(unit: "g", unitText: "g"), emoji: "🥓", owned: false),
                    .init(id: UUID(), sortIndex: 1, ingredientText: "3 large eggs", ingredientPart: "eggs", extraInformation: nil, quantity: .init(quantity: 3, quantityText: "3"), unit: nil, emoji: "🥚", owned: true),
                    .init(id: UUID(), sortIndex: 0, ingredientText: "200g pancetta", ingredientPart: "pancetta", extraInformation: nil, quantity: .init(quantity: 200, quantityText: "200"), unit: .init(unit: "g", unitText: "g"), emoji: "🥓", owned: false),
                    .init(id: UUID(), sortIndex: 1, ingredientText: "3 large eggs", ingredientPart: "eggs", extraInformation: nil, quantity: .init(quantity: 3, quantityText: "3"), unit: nil, emoji: "🥚", owned: true),
                ]
            )
        ],
        stepSections: [
            .init(
                id: UUID(),
                sortIndex: 0,
                title: "Steps",
                steps: [
                    .init(id: UUID(), sortIndex: 0, instructionText: "Crisp the pancetta in a pan.", timings: [], temperatures: [], linkedIngredients: []),
                    .init(id: UUID(), sortIndex: 1, instructionText: "Toss cooked pasta with eggs and cheese off the heat.", timings: [.init(id: UUID(), timeInSeconds: 60, timeText: "1", timeUnitText: "minute")], temperatures: [], linkedIngredients: []),
                    .init(id: UUID(), sortIndex: 0, instructionText: "Crisp the pancetta in a pan.", timings: [], temperatures: [], linkedIngredients: []),
                    .init(id: UUID(), sortIndex: 1, instructionText: "Toss cooked pasta with eggs and cheese off the heat.", timings: [.init(id: UUID(), timeInSeconds: 60, timeText: "1", timeUnitText: "minute")], temperatures: [], linkedIngredients: []),
                    .init(id: UUID(), sortIndex: 0, instructionText: "Crisp the pancetta in a pan.", timings: [], temperatures: [], linkedIngredients: []),
                    .init(id: UUID(), sortIndex: 1, instructionText: "Toss cooked pasta with eggs and cheese off the heat.", timings: [.init(id: UUID(), timeInSeconds: 60, timeText: "1", timeUnitText: "minute")], temperatures: [], linkedIngredients: [])
                ]
            )
        ],
        dominantColorHex: nil,
        homeId: nil
    )
    
    return NavigationStack {
        RecipePage(recipe)
    }
    .environment(AppRouter(initialTab: .recipes))
    .environment(RecipeTimerStore.shared)
}


extension RecipePage {
    @MainActor
    private func presentEditRecipeSheet() async {
        let fallbackRecipe = viewModel.recipe
        let recipeId = fallbackRecipe.id

        let fullRecipe = try? await db.read { db in
            try DBRecipe.full.find(recipeId).fetchOne(db)?.toDomainModel()
        }

        router.presentSheet(.recipeEdit(recipe: fullRecipe ?? fallbackRecipe))
    }

    private var recipeHasScaledIngredients: Bool {
        abs(viewModel.recipe.ingredientScale - 1.0) > 0.0001
    }
    
    private var ingredientScaleLabel: String {
        "\(ShoppingImportIngredientFormatter.formatScale(viewModel.recipe.ingredientScale))x"
    }
    
    private var recipeHasConvertedUnits: Bool {
        viewModel.recipe.ingredientUnitSystem != .original
    }
    
    private var ingredientUnitLabel: String {
        viewModel.recipe.ingredientUnitSystem.displayName
    }

    private var reimportPlan: RecipeReimportPlan {
        let source = viewModel.recipe.sourceUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else {
            return .unavailable(reason: "This recipe does not have a reusable source recorded.")
        }

        if SyntheticSourceURL.isExternalWebURL(source), let sourceURL = URL(string: source) {
            return .webURL(sourceURL)
        }

        guard let synthetic = SyntheticSourceURL.parse(source) else {
            return .unavailable(reason: "This recipe source cannot be replayed automatically.")
        }

        switch synthetic.mode {
        case .web:
            return .unavailable(reason: "This recipe was imported from the web, but the original URL is no longer available.")
        case .markdown:
            return .unavailable(reason: "This recipe was imported from pasted markdown text. Paste the original text again to re-import.")
        case .webSelection:
            return .unavailable(reason: "This recipe was imported from copied website text. Re-import from that source page or paste the selection again.")
        case .ocr:
            return .unavailable(reason: "This recipe was imported from photo text recognition. Re-import by scanning or pasting the recipe text again.")
        case .file, .archive:
            return .unavailable(reason: unavailableFileReimportMessage(for: synthetic.vendor))
        }
    }

    private func unavailableFileReimportMessage(for vendor: RecipeImportVendor) -> String {
        switch vendor {
        case .pestle:
            return "This recipe came from a Pestle export file. Automatic re-import is not possible without that file, and some video-based Pestle recipes do not expose a stable source URL."
        case .sporkcast:
            return "This recipe came from a Sporkast export file. Re-import it by selecting that export file again."
        case .crouton:
            return "This recipe came from a Crouton export file. Re-import it by selecting that export file again."
        case .paprika:
            return "This recipe came from a Paprika export file. Re-import it by selecting that export file again."
        case .markdown, .web, .unknown:
            return "This recipe came from an imported file or archive that cannot be replayed automatically. Re-import from the original file."
        }
    }

    private func mapReimportError(_ error: Error, sourceURL: URL) -> String {
        if SocialRecipeSource.isSupported(sourceURL) {
            return "We couldn't re-import from that social link right now. Check the Reel or TikTok is still available, then try again."
        }

        if SocialRecipeSource.isLikelyVideo(sourceURL) {
            return "This looks like a video source link, which can fail to parse for re-import. Try re-importing from the original app export file."
        }

        return RecipeImportError.customerFacingMessage(
            for: error,
            fallbackMessage: "We couldn't re-import this recipe right now. Please try again.",
            decodingMessage: "The source returned recipe data in an unexpected format. Please try re-importing later."
        )
    }

    private var recipeChatEnabled: Bool {
        flagKit.isEnabled(.recipeChatEnabled, default: false)
    }

    private var hasSocialRecipeImportProAccess: Bool {
        flagKit.isEnabled(.recipeSocialImportPro, default: proAccess.hasProAccess)
    }
    
    private var recipeChatSeperateTab: Bool {
        flagKit.isEnabled(.recipeChatSeperateTab, default: false)
    }
    
    private var shouldShowRecipeChat: Bool {
        recipeChatEnabled && viewModel.supportsRecipeChat
    }
    
    private var shouldShowRecipeChatInline: Bool {
        shouldShowRecipeChat && !recipeChatSeperateTab
    }
    
    private var shouldShowRecipeChatTab: Bool {
        shouldShowRecipeChat && recipeChatSeperateTab
    }
    
    private var shouldCollapseTab: Bool {
        flagKit.isEnabled(.appCollapseTabBar, default: false)
    }
}
