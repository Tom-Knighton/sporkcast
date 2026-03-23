//
//  ShoppingCategoryClassifier.swift
//  Models
//
//  Created by Codex on 21/03/2026.
//

import Foundation

public struct ShoppingCategoryClassifier: Sendable {

    public init() {}

    public func classify(
        _ rawTitle: String,
        fallback: ShoppingCategory = .unknown,
        knownItems: [ShoppingListItem] = []
    ) -> ShoppingCategory {
        let normalizedTitle = normalize(rawTitle)
        guard !normalizedTitle.isEmpty else { return fallback }

        var scores = baseKeywordScores(for: normalizedTitle)
        mergeKnownItemScores(into: &scores, normalizedTitle: normalizedTitle, knownItems: knownItems)

        guard let bestCategory = bestCategory(in: scores) else {
            return fallback
        }

        return bestCategory
    }
}

private extension ShoppingCategoryClassifier {

    static let priorityOrder: [ShoppingCategory] = [
        .produce,
        .meat,
        .seafood,
        .dairyAndEggs,
        .bakery,
        .pantry,
        .frozen,
        .snacks,
        .beverages,
        .household,
        .personalCare
    ]

    static let wordKeywords: [ShoppingCategory: Set<String>] = [
        .produce: [
            "apple", "apples", "banana", "bananas", "berries", "blueberry", "strawberry", "raspberry", "blackberry", "grape", "grapes", "melon", "watermelon", "orange", "clementine", "satsuma", "lemon", "lime", "pear", "peach", "plum", "nectarine", "mango", "pineapple", "kiwi", "avocado", "avocados",
            "carrot", "carrots", "parsnip", "swede", "turnip", "onion", "onions", "shallot", "garlic", "ginger", "potato", "potatoes", "sweetpotato", "sweetpotatoes", "tomato", "tomatoes", "cucumber", "courgette", "zucchini", "aubergine", "eggplant", "pepper", "peppers", "chilli", "chilies", "jalapeno", "broccoli", "broccolini", "cauliflower", "cabbage", "lettuce", "spinach", "kale", "rocket", "arugula", "celery", "leek", "leeks", "beetroot", "radish", "mushroom", "mushrooms", "asparagus", "springonion", "scallion", "corn", "sweetcorn", "peas", "greenbeans", "runnerbeans", "edamame",
            "herbs", "parsley", "coriander", "cilantro", "basil", "mint", "dill", "thyme", "rosemary", "sage",
            "fruit", "fruits", "veg", "vegs", "veggie", "veggies", "vegetable", "vegetables", "salad"
        ],
        .meat: [
            "beef", "chicken", "lamb", "pork", "turkey", "duck", "veal", "goat", "ham", "bacon", "sausage", "sausages", "steak", "mince", "ground", "meat", "meats", "gammon", "prosciutto", "salami", "pepperoni", "chorizo", "meatball", "meatballs", "drumstick", "drumsticks", "fillet", "fillets", "kebab", "kebabs", "patty", "patties", "burger", "burgers", "brisket", "ribs", "rib"
        ],
        .seafood: [
            "fish", "salmon", "cod", "haddock", "tuna", "trout", "mackerel", "sardine", "anchovy", "prawn", "prawns", "shrimp", "crab", "lobster", "mussel", "mussels", "clam", "clams", "scallop", "scallops", "squid", "calamari", "octopus", "hake", "pollock", "seabass", "seabream", "seafood"
        ],
        .dairyAndEggs: [
            "milk", "butter", "cheese", "cream", "creme", "yoghurt", "yogurt", "skyr", "egg", "eggs", "mozzarella", "cheddar", "brie", "feta", "parmesan", "halloumi", "ricotta", "paneer", "custard", "kefir", "creamcheese", "sourcream", "cremefraiche", "buttermilk", "margarine", "ghee", "fromage", "quark"
        ],
        .bakery: [
            "bread", "bagel", "bagels", "baguette", "croissant", "muffin", "muffins", "brioche", "bun", "buns", "roll", "rolls", "pitta", "pita", "naan", "tortilla", "wrap", "wraps", "crumpet", "sourdough", "loaf", "pastry", "pastries", "doughnut", "doughnuts", "donut", "donuts", "ciabatta", "focaccia", "breadstick", "breadsticks", "pancake", "pancakes", "waffle", "waffles"
        ],
        .pantry: [
            "rice", "pasta", "noodle", "noodles", "flour", "sugar", "salt", "pepper", "peppercorn", "beans", "lentils", "chickpeas", "spice", "spices", "seasoning", "stock", "broth", "bouillon", "sauce", "ketchup", "mustard", "mayo", "mayonnaise", "vinegar", "oil", "oliveoil", "sesameoil", "cereal", "granola", "oats", "tinned", "canned", "can", "jar", "jarred", "honey", "jam", "marmalade", "peanutbutter", "almondbutter", "tahini", "coconutmilk", "soy", "tamari", "passata", "tomatopaste", "breadcrumbs", "quinoa", "bulgur", "couscous", "bakingpowder", "bicarb", "yeast", "polenta", "semolina", "risotto", "arborio", "pickles", "relish", "pesto", "paprika", "cumin", "turmeric", "cinnamon", "vanilla", "stockcube", "stockcubes"
        ],
        .frozen: [
            "frozen", "freezer", "icecream", "ice", "sorbet", "gelato", "nuggets", "fries", "chips", "pizza", "peas", "waffles", "hashbrown", "hashbrowns", "fishfinger", "fishfingers", "dumplings", "gyoza"
        ],
        .snacks: [
            "crisps", "cracker", "crackers", "chocolate", "biscuits", "cookie", "cookies", "nuts", "snack", "snacks", "popcorn", "pretzel", "pretzels", "nacho", "nachos", "bar", "bars", "jerky", "sweets", "candy", "gum", "trailmix", "ricecake", "ricecakes", "brownie", "brownies", "cake", "cakes"
        ],
        .beverages: [
            "water", "juice", "soda", "cola", "coffee", "tea", "smoothie", "drink", "drinks", "fizzy", "sparkling", "squash", "cordial", "kombucha", "lemonade", "tonic", "milkshake", "beer", "wine", "cider", "prosecco", "champagne", "espresso", "latte", "cappuccino", "americano", "oatmilk", "almondmilk", "coconutwater", "isotonic", "electrolyte"
        ],
        .household: [
            "bleach", "detergent", "softener", "sponge", "bin", "bags", "binbag", "foil", "wrap", "spray", "cleaner", "washing", "laundry", "disinfectant", "wipe", "wipes", "toiletroll", "kitchenroll", "towel", "towels", "mop", "brush", "cloth", "cloths", "clingfilm", "parchment", "bakingpaper", "rinseaid", "dishwasher", "pods", "tablet", "tablets", "polish", "refill", "gloves", "airfreshener", "vacuum"
        ],
        .personalCare: [
            "shampoo", "conditioner", "toothpaste", "toothbrush", "deodorant", "razor", "bodywash", "moisturiser", "moisturizer", "sanitary", "wipes", "tissue", "soap", "soapbar", "facewash", "sunscreen", "lotion", "handcream", "mouthwash", "floss", "tampon", "tampons", "pad", "pads", "shaving", "gel", "handsoap", "showergel", "bathfoam"
        ]
    ]

