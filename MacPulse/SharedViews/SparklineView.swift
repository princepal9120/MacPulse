import SwiftUI
import Charts

/// Compact time-ordered history line for a metric. Values are plotted by array index.
struct SparklineView: View {
    let values: [Double]
    let color: Color
    var maxValue: Double? = nil

    var body: some View {
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                LineMark(x: .value("t", index), y: .value("v", value))
                    .interpolationMethod(.catmullRom)
                AreaMark(x: .value("t", index), y: .value("v", value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(color.opacity(0.15))
            }
        }
        .chartForegroundStyleScale(range: [color])
        .chartYScale(domain: 0...max(1, maxValue ?? (values.max() ?? 1)))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartPlotStyle { $0.frame(minHeight: 24) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("History sparkline")
        .accessibilityValue(values.last.map { String(format: "%.1f", $0) } ?? "No data")
    }
}
