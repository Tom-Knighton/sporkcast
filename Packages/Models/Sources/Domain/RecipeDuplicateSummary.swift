import Foundation

public struct RecipeDuplicateSummary: Sendable {
    public let id: UUID
    public let title: String
    public let sourceURL: String
    public let ingredientNames: [String]

    public init(id: UUID, title: String, sourceURL: String, ingredientNames: [String] = []) {
        self.id = id
        self.title = title
        self.sourceURL = sourceURL
        self.ingredientNames = ingredientNames
    }

    public init(recipe: Recipe) {
        self.init(id: recipe.id, title: recipe.title, sourceURL: recipe.sourceUrl,
                  ingredientNames: recipe.ingredientSections.flatMap(\.ingredients).map { $0.ingredientPart ?? $0.ingredientText })
    }

    public static func titleKey(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public static func sourceKey(_ source: String) -> String? {
        guard var components = URLComponents(string: source),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = components.host else { return nil }
        components.scheme = scheme
        components.host = host.lowercased()
        components.fragment = nil
        if (scheme == "https" && components.port == 443) || (scheme == "http" && components.port == 80) {
            components.port = nil
        }
        // Query order can be significant for signed URLs.
        components.percentEncodedQuery = components.percentEncodedQuery?.split(separator: "&").filter {
            let name = String($0.split(separator: "=", maxSplits: 1).first ?? "").removingPercentEncoding?.lowercased() ?? ""
            return !name.hasPrefix("utm_") && name != "fbclid" && name != "gclid"
        }.joined(separator: "&")
        if components.percentEncodedQuery?.isEmpty == true { components.percentEncodedQuery = nil }
        return components.string
    }
}
