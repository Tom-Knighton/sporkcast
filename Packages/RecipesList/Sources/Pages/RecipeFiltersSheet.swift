//
//  RecipeFiltersSheet.swift
//  RecipesList
//
//  Created by Tom Knighton on 05/04/2026.
//

import SwiftUI

struct RecipeFilters: Equatable {
    var minimumRating: Double = 0
    var minimumComments: Int = 0
    var maximumTimeMinutes: Int = 0
    var sort: RecipeSortOption = .dateModified

    var hasActiveFilters: Bool {
        minimumRating > 0 || minimumComments > 0 || maximumTimeMinutes > 0 || sort != .dateModified
    }
}

enum RecipeSortOption: String, CaseIterable, Identifiable {
    case nameAZ
    case nameZA
    case dateAdded
    case dateModified
    case time

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nameAZ:
            return "Name (A-Z)"
        case .nameZA:
            return "Name (Z-A)"
        case .dateAdded:
            return "Date Added"
        case .dateModified:
            return "Date Modified"
        case .time:
            return "Time (Shortest First)"
        }
    }
}

struct RecipeFiltersSheet: View {
    @Binding var filters: RecipeFilters
    @Environment(\.dismiss) private var dismiss

    private var minimumRatingLabel: String {
        guard filters.minimumRating > 0 else { return "Any rating" }
        let value = filters.minimumRating.formatted(.number.precision(.fractionLength(0...1)))
        return "\(value)+ stars"
    }

    private var minimumCommentsLabel: String {
        guard filters.minimumComments > 0 else { return "Any number of comments" }
        return "\(filters.minimumComments)+ comments"
    }

    private var maximumTimeLabel: String {
        guard filters.maximumTimeMinutes > 0 else { return "Any time" }
        return "Up to \(filters.maximumTimeMinutes) min"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sort") {
                    Picker("Sort By", selection: $filters.sort) {
                        ForEach(RecipeSortOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Filter") {
                    Stepper(value: $filters.maximumTimeMinutes, in: 0...480, step: 5) {
                        Text(maximumTimeLabel)
                    }
                    Stepper(value: $filters.minimumRating, in: 0...5, step: 0.5) {
                        Text(minimumRatingLabel)
                    }
                    Stepper(value: $filters.minimumComments, in: 0...500) {
                        Text(minimumCommentsLabel)
                    }
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { self.resetFilters() }) {
                        Label("Reset", systemImage: "arrow.uturn.backward")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: dismissSheet)
                }
            }
        }
    }

    private func resetFilters() {
        filters = RecipeFilters()
    }

    private func dismissSheet() {
        dismiss()
    }
}
