//
//  ImageStore.swift
//  API
//
//  Created by Tom Knighton on 20/09/2025.
//

import Foundation

public enum ImageStore {
    public static func imagesDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        let dir = base.appendingPathComponent("Images", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    public static func fileURL(forKey key: String, ext: String = "jpg") throws -> URL {
        try imagesDirectory().appendingPathComponent("\(key).\(ext)")
    }
}
