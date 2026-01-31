import Foundation

enum RecipeParserError: Error {
    case languageNotSupported(String)
}

typealias Converter = (Double) -> Double

struct UnitDetail {
    let symbol: String
    let text: String
    let conversionGroup: String?
    
    init(symbol: String, text: String, conversionGroup: String? = nil) {
        self.symbol = symbol
        self.text = text
        self.conversionGroup = conversionGroup
    }
}

public struct AlternativeQuantity {
    let quantity: Double
    let unit: String
    let unitText: String
    let minQuantity: Double
    let maxQuantity: Double
    
    public init(quantity: Double, unit: String, unitText: String, minQuantity: Double, maxQuantity: Double) {
        self.quantity = quantity
        self.unit = unit
        self.unitText = unitText
        self.minQuantity = minQuantity
        self.maxQuantity = maxQuantity
    }
}

public struct IngredientResult {
    public let quantity: Double
    public let quantityText: String
    public let minQuantity: Double
    public let maxQuantity: Double
    public let unit: String
    public let unitText: String
    public let ingredient: String
    public let extra: String
    public let alternativeQuantities: [AlternativeQuantity]
    
    public init(quantity: Double, quantityText: String, minQuantity: Double, maxQuantity: Double, unit: String, unitText: String, ingredient: String, extra: String, alternativeQuantities: [AlternativeQuantity]) {
        self.quantity = quantity
        self.quantityText = quantityText
        self.minQuantity = minQuantity
        self.maxQuantity = maxQuantity
        self.unit = unit
        self.unitText = unitText
        self.ingredient = ingredient
        self.extra = extra
        self.alternativeQuantities = alternativeQuantities
    }
}

public struct InstructionTime {
    public let timeInSeconds: Int
    public let timeUnitText: String
    public let timeText: String
    
    public init(timeInSeconds: Int, timeUnitText: String, timeText: String) {
        self.timeInSeconds = timeInSeconds
        self.timeUnitText = timeUnitText
        self.timeText = timeText
    }
}

public struct InstructionResult {
    public let totalTimeInSeconds: Int
    public let timeItems: [InstructionTime]
    public let temperature: Double
    public let temperatureUnit: String
    public let temperatureText: String
    public let temperatureUnitText: String
    public let alternativeTemperatures: [AlternativeQuantity]
    
    public init(totalTimeInSeconds: Int, timeItems: [InstructionTime], temperature: Double, temperatureUnit: String, temperatureText: String, temperatureUnitText: String, alternativeTemperatures: [AlternativeQuantity]) {
        self.totalTimeInSeconds = totalTimeInSeconds
        self.timeItems = timeItems
        self.temperature = temperature
        self.temperatureUnit = temperatureUnit
        self.temperatureText = temperatureText
        self.temperatureUnitText = temperatureUnitText
        self.alternativeTemperatures = alternativeTemperatures
    }
}

struct UnitsConfig {
    let ingredientUnits: [String: UnitDetail]
    let ingredientSizes: [String]
    let timeUnits: [String: String]
    let timeUnitMultipliers: [String: Int]
    let temperatureUnits: [String: UnitDetail]
    let ingredientPrepositions: [String]
    let temperatureMarkers: [String]
    let ingredientQuantities: [String: Int]
    let ingredientRangeMarker: [String]
    let ingredientQuantityAddMarker: [String]
    let converters: [String: Converter]
    let defaultConversions: [String: [String]]
    let defaultTemperatureUnit: String?
}

let unicodeFractions: [String: String] = [
    "½": "1/2", "⅓": "1/3", "⅔": "2/3", "¼": "1/4", "¾": "3/4",
    "⅕": "1/5", "⅖": "2/5", "⅗": "3/5", "⅘": "4/5", "⅙": "1/6",
    "⅚": "5/6", "⅐": "1/7", "⅛": "1/8", "⅜": "3/8", "⅝": "5/8",
    "⅞": "7/8", "⅑": "1/9", "⅒": "1/10"
]

