//
//  RecipeEntity.swift
//  sporkcast
//
//  Created by Tom Knighton on 28/06/2026.
//

import AppIntents
import CoreTransferable
import CoreSpotlight
import Environment
import Models
import UniformTypeIdentifiers

@available(anyAppleOS 27.0, *)
public struct RecipeEntity: IndexedEntity, URLRepresentableEntity, Identifiable, Sendable {
    
    public static let defaultQuery = RecipeEntryEntityQuery()
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Recipe")
    public static let urlRepresentation: EntityURLRepresentation<RecipeEntity> = "sporkcast://recipe/\(.id)"

    public let id: UUID
    
    @Property(indexingKey: \.displayName)
    public var title: String
    
    @Property(indexingKey: \.contentDescription)
    public var summary: String?
    
    @Property(indexingKey: \.keywords)
    public var keywords: [String]
    
    @Property
    public var ingredientNames: [String]
    
    @Property
    public var duration: Duration?
    
    @Property
    public var serves: String?
    
    @Property
    public var prepDuration: Duration?
    
    @Property
    public var imageUrl: URL?

    public var imageData: Data?
        
    public var displayRepresentation: DisplayRepresentation {
        let synonyms: [LocalizedStringResource] = [
            "\(title)",
            "\(title) recipe",
            "\(title) ingredients",
            "recipe",
            "cook"
        ]

        if let imageData {
            return DisplayRepresentation(title: "\(title)", subtitle: "\(displaySubtitle)", image: .init(data: imageData), synonyms: synonyms)
        } else if let imageUrl {
            return DisplayRepresentation(title: "\(title)", subtitle: "\(displaySubtitle)", image: .init(url: imageUrl), synonyms: synonyms)
        } else {
            return DisplayRepresentation(title: "\(title)", subtitle: "\(displaySubtitle)", image: .init(systemName: "fork.knife"), synonyms: synonyms)
        }
    }
    
    public var attributeSet: CSSearchableItemAttributeSet {
        let attributeSet = defaultAttributeSet
        let searchableKeywords = Self.searchableKeywords(
            title: title,
            summary: summary,
            keywords: keywords,
            ingredientNames: ingredientNames
        )

        attributeSet.contentURL = URL(string: "sporkcast://recipe/\(id.uuidString)")
        attributeSet.title = title
        attributeSet.displayName = title
        attributeSet.contentType = "online.tomk.sporkcast.recipe"
        attributeSet.contentTypeTree = [
            "online.tomk.sporkcast.recipe",
            UTType.json.identifier,
            UTType.data.identifier
        ]
        attributeSet.domainIdentifier = "recipes"
        attributeSet.keywords = searchableKeywords
        attributeSet.alternateNames = [
            "\(title) recipe",
            "\(title) recipes",
            "\(title) ingredients",
            "\(title) cooking",
            "\(title) cookbook"
        ]
        attributeSet.subject = "Recipe"
        attributeSet.theme = "Recipes"
        attributeSet.textContent = searchableKeywords.joined(separator: "\n")
        attributeSet.contentDescription = summary ?? displaySubtitle
        
        return attributeSet
    }
    
    
    public init(recipe: Recipe) {
        self.id = recipe.id
        self.title = recipe.title
        self.imageUrl = URL(string: recipe.image.imageUrl ?? "")
        self.imageData = recipe.image.imageThumbnailData
        self.summary = recipe.description
        self.keywords = Self.makeSearchKeywords(from: recipe)
        self.ingredientNames = recipe.ingredientSections.flatMap(\.ingredients).compactMap(\.ingredientText)
        if let _rtt = recipe.timing.totalTime {
            self.duration = .init(.seconds(_rtt * 60))
        }
        if let _rpt = recipe.timing.prepTime {
            self.prepDuration = .init(.seconds(_rpt * 60))
        }
        self.imageUrl = URL(string: recipe.image.imageUrl ?? "")
        self.serves = recipe.serves
    }

    public init(summary: RecipeIntentSummary) {
        self.id = summary.id
        self.title = summary.title
        self.summary = summary.summary
        self.keywords = summary.keywords
        self.ingredientNames = summary.ingredientNames
        if let totalMinutes = summary.totalMinutes {
            self.duration = .init(.seconds(totalMinutes * 60))
        }
        if let prepMinutes = summary.prepMinutes {
            self.prepDuration = .init(.seconds(prepMinutes * 60))
        }
        self.serves = summary.serves
        self.imageUrl = summary.imageURLString.flatMap(URL.init(string:))
        self.imageData = summary.imageData
    }
    
}

@available(anyAppleOS 27.0, *)
extension RecipeEntity {
        
    static func makeSearchKeywords(
        from record: Recipe
    ) -> [String] {

        var values = record.ingredientSections.flatMap(\.ingredients).compactMap(\.ingredientText)
            + record.tags.map(\.name)
        values.append(contentsOf: [record.title, record.description ?? "", record.author ?? ""])
        values.append(contentsOf: Self.baseSearchKeywords(for: record.title))
        
        
        return Array(
            Set(
                values 
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        )
        .sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    static func searchableKeywords(
        title: String,
        summary: String?,
        keywords: [String],
        ingredientNames: [String]
    ) -> [String] {
        let values = keywords
            + ingredientNames
            + [title, summary]
                .compactMap { $0 }
            + baseSearchKeywords(for: title)

        return Array(
            Set(
                values
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        )
        .sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    static func baseSearchKeywords(for title: String) -> [String] {
        [
            "recipe",
            "recipes",
            "cookbook",
            "cooking",
            "ingredients",
            "\(title) recipe",
            "\(title) recipes",
            "\(title) ingredients",
            "\(title) cookbook"
        ]
    }
    
    var displaySubtitle: String {
        var components: [String] = []
        
        if let duration {
            components.append(Self.format(duration))
        }
        
        if let serves {
            components.append(serves)
        }
        
        return components.isEmpty ? "Recipe" : components.joined(separator: " · ")
    }
    
    static func format(_ duration: Duration) -> String {
        let totalSeconds = duration.components.seconds
        let totalMinutes = max(1, Int(totalSeconds / 60))
        
        guard totalMinutes >= 60 else {
            return "\(totalMinutes) min"
        }
        
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        guard minutes > 0 else {
            return "\(hours) hr"
        }
        
        return "\(hours) hr \(minutes) min"
    }
}
