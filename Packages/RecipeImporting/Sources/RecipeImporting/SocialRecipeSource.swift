//
//  SocialRecipeSource.swift
//  RecipeImporting
//
//  Created by Tom Knighton on 20/05/2026.
//

import Foundation

public enum SocialRecipeSource {
    public static func isSupported(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return isInstagram(host) || isTikTok(host)
    }

    public static func isLikelyVideo(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }

        let videoHosts = [
            "youtube.com",
            "youtu.be",
            "tiktok.com",
            "instagram.com",
            "facebook.com",
            "fb.watch",
            "vimeo.com"
        ]

        return videoHosts.contains { host == $0 || host.hasSuffix(".\($0)") }
    }

    private static func isInstagram(_ host: String) -> Bool {
        host == "instagram.com"
            || host == "www.instagram.com"
            || host.hasSuffix(".instagram.com")
    }

    private static func isTikTok(_ host: String) -> Bool {
        host == "tiktok.com"
            || host == "www.tiktok.com"
            || host.hasSuffix(".tiktok.com")
    }
}
