//
//  RecipePage.swift
//  Recipe
//
//  Created by Tom Knighton on 24/08/2025.
//

import SwiftUI
import Design
import API

public struct RecipePage: View {
    
    @State private var offset: CGFloat = 0
    @State private var showNavTitle = false
    @Environment(\.colorScheme) private var scheme
    
    @Environment(\.networkClient) private var client
    @State private var recipe: Recipe?
    
    @State private var selection: Int = 1
    @State private var dominantColor: Color = .clear
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    if let recipe {
                        RecipeHeadingView(recipe.imageUrl ?? "")
                        
                        RecipeTitleView(for: recipe)
                        
                        VStack {
                            Spacer().frame(height: 20)
                            
                            HStack(spacing: 24) {
                                if let totalTime = recipe.totalMins {
                                    VStack(alignment: .leading) {
                                        Text("Total Time")
                                            .font(.caption.weight(.heavy))
                                            .opacity(0.7)
                                            .textCase(.uppercase)
                                        Text("\(totalTime, specifier: "%.0f") mins")
                                            .bold()
                                        
                                    }
                                    Divider()
                                }
                                
                                if let cookingMins = recipe.minutesToCook {
                                    VStack(alignment: .leading) {
                                        Text("Cooking Time")
                                            .font(.caption.weight(.heavy))
                                            .opacity(0.7)
                                            .textCase(.uppercase)
                                        Text("\(cookingMins, specifier: "%.0f") mins")
                                            .bold()
                                        
                                    }
                                    Divider()
                                        .overlay(Material.bar)
                                        .opacity(0.68)
                                }
                                
                                if let serves = recipe.serves {
                                    VStack(alignment: .leading) {
                                        Text("Serves")
                                            .font(.caption.weight(.heavy))
                                            .opacity(0.7)
                                            .textCase(.uppercase)
                                        Text(serves)
                                            .bold()
                                        
                                    }
                                }
                                
                                Spacer()
                            }
                            
                            Spacer().frame(height: 20)
                            
                            RecipeSourceButton(recipe, with: dominantColor)
                            
                            Spacer().frame(height: 20)
                            HStack {
                                Picker("", selection: $selection) {
                                    Text("Ingredients")
                                        .tag(1)
                                    Text("Directions").tag(2)
                                }
                                .pickerStyle(.segmented)
                                Spacer()
                            }
                            
                        }
                        .padding(.horizontal)
                    }
                }
                .fontDesign(.rounded)
            }
            .scrollBounceBehavior(.basedOnSize)
            .onScrollGeometryChange(for: CGFloat.self, of: { geo in
                return geo.contentOffset.y + geo.contentInsets.top
            }, action: { new, old in
                offset = new
            })
        }
        .ignoresSafeArea()
        .task(id: "load") {
            if recipe != nil { return }
            
            self.recipe = try? await client.post(Recipes.uploadFromUrl(url: "https://beatthebudget.com/recipe/chicken-katsu-curry/"))
        }
        .colorScheme(.dark)
        .background(
            ZStack {
                if let recipe {
                    AsyncImage(url: URL(string: recipe.imageUrl ?? "")) { img in
                        img
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .task {
                                self.dominantColor = await img.getDominantColor() ?? .clear
                            }
                    } placeholder: {
                        EmptyView()
                    }
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(2)
                    .blur(radius: scheme == .dark ? 100 : 64)
                    .ignoresSafeArea()
                    .overlay(Material.ultraThin.opacity(0.2))
                }
            }
        )
        .onPreferenceChange(TitleBottomYKey.self) { bottom in
            let collapsed = bottom < 0
            if collapsed != showNavTitle {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showNavTitle = collapsed
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(recipe?.title ?? "")
                    .font(.headline)
                    .opacity(showNavTitle ? 1 : 0)
                    .accessibilityHidden(!showNavTitle)
                    .animation(.easeInOut(duration: 0.2), value: showNavTitle)
            }
        }
    }
}

