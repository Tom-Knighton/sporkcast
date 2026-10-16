import Foundation

struct RecipeChatSuggestion: Identifiable {
    let title: String
    let symbol: String
    let prompt: String

    var id: String { title }
}
