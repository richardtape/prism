//
//  WeatherLocationProvider.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-08.
//

import CoreLocation
import Foundation

/// Resolves a location string or current device location for WeatherKit queries.
struct WeatherLocationProvider {
    struct ResolvedLocation {
        let coordinate: CLLocation
        let displayName: String
    }

    func resolve(locationQuery: String?) async throws -> ResolvedLocation {
        if let query = locationQuery?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty {
            return try await geocode(query)
        }
        return try await CurrentLocationRequest.request()
    }

    private func geocode(_ query: String) async throws -> ResolvedLocation {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString(query)
        guard let placemark = placemarks.first, let location = placemark.location else {
            throw WeatherLocationError.notFound
        }

        let nameParts = [placemark.locality, placemark.administrativeArea, placemark.country]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let displayName = nameParts.first.map { _ in nameParts.joined(separator: ", ") } ?? query
        return ResolvedLocation(coordinate: location, displayName: displayName)
    }
}

enum WeatherLocationError: Error {
    case notFound
    case timeout
}

@MainActor
private final class CurrentLocationRequest: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<WeatherLocationProvider.ResolvedLocation, Error>?

    static func request() async throws -> WeatherLocationProvider.ResolvedLocation {
        let request = CurrentLocationRequest()
        return try await request.perform()
    }

    private func perform() async throws -> WeatherLocationProvider.ResolvedLocation {
        let status = CLLocationManager.authorizationStatus()
        #if os(macOS)
        let isAuthorized = (status == .authorized)
        #else
        let isAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
        #endif
        guard isAuthorized else {
            throw CLError(.denied)
        }

        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        manager.delegate = self
        manager.requestLocation()

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if let continuation = self.continuation {
                    continuation.resume(throwing: WeatherLocationError.timeout)
                    self.continuation = nil
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first, let continuation else { return }
        let displayName = "Current Location"
        continuation.resume(returning: .init(coordinate: location, displayName: displayName))
        self.continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let continuation else { return }
        continuation.resume(throwing: error)
        self.continuation = nil
    }
}
