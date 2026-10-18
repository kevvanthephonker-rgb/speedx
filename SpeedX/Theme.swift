import SwiftUI
import UIKit

/// App-wide switches.
enum AppConfig {
    /// When true the app runs on a scripted "simulated drive" instead of real
    /// GPS so the readout can be tested indoors (no satellite lock needed).
    /// Keep this FALSE for real use — GPS speedometer, lives on real hardware.
    static let simulatedDrive = false
}

/// Shared dial calibration (single source of truth for gauge scaling).
enum Gauge {
    static let maxKmh: Double = 90
}

/// Shared dark/neon palette and small helpers used across all screens.
enum SpeedXTheme {
    /// Primary neon accent — #30FF7A.
    static let accent = Color(red: 0.188, green: 1.0, blue: 0.478)
    /// Deeper green used at the start of the gradient ramp.
    static let accentDeep = Color(red: 0.09, green: 0.62, blue: 0.29)
    /// Soft highlight at the end of the gradient ramp.
    static let accentGlow = Color(red: 0.72, green: 1.0, blue: 0.80)
    /// Text drawn on top of the accent fill (very dark green-black).
    static let onAccent = Color(red: 0.03, green: 0.10, blue: 0.05)
    /// Amber used for paused/waiting states.
    static let amber = Color(red: 0.99, green: 0.75, blue: 0.19)

    /// Almost-black app background.
    static let background = Color(red: 0.043, green: 0.055, blue: 0.071)
    /// Frosted card fill used by stat tiles.
    static let card = Color.white.opacity(0.06)
    static let cardStroke = Color.white.opacity(0.08)

    /// Dim ring that always shows the full 270° dial.
    static var trackGradient: AngularGradient {
        AngularGradient(colors: [Color.white.opacity(0.06),
                                 Color.white.opacity(0.13),
                                 Color.white.opacity(0.06)],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(270))
    }

    /// Neon ramp that fills as speed climbs.
    static var sweepGradient: AngularGradient {
        AngularGradient(colors: [accentDeep, accent, accentGlow],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(270))
    }
}

/// Recording button feedback: subtle press-down scale.
struct PressFeedback: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Tiny haptic helpers.
enum Haptics {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func tap()     { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}

/// Value formatting helpers.
enum Fmt {
    /// Distance in metres → human units (m below 1 km, then km).
    static func distance(_ meters: Double) -> (value: String, unit: String) {
        if meters < 1000 {
            return (String(format: "%.0f", meters), "m")
        }
        return (String(format: "%.2f", meters / 1000), "km")
    }

    /// Seconds → "m:ss" (or "h:mm:ss" past one hour).
    static func timer(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                     : String(format: "%d:%02d", m, s)
    }
}
