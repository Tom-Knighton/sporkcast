//
//  MealplanEntryEntity.swift
//  sporkcast
//
//  Created by Tom Knighton on 16/06/2026.
//

import Foundation
@preconcurrency import AppIntents
import CoreSpotlight
import GeoToolbox
import Models

@available(anyAppleOS 27.0, *)
@AppEntity(schema: .calendar.calendar)
public struct MealplanCalendarEntity: Identifiable, Sendable {
    public static let defaultQuery = MealplanCalendarQuery()

    public static let mealplan = MealplanCalendarEntity()

    public let id: UUID

    @Property(title: "Title", indexingKey: \.title)
    public var title: String

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", image: .init(systemName: "calendar"))
    }

    public init() {
        self.id = UUID(uuidString: "9F4C75E1-1775-47C3-85F5-2760E9F3B934")!
        self.title = "Sporkcast Mealplan"
    }
}

@available(anyAppleOS 27.0, *)
public struct MealplanCalendarQuery: EnumerableEntityQuery {
    public init() {}

    public func entities(for identifiers: [MealplanCalendarEntity.ID]) async throws -> [MealplanCalendarEntity] {
        identifiers.contains(MealplanCalendarEntity.mealplan.id) ? [.mealplan] : []
    }

    public func suggestedEntities() async throws -> [MealplanCalendarEntity] {
        [.mealplan]
    }

    public func allEntities() async throws -> [MealplanCalendarEntity] {
        [.mealplan]
    }
}

@available(anyAppleOS 27.0, *)
@AppEnum(schema: .calendar.attendeeStatus)
public enum PlannedMealAttendeeStatus: String, Sendable {
    case accepted
    case declined
    case tentative

    public static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .accepted: "Accepted",
        .declined: "Declined",
        .tentative: "Tentative"
    ]
}

@available(anyAppleOS 27.0, *)
@AppEnum(schema: .calendar.attendeeType)
public enum PlannedMealAttendeeType: String, Sendable {
    case person

    public static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .person: "Person"
    ]
}

@available(anyAppleOS 27.0, *)
@AppEntity(schema: .calendar.attendee)
public struct PlannedMealAttendeeEntity: TransientAppEntity, Sendable {
    @Property(title: "Person")
    public var person: IntentPerson

    @Property(title: "Status")
    public var status: PlannedMealAttendeeStatus?

    @Property(title: "Optional")
    public var isAttendanceOptional: Bool

    @Property(title: "Type")
    public var type: PlannedMealAttendeeType?

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(String(describing: person.name))")
    }

    public init() {
        self.person = IntentPerson(identifier: .unknown, name: .unknown, handle: nil)
        self.status = nil
        self.isAttendanceOptional = false
        self.type = .person
    }
}

@available(anyAppleOS 27.0, *)
@AppEnum(schema: .calendar.eventStatus)
public enum PlannedMealEventStatus: String, Sendable {
    case confirmed
    case tentative
    case cancelled

    public static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .confirmed: "Confirmed",
        .tentative: "Tentative",
        .cancelled: "Cancelled"
    ]
}

@available(anyAppleOS 27.0, *)
public enum EventLocationCases: Sendable {
    case place(PlaceDescriptor)
    case description(String)
}

@available(anyAppleOS 27.0, *)
public enum EventAlarmCases: Sendable {
    case relative(Duration)
    case absolute(Date)
}

@available(anyAppleOS 27.0, *)
extension EventLocationCases: nonisolated _IntentValueRepresentable {
    nonisolated public static var allIntentValueTypes: [any _IntentValue.Type] {
        [PlaceDescriptor.self, String.self]
    }

    nonisolated public var asIntentValue: any _IntentValue {
        switch self {
        case let .place(place):
            return place
        case let .description(description):
            return description
        }
    }

    @ResolverSpecificationBuilder<Self>
    nonisolated public static var defaultResolverSpecification: some ResolverSpecification {
        PlaceDescriptorResolver()
        StringResolver()
    }

    struct PlaceDescriptorResolver: AppIntents.Resolver {
        func resolve(from input: PlaceDescriptor, context: IntentParameterContext<EventLocationCases>) async throws -> EventLocationCases? {
            .place(input)
        }
    }

    struct StringResolver: AppIntents.Resolver {
        func resolve(from input: String, context: IntentParameterContext<EventLocationCases>) async throws -> EventLocationCases? {
            .description(input)
        }
    }
}

@available(anyAppleOS 27.0, *)
extension EventLocationCases: nonisolated AppUnionValue {
    public typealias Cases = EventLocationCasesCases

    public enum EventLocationCasesCases: String, nonisolated AppUnionValueCasesProviding {
        public typealias UnionValue = EventLocationCases

        case place
        case description
    }
}