    static let phraseKeywords: [ShoppingCategory: [String]] = [
        .produce: [
            "spring onion", "sweet potato", "baby spinach", "mixed salad", "cherry tomato", "fresh herbs", "green beans", "red onion", "garlic cloves", "fresh basil", "salad leaves"
        ],
        .meat: [
            "chicken thigh", "chicken breast", "pork belly", "beef mince", "chicken mince", "turkey mince", "beef steak", "pork chops", "beef burgers", "bacon rashers", "lamb chops"
        ],
        .seafood: [
            "smoked salmon", "fish fillet", "tuna steak", "king prawn", "white fish", "fresh salmon", "cod fillet", "raw prawns"
        ],
        .dairyAndEggs: [
            "greek yogurt", "double cream", "single cream", "cottage cheese", "sour cream", "free range eggs", "cream cheese", "creme fraiche", "whole milk"
        ],
        .bakery: [
            "garlic bread", "burger bun", "hot dog bun", "sliced bread", "wholemeal bread", "wraps", "pizza base", "fresh baguette"
        ],
        .pantry: [
            "olive oil", "soy sauce", "tomato paste", "coconut milk", "chicken stock", "black beans", "kidney beans", "passata sauce", "baking powder", "plain flour", "brown sugar", "curry paste"
        ],
        .frozen: [
            "frozen peas", "frozen berries", "frozen chips", "frozen pizza", "ice cream", "frozen veg", "frozen vegetables", "frozen fruit"
        ],
        .snacks: [
            "potato chips", "dark chocolate", "protein bar", "rice cakes", "snack bar", "chocolate bar", "mixed nuts"
        ],
        .beverages: [
            "sparkling water", "orange juice", "apple juice", "cold brew", "oat milk", "ground coffee", "green tea"
        ],
        .household: [
            "kitchen roll", "toilet roll", "bin bag", "washing up liquid", "surface spray", "dishwasher tablets", "laundry detergent", "fabric softener", "all purpose cleaner", "kitchen cleaner"
        ],
        .personalCare: [
            "shower gel", "body wash", "hand soap", "face wash", "tooth brush", "tooth paste", "deodorant spray", "shaving gel"
        ]
    ]