#Preview {
    NavigationStack {
        RecipePage()
            .withPreviewEnvs()
    }
    
}

extension String  {
    var isNumber: Bool {
        return !isEmpty && rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
    }
}

extension Image {
    
    @MainActor
    func getDominantColor() async -> Color? {
        if let uiImage = ImageRenderer(content: self).uiImage {
            return Color(uiColor: uiImage.dominantBackgroundColor() ?? .clear)
        }
        
        return .clear
    }
}

extension UIImage {
    /// Dominant color, biased toward the center via a 2D Gaussian.
    /// - Parameters:
    ///   - centerBias: 0 => no bias (uniform). Higher => stronger center preference.
    ///   - maxDimension: Longest side to downscale to (performance knob).
    ///   - alphaThreshold: Skip pixels below this alpha.
    ///   - quantizationBits: Per-channel bits for histogram buckets (e.g. 5 -> 32 levels).
    func dominantBackgroundColor(
        centerBias: Double = 2.0,
        maxDimension: Int = 64,
        alphaThreshold: UInt8 = 8,
        quantizationBits: Int = 5
    ) -> UIColor? {
        guard let cg = cgImage,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }
        
        let srcW = cg.width
        let srcH = cg.height
        if srcW == 0 || srcH == 0 { return nil }
        
        let scale = Double(maxDimension) / Double(max(srcW, srcH))
        let w = max(1, Int(Double(srcW) * scale))
        let h = max(1, Int(Double(srcH) * scale))
        
        // RGBA8 premultipliedLast in sRGB
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        ctx.interpolationQuality = .low
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { return nil }
        
        let bytesPerRow = ctx.bytesPerRow
        let ptr = data.bindMemory(to: UInt8.self, capacity: bytesPerRow * h)
        
        struct Acc { var w: Double; var r: Double; var g: Double; var b: Double; var a: Double }
        var buckets: [Int: Acc] = [:]
        buckets.reserveCapacity(2048)
        
        let qShift = max(0, 8 - quantizationBits)
        let cx = Double(w - 1) / 2.0
        let cy = Double(h - 1) / 2.0
        
        // sigma controls how quickly weight decays from center. Higher centerBias => smaller sigma => stronger bias.
        let baseSigma = Double(min(w, h)) / 2.0
        let sigma = centerBias <= 0 ? Double.infinity : baseSigma / centerBias
        let twoSigmaSq = 2.0 * sigma * sigma
        
        for y in 0..<h {
            let row = y * bytesPerRow
            for x in 0..<w {
                let o = row + x * 4
                let r = ptr[o]
                let g = ptr[o + 1]
                let b = ptr[o + 2]
                let a = ptr[o + 3]
                if a < alphaThreshold { continue }
                
                let weight: Double
                if centerBias <= 0 {
                    weight = 1.0
                } else {
                    let dx = Double(x) - cx
                    let dy = Double(y) - cy
                    let d2 = dx*dx + dy*dy
                    weight = exp(-d2 / twoSigmaSq)
                }
                
                let qr = Int(r) >> qShift
                let qg = Int(g) >> qShift
                let qb = Int(b) >> qShift
                let key = (qr << (2 * quantizationBits)) | (qg << quantizationBits) | qb
                
                var acc = buckets[key] ?? Acc(w: 0, r: 0, g: 0, b: 0, a: 0)
                acc.w += weight
                acc.r += weight * Double(r)
                acc.g += weight * Double(g)
                acc.b += weight * Double(b)
                acc.a += weight * Double(a)
                buckets[key] = acc
            }
        }
        
        guard let best = buckets.max(by: { $0.value.w < $1.value.w })?.value, best.w > 0 else { return nil }
        
        let r = CGFloat(best.r / best.w) / 255.0
        let g = CGFloat(best.g / best.w) / 255.0
        let b = CGFloat(best.b / best.w) / 255.0
        let a = CGFloat(best.a / best.w) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
