import SwiftUI

struct MonitorView: View {
    @StateObject private var viewModel = MonitorViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label("menu_monitor".localized, systemImage: "waveform.path.ecg").font(.title2.bold())
                    Spacer()
                    Text(viewModel.metrics.updatedAt, style: .time).font(.caption).foregroundStyle(.secondary)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                    metricCard(title: "CPU Load", value: viewModel.metrics.cpuPercent, detail: String(format: "1m %.2f  5m %.2f  15m %.2f", viewModel.metrics.loadAverage.first ?? 0, viewModel.metrics.loadAverage.dropFirst().first ?? 0, viewModel.metrics.loadAverage.last ?? 0), icon: "cpu", color: .blue)
                    metricCard(title: "Memory", value: viewModel.metrics.memoryPercent, detail: "\(Int64(viewModel.metrics.usedMemory).formattedByteCount()) / \(Int64(viewModel.metrics.totalMemory).formattedByteCount())", icon: "memorychip", color: .purple)
                    metricCard(title: "Disk", value: viewModel.metrics.diskPercent, detail: "\(Int64(viewModel.metrics.usedDisk).formattedByteCount()) / \(Int64(viewModel.metrics.totalDisk).formattedByteCount())", icon: "internaldrive", color: .orange)
                }
                Text("Read-only metrics. Hardware controls and sensor access require privileged APIs and are intentionally not enabled.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private func metricCard(title: String, value: Double, detail: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.headline).foregroundStyle(color)
            Text("\(Int(value.rounded()))%").font(.system(size: 34, weight: .bold, design: .rounded))
            ProgressView(value: value, total: 100).tint(color)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }.padding().glassCard()
    }
}