func tokenize(_ text: String, removeSpaces: Bool = true) -> [String] {
    guard !text.isEmpty else { return [] }
    let pattern = "([a-zÀ-ÿ-]+|[0-9._]+|.|!|\\?|'|\"|:|;|,|-)"
    let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    var tokens: [String] = []
    var lastEnd = text.startIndex
    
    regex.enumerateMatches(in: text, range: NSRange(text.startIndex..., in: text)) { match, _, _ in
        guard let match = match else { return }
        let range = Range(match.range, in: text)!
        if lastEnd < range.lowerBound {
            let gap = String(text[lastEnd..<range.lowerBound])
            if !gap.isEmpty { tokens.append(gap) }
        }
        tokens.append(String(text[range]))
        lastEnd = range.upperBound
    }
    
    if lastEnd < text.endIndex {
        let remainder = String(text[lastEnd...])
        if !remainder.isEmpty { tokens.append(remainder) }
    }
    
    return tokens.filter { !$0.isEmpty && (!removeSpaces || $0 != " ") }
}

func getQuantityValue(_ text: String) -> Double {
    guard !text.isEmpty else { return 0 }
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    if trimmed.contains("/") {
        let parts = trimmed.components(separatedBy: .whitespaces).flatMap { $0.components(separatedBy: "+") }
        var total = 0.0
        for part in parts where !part.isEmpty {
            if part.contains("/") {
                let fractionParts = part.split(separator: "/")
                if fractionParts.count == 2, let num = Double(fractionParts[0]), let denom = Double(fractionParts[1]), denom != 0 {
                    total += num / denom
                }
            } else if let value = Double(part) {
                total += value
            }
        }
        return (total * 100).rounded() / 100
    }
    return Double(trimmed) ?? 0
}

func getQuantity(_ tokens: [String], _ units: UnitsConfig, _ startIndex: Int = 0) -> (Double, Double, String, Int) {
    var quantityText = ""
    var quantityConvertible = ""
    var firstQuantityConvertible = ""
    var space = ""
    var previousWasNumber = false
    var index = startIndex
    
    while index < tokens.count {
        let item = tokens[index]
        let hasNext = index + 1 < tokens.count
        let isSpace = item == " "
        let isNumber = !isSpace && Double(item) != nil
        let isFraction = item == "/" && previousWasNumber && hasNext && Double(tokens[index + 1]) != nil
        let isSpecialFraction = unicodeFractions[item] != nil
        let isTextNumber = units.ingredientQuantities[item.lowercased()] != nil
        
        if isNumber || isFraction || isSpecialFraction || isTextNumber {
            var value = item
            var specialSpace = space
            if isSpecialFraction {
                value = unicodeFractions[item]!
                specialSpace = quantityConvertible.isEmpty ? space : " "
            } else if isTextNumber {
                value = String(units.ingredientQuantities[item.lowercased()]!)
            }
            quantityText += "\(space)\(item)"
            quantityConvertible += "\(specialSpace)\(value)"
        } else if !quantityText.isEmpty && units.ingredientQuantityAddMarker.contains(item) {
            quantityText += "\(space)\(item)"
        } else if !quantityText.isEmpty && units.ingredientRangeMarker.contains(item) {
            firstQuantityConvertible = quantityConvertible
            quantityText += "\(space)\(item)"
            quantityConvertible = ""
        } else if !isSpace && !quantityText.isEmpty {
            break
        } else if !isSpace {
            if let _ = units.ingredientUnits[item.lowercased()] {
                break
            }
        }
        space = isSpace ? " " : ""
        previousWasNumber = isNumber
        index += 1
    }
    
    if quantityText.isEmpty {
        index = startIndex
    }
    
    let firstQuantityValue = getQuantityValue(firstQuantityConvertible)
    let quantityValue = getQuantityValue(quantityConvertible)
    
    return (firstQuantityValue, quantityValue, quantityText, index)
}

