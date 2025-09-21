//
//  RecipeStepsView.swift
//  Recipe
//
//  Created by Tom Knighton on 21/09/2025.
//

import SwiftUI
import API

public struct RecipeStepsView: View {
    
    @Environment(RecipeViewModel.self) private var viewModel
    @State private var stepSections: [RecipeStepSection] = []
    
    public let tint: Color
    
    public var body: some View {
        VStack(alignment: .leading) {
            ForEach(stepSections) { section in
                Text(section.title)
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(section.steps ?? []) { step in
                    HStack {
                        ZStack {
                            Circle()
                                .fill(tint)
                                .frame(width: 25, height: 25)
                            
                            Text(String(describing: step.sortIndex + 1))
                                .bold()
                        }
                        
                        Text(step.rawStep)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Material.thin)
                    .clipShape(.rect(cornerRadius: 10))
                }
            }
        }
        .fontDesign(.rounded)
        .frame(maxWidth: .infinity)
        .onAppear {
            if stepSections.isEmpty {
                let sections = viewModel.recipe?.stepSections?.sorted(by: { $0.sortIndex < $1.sortIndex }) ?? []
                sections.forEach { sect in
                    if sect.title.isEmpty {
                        sect.title = "Steps:"
                    }
                    sect.steps = sect.steps?.sorted(by: { $0.sortIndex < $1.sortIndex })
                }
                self.stepSections = sections
            }
        }
    }
}
