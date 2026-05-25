//
//  WeatherSettingsPage.swift
//  Settings
//

import CoreLocation
import Design
import Environment
import MapKit
import SwiftUI

struct WeatherSettingsPage: View {
    @Environment(\.appSettings) private var store
    @Environment(\.flagKit) private var flagKit
    @Environment(\.proAccess) private var proAccess

    @State private var isPaywallPresented = false
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 51.5072, longitude: -0.1276),
            span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
        )
    )

    private var hasWeatherAccess: Bool {
        flagKit.isEnabled(.mealplanWeatherPro, default: proAccess.hasProAccess)
    }

    private var selectedCoordinate: CLLocationCoordinate2D? {
        guard let latitude = store.settings.weatherLocationOverrideLatitude,
              let longitude = store.settings.weatherLocationOverrideLongitude else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var body: some View {
        List {
            if hasWeatherAccess {
                Section {
                    Toggle("Show in Mealplan", isOn: store.binding(\.showMealplanWeather))
                }

                Section {
                    weatherMap
                        .frame(height: 260)
                        .clipShape(.rect(cornerRadius: 10))
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                    if let selectedCoordinate {
                        LabeledContent("Override") {
                            Text("\(selectedCoordinate.latitude, format: .number.precision(.fractionLength(4))), \(selectedCoordinate.longitude, format: .number.precision(.fractionLength(4)))")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Label("Using Current Location", systemImage: "location.fill")
                            .foregroundStyle(.secondary)
                    }

                    Button("Use Current Location", systemImage: "location") {
                        store.update {
                            $0.weatherLocationOverrideLatitude = nil
                            $0.weatherLocationOverrideLongitude = nil
                        }
                    }
                    .disabled(selectedCoordinate == nil)
                } header: {
                    Text("Location")
                } footer: {
                    Text("Tap the map to pin a permanent weather location. Clearing the pin uses the device's current location.")
                }
            } else {
                Section {
                    Label("Weather in Mealplan", systemImage: "cloud.sun.fill")
                    Label("Weather-aware discovery", systemImage: "sparkles")
                    Label("Manual location override", systemImage: "mappin.and.ellipse")

                    Button("Unlock Weather", systemImage: "sparkles") {
                        isPaywallPresented = true
                    }
                } header: {
                    Text("Pro Weather")
                } footer: {
                    Text("Weather is a Sporkast Pro feature. Unlock it to show forecasts in meal planning and send local weather context to recipe discovery.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Weather")
        .scrollContentBackground(.hidden)
        .background(Color.layer1)
        .onAppear(perform: syncCameraToSelection)
        .sheet(isPresented: $isPaywallPresented) {
            ProPaywallView()
        }
    }

    private var weatherMap: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                if let selectedCoordinate {
                    Marker("Weather Location", systemImage: "mappin", coordinate: selectedCoordinate)
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .onTapGesture(coordinateSpace: .local) { point in
                guard let coordinate = proxy.convert(point, from: .local) else { return }
                store.update {
                    $0.weatherLocationOverrideLatitude = coordinate.latitude
                    $0.weatherLocationOverrideLongitude = coordinate.longitude
                }
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
                    )
                )
            }
        }
    }

    private func syncCameraToSelection() {
        guard let selectedCoordinate else { return }
        cameraPosition = .region(
            MKCoordinateRegion(
                center: selectedCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
            )
        )
    }
}
