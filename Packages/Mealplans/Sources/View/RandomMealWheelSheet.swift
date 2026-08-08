//
//  RandomMealWheelSheet.swift
//  Mealplans
//
//  Created by Codex on 08/08/2026.
//

import SwiftUI
import UIKit
import Models
import Environment
import RecipesList

struct RandomMealWheelSheet: View {
    private let defaultMealLimit = 25
    private let stepAmount = 5

    @Environment(\.dismiss) private var dismiss
    @State private var repository = RecipesRepository(observesChanges: false)
    @State private var allRecipes: [Recipe] = []
    @State private var wheelRecipes: [Recipe] = []
    @State private var isLoading = true
    @State private var isSpinning = false
    @State private var isAddingMeal = false
    @State private var rotation: Double = 0
    @State private var selectedRecipe: Recipe?
    @State private var mealLimit = 25
    @State private var includesAllRecipes = false
    @State private var errorMessage: String?
    @State private var successTrigger = false
    @State private var spinHapticTrigger = false
    @State private var confettiID = UUID()

    let onSelect: (Recipe) async throws -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isLoading {
                    ProgressView("Loading recipes")
                        .frame(maxWidth: .infinity, minHeight: 320)
                } else if allRecipes.isEmpty {
                    ContentUnavailableView("No Recipes", systemImage: "fork.knife", description: Text("Add a recipe before spinning for a random meal."))
                        .frame(maxWidth: .infinity, minHeight: 320)
                } else {
                    VStack(spacing: 18) {
                        RandomMealWheelControls(
                            mealLimit: mealLimit,
                            selectedCount: wheelRecipes.count,
                            totalCount: allRecipes.count,
                            includesAllRecipes: includesAllRecipes,
                            canDecrease: canDecreaseMealLimit,
                            canIncrease: canIncreaseMealLimit,
                            isDisabled: isSpinning || isAddingMeal || selectedRecipe != nil,
                            onDecrease: decreaseMealLimit,
                            onIncrease: increaseMealLimit,
                            onToggleAll: toggleAllRecipes,
                            onShuffle: refreshWheelRecipes
                        )

                        RandomMealWheel(recipes: wheelRecipes, rotation: rotation)
                            .frame(width: 320, height: 320)
                            .frame(maxWidth: .infinity)
                            .onTapGesture {
                                spin()
                            }
                            .accessibilityLabel("Random meal wheel")
                            .accessibilityHint("Tap to spin and add a random meal to this day.")

                        RandomMealWheelStatus(
                            statusText: statusText,
                            errorMessage: errorMessage,
                            selectedRecipe: selectedRecipe,
                            isSpinning: isSpinning,
                            isAddingMeal: isAddingMeal,
                            onAdd: addSelectedRecipe,
                            onSpinAgain: spinAgain
                        )
                        .frame(minHeight: selectedRecipe == nil ? 72 : 164)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding()
            .navigationTitle("Random Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem {
                    Button(role: .close) { dismiss() }
                }
            }
            .task {
                await loadRecipes()
            }
            .sensoryFeedback(.success, trigger: successTrigger)
            .sensoryFeedback(.selection, trigger: spinHapticTrigger)
            .overlay {
                if selectedRecipe != nil {
                    RandomMealConfettiBurstView()
                        .id(confettiID)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var statusText: String {
        if isSpinning {
            return "Spinning..."
        }

        if let selectedRecipe {
            return selectedRecipe.title
        }

        return "Ready to spin"
    }

    private func loadRecipes() async {
        isLoading = true
        errorMessage = nil

        do {
            allRecipes = try await repository.getAllRecipes().sorted {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            mealLimit = min(defaultMealLimit, max(allRecipes.count, 1))
            includesAllRecipes = allRecipes.count <= defaultMealLimit
            refreshWheelRecipes()
        } catch {
            errorMessage = "Failed to load recipes."
        }

        isLoading = false
    }

    private func spin() {
        guard !isSpinning, !isAddingMeal, selectedRecipe == nil, !wheelRecipes.isEmpty else { return }

        errorMessage = nil
        selectedRecipe = nil
        isSpinning = true

        let selectedIndex = Int.random(in: wheelRecipes.indices)
        let segmentDegrees = 360.0 / Double(wheelRecipes.count)
        let fullSpins = Double(Int.random(in: 5...7)) * 360
        let targetRotation = rotation + fullSpins - (Double(selectedIndex) * segmentDegrees) - (segmentDegrees / 2)

        withAnimation(.timingCurve(0.12, 0.86, 0.18, 1.0, duration: 3.2)) {
            rotation = targetRotation
        }
        startSpinHaptics()

        Task {
            try? await Task.sleep(for: .seconds(3.25))

            guard !Task.isCancelled else { return }

            let recipe = wheelRecipes[selectedIndex]

            withAnimation(.spring(duration: 0.45, bounce: 0.3)) {
                selectedRecipe = recipe
                isSpinning = false
            }
            confettiID = UUID()
            successTrigger.toggle()
        }
    }

    private func startSpinHaptics() {
        Task {
            let tickDelays: [Duration] = [
                .milliseconds(55), .milliseconds(55), .milliseconds(60), .milliseconds(60),
                .milliseconds(65), .milliseconds(70), .milliseconds(75), .milliseconds(80),
                .milliseconds(85), .milliseconds(95), .milliseconds(105), .milliseconds(120),
                .milliseconds(140), .milliseconds(165), .milliseconds(190), .milliseconds(225),
                .milliseconds(260), .milliseconds(310), .milliseconds(370), .milliseconds(440)
            ]

            for delay in tickDelays {
                guard !Task.isCancelled, isSpinning else { return }
                spinHapticTrigger.toggle()
                try? await Task.sleep(for: delay)
            }
        }
    }

    private func addSelectedRecipe() {
        guard let selectedRecipe, !isAddingMeal else { return }

        errorMessage = nil
        isAddingMeal = true

        Task {
            do {
                try await onSelect(selectedRecipe)
                isAddingMeal = false
                dismiss()
            } catch {
                errorMessage = "Failed to add meal."
                isAddingMeal = false
            }
        }
    }

    private func spinAgain() {
        guard !isSpinning, !isAddingMeal else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            selectedRecipe = nil
        }
        errorMessage = nil
    }

    private var canDecreaseMealLimit: Bool {
        !includesAllRecipes && mealLimit > stepAmount
    }

    private var canIncreaseMealLimit: Bool {
        !includesAllRecipes && mealLimit < allRecipes.count
    }

    private func decreaseMealLimit() {
        guard canDecreaseMealLimit else { return }
        mealLimit = max(stepAmount, mealLimit - stepAmount)
        refreshWheelRecipes()
    }

    private func increaseMealLimit() {
        guard canIncreaseMealLimit else { return }
        mealLimit = min(allRecipes.count, mealLimit + stepAmount)
        refreshWheelRecipes()
    }

    private func toggleAllRecipes() {
        includesAllRecipes.toggle()
        refreshWheelRecipes()
    }

    private func refreshWheelRecipes() {
        selectedRecipe = nil
        errorMessage = nil
        isAddingMeal = false
        let cappedLimit = min(max(mealLimit, 1), allRecipes.count)
        wheelRecipes = includesAllRecipes
            ? allRecipes.shuffled()
            : Array(allRecipes.shuffled().prefix(cappedLimit))
    }
}

private struct RandomMealWheel: View {
    let recipes: [Recipe]
    let rotation: Double

    private let colors: [Color] = [
        .pink, .orange, .yellow, .green, .teal, .blue, .indigo, .purple
    ]

    var body: some View {
        ZStack {
            ZStack {
                ForEach(recipes.enumerated(), id: \.element.id) { index, recipe in
                    RandomMealWheelSegment(
                        index: index,
                        count: recipes.count,
                        color: colors[index % colors.count]
                    )

                    RandomMealWheelRecipeMarker(
                        recipe: recipe,
                        index: index,
                        count: recipes.count
                    )
                }
            }
            .rotationEffect(.degrees(rotation))

            Circle()
                .fill(.background)
                .frame(width: 64, height: 64)
                .shadow(radius: 8, y: 2)

            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 42))
                .foregroundStyle(.primary, .background)

            VStack {
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .shadow(radius: 2, y: 1)
                    .offset(y: -8)
                Spacer()
            }
        }
        .padding(8)
        .overlay {
            Circle()
                .stroke(.white.opacity(0.85), lineWidth: 4)
        }
        .clipShape(Circle())
        .shadow(radius: 14, y: 8)
        .contentShape(Circle())
    }
}

private struct RandomMealWheelControls: View {
    let mealLimit: Int
    let selectedCount: Int
    let totalCount: Int
    let includesAllRecipes: Bool
    let canDecrease: Bool
    let canIncrease: Bool
    let isDisabled: Bool
    let onDecrease: () -> Void
    let onIncrease: () -> Void
    let onToggleAll: () -> Void
    let onShuffle: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                StepperButton(systemImage: "minus", isEnabled: canDecrease && !isDisabled, action: onDecrease)