func getUnit(_ tokens: [String], _ startIndex: Int, _ units: UnitsConfig) -> (String, String, Int) {
    guard startIndex < tokens.count else { return ("", "", startIndex) }
    var index = startIndex
    
    while index < tokens.count && (units.ingredientSizes.contains(tokens[index]) || tokens[index] == " ") {
        index += 1
    }
    
    guard index < tokens.count else { return ("", "", index) }
    
    let possibleUOM = tokens[index]
    let possibleUOMLower = possibleUOM.lowercased()
    
    guard let unit = units.ingredientUnits[possibleUOMLower] else {
        return ("", "", index)
    }
    
    return (unit.text, possibleUOM, index + 1)
}

func getIngredient(_ tokens: [String], _ startIndex: Int, _ units: UnitsConfig) -> (String, Int) {
    guard startIndex < tokens.count else { return ("", startIndex) }
    var index = startIndex
    
    if index < tokens.count && tokens[index] == " " {
        index += 1
    }
    
    guard index < tokens.count else { return ("", index) }
    
    let firstToken = tokens[index]
    let skipFirstToken = units.ingredientPrepositions.contains(firstToken) || units.ingredientSizes.contains(firstToken) || firstToken == "."
    
    let separatorIndex = tokens.firstIndex(where: { $0 == "," }) ?? tokens.count
    let endIndex = separatorIndex > 0 ? separatorIndex : tokens.count
    var cleanTokens: [String] = []
    var withinParenthesis = false
    
    var newStartIndex = index
    if skipFirstToken {
        newStartIndex = index + 1
        if newStartIndex < tokens.count, tokens[newStartIndex] == " " {
            newStartIndex += 1
        }
    }
    let upperBound = min(endIndex, tokens.count)
    guard newStartIndex < upperBound else { return ("", endIndex) }
    
    for i in newStartIndex..<upperBound {
        let item = tokens[i]
        withinParenthesis = withinParenthesis || item == "("
        if !withinParenthesis {
            cleanTokens.append(item)
        }
        withinParenthesis = withinParenthesis && item != ")"
    }
    
    return (cleanTokens.joined().trimmingCharacters(in: .whitespaces), endIndex)
}

func getExtra(_ tokens: [String], _ startIndex: Int) -> String {
    guard startIndex + 1 < tokens.count else { return "" }
    return tokens[(startIndex + 1)...].joined().trimmingCharacters(in: .whitespaces)
}

func convert(_ input: Double, _ from: String, _ to: String, _ units: UnitsConfig) -> Double {
    guard let converter = units.converters["\(from)->\(to)"] else { return input }
    return converter(input)
}

func round(_ value: Double, _ minFraction: Int, _ maxFraction: Int) -> Double {
    let formatter = NumberFormatter()
    formatter.minimumFractionDigits = minFraction
    formatter.maximumFractionDigits = maxFraction
    formatter.usesGroupingSeparator = false
    formatter.locale = Locale(identifier: "en")
    let str = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    return Double(str) ?? value
}

func getIngredientConversions(_ defaultQuantity: AlternativeQuantity, _ units: UnitsConfig) -> [AlternativeQuantity] {
    guard let unit = units.ingredientUnits[defaultQuantity.unit],
          let conversionGroup = unit.conversionGroup,
          let defaultConversions = units.defaultConversions[conversionGroup] else {
        return []
    }
    
    return defaultConversions.filter { $0 != unit.symbol }.compactMap { possibility in
        let quantity = convert(defaultQuantity.quantity, unit.symbol, possibility, units)
        let minQuantity = convert(defaultQuantity.minQuantity, unit.symbol, possibility, units)
        let maxQuantity = convert(defaultQuantity.maxQuantity, unit.symbol, possibility, units)
        
        guard let possibilityUOM = units.ingredientUnits[possibility] else { return nil }
        
        return AlternativeQuantity(
            quantity: round(quantity, 0, 4),
            unit: possibility,
            unitText: possibilityUOM.text,
            minQuantity: round(minQuantity, 0, 4),
            maxQuantity: round(maxQuantity, 0, 4)
        )
    }
}

