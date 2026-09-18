import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authDenied = false
    @Published var isLocating = false
    @Published var errorMessage: String?
    /// True when the user granted only approximate location — the proximity
    /// order is then accurate to a few hundred metres at best.
    @Published var reducedAccuracy = false

    private var timeoutTask: Task<Void, Never>?
    private let timeoutSeconds: UInt64 = 12
    /// While a list is on screen we keep updating so the "a prop meu" order
    /// follows the user as they walk (v4). Stopped on disappear.
    private var continuous = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 30
    }

    /// One-shot fix (used by the route builder).
    func request() {
        continuous = false
        begin()
        if manager.authorizationStatus != .notDetermined { manager.requestLocation() }
    }

    /// Keeps the position updated while the screen is visible.
    func startUpdating() {
        continuous = true
        begin()
        if manager.authorizationStatus != .notDetermined { manager.startUpdatingLocation() }
    }

    func stopUpdating() {
        continuous = false
        manager.stopUpdatingLocation()
        cancel()
    }

    private func begin() {
        errorMessage = nil
        let status = manager.authorizationStatus
        // Recomputed on every request so that enabling the permission in
        // Settings clears the warning instead of leaving it stuck on screen.
        authDenied = (status == .denied || status == .restricted)
        guard !authDenied else {
            isLocating = false
            return
        }
        reducedAccuracy = (manager.accuracyAuthorization == .reducedAccuracy)
        if location == nil { isLocating = true }
        startTimeout()
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func cancel() {
        timeoutTask?.cancel()
        timeoutTask = nil
        isLocating = false
    }

    /// Without this, `requestLocation()` indoors or underground (the Tokyo
    /// metro, a department store basement) left the spinner turning forever.
    private func startTimeout() {
        timeoutTask?.cancel()
        let seconds = timeoutSeconds
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            guard !Task.isCancelled, let self, self.isLocating else { return }
            self.isLocating = false
            if self.location == nil {
                self.errorMessage = "No s'ha pogut obtenir la ubicació. Torna-ho a provar a l'exterior."
            }
        }
    }

    private func settle(location newLocation: CLLocation?, failure: String?) {
        timeoutTask?.cancel()
        timeoutTask = nil
        isLocating = false
        if let newLocation { location = newLocation }
        // A transient failure while we already have a fix is not worth a warning.
        errorMessage = (location == nil) ? failure : nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.authDenied = false
                self.reducedAccuracy = (manager.accuracyAuthorization == .reducedAccuracy)
                if self.continuous { manager.startUpdatingLocation() } else { manager.requestLocation() }
            case .denied, .restricted:
                self.authDenied = true
                self.settle(location: nil, failure: nil)
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let last = locations.last
        Task { @MainActor in
            self.settle(location: last, failure: nil)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.settle(location: nil, failure: "No s'ha pogut obtenir la ubicació. Torna-ho a provar a l'exterior.")
        }
    }
}
