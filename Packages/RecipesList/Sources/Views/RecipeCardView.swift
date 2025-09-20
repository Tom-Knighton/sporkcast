//
//  RecipeCardView.swift
//  RecipesList
//
//  Created by Tom Knighton on 20/09/2025.
//

import API
import SwiftUI
import Design

public struct RecipeCardView: View {
    
    let recipe: Recipe
    
    public var body: some View {
        ZStack {
            LinearGradient(colors: [.clear, .clear, .clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
            VStack {
                HStack {
                    Spacer()
                    
                    if let totalMins = recipe.totalMins ?? recipe.minutesToCook {
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
        .background(image.blur(radius: 1))
        .clipShape(.rect(cornerRadius: 10))
        .fontDesign(.rounded)
    }
    
    @ViewBuilder
    private var image: some View {
        if let data = recipe.thumbnailData, let ui = UIImage(data: data) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else if let file = recipe.imageAssetFileName,
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
