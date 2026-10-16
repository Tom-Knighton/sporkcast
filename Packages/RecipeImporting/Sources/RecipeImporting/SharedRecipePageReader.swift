import Foundation

enum SharedRecipePageReader {
    static let defaultsKey = "share.recipePage.v1"

    static func takeRecipe(for url: URL, defaults: UserDefaults? = UserDefaults(suiteName: "group.sporkcast")) -> ImportedRecipeRecord? {
        guard let defaults, let data = defaults.data(forKey: defaultsKey) else { return nil }
        defer { defaults.removeObject(forKey: defaultsKey) }
        guard data.count <= 1_000_000,
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              snapshot.url == url.absoluteString,
              (0...300).contains(Date().timeIntervalSince1970 - snapshot.createdAt) else { return nil }
        return RecipeSchemaParser.parse(scripts: snapshot.jsonLD, sourceURL: url)
    }

    private struct Snapshot: Decodable {
        let url: String
        let createdAt: TimeInterval
        let jsonLD: [String]
    }
}
