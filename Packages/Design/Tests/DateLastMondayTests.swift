import Foundation
import Testing
@testable import Design

@Test func lastMondayAlwaysReturnsPreviousMonday() throws {
    var calendar = Calendar(identifier: .iso8601)
    calendar.firstWeekday = 2

    // Monday
    let reference = calendar.date(from: DateComponents(year: 2025, month: 11, day: 17))!
    let monday = reference.lastMonday(calendar: calendar)
    #expect(calendar.isDate(monday, inSameDayAs: calendar.date(from: DateComponents(year: 2025, month: 11, day: 10))!))

    // Tuesday should return same Monday
    let tuesday = calendar.date(byAdding: .day, value: 1, to: reference)!
    let tuesdayMonday = tuesday.lastMonday(calendar: calendar)
    #expect(calendar.isDate(tuesdayMonday, inSameDayAs: monday))
}
