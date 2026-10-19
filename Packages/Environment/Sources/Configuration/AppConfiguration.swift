import Foundation

public enum AppConfiguration {
    public static let environment = value("SPORKCAST_ENVIRONMENT", developmentDefault: "development")
    public static let apiURL = value("SPORKCAST_API_URL", developmentDefault: "https://api.dev.recipe.tomk.online/")
    public static let supabaseURL = requiredURL("SPORKCAST_SUPABASE_URL", developmentDefault: "https://db.sporkast.dev.tomk.online")
    public static let supabasePublishableKey = value("SPORKCAST_SUPABASE_PUBLIC_KEY", developmentDefault: "sb_publishable_tyZO5jlR3XGvNuNHGOKDpe_Xms05kQF")
    public static let revenueCatAPIKey = value("SPORKCAST_REVENUECAT_API_KEY", developmentDefault: "test_LLDFxuRGhaxgNbxfraFSrtPXLqP")
    public static let launchDarklyMobileKey = value("SPORKCAST_LAUNCHDARKLY_MOBILE_KEY", developmentDefault: "mob-0e75d9dd-fb2e-4080-b627-83dfaf403079")
    public static let appGroupIdentifier = value("SPORKCAST_APP_GROUP", developmentDefault: "group.sporkcast.development")
    public static let urlScheme = value("SPORKCAST_URL_SCHEME", developmentDefault: "sporkcast-development")
    public static let keychainService = value("SPORKCAST_KEYCHAIN_SERVICE", developmentDefault: "online.tomk.sporkcast.development.supabase")
    public static let inviteHost = value("SPORKCAST_INVITE_HOST", developmentDefault: "sporkast.tom-knighton.com")

    public static var databasePath: String? {
        guard environment == "production" else { return nil }
        // The production bundle ID was previously used by dev builds. Keep their database untouched.
        do {
            let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            return directory.appending(path: "Sporkcast.production.sqlite").path
        } catch {
            fatalError("Unable to create production database directory: \(error)")
        }
    }

    private static func requiredURL(_ key: String, developmentDefault: String) -> URL {
        guard let url = URL(string: value(key, developmentDefault: developmentDefault)),
              url.scheme == "https", url.host != nil else {
            fatalError("\(key) must be an HTTPS URL")
        }
        return url
    }

    private static func value(_ key: String, developmentDefault: String) -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        #if DEBUG
        // Package tests and previews can run without the application's Info.plist.
        if info["SPORKCAST_ENVIRONMENT"] == nil {
            return developmentDefault
        }
        #endif
        guard let value = info[key] as? String,
              !value.isEmpty,
              !value.contains("$(") else {
            fatalError("Missing \(key) for \(Bundle.main.bundleIdentifier ?? "app"). Check Configuration/*.xcconfig.")
        }
        return value
    }
}