                VStack(spacing: 2) {
                    Text(includesAllRecipes ? "All recipes" : "\(selectedCount) meals")
                        .font(.headline)
                    Text("\(totalCount) available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                StepperButton(systemImage: "plus", isEnabled: canIncrease && !isDisabled, action: onIncrease)
            }

            HStack(spacing: 10) {
                Button(action: onToggleAll) {
                    Label(includesAllRecipes ? "Limit wheel" : "Include all", systemImage: includesAllRecipes ? "line.3.horizontal.decrease.circle" : "infinity.circle")
                        .frame(maxWidth: .infinity)
                }
                .disabled(isDisabled)

                Button(action: onShuffle) {
                    Label("Shuffle", systemImage: "shuffle")
                        .frame(maxWidth: .infinity)
                }
                .disabled(isDisabled)
            }
            .buttonStyle(.glass)
            .font(.subheadline.weight(.semibold))
        }
    }
}

private struct StepperButton: View {
    let systemImage: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline)
                .frame(width: 42, height: 36)
        }
        .buttonStyle(.glass)
        .disabled(!isEnabled)
        .accessibilityLabel(systemImage == "plus" ? "Increase meal count" : "Decrease meal count")
    }
}

private struct RandomMealWheelStatus: View {
    let statusText: String
    let errorMessage: String?
    let selectedRecipe: Recipe?
    let isSpinning: Bool
    let isAddingMeal: Bool
    let onAdd: () -> Void
    let onSpinAgain: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if let selectedRecipe {
                RandomMealWinnerView(
                    recipe: selectedRecipe,
                    isAddingMeal: isAddingMeal,
                    onAdd: onAdd,
                    onSpinAgain: onSpinAgain
                )
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text(statusText)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .contentTransition(.numericText())

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                } else {
                    Text(isSpinning ? "Finding a winner..." : "Tap the wheel to spin")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct RandomMealWinnerView: View {
    let recipe: Recipe
    let isAddingMeal: Bool
    let onAdd: () -> Void
    let onSpinAgain: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Label("Winner", systemImage: "party.popper.fill")
                .font(.headline)
                .foregroundStyle(.green)

            RecipeCardView(recipe: recipe, enablePreview: false)
                .frame(height: 132)
                .clipShape(.rect(cornerRadius: 10))

            HStack(spacing: 10) {
                Button(action: onSpinAgain) {
                    Label("Spin Again", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .disabled(isAddingMeal)

                Button(action: onAdd) {
                    if isAddingMeal {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Add", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(isAddingMeal)
            }
            .font(.subheadline.weight(.semibold))
        }
    }
}

private struct RandomMealWheelSegment: View {
    let index: Int
    let count: Int
    let color: Color

    var body: some View {
        RandomMealWedge(
            startAngle: startAngle,
            endAngle: endAngle
        )
        .fill(color.gradient)
    }

    private var segmentDegrees: Double {
        360.0 / Double(count)
    }

    private var startAngle: Angle {
        .degrees(-90 + (Double(index) * segmentDegrees))
    }

    private var endAngle: Angle {
        .degrees(-90 + (Double(index + 1) * segmentDegrees))
    }
}

private struct RandomMealWheelRecipeMarker: View {
    let recipe: Recipe
    let index: Int
    let count: Int

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 4) {
                RecipeWheelThumbnail(recipe: recipe)
                    .frame(width: thumbnailSize, height: thumbnailSize)

                Text(shortTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: labelWidth)
                    .shadow(radius: 1)
            }
            .position(labelPosition(in: proxy.size))
            .rotationEffect(.degrees(labelRotation))
        }
        .allowsHitTesting(false)
    }

    private var shortTitle: String {
        if recipe.title.count > 16 {
            return String(recipe.title.prefix(15)) + "..."
        }

        return recipe.title
    }

    private var labelWidth: CGFloat {
        count > 18 ? 58 : 82
    }

    private var thumbnailSize: CGFloat {
        count > 18 ? 28 : 36
    }

    private var centerAngle: Double {
        -90 + ((Double(index) + 0.5) * (360.0 / Double(count)))
    }

    private var labelRotation: Double {
        centerAngle + 90
    }

    private func labelPosition(in size: CGSize) -> CGPoint {
        let radius = min(size.width, size.height) * 0.34
        let radians = centerAngle * .pi / 180
        return CGPoint(
            x: size.width / 2 + (cos(radians) * radius),
            y: size.height / 2 + (sin(radians) * radius)
        )
    }
}

private struct RecipeWheelThumbnail: View {
    let recipe: Recipe

