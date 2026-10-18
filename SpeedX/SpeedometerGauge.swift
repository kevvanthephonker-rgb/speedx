import SwiftUI

/// Circular needle-and-arc speedometer.
///
/// The dial sweeps 270° clockwise, starting at the bottom-right (135°),
/// exactly like a real car speedometer. 0 km/h sits at the gap.
struct SpeedometerGauge: View {
    /// Live speed to display, in km/h.
    var speed: Double
    /// Fraction of the dial to fill (0...1).
    var progress: Double

    private let startDegrees: Double = 135
    private let sweepDegrees: Double = 270
    private let maxKmh: Double = 90

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let radius = side / 2
            let lineWidth = max(14, side * 0.05)

            ZStack {
                // Track
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(SpeedXTheme.trackGradient,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(startDegrees))

                // Neon fill
                if progress > 0.004 {
                    Circle()
                        .trim(from: 0, to: 0.75 * min(max(progress, 0), 1))
                        .stroke(SpeedXTheme.sweepGradient,
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(startDegrees))
                        .shadow(color: SpeedXTheme.accent.opacity(0.55), radius: lineWidth * 0.4)
                        .animation(.easeOut(duration: 0.18), value: progress)
                }

                tickMarks(radius: radius, lineWidth: lineWidth)
                labels(radius: radius)
                needle(radius: radius)
                hub
                readout(side: side)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Element builders

    /// Needle angle for the current progress (135°…405° clockwise from east).
    private var needleAngle: Double {
        startDegrees + sweepDegrees * min(max(progress, 0), 1)
    }

    private func angleDegrees(for kmh: Double) -> Double {
        startDegrees + sweepDegrees * kmh / maxKmh
    }

    private func tickMarks(radius: CGFloat, lineWidth: CGFloat) -> some View {
        ForEach(0..<19, id: \.self) { i in
            let major = i % 2 == 0
            Capsule()
                .fill(major ? Color.white.opacity(0.8) : Color.white.opacity(0.25))
                .frame(width: major ? 3 : 2, height: major ? 16 : 9)
                .offset(y: -(radius - lineWidth / 2 - 8))
                .rotationEffect(.degrees(angleDegrees(for: Double(i) * 5)))
        }
    }

    private func labels(radius: CGFloat) -> some View {
        ForEach([0, 30, 60, 90], id: \.self) { value in
            Text("\(value)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .offset(y: -(radius * 0.7))
                .rotationEffect(.degrees(angleDegrees(for: Double(value))))
        }
    }

    private func needle(radius: CGFloat) -> some View {
        let length = radius * 0.6
        return Capsule()
            .fill(SpeedXTheme.accent)
            .frame(width: 4.5, height: length)
            .shadow(color: SpeedXTheme.accent.opacity(0.8), radius: 5)
            .offset(y: -length / 2)
            .rotationEffect(.degrees(needleAngle))
            .animation(.easeOut(duration: 0.18), value: needleAngle)
    }

    private var hub: some View {
        Circle()
            .fill(Color(red: 0.07, green: 0.09, blue: 0.12))
            .frame(width: 30, height: 30)
            .overlay(Circle().strokeBorder(SpeedXTheme.accent.opacity(0.65), lineWidth: 2))
            .overlay(Circle().fill(Color.white.opacity(0.85)).frame(width: 6, height: 6))
    }

    private func readout(side: CGFloat) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(min(speed, 999).rounded()))")
                .font(.system(size: side * 0.26, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
            Text("KM/H")
                .font(.system(size: max(11, side * 0.045), weight: .bold))
                .kerning(3)
                .foregroundColor(SpeedXTheme.accent)
        }
        .offset(y: side * 0.18)
    }
}
