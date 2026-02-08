//
//  PermissionManager.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-08.
//

import CoreLocation
import EventKit
import Foundation
#if canImport(MusicKit)
import MusicKit
#endif

/// Skill-level permissions required to execute tool calls.
public enum SkillPermission: String, CaseIterable, Sendable, Identifiable {
    case weather
    case music
    case reminders

    public var id: String { rawValue }
}

/// Normalized permission status for skill gating and UI.
public enum PermissionStatus: String, Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unavailable
}

/// Abstraction for permission checks and requests used by skill gating and UI.
public protocol PermissionManaging: Sendable {
    func status(for permission: SkillPermission) -> PermissionStatus
    func requestAccess(for permission: SkillPermission) async -> PermissionStatus
}

/// Default permission manager that bridges CoreLocation, MusicKit, and EventKit.
public final class PermissionManager: PermissionManaging, @unchecked Sendable {
    public static let shared = PermissionManager()

    private let eventStore = EKEventStore()

    private init() {}

    public func status(for permission: SkillPermission) -> PermissionStatus {
        switch permission {
        case .weather:
            let status = currentLocationStatus()
            PrismLogger.skillInfo("Location status check: \(status.rawValue)")
            return status
        case .music:
            return Self.musicStatus()
        case .reminders:
            return Self.mapEventKitStatus(EKEventStore.authorizationStatus(for: .reminder))
        }
    }

    public func requestAccess(for permission: SkillPermission) async -> PermissionStatus {
        switch permission {
        case .weather:
            PrismLogger.skillInfo("Requesting location access.")
            return await LocationPermissionRequest.requestAccess(currentStatus: currentLocationStatus)
        case .music:
            return await Self.requestMusicAccess()
        case .reminders:
            return await requestRemindersAccess()
        }
    }

    private func currentLocationStatus() -> PermissionStatus {
        guard CLLocationManager.locationServicesEnabled() else {
            return .restricted
        }

        let classStatus = CLLocationManager.authorizationStatus()
        if #available(macOS 11.0, *) {
            let instanceStatus = CLLocationManager().authorizationStatus
            let resolved = Self.resolveLocationStatus(classStatus, instanceStatus)
            PrismLogger.skillInfo("Location status detail: class=\(classStatus.rawValue) instance=\(instanceStatus.rawValue) resolved=\(resolved.rawValue)")
            return Self.mapLocationStatus(resolved)
        }
        PrismLogger.skillInfo("Location status detail: class=\(classStatus.rawValue)")
        return Self.mapLocationStatus(classStatus)
    }

    private static func resolveLocationStatus(
        _ first: CLAuthorizationStatus,
        _ second: CLAuthorizationStatus
    ) -> CLAuthorizationStatus {
        let statuses = [first, second]
        if statuses.contains(where: { isAuthorized($0) }) {
            return .authorized
        }
        if statuses.contains(.denied) {
            return .denied
        }
        if statuses.contains(.restricted) {
            return .restricted
        }
        if statuses.contains(.notDetermined) {
            return .notDetermined
        }
        return first
    }

    private static func isAuthorized(_ status: CLAuthorizationStatus) -> Bool {
        #if os(macOS)
        return status == .authorized
        #else
        return status == .authorizedAlways || status == .authorizedWhenInUse || status == .authorized
        #endif
    }

    fileprivate static func mapLocationStatus(_ status: CLAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorizedAlways, .authorizedWhenInUse, .authorized:
            return .authorized
        @unknown default:
            return .unavailable
        }
    }

    private static func mapEventKitStatus(_ status: EKAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized, .fullAccess:
            return .authorized
        case .writeOnly:
            return .restricted
        @unknown default:
            return .unavailable
        }
    }

    private static func musicStatus() -> PermissionStatus {
        #if canImport(MusicKit)
        if #available(macOS 12.0, *) {
            return mapMusicStatus(MusicAuthorization.currentStatus)
        }
        #endif
        return .unavailable
    }

    private static func requestMusicAccess() async -> PermissionStatus {
        #if canImport(MusicKit)
        if #available(macOS 12.0, *) {
            let current = MusicAuthorization.currentStatus
            if current != .notDetermined {
                return mapMusicStatus(current)
            }
            let requested = await MusicAuthorization.request()
            return mapMusicStatus(requested)
        }
        #endif
        return .unavailable
    }

    @available(macOS 12.0, *)
    private static func mapMusicStatus(_ status: MusicAuthorization.Status) -> PermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .authorized:
            return .authorized
        @unknown default:
            return .unavailable
        }
    }

    private func requestRemindersAccess() async -> PermissionStatus {
        let status = Self.mapEventKitStatus(EKEventStore.authorizationStatus(for: .reminder))
        guard status == .notDetermined else { return status }

        return await withCheckedContinuation { continuation in
            eventStore.requestAccess(to: .reminder) { _, _ in
                let updated = EKEventStore.authorizationStatus(for: .reminder)
                continuation.resume(returning: Self.mapEventKitStatus(updated))
            }
        }
    }
}

@MainActor
private final class LocationPermissionRequest: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<PermissionStatus, Never>?
    private var timeoutTask: Task<Void, Never>?

    static func requestAccess(currentStatus: @escaping () -> PermissionStatus) async -> PermissionStatus {
        let handler = LocationPermissionRequest()
        return await handler.request(currentStatus: currentStatus)
    }

    private func request(currentStatus: @escaping () -> PermissionStatus) async -> PermissionStatus {
        let current = currentStatus()
        guard current == .notDetermined else { return current }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            #if os(macOS)
            if manager.responds(to: #selector(CLLocationManager.requestWhenInUseAuthorization)) {
                manager.requestWhenInUseAuthorization()
            }
            manager.startUpdatingLocation()
            #else
            manager.requestWhenInUseAuthorization()
            #endif

            timeoutTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                guard let continuation = self.continuation else { return }
                let status = PermissionManager.mapLocationStatus(CLLocationManager.authorizationStatus())
                continuation.resume(returning: status)
                self.continuation = nil
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        handleAuthorizationChange()
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        handleAuthorizationChange()
    }

    private func handleAuthorizationChange() {
        guard let continuation else { return }
        let status = PermissionManager.mapLocationStatus(CLLocationManager.authorizationStatus())
        guard status != .notDetermined else { return }
        continuation.resume(returning: status)
        self.continuation = nil
        manager.stopUpdatingLocation()
        timeoutTask?.cancel()
        timeoutTask = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let continuation else { return }
        let status = PermissionManager.mapLocationStatus(CLLocationManager.authorizationStatus())
        continuation.resume(returning: status)
        self.continuation = nil
        manager.stopUpdatingLocation()
        timeoutTask?.cancel()
        timeoutTask = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let continuation else { return }
        let status = PermissionManager.mapLocationStatus(CLLocationManager.authorizationStatus())
        continuation.resume(returning: status)
        self.continuation = nil
        manager.stopUpdatingLocation()
        timeoutTask?.cancel()
        timeoutTask = nil
    }
}
