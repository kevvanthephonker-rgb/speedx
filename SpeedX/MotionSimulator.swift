import Foundation
import CoreLocation

/// Indoor test rig for SpeedX.
///
/// When `AppConfig.simulatedDrive` is true, this generates a scripted ~2-minute
/// drive (standing start → city crawl → open-road surge → clearway → stop)
/// and feeds the measurements to TripEngine, so the gauge, stats and controls
/// can be verified without a real GPS lock. In the Simulator, Core Location can
/// be played back anyway — on-device, satellites need line-of-sight to the sky.
final class MotionSimulator: ObservableObject {
    private weak var engine: TripEngine?
    private var timer: Timer?

    /// Accumulated simulated seconds; only advances while the trip is running.
    private var clock: TimeInterval = 0

    /// Marching longitude so distance comes out of real haversine steps.
    private var lon: Double = -122.332
    private let lat: Double = 47.608

    /// Script length in seconds, after which the drive loops from standstill.
    private static let loopLength: TimeInterval = 122

    func attach(to engine: TripEngine) {
        guard self.engine !== engine else { return }
        self.engine = engine
        startTicking()
    }

    private func startTicking() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard let engine else { return }
        switch engine.phase {
        case .running:
            clock = (clock + 0.2).truncatingRemainder(dividingBy: Self.loopLength)
            engine.ingest(makeFix(speedKmh: scriptedSpeed(at: clock)))
        case .paused:
            break
        case .idle:
            clock = 0
        }
    }

    // MARK: Script

    /// Staged drive schedule: standing start, city crawl, open-road surge,
    /// clearway pass, and a final stop — then it loops.
    private func scriptedSpeed(at t: TimeInterval) -> Double {
        let s = t.truncatingRemainder(dividingBy: Self.loopLength)
        if s < 8  { return ramp(0, 18, s / 8) }
        if s < 15 { return 18 }
        if s < 22 { return ramp(18, 9, (s - 15) / 7) }
        if s < 30 { return 9 }
        if s < 45 { return ramp(9, 64, (s - 30) / 15) }
        if s < 52 { return 64 }
        if s < 60 { return ramp(64, 47, (s - 52) / 8) }
        if s < 70 { return 47 }
        if s < 80 { return ramp(47, 79, (s - 70) / 10) }
        if s < 86 { return 79 }
        if s < 96 { return ramp(79, 38, (s - 86) / 10) }
        if s < 108 { return 38 }
        if s < 118 { return ramp(38, 0, (s - 108) / 10) }
        return 0
    }

    /// Smooth ease-in-out transition between two speeds over a 0…1 progress span.
    private func ramp(_ from: Double, _ to: Double, _ rawProgress: Double) -> Double {
        let p = max(0, min(rawProgress, 1))
        let eased = 0.5 - 0.5 * cos(p * Double.pi)
        return from + (to - from) * eased
    }

    // MARK: Fix generation

    private func makeFix(speedKmh: Double) -> CLLocation {
        let speed = speedKmh / 3.6
        let dt = 0.2
        let dKm = speed * dt / 1000
        lon += dKm / (111.32 * cos(lat * .pi / 180))

        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            altitude: 40,
            horizontalAccuracy: 5,
            verticalAccuracy: 10,
            course: 90,
            speed: speed,
            timestamp: Date()
        )
    }
}
