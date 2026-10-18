import Foundation
import CoreLocation
import Combine

/// Drives all GPS measurement for SpeedX.
///
/// Location updates are started/stopped with trip state (start/pause), so the
/// GPS radio rests while paused and the trip timer pauses with it.
final class TripEngine: NSObject, ObservableObject, CLLocationManagerDelegate {

    // MARK: - Trip state

    enum Phase {
        case idle, running, paused
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var speedKmh: Double = 0        // live speed
    @Published private(set) var maxSpeedKmh: Double = 0
    @Published private(set) var avgSpeedKmh: Double = 0     // over moving time only
    @Published private(set) var distanceMeters: Double = 0
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var accuracy: CLLocationAccuracy = 0
    @Published private(set) var isAuthorized = false

    // MARK: - Internals

    private let manager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var movingSeconds: TimeInterval = 0   // time actually spent moving
    private var tickTimer: Timer?
    private var segmentStart: Date?               // when the current run began

    /// Speeds below this (km/h) read as GPS jitter, not real motion.
    private static let jitterFloorKmh: Double = 1.5
    /// GPS "course" within this spread (degrees) is treated as travelling straight.
    private static let courseSpread: Double = 60

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = true
        if AppConfig.simulatedDrive {
            manager.activityType = .otherNavigation
        }
    }

    // MARK: - Controls (Start / Pause / Reset)

    func start() {
        switch phase {
        case .running:
            return
        case .paused:
            resumeRun()
        case .idle:
            startFreshRun()
        }
    }

    private func startFreshRun() {
        requestPermissionIfUnknown()
        resetCounters()
        phase = .running
        segmentStart = Date()
        startTimerAndLocation()
    }

    private func resumeRun() {
        phase = .running
        segmentStart = Date()
        lastLocation = nil          // discard stale fix from the pause gap
        startTimerAndLocation()
    }

    private func startTimerAndLocation() {
        startTickTimer()
        guard !AppConfig.simulatedDrive else { return }
        manager.startUpdatingLocation()
    }

    func pause() {
        guard phase == .running else { return }
        freezeSegment()
        phase = .paused
        stopTickTimer()
        manager.stopUpdatingLocation()
    }

    func reset() {
        phase = .idle
        stopTickTimer()
        manager.stopUpdatingLocation()
        resetCounters()
    }

    private func freezeSegment() {
        if let start = segmentStart {
            elapsedSeconds += Date().timeIntervalSince(start)
            segmentStart = nil
        }
    }

    private func resetCounters() {
        segmentStart = nil
        lastLocation = nil
        movingSeconds = 0
        speedKmh = 0
        maxSpeedKmh = 0
        avgSpeedKmh = 0
        distanceMeters = 0
        elapsedSeconds = 0
        accuracy = 0
    }

    // MARK: - Timer

    private func startTickTimer() {
        stopTickTimer()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func stopTickTimer() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func tick() {
        guard phase == .running, let start = segmentStart else { return }
        elapsedSeconds += Date().timeIntervalSince(start)
        segmentStart = Date()
        updateAverage()
    }

    // MARK: - Averages

    private func updateAverage() {
        avgSpeedKmh = movingSeconds > 1 ? (distanceMeters / movingSeconds) * 3.6 : 0
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
        default:
            isAuthorized = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !AppConfig.simulatedDrive else { return }   // the simulator owns measurement in test mode
        guard phase == .running else { return }
        for location in locations where location.horizontalAccuracy >= 0 {
            ingest(location)
        }
        updateAverage()
    }

    /// Ingests one fix. Real hardware path: called by the delegate loop with
    /// every update; test path: called by MotionSimulator with staged data.
    func ingest(_ location: CLLocation) {
        accuracy = location.horizontalAccuracy

        if let previous = lastLocation {
            let distance = location.distance(from: previous)
            let seconds = location.timestamp.timeIntervalSince(previous.timestamp)
            let straighten = courseCast(previous, location)   // 0..1 confidence in true motion
            let kilometres = distance * straighten / 1000

            if kilometres > 0 {
                distanceMeters += kilometres * 1000
                movingSeconds += seconds * straighten
            }
        }

        let kmh = max(0, location.speed) * 3.6
        if kmh >= Self.jitterFloorKmh {
            speedKmh = kmh
            maxSpeedKmh = max(maxSpeedKmh, kmh)
        } else {
            speedKmh = 0
        }

        lastLocation = location
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let clError = error as? CLError
        // .locationUnknown is routine while the GPS locks on; anything else is worth surfacing.
        if clError?.code != CLError.Code.locationUnknown {
            print("Location error: \(error.localizedDescription)")
        }
    }

    /// During warm-up the GPS reports wildly wandering courses between fixes.
    /// Scale distance by how straight the last two readings agree, plus accuracy,
    /// so jitter never inflates the odometer. Clean driving data returns ~1.0.
    private func courseCast(_ previous: CLLocation, _ current: CLLocation) -> Double {
        let accAvg = (previous.horizontalAccuracy + current.horizontalAccuracy) / 2
        let accuracyTrust = min(1, accAvg > 0 ? 30 / accAvg : 1)   // fixes <30m get full trust

        let turn = abs(previous.course - current.course)
        let spread = min(turn, 360 - turn)                          // 0 = same heading, 180 = reversal
        let straight = spread <= Self.courseSpread ? 1 : 1 - min(1, (spread - Self.courseSpread) / 90)

        return accuracyTrust * straight
    }

    // MARK: - Permission

    private func requestPermissionIfUnknown() {
        guard !AppConfig.simulatedDrive else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
        default:
            isAuthorized = false
        }
    }
}
