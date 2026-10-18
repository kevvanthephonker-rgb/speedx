import SwiftUI

/// Main (and only) screen: gauge, stat tiles and controls.
struct ContentView: View {
    @StateObject private var engine = TripEngine()
    @StateObject private var motion = MotionSimulator()

    var body: some View {
        ZStack {
            SpeedXTheme.background.ignoresSafeArea()

            VStack(spacing: 14) {
                header

                SpeedometerGauge(speed: engine.speedKmh,
                                 progress: min(engine.speedKmh / Gauge.maxKmh, 1))
                    .frame(maxHeight: 340)
                    .overlay(alignment: .center) {
                        if engine.phase == .paused {
                            pausedBadge
                        }
                    }

                stats
                Spacer(minLength: 0)
                controls
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 10)
        }
        .onAppear {
            motion.attach(to: engine)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("SpeedX")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)

                    if AppConfig.simulatedDrive {
                        Text("SIM")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(SpeedXTheme.background)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(SpeedXTheme.amber))
                    }
                }

                Text("GPS speedometer")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.55))
            }

            Spacer()

            gpsBadge
        }
    }

    private var gpsBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(engine.accuracy > 0 ? SpeedXTheme.accent : Color.white.opacity(0.3))
                .frame(width: 8, height: 8)

            Text(engine.accuracy > 0
                 ? String(format: "±%.0f m", engine.accuracy)
                 : "GPS")
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundColor(.white.opacity(0.75))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(SpeedXTheme.card))
    }

    // MARK: Stats

    private var stats: some View {
        let distance = Fmt.distance(engine.distanceMeters)

        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                StatTile(label: "Max",
                         value: String(format: "%.0f", engine.maxSpeedKmh),
                         unit: "km/h")
                StatTile(label: "Average",
                         value: String(format: "%.0f", engine.avgSpeedKmh),
                         unit: "km/h")
            }

            HStack(spacing: 10) {
                StatTile(label: "Distance",
                         value: distance.value,
                         unit: distance.unit)
                StatTile(label: "Trip",
                         value: Fmt.timer(engine.elapsedSeconds),
                         unit: nil)
            }
        }
    }

    private var pausedBadge: some View {
        Label("Paused", systemImage: "pause.fill")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(SpeedXTheme.amber)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.black.opacity(0.8)))
            .offset(y: -40)
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 12) {
            resetButton
            mainButton
        }
    }

    private var mainButton: some View {
        Button {
            Haptics.success()
            if engine.phase == .running {
                engine.pause()
            } else {
                engine.start()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                Text(mainTitle)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .foregroundColor(SpeedXTheme.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: [SpeedXTheme.accentGlow, SpeedXTheme.accent],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))
            )
            .shadow(color: SpeedXTheme.accent.opacity(0.35), radius: 14, y: 5)
        }
        .buttonStyle(PressFeedback())
    }

    private var resetButton: some View {
        Button {
            guard engine.phase != .idle else { return }
            Haptics.warning()
            engine.reset()
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 84, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(SpeedXTheme.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(SpeedXTheme.cardStroke, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PressFeedback())
    }

    private var mainTitle: String {
        switch engine.phase {
        case .running: return "Pause"
        case .paused:  return "Resume"
        case .idle:    return "Start"
        }
    }

    private var icon: String {
        engine.phase == .running ? "pause.fill" : "play.fill"
    }
}
