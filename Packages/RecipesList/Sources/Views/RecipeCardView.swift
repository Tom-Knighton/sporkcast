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
import Nuke
import UIKit

@MainActor
private final class RecipeImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    
    private var task: ImageTask?
    
    func load(from url: URL?) {
        task?.cancel()
        task = nil
        image = nil
        
        guard let url else { return }
        
        let request = ImageRequest(url: url)
        
        if let cached = ImagePipeline.shared.cache.cachedImage(for: request) {
            image = cached.image
            return
        }
        
        task = ImagePipeline.shared.loadImage(with: request) { [weak self] result in
            guard let self else { return }
            if case .success(let response) = result {
                Task { @MainActor in self.image = response.image }
            }
        }
    }
    
    deinit { task?.cancel() }
}

private struct RecipeRemoteImage: View {
    let url: URL?
    let preloaded: UIImage?
    let onLoaded: ((UIImage) -> Void)?
    
    @StateObject private var loader = RecipeImageLoader()
    
    var body: some View {
        Group {
            if let preloaded {
                Image(uiImage: preloaded)
                    .resizable()
                    .scaledToFill()
            } else if let img = loader.image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .onAppear { onLoaded?(img) }
            } else {
                Rectangle().opacity(0.1)
            }
        }
        .onAppear {
            guard preloaded == nil else { return }
            loader.load(from: url)
        }
        .onChange(of: url) { _, newValue in
            guard preloaded == nil else { return }
            loader.load(from: newValue)
        }
    }
}

public struct RecipeCardView: View {
    
    let recipe: Recipe
    let hasPreview: Bool
    let preloadedImage: UIImage?
    let onImageLoaded: ((UIImage) -> Void)?
    
    private var imageURL: URL? {
        guard let s = recipe.image.imageUrl, !s.isEmpty else { return nil }
        return URL(string: s)
    }
    
    public init(
        recipe: Recipe,
        enablePreview: Bool = true,
        preloadedImage: UIImage? = nil,
        onImageLoaded: ((UIImage) -> Void)? = nil
    ) {
        self.recipe = recipe
        self.hasPreview = enablePreview
        self.preloadedImage = preloadedImage
        self.onImageLoaded = onImageLoaded
    }
    
    public var body: some View {
        ZStack {
            RecipeRemoteImage(url: imageURL, preloaded: preloadedImage, onLoaded: onImageLoaded)
                .clipped()
                .frame(idealHeight: 135)
                .fixedSize(horizontal: false, vertical: true)
            
            LinearGradient(colors: [.clear, .clear, .clear, .black.opacity(0.7)],
                           startPoint: .top,
                           endPoint: .bottom)
            
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
        .clipShape(.rect(corners: .concentric))
        .fontDesign(.rounded)
        .contentShape(Rectangle())
    }
}
