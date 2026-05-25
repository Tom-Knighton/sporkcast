//
//  MealplanWeatherService.swift
//  Environment
//

import API
import CoreLocation
import Foundation
import Observation
import WeatherKit

public struct MealplanWeatherForecast: Codable, Equatable, Identifiable, Sendable {
    public var date: Date
    public var condition: String
    public var symbolName: String
    public var temperatureC: Double
    public var fetchedAt: Date

    public var id: Date { date }

    public init(
        date: Date,
        condition: String,
        symbolName: String,
        temperatureC: Double,
        fetchedAt: Date = .now
    ) {
        self.date = date
        self.condition = condition
        self.symbolName = symbolName
        self.temperatureC = temperatureC
        self.fetchedAt = fetchedAt
    }
}

@MainActor
public protocol MealplanWeatherProviding: AnyObject {
    var dailyForecasts: [Date: MealplanWeatherForecast] { get }

    func forecast(for date: Date, calendar: Calendar) -> MealplanWeatherForecast?
    func loadDailyForecasts(startDate: Date, endDate: Date, calendar: Calendar) async
    func discoveryWeatherContext(calendar: Calendar) async -> DiscoveryWeatherContext?
}

@MainActor
@Observable
public final class MealplanWeatherService: NSObject, MealplanWeatherProviding, @preconcurrency CLLocationManagerDelegate {
    public static let shared = MealplanWeatherService()

    public private(set) var dailyForecasts: [Date: MealplanWeatherForecast] = [:]

    @ObservationIgnored private let cacheKey = "mealplan.weather.forecasts.cache.v1"
    @ObservationIgnored private let cacheAttemptKey = "mealplan.weather.forecasts.lastAttempt.v1"
    @ObservationIgnored private let cacheMaxAge: TimeInterval = 6 * 60 * 60
    @ObservationIgnored private let maxForecastDays = 10
    @ObservationIgnored private let locationManager = CLLocationManager()
    @ObservationIgnored private let weatherService = WeatherService.shared
    @ObservationIgnored private let encoder = JSONEncoder()
    @ObservationIgnored private let decoder = JSONDecoder()
    @ObservationIgnored private var locationContinuations: [UUID: CheckedContinuation<CLLocation?, Never>] = [:]

    override private init() {
        super.init()
        locationManager.delegate = self
        dailyForecasts = loadCachedForecasts()
    }

    public func forecast(for date: Date, calendar: Calendar = .current) -> MealplanWeatherForecast? {
        dailyForecasts[calendar.startOfDay(for: date)]
    }

    public func loadDailyForecasts(startDate: Date, endDate: Date, calendar: Calendar = .current) async {
        let requestedStart = calendar.startOfDay(for: startDate)
        let requestedEnd = min(
            calendar.startOfDay(for: endDate),
            calendar.date(byAdding: .day, value: maxForecastDays - 1, to: requestedStart) ?? endDate
        )
        let now = Date()

        let requestedDays = days(from: requestedStart, through: requestedEnd, calendar: calendar)
        let hasFreshRequestedRange = requestedDays.allSatisfy { day in
            guard let forecast = dailyForecasts[day] else { return false }
            return now.timeIntervalSince(forecast.fetchedAt) < cacheMaxAge
        }

        guard !hasFreshRequestedRange else {
            return
        }

        if let lastAttempt = UserDefaults.appGroup.object(forKey: cacheAttemptKey) as? Date,
           now.timeIntervalSince(lastAttempt) < cacheMaxAge {
            return
        }

        guard let location = await currentLocation() else { return }
        UserDefaults.appGroup.set(now, forKey: cacheAttemptKey)

        do {
            let exclusiveEnd = calendar.date(byAdding: .day, value: 1, to: requestedEnd) ?? endDate
            let forecast = try await weatherService.weather(
                for: location,
                including: .daily(startDate: requestedStart, endDate: exclusiveEnd)
            )

            var next = dailyForecasts
            for dayWeather in forecast.forecast {
                let day = calendar.startOfDay(for: dayWeather.date)
                next[day] = MealplanWeatherForecast(
                    date: day,
                    condition: String(describing: dayWeather.condition),
                    symbolName: dayWeather.symbolName,
                    temperatureC: dayWeather.highTemperature.converted(to: .celsius).value,
                    fetchedAt: now
                )
            }

            dailyForecasts = next
            persist(next)
        } catch {
#if DEBUG
            print("WeatherKit forecast load failed: \(error.localizedDescription)")
#endif
        }
    }

