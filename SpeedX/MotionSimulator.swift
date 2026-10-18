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

    /// The staged drive: (start, end, fromSec, toSec) segments, held-speed between.
    private func scriptedSpeed(at t: TimeInterval) -> Double {
        let seg: (Double, Double, Double, Double) = { start, end, from, to in
            guard t >= from else { return 0 }
            let progress = min((t - from) / (to - from), 1)
            let eased = 0.5 - 0.5 * cos(progress * .pi)   // smooth ease-in-out
            return start + (end - start) * eased
        }
        let hold: (Double, Double, Double) = { value, from, to in
            (t >= from && t < to) ? value : 0
        }
        return
            seg(0, 18, 0, 8) +
            hold(18, 8, 15) +
            seg(18, 9, 15, 22) +
            hold(9, 22, 30) +
            seg(9, 64, 30, 45) +
            hold(64, 45, 52) +
            seg(64, 47, 52, 60) +
            hold(47, 60, 70) +
            seg(47, 79, 70, 80) +
            hold(79, 80, 86) +
            seg(79, 38, 86, 96) +
            hold(38, 96, 108) +
            seg(38, 0, 108, 118) +
            hold(0, 118, Self.loopLength)
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
