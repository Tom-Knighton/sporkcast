//
//  SettingsStore.swift
//  Environment
//
//  Created by Tom Knighton on 11/10/2025.
//

import SwiftUI
import Observation

public extension UserDefaults {
    nonisolated(unsafe) static let appGroup: UserDefaults = {
        guard let ud = UserDefaults(suiteName: "group.sporkcast") else {
            fatalError("Missing app group")
        }
        return ud
    }()
}

public extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
}

@Observable
public final class SettingsStore {
    public private(set) var settings: AppSettings
    
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key = "app.settings.v1"
    @ObservationIgnored private let encoder = JSONEncoder()
    @ObservationIgnored private let decoder = JSONDecoder()
    @ObservationIgnored private let queue = DispatchQueue(label: "settings.v1.store")
    
    public init(defaults: UserDefaults = .appGroup) {
        self.defaults = defaults
        self.settings = (defaults.data(forKey: key)).flatMap { try? JSONDecoder().decode(AppSettings.self, from: $0) } ?? .default
    }
    
    public func update(_ mutate: (inout AppSettings) -> Void) {
        queue.sync {
            var next = settings
            mutate(&next)
            guard next != settings else { return }
            if let data = try? encoder.encode(next) {
                defaults.set(data, forKey: key)
            }
            settings = next
            NotificationCenter.default.post(name: .settingsChanged, object: self)
        }
    }
    
    public func binding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { newValue in self.update { $0[keyPath: keyPath] = newValue } }
        )
    }
}