func getUnitsForLanguage(_ language: String?, fallbackLanguage: String? = nil) throws -> UnitsConfig {
    guard let lang = language else {
        throw RecipeParserError.languageNotSupported("null")
    }
    
    let lowercased = lang.lowercased()
    if lowercased == "en-us" {
        return createAmericanEnglishUnits()
    } else if lowercased == "en" {
        return createEnglishUnits()
    } else if let fallback = fallbackLanguage {
        return try getUnitsForLanguage(fallback, fallbackLanguage: nil)
    }
    
    let message = fallbackLanguage == nil
    ? "Language \(lang) is not supported"
    : "Language \(lang) is not supported and no fallback language is provided"
    throw RecipeParserError.languageNotSupported(message)
}

public func parseIngredient(_ text: String?, _ language: String?, includeExtra: Bool = true, includeAlternativeUnits: Bool = false, fallbackLanguage: String? = nil) throws -> IngredientResult? {
    guard let text = text, !text.isEmpty else { return nil }
    
    let units = try getUnitsForLanguage(language, fallbackLanguage: fallbackLanguage)
    let tokens = tokenize(text, removeSpaces: false)
    
    guard !tokens.isEmpty && !tokens.allSatisfy({ $0 == " " }) else { return nil }
    
    let (firstQuantity, quantity, quantityText, quantityEndIndex) = getQuantity(tokens, units)
    let (unit, unitText, unitEndIndex) = getUnit(tokens, quantityEndIndex, units)
    
    var alternativeQuantities: [AlternativeQuantity] = []
    var ingredientStartIndex = unitEndIndex
    
    if unitEndIndex < tokens.count && (tokens[unitEndIndex] == "(" || (unitEndIndex + 1 < tokens.count && tokens[unitEndIndex + 1] == "(") || tokens[unitEndIndex] == "/" || (unitEndIndex + 1 < tokens.count && tokens[unitEndIndex + 1] == "/")) {
        let altStart = unitEndIndex + 1
        let (altFirstQuantity, altQuantity, _, altQtyEndIndex) = getQuantity(tokens, units, altStart)
        let (altUnit, altUnitText, altUnitEndIndex) = getUnit(tokens, altQtyEndIndex, units)
        
        if altQuantity > 0 {
            alternativeQuantities.append(AlternativeQuantity(
                quantity: altQuantity,
                unit: altUnit,
                unitText: altUnitText,
                minQuantity: altFirstQuantity > 0 ? altFirstQuantity : altQuantity,
                maxQuantity: altQuantity
            ))
        }
        
        ingredientStartIndex = altUnitEndIndex < tokens.count && tokens[altUnitEndIndex] == ")" ? altUnitEndIndex + 2 : altUnitEndIndex
    }
    
    let (ingredient, ingredientEndIndex) = getIngredient(tokens, ingredientStartIndex, units)
    let extra = includeExtra ? getExtra(tokens, ingredientEndIndex) : ""
    let minQuantity = firstQuantity > 0 ? firstQuantity : quantity
    let maxQuantity = quantity
    
    if includeAlternativeUnits {
        alternativeQuantities.append(contentsOf: getIngredientConversions(
            AlternativeQuantity(quantity: quantity, unit: unit, unitText: unitText, minQuantity: minQuantity, maxQuantity: maxQuantity),
            units
        ))
    }
    
    return IngredientResult(
        quantity: quantity,
        quantityText: quantityText,
        minQuantity: minQuantity,
        maxQuantity: maxQuantity,
        unit: unit,
        unitText: unitText,
        ingredient: ingredient,
        extra: extra,
        alternativeQuantities: alternativeQuantities
    )
}

func getTemperatureConversions(_ temperature: Double, _ uom: String, _ units: UnitsConfig) -> [AlternativeQuantity] {
    guard let unit = units.temperatureUnits[uom],
          let conversionGroup = unit.conversionGroup,
          let defaultConversions = units.defaultConversions[conversionGroup] else {
        return []
    }
    
    return defaultConversions.filter { $0 != unit.symbol }.compactMap { possibility in
        guard let possibilityUOM = units.temperatureUnits[possibility] else { return nil }
        let quantity = convert(temperature, unit.symbol, possibility, units)
        let rounded = round(quantity, 0, 4)
        return AlternativeQuantity(
            quantity: rounded,
            unit: possibility,
            unitText: possibilityUOM.text,
            minQuantity: rounded,
            maxQuantity: rounded
        )
    }
}