@available(anyAppleOS 27.0, *)
extension EventAlarmCases: nonisolated _IntentValueRepresentable {
    nonisolated public static var allIntentValueTypes: [any _IntentValue.Type] {
        [Duration.self, Date.self]
    }

    nonisolated public var asIntentValue: any _IntentValue {
        switch self {
        case let .relative(duration):
            return duration
        case let .absolute(date):
            return date
        }
    }

    @ResolverSpecificationBuilder<Self>
    nonisolated public static var defaultResolverSpecification: some ResolverSpecification {
        DurationResolver()
        DateResolver()
    }

    struct DurationResolver: AppIntents.Resolver {
        func resolve(from input: Duration, context: IntentParameterContext<EventAlarmCases>) async throws -> EventAlarmCases? {
            .relative(input)
        }
    }

    struct DateResolver: AppIntents.Resolver {
        func resolve(from input: Date, context: IntentParameterContext<EventAlarmCases>) async throws -> EventAlarmCases? {
            .absolute(input)
        }
    }
}

@available(anyAppleOS 27.0, *)
extension EventAlarmCases: nonisolated AppUnionValue {
    public typealias Cases = EventAlarmCasesCases

    public enum EventAlarmCasesCases: String, nonisolated AppUnionValueCasesProviding {
        public typealias UnionValue = EventAlarmCases

        case relative
        case absolute
    }
}

@available(anyAppleOS 27.0, *)
@AppEntity(schema: .calendar.event)
public struct PlannedMealEntity: IndexedEntity, Identifiable, Sendable {
    
    public static let defaultQuery = PlannedMealQuery()
    
    public let id: UUID
    
    @Property(title: "Title", indexingKey: \.title)
    public var title: String
    
    @Property(title: "Start Date", indexingKey: \.startDate)
    public var startDate: Date
    
    @Property(title: "End Date")
    public var endDate: Date
    
    @Property(title: "All Day")
    public var isAllDay: Bool
    
    @Property(title: "Calendar")
    public var calendar: MealplanCalendarEntity

    @Property(title: "Recurrence")
    public var recurrence: Calendar.RecurrenceRule?

    @Property(title: "Attendees")
    public var attendees: [PlannedMealAttendeeEntity]

    @Property(title: "Organizers")
    public var organizers: [IntentPerson]

    @Property(title: "Note")
    public var note: String?

    @Property(title: "Alarms")
    public var alarms: [EventAlarmCases]

    @Property(title: "Virtual Location")
    public var virtualLocation: URL?

    @Property(title: "Travel Time")
    public var travelTime: Duration?

    @Property(title: "Location")
    public var location: EventLocationCases?

    @Property(title: "Status")
    public var status: PlannedMealEventStatus?
    
    @Property(title: "ImageUrl")
    public var imageUrl: URL?

    public var recipeName: String { title }
    public var date: Date { startDate }
    
    public var displayRepresentation: DisplayRepresentation {
        let dateText = startDate.formatted(date: .abbreviated, time: .omitted)

        let synonyms: [LocalizedStringResource] = ["mealplan", "meal plan", "dinner", "eating", "\(title)", "\(dateText)"]
        if let imageUrl {
            return DisplayRepresentation(title: "\(title)", subtitle: "\(dateText)", image: .init(url: imageUrl), synonyms: synonyms)
        } else {
            return DisplayRepresentation(title: "\(title)", subtitle: "\(dateText)", synonyms: synonyms)
        }
    }

    public var attributeSet: CSSearchableItemAttributeSet {
        let attributeSet = defaultAttributeSet
        let dateText = startDate.formatted(date: .abbreviated, time: .omitted)

        attributeSet.contentURL = URL(string: "sporkcast://mealplan?id=\(id.uuidString)")
        attributeSet.startDate = startDate
        attributeSet.endDate = endDate
        attributeSet.allDay = true
        
        attributeSet.keywords = [
            "meal plan",
            "mealplan",
            "planned meal",
            "dinner",
            "eating",
            title,
            dateText
        ]
        
        attributeSet.alternateNames = [
            "\(title) meal",
            "\(title) dinner"
        ]
        
        attributeSet.contentDescription = "Planned for \(dateText)"

        return attributeSet
    }
    

    public init(mealplanEntry: MealplanEntry) {
        self.id = mealplanEntry.id
        self.title = mealplanEntry.recipe?.title ?? mealplanEntry.note ?? "No Recipe"
        self.startDate = Calendar.current.startOfDay(for: mealplanEntry.date)
        self.endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? startDate
        self.isAllDay = true
        self.calendar = .mealplan
        self.recurrence = nil
        self.attendees = []
        self.organizers = []
        self.note = mealplanEntry.note
        self.alarms = []
        self.virtualLocation = nil
        self.travelTime = nil
        self.location = nil
        self.status = .confirmed
        self.imageUrl = URL(string: mealplanEntry.recipe?.image.imageUrl ?? "")
    }
}
