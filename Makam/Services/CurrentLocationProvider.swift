// MARK: - CurrentLocationProvider.swift
// One-shot, async/await-friendly Core Location fetch used to feed the
// Settings location picker (Country → City → District) so the backend can
// sort results nearest-first. Modeled on QiblaViewModel's
// CLLocationManagerDelegate usage, but simplified to a single fix with a
// timeout so the Settings UI never hangs waiting on a slow/never-arriving fix.
//
// NOT compiled into the MakamWidget extension target — do not add this file
// to MakamWidget's sources in project.yml.

import CoreLocation

@MainActor
final class CurrentLocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?
    private var didResume = false

    override init() {
        super.init()
        // Country/city/district-level sorting only needs city-level precision;
        // this avoids a slow, high-accuracy GPS fix (especially on a cold
        // start indoors) making the 5s timeout the common case.
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func requestOneShotLocation(timeout: TimeInterval = 5) async -> CLLocationCoordinate2D? {
        didResume = false
        manager.delegate = self

        // A cached last-known fix resolves near-instantly and is plenty
        // precise for this feature — use it before waiting on a fresh fix.
        if let cached = manager.location {
            return cached.coordinate
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            default:
                resume(with: nil)
            }
            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                resume(with: nil)
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                self.resume(with: nil)
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.resume(with: locations.last?.coordinate)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.resume(with: nil)
        }
    }

    private func resume(with coordinate: CLLocationCoordinate2D?) {
        guard !didResume else { return }
        didResume = true
        continuation?.resume(returning: coordinate)
        continuation = nil
    }
}
