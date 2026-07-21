//
//  MealplanSnippetView.swift
//  sporkcast
//
//  Created by Tom Knighton on 18/06/2026.
//

import SwiftUI
import AppIntents

@available(anyAppleOS 27.0, *)
public struct MealplanSnippetView: View {
    
    let title: String
    let plannedMeals: [PlannedMealEntity]
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            if plannedMeals.isEmpty {
                Text("Nothing planned")
                    .font(.subheadline)
            } else {
                ForEach(plannedMeals) { meal in
                    Button(intent: OpenMealplanIntent()) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(meal.recipeName)
                                    .font(.body)
                                
                                Text("\(meal.date.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                            }
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
    }
}

@available(anyAppleOS 27.0, *)
#Preview {
    MealplanSnippetView(title: MealPlanPeriod.thisWeek.displayName, plannedMeals: [])
}
