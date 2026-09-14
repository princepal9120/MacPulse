import SwiftUI

/// Single-ring progress gauge — compact companion to DiskRingsChartView for one-value metrics.
struct RingGaugeView: View {
    let percent: Double
    let icon: String
    let color: Color
    var lineWidth: CGFloat = 10

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.015, CGFloat(min(100, max(0, percent))) / 100))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Animation.appleMomentum, value: percent)
            VStack(spacing: 2) {
                Image(systemName: icon).font(.caption2).foregroundStyle(color)
                Text("\(Int(percent.rounded()))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(icon)")
        .accessibilityValue("\(Int(percent.rounded())) percent")
    }
}