public func parseInstruction(_ text: String?, _ language: String?, includeAlternativeTemperatureUnit: Bool = false, fallbackLanguage: String? = nil) throws -> InstructionResult? {
    guard let text = text, !text.isEmpty else { return nil }
    
    let units = try getUnitsForLanguage(language, fallbackLanguage: fallbackLanguage)
    let tokens = tokenize(text)
    guard !tokens.isEmpty else { return nil }
    
    var number: Double = 0
    var numberText = ""
    var timeItems: [InstructionTime] = []
    var totalTimeInSeconds = 0
    var temperature: Double = 0
    var temperatureText = ""
    var temperatureUnit = ""
    var temperatureUnitText = ""
    var alternativeTemperatures: [AlternativeQuantity] = []
    
    for token in tokens {
        if let maybeNumber = Double(token) {
            number = maybeNumber
            numberText = token
        } else if number > 0 {
            let maybeUnit = token.lowercased()
            
            if units.temperatureMarkers.contains(maybeUnit) {
                if let defaultTempUnit = units.defaultTemperatureUnit,
                   let tempUnit = units.temperatureUnits[defaultTempUnit] {
                    temperature = number
                    temperatureText = numberText
                    temperatureUnit = tempUnit.text
                }
                continue
            }
            
            if let timeUnit = units.timeUnits[maybeUnit],
               let multiplier = units.timeUnitMultipliers[timeUnit] {
                let timeInSeconds = Int(number) * multiplier
                totalTimeInSeconds += timeInSeconds
                timeItems.append(InstructionTime(
                    timeInSeconds: timeInSeconds,
                    timeUnitText: token,
                    timeText: numberText
                ))
            } else if let tempUnit = units.temperatureUnits[maybeUnit] {
                temperature = number
                temperatureText = numberText
                temperatureUnit = tempUnit.text
                temperatureUnitText = token
            }
            
            number = 0
        }
    }
    
    if includeAlternativeTemperatureUnit && temperature > 0 {
        alternativeTemperatures = getTemperatureConversions(temperature, temperatureUnit, units)
    }
    
    return InstructionResult(
        totalTimeInSeconds: totalTimeInSeconds,
        timeItems: timeItems,
        temperature: temperature,
        temperatureUnit: temperatureUnit, temperatureText: temperatureText,
        temperatureUnitText: temperatureUnitText,
        alternativeTemperatures: alternativeTemperatures
    )
}

