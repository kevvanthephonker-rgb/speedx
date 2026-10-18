import SwiftUI

/// Small labelled card used for Max / Average / Distance / Trip time.struct StatTile: View {
    var label: String
    var value: String
    var unit: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .kerning(1.3)
                .foregroundColor(.white.opacity(0.5))

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if let unit {
                    Text(unit)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.45))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(SpeedXTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(SpeedXTheme.cardStroke, lineWidth: 1)
                )
        )
    }
}
