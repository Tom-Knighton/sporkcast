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
            if let uiColour = uiImage.dominantBackgroundColor(centerBias: 20) {
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
