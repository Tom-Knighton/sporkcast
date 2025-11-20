//
//  RecipeCardView.swift
//  RecipesList
//
//  Created by Tom Knighton on 20/09/2025.
//

import Models
import SwiftUI
import Design
import Environment
import API

public struct RecipeCardView: View {
    
    @State private var showDeleteConfirm = false
    @Environment(AppRouter.self) private var router
    let recipe: Recipe
    let hasPreview: Bool
    
    public init(recipe: Recipe, enablePreview: Bool = true) {
        self.recipe = recipe
        self.hasPreview = enablePreview
    }
    
    public var body: some View {
        ZStack {
            LinearGradient(colors: [.clear, .clear, .clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
            VStack {
                HStack {
                    Spacer()
                    
                    if let totalMins = recipe.timing.totalTime ?? recipe.timing.cookTime {
                        HStack {
                            Image(systemName: "clock")
                            Text("\(Int(totalMins))m")
                        }
                        .bold()
                        .padding(.all, 8)
                        .background(Material.ultraThin)
                        .clipShape(.rect(cornerRadius: 10))
                        .labelIconToTitleSpacing(8)
                        .foregroundStyle(.primary)
                    }
                    
                    if let serves = recipe.serves, serves.isNumber {
                        HStack {
                            Image(systemName: "person")
                            Text(serves)
                        }
                        .bold()
                        .padding(.all, 8)
                        .background(Material.ultraThin)
                        .clipShape(.rect(cornerRadius: 10))
                        .labelIconToTitleSpacing(8)
                        .foregroundStyle(.primary)
                    }
                }
                Spacer()
                Text(recipe.title)
                    .bold()
                    .clipShape(.rect(cornerRadius: 10))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.white)
                    .shadow(radius: 3)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, minHeight: 135)
        .background(image)
        .clipShape(.rect(cornerRadius: 10))
        .fontDesign(.rounded)
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: { router.navigateTo(.recipe(recipe: recipe)) }) {
                Label("Open", systemImage: "hand.point.up")
            }
            Divider()
            Button(role: .destructive) {
                self.showDeleteConfirm = true
            } label: { Label("Delete", systemImage: "trash").tint(.red) }
        }
        .alert("Delete Recipe", isPresented: $showDeleteConfirm) {
            Button(role: .cancel) { } label: { Text("Cancel") }
//            Button(role: .destructive) {
//                Task {
//                    let id = recipe.id
//                    try? context.delete(model: SDRecipe.self, where: #Predicate<SDRecipe> { sd in sd.id == id })
//                    try? context.save()
//                }
//            } label: { Text("Delete") }
        } message: {
            Text("Are you sure you want to delete this recipe? This cannot be undone.")
        }


    }
    
    @ViewBuilder
    private var image: some View {
        if let data = recipe.image.imageThumbnailData, let ui = UIImage(data: data) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else if let url = recipe.image.imageUrl {
            AsyncImage(url: URL(string: url)) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                EmptyView()
            }

        } else {
            Rectangle().opacity(0.1)
        }
    }
}