    var body: some View {
        ZStack {
            Circle()
                .fill(.thinMaterial)

            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                    default:
                        Image(systemName: "fork.knife")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
            } else {
                Image(systemName: "fork.knife")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(.white.opacity(0.8), lineWidth: 1)
        }
        .shadow(radius: 2, y: 1)
    }

    private var uiImage: UIImage? {
        guard let data = recipe.image.imageThumbnailData else { return nil }
        return UIImage(data: data)
    }

    private var imageURL: URL? {
        guard let imageUrl = recipe.image.imageUrl, !imageUrl.isEmpty else { return nil }
        return URL(string: imageUrl)
    }
}

private struct RandomMealConfettiBurstView: View {
    @State private var isExpanded = false

    private let pieces: [RandomMealConfettiPiece] = (0..<56).map { index in
        RandomMealConfettiPiece(index: index)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(pieces) { piece in
                    RoundedRectangle(cornerRadius: piece.cornerRadius)
                        .fill(piece.color)
                        .frame(width: piece.size.width, height: piece.size.height)
                        .rotationEffect(.degrees(isExpanded ? piece.rotation : 0))
                        .offset(
                            x: isExpanded ? piece.finalX(in: proxy.size.width) : 0,
                            y: isExpanded ? piece.finalY(in: proxy.size.height) : 0
                        )
                        .opacity(isExpanded ? 0 : 1)
                        .animation(
                            .easeOut(duration: piece.duration).delay(piece.delay),
                            value: isExpanded
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .position(x: proxy.size.width / 2, y: proxy.size.height * 0.62)
            .onAppear {
                isExpanded = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isExpanded = true
                }
            }
        }
    }
}

private struct RandomMealConfettiPiece: Identifiable {
    let id: Int
    let angle: Double
    let distance: Double
    let delay: Double
    let duration: Double
    let rotation: Double
    let size: CGSize
    let color: Color
    let cornerRadius: CGFloat

    init(index: Int) {
        id = index
        angle = Double(index) * 137.5
        distance = 92 + Double((index * 31) % 156)
        delay = Double(index % 8) * 0.025
        duration = 1.2 + Double(index % 5) * 0.12
        rotation = Double((index * 47) % 360)
        size = CGSize(width: 7 + CGFloat(index % 4) * 2, height: 12 + CGFloat(index % 3) * 4)
        cornerRadius = CGFloat(index % 2)

        let palette: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
        color = palette[index % palette.count]
    }

    func finalX(in width: CGFloat) -> CGFloat {
        cos(angle * .pi / 180) * distance
    }

    func finalY(in height: CGFloat) -> CGFloat {
        sin(angle * .pi / 180) * distance + 24
    }
}

private struct RandomMealWedge: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