    static let stemKeywords: [ShoppingCategory: [String]] = [
        .produce: ["veg", "fruit", "salad", "tomat", "potat", "onion", "spinach", "lettuc", "cucumb", "pepper", "brocc", "carrot", "mushroom", "herb"],
        .meat: ["chicken", "beef", "pork", "turkey", "lamb", "sausage", "bacon", "ham", "meat", "minc", "burger", "steak"],
        .seafood: ["salmon", "tuna", "fish", "prawn", "shrimp", "mussel", "clam", "scallop", "seafood", "lobster"],
        .dairyAndEggs: ["milk", "yog", "chees", "cream", "butter", "egg", "mozz", "chedd", "ricott", "feta"],
        .bakery: ["bread", "bagel", "bun", "roll", "croiss", "pastr", "tortill", "wrap", "loaf", "pita"],
        .pantry: ["pasta", "rice", "noodle", "flour", "sugar", "spice", "sauce", "stock", "broth", "vinegar", "oil", "bean", "lentil"],
        .frozen: ["frozen", "freezer", "icecream", "sorbet", "hashbrown", "dumpling", "gyoza"],
        .snacks: ["snack", "choc", "biscuit", "cookie", "cracker", "popcorn", "pretzel", "nacho", "sweet", "candy"],
        .beverages: ["drink", "juice", "water", "coffee", "tea", "soda", "cola", "sparkling", "smoothie", "milkshake"],
        .household: ["deterg", "laundr", "dishwash", "bleach", "clean", "disinfect", "toiletroll", "kitchenroll", "binbag", "airfresh"],
        .personalCare: ["shampo", "condition", "tooth", "deodor", "razor", "bodywash", "moistur", "sanitar", "lotion", "mouthwash"]
    ]

    func baseKeywordScores(for normalizedTitle: String) -> [ShoppingCategory: Int] {
        let tokens = tokenSet(from: normalizedTitle)
        let compactedTitle = normalizedTitle.replacingOccurrences(of: " ", with: "")
        var scores: [ShoppingCategory: Int] = [:]

        for category in ShoppingCategory.allCases where category != .unknown {
            let tokenScore = Self.wordKeywords[category, default: []].reduce(into: 0) { score, keyword in
                if tokens.contains(keyword) {
                    score += 3
                }
            }

            let phraseScore = Self.phraseKeywords[category, default: []].reduce(into: 0) { score, phrase in
                if normalizedTitle.contains(phrase) {
                    score += 4
                }
            }

            let stemMatchCount = Self.stemKeywords[category, default: []].reduce(into: 0) { count, stem in
                if tokens.contains(where: { token in
                    isStemMatch(token: token, stem: stem)
                }) {
                    count += 1
                }
            }

            let compactKeywordMatches = Self.wordKeywords[category, default: []].reduce(into: 0) { count, keyword in
                guard keyword.count >= 6 else { return }
                if compactedTitle.contains(keyword) {
                    count += 1
                }
            }

            let stemScore = min(stemMatchCount, 3) * 2
            let compactScore = min(compactKeywordMatches, 2)
            let total = tokenScore + phraseScore + stemScore + compactScore
            if total > 0 {
                scores[category] = total
            }
        }

        return scores
    }