    public func discoveryWeatherContext(calendar: Calendar = .current) async -> DiscoveryWeatherContext? {
        let today = calendar.startOfDay(for: .now)
        if forecast(for: today, calendar: calendar) == nil {
            await loadDailyForecasts(startDate: today, endDate: today, calendar: calendar)
        }

        guard let forecast = forecast(for: today, calendar: calendar) else {
            return DiscoveryWeatherContext(season: currentSeason(calendar: calendar))
        }

        return DiscoveryWeatherContext(
            condition: forecast.condition,
            temperatureC: forecast.temperatureC,
            season: currentSeason(calendar: calendar)
        )
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            completeLocationRequests(with: nil)
        case .notDetermined:
            break
        @unknown default:
            completeLocationRequests(with: nil)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        completeLocationRequests(with: locations.last)
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        completeLocationRequests(with: manager.location)
    }

    private func currentLocation() async -> CLLocation? {
        if let location = locationManager.location,
           abs(location.timestamp.timeIntervalSinceNow) < 60 * 60 {
            return location
        }

        return await withCheckedContinuation { continuation in
            let id = UUID()
            locationContinuations[id] = continuation

            switch locationManager.authorizationStatus {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                locationManager.requestLocation()
            case .denied, .restricted:
                completeLocationRequest(id, with: nil)
            @unknown default:
                completeLocationRequest(id, with: nil)
            }
        }
    }

    private func completeLocationRequests(with location: CLLocation?) {
        let continuations = locationContinuations
        locationContinuations.removeAll()
        for continuation in continuations.values {
            continuation.resume(returning: location)
        }
    }

    private func completeLocationRequest(_ id: UUID, with location: CLLocation?) {
        guard let continuation = locationContinuations.removeValue(forKey: id) else { return }
        continuation.resume(returning: location)
    }

    private func days(from startDate: Date, through endDate: Date, calendar: Calendar) -> [Date] {
        var result: [Date] = []
        var date = startDate
        while date <= endDate {
            result.append(date)
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return result
    }

    private func loadCachedForecasts() -> [Date: MealplanWeatherForecast] {
        guard let data = UserDefaults.appGroup.data(forKey: cacheKey),
              let cached = try? decoder.decode([MealplanWeatherForecast].self, from: data) else {
            return [:]
        }

        let cutoff = Date().addingTimeInterval(-cacheMaxAge)
        return Dictionary(
            uniqueKeysWithValues: cached
                .filter { $0.fetchedAt >= cutoff }
                .map { ($0.date, $0) }
        )
    }

    private func persist(_ forecasts: [Date: MealplanWeatherForecast]) {
        let cutoff = Date().addingTimeInterval(-cacheMaxAge)
        let fresh = forecasts.values.filter { $0.fetchedAt >= cutoff }
        guard let data = try? encoder.encode(fresh) else { return }
        UserDefaults.appGroup.set(data, forKey: cacheKey)
    }

    private func currentSeason(calendar: Calendar) -> String {
        switch calendar.component(.month, from: Date()) {
        case 3...5:
            return "spring"
        case 6...8:
            return "summer"
        case 9...11:
            return "autumn"
        default:
            return "winter"
        }
    }
}

public final class MockMealplanWeatherService: MealplanWeatherProviding {
    public var dailyForecasts: [Date: MealplanWeatherForecast]

    public init(dailyForecasts: [Date: MealplanWeatherForecast] = [:]) {
        self.dailyForecasts = dailyForecasts
    }

    public func forecast(for date: Date, calendar: Calendar = .current) -> MealplanWeatherForecast? {
        dailyForecasts[calendar.startOfDay(for: date)]
    }

    public func loadDailyForecasts(startDate: Date, endDate: Date, calendar: Calendar = .current) async {}

    public func discoveryWeatherContext(calendar: Calendar = .current) async -> DiscoveryWeatherContext? {
        guard let forecast = forecast(for: .now, calendar: calendar) else {
            return DiscoveryWeatherContext(season: nil)
        }

        return DiscoveryWeatherContext(
            condition: forecast.condition,
            temperatureC: forecast.temperatureC,
            season: nil
        )
    }
}
