//
//  RecipePreview.swift
//  RecipesList
//
//  Created by Tom Knighton on 11/10/2025.
//

import SwiftUI
import API
import Environment

struct RecipePreview: View {
    
    let recipe: SDRecipe
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack {
                    HStack(spacing: 24) {
                        if let totalTime = recipe.totalMins {
                            VStack(alignment: .leading) {
                                Text("Time")
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
                        
                        if let serves = recipe.serves {
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
                    
                    ForEach(recipe.ingredients?.sorted(by: { $0.sortIndex > $1.sortIndex }) ?? []) { ingredient in
                        HStack {
                            ZStack {
                                Circle()
                                    .frame(width: 25, height: 25)
                                
                                if let emoji = ingredient.emojiDescriptor {
                                    Text(emoji)
                                        .font(.caption)
                                }
                            }
                            
                            Text(ingredient.rawIngredient)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Material.thin)
                        .clipShape(.rect(cornerRadius: 10))
                    }
                    
                    Spacer().frame(height: 8)
                }
                .padding()
            }
        }
    }
}