    func mergeKnownItemScores(
        into scores: inout [ShoppingCategory: Int],
        normalizedTitle: String,
        knownItems: [ShoppingListItem]
    ) {
        guard !knownItems.isEmpty else { return }

        let itemTokens = tokenSet(from: normalizedTitle)

        for knownItem in knownItems {
            let knownCategory = ShoppingCategory(categoryIdentifier: knownItem.categoryId)
            guard knownCategory != .unknown else { continue }

            let knownNormalizedTitle = normalize(knownItem.title)
            guard !knownNormalizedTitle.isEmpty else { continue }

            let trustWeight = confidenceWeight(for: knownItem.categorySource)
            if knownNormalizedTitle == normalizedTitle {
                scores[knownCategory, default: 0] += 30 * trustWeight
                continue
            }

            if knownNormalizedTitle.count >= 4,
               (knownNormalizedTitle.hasPrefix(normalizedTitle) || normalizedTitle.hasPrefix(knownNormalizedTitle)) {
                scores[knownCategory, default: 0] += 8 * trustWeight
            }

            if hasMeaningfulContainment(between: normalizedTitle, and: knownNormalizedTitle) {
                scores[knownCategory, default: 0] += 5 * trustWeight
            }

            let knownTokens = tokenSet(from: knownNormalizedTitle)
            let overlapCount = itemTokens.intersection(knownTokens).count
            if overlapCount > 0 {
                scores[knownCategory, default: 0] += overlapCount * 4 * trustWeight
            }
        }
    }

    func bestCategory(in scores: [ShoppingCategory: Int]) -> ShoppingCategory? {
        guard let bestCategory = Self.priorityOrder.max(by: { lhs, rhs in
            let leftScore = scores[lhs, default: 0]
            let rightScore = scores[rhs, default: 0]
            return leftScore < rightScore
        }), scores[bestCategory, default: 0] > 0 else {
            return nil
        }

        return bestCategory
    }

    func confidenceWeight(for categorySource: String?) -> Int {
        switch categorySource?.lowercased() {
        case "manual", "suggestion":
            return 3
        case "classifier":
            return 1
        default:
            return 2
        }
    }

    func hasMeaningfulContainment(between lhs: String, and rhs: String) -> Bool {
        let shorter = lhs.count <= rhs.count ? lhs : rhs
        guard shorter.count >= 5 else { return false }
        return lhs.contains(rhs) || rhs.contains(lhs)
    }

    func isStemMatch(token: String, stem: String) -> Bool {
        guard token.count >= 3 else { return false }
        if token.hasPrefix(stem) {
            return true
        }
        if stem.count >= 5 && stem.hasPrefix(token) {
            return true
        }
        return false
    }

    func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "'", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    func tokenSet(from normalized: String) -> Set<String> {
        let rawTokens = normalized.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        var tokens: Set<String> = []

        for token in rawTokens {
            guard token.count >= 2 else { continue }
            tokens.insert(token)

            if token.hasSuffix("es"), token.count > 4 {
                tokens.insert(String(token.dropLast(2)))
            } else if token.hasSuffix("s"), token.count > 3 {
                tokens.insert(String(token.dropLast()))
            }

            let compactToken = token.replacingOccurrences(of: " ", with: "")
            tokens.insert(compactToken)
        }

        return tokens
    }
}
