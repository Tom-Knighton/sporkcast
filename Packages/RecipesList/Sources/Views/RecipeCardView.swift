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
    @Environment(\.modelContext) private var context
    let recipe: Recipe
    
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
        .frame(maxWidth: .infinity, minHeight: 150)
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
        } preview: {
            RecipePreview(recipe: recipe)
        }
        .alert("Delete Recipe", isPresented: $showDeleteConfirm) {
            Button(role: .cancel) { } label: { Text("Cancel") }
            Button(role: .destructive) {
                Task {
                    let id = recipe.id
                    try? context.delete(model: SDRecipe.self, where: #Predicate<SDRecipe> { sd in sd.id == id })
                    try? context.save()
                }
            } label: { Text("Delete") }
        } message: {
            Text("Are you sure you want to delete this recipe? This cannot be undone.")
        }


    }
    
    @ViewBuilder
    private var image: some View {
        if let data = recipe.image.imageThumbnailData, let ui = UIImage(data: data) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else if let file = recipe.image.imageAssetFileName,
                  let url = try? ImageStore.imagesDirectory().appendingPathComponent(file),
                  let data = try? Data(contentsOf: url),
                  let ui = UIImage(data: data) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else {
            Rectangle().opacity(0.1)
        }
    }
}


class PrivateImage {
    private let baseImage: UIImage
    
    init?(privateSystemName name: String) {
        guard let bundleClass = NSClassFromString("SFSCoreGlyphsBundle") as AnyObject?,
              let bundle = bundleClass.perform(NSSelectorFromString("private"))?.takeUnretainedValue(),
              let assetManagerClass = NSClassFromString("_UIAssetManager") as AnyObject?,
              let assetManager = assetManagerClass.perform(NSSelectorFromString("assetManagerForBundle:"), with: bundle)?.takeUnretainedValue(),
              let baseImage = assetManager.perform(NSSelectorFromString("imageNamed:"), with: name)?.takeUnretainedValue() as? UIImage else {
            return nil
        }
        self.baseImage = baseImage
    }
    
    func imageAsset() -> Image? {
        Image(uiImage: self.baseImage.withRenderingMode(.alwaysTemplate))
    }
}

extension Image {
    init?(privateSystemName: String) {
        guard let privateImage = PrivateImage(privateSystemName: privateSystemName) else {
            return nil
        }
        self = privateImage.imageAsset() ?? Image(systemName: "questionmark.square.fill")
    }
}
