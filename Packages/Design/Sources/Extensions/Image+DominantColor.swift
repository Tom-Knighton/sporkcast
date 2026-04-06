//
//  Image+DominantColor.swift
//  Design
//
//  Created by Tom Knighton on 19/09/2025.
//

import SwiftUI
import UIKit

public extension Image {
    
    @MainActor
    func getDominantColor() async -> Color? {
        if let uiImage = ImageRenderer(content: self).uiImage {
            if let uiColour = uiImage.dominantBackgroundColor(
                centerBias: 20,
                minimumSaturation: 0.22,
                preferredBrightnessRange: 0.28...0.74
            ) {
                return Color(uiColor: uiColour)
            } else {
                return .clear
            }
        }
        
        return .clear
    }
}

public extension UIImage {
    /// Dominant color, biased toward the center via a 2D Gaussian.
    /// - Parameters:
    ///   - centerBias: 0 => no bias (uniform). Higher => stronger center preference.
    ///   - maxDimension: Longest side to downscale to (performance knob).
    ///   - alphaThreshold: Skip pixels below this alpha.
    ///   - quantizationBits: Per-channel bits for histogram buckets (e.g. 5 -> 32 levels).
    ///   - minimumSaturation: Lower values increase tolerance for gray/white/near-neutral colors.
    ///   - preferredBrightnessRange: Color value/brightness range to prefer (penalizes very dark/light picks).
    func dominantBackgroundColor(
        centerBias: Double = 2.0,
        maxDimension: Int = 64,
        alphaThreshold: UInt8 = 8,
        quantizationBits: Int = 5,
        minimumSaturation: Double = 0.16,
        preferredBrightnessRange: ClosedRange<Double> = 0.20...0.82
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
        
        let clampedMinimumSaturation = min(max(minimumSaturation, 0), 1)
        let lower = min(max(preferredBrightnessRange.lowerBound, 0), 1)
        let upper = min(max(preferredBrightnessRange.upperBound, 0), 1)
        let clampedBrightnessRange = min(lower, upper)...max(lower, upper)

        func brightnessPenalty(_ value: Double) -> Double {
            if clampedBrightnessRange.contains(value) { return 1.0 }

            // Keep a small floor so neutral/very dark/light images still return a color.
            let floor = 0.04
            if value < clampedBrightnessRange.lowerBound {
                guard clampedBrightnessRange.lowerBound > 0 else { return 1.0 }
                return max(floor, value / clampedBrightnessRange.lowerBound)
            } else {
                let upperGap = max(0.001, 1.0 - clampedBrightnessRange.upperBound)
                return max(floor, (1.0 - value) / upperGap)
            }
        }

        func score(_ acc: Acc) -> Double {
            guard acc.w > 0 else { return 0 }

            let r = (acc.r / acc.w) / 255.0
            let g = (acc.g / acc.w) / 255.0
            let b = (acc.b / acc.w) / 255.0

            let maxChannel = max(r, max(g, b))
            let minChannel = min(r, min(g, b))
            let chroma = maxChannel - minChannel
            let saturation = maxChannel == 0 ? 0 : chroma / maxChannel
            let brightness = maxChannel

            let saturationPenalty: Double
            if clampedMinimumSaturation <= 0 {
                saturationPenalty = 1.0
            } else {
                saturationPenalty = max(0.04, min(1.0, saturation / clampedMinimumSaturation))
            }

            // Slight tie-break toward colorful results once penalties are applied.
            let vibranceBias = 0.75 + (0.25 * saturation)
            return acc.w * saturationPenalty * brightnessPenalty(brightness) * vibranceBias
        }

        guard let best = buckets.values.max(by: { score($0) < score($1) }), best.w > 0 else { return nil }
        
        let r = CGFloat(best.r / best.w) / 255.0
        let g = CGFloat(best.g / best.w) / 255.0
        let b = CGFloat(best.b / best.w) / 255.0
        let a = CGFloat(best.a / best.w) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