func createEnglishUnits() -> UnitsConfig {
    var ingredientUnits: [String: UnitDetail] = [:]
    let bag = UnitDetail(symbol: "bag", text: "bag")
    let batch = UnitDetail(symbol: "batch", text: "batch")
    let box = UnitDetail(symbol: "box", text: "box")
    let bunch = UnitDetail(symbol: "bunch", text: "bunch")
    let cup = UnitDetail(symbol: "cup", text: "cup", conversionGroup: "volume")
    let can = UnitDetail(symbol: "can", text: "can")
    let clove = UnitDetail(symbol: "clove", text: "clove")
    let dash = UnitDetail(symbol: "dash", text: "dash")
    let drop = UnitDetail(symbol: "drop", text: "drop")
    let gram = UnitDetail(symbol: "g", text: "gram", conversionGroup: "mass")
    let gallon = UnitDetail(symbol: "gal", text: "gallon", conversionGroup: "volume")
    let grain = UnitDetail(symbol: "grain", text: "grain")
    let inch = UnitDetail(symbol: "in", text: "inch", conversionGroup: "length")
    let cm = UnitDetail(symbol: "cm", text: "centimeter", conversionGroup: "length")
    let kilogram = UnitDetail(symbol: "kg", text: "kilogram", conversionGroup: "mass")
    let pound = UnitDetail(symbol: "lb", text: "pound", conversionGroup: "mass")
    let liter = UnitDetail(symbol: "l", text: "liter", conversionGroup: "volume")
    let milligram = UnitDetail(symbol: "mg", text: "milligram", conversionGroup: "mass")
    let milliliter = UnitDetail(symbol: "ml", text: "milliliter", conversionGroup: "volume")
    let ounce = UnitDetail(symbol: "oz", text: "ounce", conversionGroup: "mass")
    let pkg = UnitDetail(symbol: "package", text: "package")
    let piece = UnitDetail(symbol: "piece", text: "piece")
    let pinch = UnitDetail(symbol: "pinch", text: "pinch")
    let pint = UnitDetail(symbol: "pnt", text: "pint", conversionGroup: "volume")
    let quart = UnitDetail(symbol: "qt", text: "quart", conversionGroup: "volume")
    let slice = UnitDetail(symbol: "slice", text: "slice")
    let stalk = UnitDetail(symbol: "stalk", text: "stalk")
    let stick = UnitDetail(symbol: "stick", text: "stick")
    let teaspoon = UnitDetail(symbol: "tsp", text: "teaspoon", conversionGroup: "volume")
    let tablespoon = UnitDetail(symbol: "tbsp", text: "tablespoon", conversionGroup: "volume")
    
    for (keys, unit) in [
        (["bag", "bags"], bag), (["batch", "batches"], batch), (["box", "boxes"], box),
        (["bunch", "bunches"], bunch), (["c", "cup", "cups"], cup), (["can", "cans"], can),
        (["cm", "centimeter", "centimeters"], cm), (["clove", "cloves"], clove),
        (["dash", "dashes"], dash), (["drop", "drops"], drop), (["g", "gram", "grams"], gram),
        (["gal", "gallon", "gallons"], gallon), (["gr", "grain", "grains"], grain),
        (["inch", "inches", "in"], inch), (["kg", "kgs", "kilogram", "kilograms"], kilogram),
        (["lb", "lbs", "pound", "pounds"], pound), (["liter", "liters", "litre", "litres", "lt", "l", "lts"], liter),
        (["mg", "mgs", "milligram", "milligrams"], milligram), (["milliliter", "millilitre", "millilitres", "milliliters", "ml", "mls"], milliliter),
        (["ounce", "ounces", "oz", "ozs"], ounce), (["package", "packages", "pkg", "pkgs"], pkg),
        (["pcs", "piece", "pieces"], piece), (["pinch", "pinches"], pinch),
        (["pint", "pints", "pnt", "pt", "pts"], pint), (["qt", "qts", "quart", "quarts"], quart),
        (["slice", "slices"], slice), (["stalk", "stalks"], stalk), (["stick", "sticks"], stick),
        (["t", "teaspoon", "teaspoons", "tsp", "tspn"], teaspoon),
        (["tablespoon", "tablespoons", "tbs", "tbsp", "tbspn"], tablespoon),
    ] {
        for key in keys { ingredientUnits[key] = unit }
    }
    
    let timeUnits: [String: String] = [
        "min": "minute", "mins": "minute", "minute": "minute", "minutes": "minute",
        "sec": "second", "secs": "second", "second": "second", "seconds": "second",
        "h": "hour", "hour": "hour", "hours": "hour",
        "day": "day", "days": "day"
    ]
    
    let timeUnitMultipliers: [String: Int] = [
        "minute": 60, "second": 1, "hour": 3600, "day": 86400
    ]
    
    let fahrenheit = UnitDetail(symbol: "f", text: "fahrenheit", conversionGroup: "temperature")
    let celsius = UnitDetail(symbol: "c", text: "celsius", conversionGroup: "temperature")
    let temperatureUnits: [String: UnitDetail] = [
        "fahrenheit": fahrenheit, "f": fahrenheit,
        "c": celsius, "celsius": celsius
    ]
    
    let ingredientQuantities: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10
    ]
    
    let lbFactor = 2.20462
    let ozFactor = 35.274
    let mgFactor = 1000000.0
    let gFactor = 1000.0
    let cmFactor = 2.54
    
    let converters: [String: Converter] = [
        "c->f": { $0 * 9 / 5 + 32 },
        "f->c": { ($0 - 32) * 5 / 9 },
        "kg->lb": { $0 * lbFactor }, "kg->oz": { $0 * ozFactor },
        "kg->mg": { $0 * mgFactor }, "kg->g": { $0 * gFactor },
        "lb->kg": { $0 / lbFactor }, "lb->oz": { ($0 / lbFactor) * ozFactor },
        "lb->mg": { ($0 / lbFactor) * mgFactor }, "lb->g": { ($0 / lbFactor) * gFactor },
        "oz->kg": { $0 / ozFactor }, "oz->lb": { ($0 / ozFactor) * lbFactor },
        "oz->mg": { ($0 / ozFactor) * mgFactor }, "oz->g": { ($0 / ozFactor) * gFactor },
        "mg->kg": { $0 / mgFactor }, "mg->lb": { ($0 / mgFactor) * lbFactor },
        "mg->oz": { ($0 / mgFactor) * ozFactor }, "mg->g": { ($0 / mgFactor) * gFactor },
        "g->kg": { $0 / gFactor }, "g->lb": { ($0 / gFactor) * lbFactor },
        "g->oz": { ($0 / gFactor) * ozFactor }, "g->mg": { ($0 / gFactor) * mgFactor },
        "in->cm": { $0 * cmFactor }, "cm->in": { $0 / cmFactor }
    ]
    
    let defaultConversions: [String: [String]] = [
        "mass": ["lb", "kg", "oz", "mg", "g"],
        "length": ["in", "cm"],
        "temperature": ["f", "c"]
    ]
    
    return UnitsConfig(
        ingredientUnits: ingredientUnits,
        ingredientSizes: ["large", "medium", "small"],
        timeUnits: timeUnits,
        timeUnitMultipliers: timeUnitMultipliers,
        temperatureUnits: temperatureUnits,
        ingredientPrepositions: ["of"],
        temperatureMarkers: ["°", "degree", "degrees"],
        ingredientQuantities: ingredientQuantities,
        ingredientRangeMarker: ["to", "-", "–", "or"],
        ingredientQuantityAddMarker: ["and"],
        converters: converters,
        defaultConversions: defaultConversions,
        defaultTemperatureUnit: nil
    )
}

func createAmericanEnglishUnits() -> UnitsConfig {
    let config = createEnglishUnits()
    
    let lFactor = 0.236588
    let tbspFactor = 16.0
    let mlFactor = 236.588
    let qtFactor = 0.25
    let tspFactor = 48.0
    let galFactor = 0.0625
    let ptFactor = 0.416337
    
    var converters = config.converters
    converters["cup->l"] = { $0 * lFactor }
    converters["cup->ml"] = { $0 * mlFactor }
    converters["cup->tbsp"] = { $0 * tbspFactor }
    converters["cup->qt"] = { $0 * qtFactor }
    converters["cup->tsp"] = { $0 * tspFactor }
    converters["cup->gal"] = { $0 * galFactor }
    converters["cup->pt"] = { $0 * ptFactor }
    
    converters["l->cup"] = { $0 / lFactor }
    converters["l->ml"] = { ($0 / lFactor) * mlFactor }
    converters["l->tbsp"] = { ($0 / lFactor) * tbspFactor }
    converters["l->qt"] = { ($0 / lFactor) * qtFactor }
    converters["l->tsp"] = { ($0 / lFactor) * tspFactor }
    converters["l->gal"] = { ($0 / lFactor) * galFactor }
    converters["l->pt"] = { ($0 / lFactor) * ptFactor }
    
    converters["ml->cup"] = { $0 / mlFactor }
    converters["ml->l"] = { ($0 / mlFactor) * lFactor }
    converters["ml->tbsp"] = { ($0 / mlFactor) * tbspFactor }
    converters["ml->qt"] = { ($0 / mlFactor) * qtFactor }
    converters["ml->tsp"] = { ($0 / mlFactor) * tspFactor }
    converters["ml->gal"] = { ($0 / mlFactor) * galFactor }
    converters["ml->pt"] = { ($0 / mlFactor) * ptFactor }
    
    converters["tbsp->cup"] = { $0 / tbspFactor }
    converters["tbsp->l"] = { ($0 / tbspFactor) * lFactor }
    converters["tbsp->ml"] = { ($0 / tbspFactor) * mlFactor }
    converters["tbsp->qt"] = { ($0 / tbspFactor) * qtFactor }
    converters["tbsp->tsp"] = { ($0 / tbspFactor) * tspFactor }
    converters["tbsp->gal"] = { ($0 / tbspFactor) * galFactor }
    converters["tbsp->pt"] = { ($0 / tbspFactor) * ptFactor }
    
    converters["qt->cup"] = { $0 / qtFactor }
    converters["qt->l"] = { ($0 / qtFactor) * lFactor }
    converters["qt->ml"] = { ($0 / qtFactor) * mlFactor }
    converters["qt->tbsp"] = { ($0 / qtFactor) * tbspFactor }
    converters["qt->tsp"] = { ($0 / qtFactor) * tspFactor }
    converters["qt->gal"] = { ($0 / qtFactor) * galFactor }
    converters["qt->pt"] = { ($0 / qtFactor) * qtFactor }
    
    converters["tsp->cup"] = { $0 / tspFactor }
    converters["tsp->l"] = { ($0 / tspFactor) * lFactor }
    converters["tsp->ml"] = { ($0 / tspFactor) * mlFactor }
    converters["tsp->tbsp"] = { ($0 / tspFactor) * tbspFactor }
    converters["tsp->qt"] = { ($0 / tspFactor) * qtFactor }
    converters["tsp->gal"] = { ($0 / tspFactor) * galFactor }
    converters["tsp->pt"] = { ($0 / tspFactor) * ptFactor }
    
    converters["gal->cup"] = { $0 / galFactor }
    converters["gal->l"] = { ($0 / galFactor) * lFactor }
    converters["gal->ml"] = { ($0 / galFactor) * mlFactor }
    converters["gal->tbsp"] = { ($0 / galFactor) * tbspFactor }
    converters["gal->qt"] = { ($0 / galFactor) * qtFactor }
    converters["gal->tsp"] = { ($0 / galFactor) * tspFactor }
    converters["gal->pt"] = { ($0 / galFactor) * ptFactor }
    
    converters["pt->cup"] = { $0 / ptFactor }
    converters["pt->l"] = { ($0 / ptFactor) * lFactor }
    converters["pt->ml"] = { ($0 / ptFactor) * mlFactor }
    converters["pt->tbsp"] = { ($0 / ptFactor) * tbspFactor }
    converters["pt->qt"] = { ($0 / ptFactor) * qtFactor }
    converters["pt->tsp"] = { ($0 / ptFactor) * tspFactor }
    converters["pt->gal"] = { ($0 / ptFactor) * galFactor }
    
    var defaultConversions = config.defaultConversions
    defaultConversions["volume"] = ["cup", "tbsp", "l", "ml", "qt", "tsp", "gal", "pt"]
    
    return UnitsConfig(
        ingredientUnits: config.ingredientUnits,
        ingredientSizes: config.ingredientSizes,
        timeUnits: config.timeUnits,
        timeUnitMultipliers: config.timeUnitMultipliers,
        temperatureUnits: config.temperatureUnits,
        ingredientPrepositions: config.ingredientPrepositions,
        temperatureMarkers: config.temperatureMarkers,
        ingredientQuantities: config.ingredientQuantities,
        ingredientRangeMarker: config.ingredientRangeMarker,
        ingredientQuantityAddMarker: config.ingredientQuantityAddMarker,
        converters: converters,
        defaultConversions: defaultConversions,
        defaultTemperatureUnit: "fahrenheit"
    )
}
