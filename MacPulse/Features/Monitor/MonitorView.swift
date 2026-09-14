import SwiftUI
import Charts

// MARK: - Monitor View Mode
enum MonitorTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case history = "History"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "speedometer"
        case .history: return "chart.xyaxis.line"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - Main Monitor View
public struct MonitorView: View {
    @ObservedObject var viewModel: MonitorViewModel
    @State private var activeTab: MonitorTab = .dashboard
    @State private var selectedHistoryMetric: HistoryMetricType = .power
    @State private var selectedRange: String = "1h"

    public init(viewModel: MonitorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Segmented Switcher (Image 1 & 2)
            topBar
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 20) {
                    switch activeTab {
                    case .dashboard:
                        dashboardContent
                    case .history:
                        historyContent
                    case .settings:
                        settingsContent
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .task { viewModel.start() }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Spacer()
            HStack(spacing: 4) {
                ForEach(MonitorTab.allCases) { tab in
                    Button {
                        withAnimation(Animation.appleMomentum) { activeTab = tab }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13, weight: .semibold))
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            activeTab == tab
                                ? Color.accentColor
                                : Color.clear
                        )
                        .foregroundStyle(activeTab == tab ? Color.white : Color.primary.opacity(0.75))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.rawValue)
                    .accessibilityAddTraits(activeTab == tab ? [.isSelected] : [])
                }
            }
            .padding(4)
            .background(Color.primary.opacity(0.06))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
            Spacer()
        }
    }

    // MARK: - Dashboard Content (Image 1)
    private var dashboardContent: some View {
        VStack(spacing: 16) {
            // System Header Banner
            systemHeaderBanner

            // 6 Liquid Glass Cards in a 2-Column Grid
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                cpuCard
                memoryCard
                gpuCard
                powerCard
                networkCard
                diskCard
            }
        }
    }

    // MARK: - System Header Banner
    private var systemHeaderBanner: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Mac")
                        .font(.system(size: 13, weight: .semibold))
                    HStack(spacing: 6) {
                        Text(viewModel.metrics.macModel)
                        Text("•")
                        Image(systemName: "wifi")
                        Text(viewModel.metrics.networkName)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "memorychip")
                        .font(.caption)
                        .foregroundStyle(.pink)
                    Text("\(Int(ceil(Double(viewModel.metrics.totalMemory) / (1024 * 1024 * 1024)))) GB")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.pink.opacity(0.1), in: Capsule())

                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text(viewModel.metrics.uptimeFormatted)
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.blue.opacity(0.1), in: Capsule())

                if let firstAnomaly = viewModel.anomalies.first, firstAnomaly.severity != "Optimal" {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text(firstAnomaly.title)
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.12), in: Capsule())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: 14)
    }

    // MARK: - 1. CPU Card
    private var cpuCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("CPU", systemImage: "cpu")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.blue)
                Spacer()
            }

            Text(String(format: "%.1f%%", viewModel.metrics.cpuPercent))
                .font(.system(size: 42, weight: .bold, design: .rounded))

            // User / System split progress bar
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        HStack(spacing: 0) {
                            Capsule()
                                .fill(Color.cyan)
                                .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(viewModel.metrics.userPercent / 100.0))))
                            Capsule()
                                .fill(Color.yellow)
                                .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(viewModel.metrics.systemPercent / 100.0))))
                        }
                    }
                }
                .frame(height: 6)

                HStack(spacing: 14) {
                    HStack(spacing: 5) {
                        Circle().fill(Color.cyan).frame(width: 6, height: 6)
                        Text("user \(Int(viewModel.metrics.userPercent))%")
                    }
                    HStack(spacing: 5) {
                        Circle().fill(Color.yellow).frame(width: 6, height: 6)
                        Text("system \(Int(viewModel.metrics.systemPercent))%")
                    }
                    Spacer()
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            // Core load bubbles
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    let cores = viewModel.metrics.perCorePercentages.isEmpty
                        ? Array(repeating: viewModel.metrics.cpuPercent, count: viewModel.metrics.activeProcessorCount)
                        : viewModel.metrics.perCorePercentages
                    ForEach(0..<min(cores.count, 16), id: \.self) { idx in
                        let load = cores[idx]
                        Circle()
                            .fill(Color.blue.opacity(max(0.2, min(1.0, load / 100.0))))
                            .frame(width: 10, height: 10)
                    }
                    Spacer()
                    Text("Sampling \(viewModel.metrics.activeProcessorCount) cores")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)

            Divider().opacity(0.4)

            // Footer: Load average & Temp
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Load average")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f · %.2f · %.2f",
                                viewModel.metrics.loadAverage.first ?? 0,
                                viewModel.metrics.loadAverage.dropFirst().first ?? 0,
                                viewModel.metrics.loadAverage.last ?? 0))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Temp")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 3) {
                        Image(systemName: "thermometer.medium")
                            .foregroundStyle(.orange)
                        Text(String(format: "%.0f°C", viewModel.metrics.cpuTemp))
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 18)
    }

    // MARK: - 2. Memory Card
    private var memoryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("MEMORY", systemImage: "memorychip")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.purple)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Int64(viewModel.metrics.usedMemory).formattedByteCount())
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                Text("Used")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text("\(Int(viewModel.metrics.pressurePercent))% Pressure")
                    .font(.system(size: 12, weight: .semibold))
                Text("•")
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.metrics.pressureState == "Critical" ? Color.red : (viewModel.metrics.pressureState == "Warning" ? Color.orange : Color.green))
                        .frame(width: 7, height: 7)
                    Text(viewModel.metrics.pressureState)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("COMPOSITION")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)

                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(Color.indigo).frame(width: 7, height: 7)
                        Text("Wired")
                            .font(.caption)
                    }
                    Spacer()
                    Text(Int64(viewModel.metrics.wiredMemory).formattedByteCount())
                        .font(.caption.bold())
                }

                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(Color.pink).frame(width: 7, height: 7)
                        Text("Compressed")
                            .font(.caption)
                    }
                    Spacer()
                    Text(Int64(viewModel.metrics.compressedMemory).formattedByteCount())
                        .font(.caption.bold())
                }

                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(Color.purple).frame(width: 7, height: 7)
                        Text("App + cache")
                            .font(.caption)
                    }
                    Spacer()
                    Text(Int64(viewModel.metrics.appAndCacheMemory).formattedByteCount())
                        .font(.caption.bold())
                }
            }
            .padding(.top, 4)
        }
        .padding(18)
        .glassCard(cornerRadius: 18)
    }

    // MARK: - 3. GPU Card
    private var gpuCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("GPU", systemImage: "square.grid.2x2.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.indigo)
                Spacer()
                Text("\(viewModel.metrics.gpuCoreCount) Cores")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }

            Text(String(format: "%.1f%%", viewModel.metrics.gpuPercent))
                .font(.system(size: 42, weight: .bold, design: .rounded))

            // Memory bar
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(Color.indigo)
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(min(1.0, Double(viewModel.metrics.gpuMemoryUsed) / Double(max(1, viewModel.metrics.totalMemory)))))))
                    }
                }
                .frame(height: 6)

                HStack {
                    HStack(spacing: 5) {
                        Circle().fill(Color.cyan).frame(width: 6, height: 6)
                        Text("memory \(Int64(viewModel.metrics.gpuMemoryUsed).formattedByteCount())")
                    }
                    Spacer()
                    Text(viewModel.metrics.gpuName)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Divider().opacity(0.4)

            // Footer: Power & Temp
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Power")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f W", viewModel.metrics.gpuPowerWatts))
                        .font(.system(size: 12, weight: .semibold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Temp")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 3) {
                        Image(systemName: "thermometer.medium")
                            .foregroundStyle(.orange)
                        Text(String(format: "%.0f°C", viewModel.metrics.gpuTemp))
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 18)
    }

    // MARK: - 4. Power Card
    private var powerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("POWER", systemImage: "bolt.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.yellow)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.1f", viewModel.metrics.systemPowerWatts))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                Text("W")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            // Rails
            VStack(alignment: .leading, spacing: 6) {
                Text("RAILS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)

                powerRailRow(title: "CPU", watts: viewModel.metrics.cpuPowerWatts, color: .cyan)
                powerRailRow(title: "GPU", watts: viewModel.metrics.gpuPowerWatts, color: .indigo)
                powerRailRow(title: "DRAM", watts: viewModel.metrics.dramPowerWatts, color: .red)
                powerRailRow(title: "Display", watts: viewModel.metrics.displayPowerWatts, color: .teal)
            }

            Divider().opacity(0.4)

            // Footer: Level, Source, Health, Cycles, Temp
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Level").font(.caption2).foregroundStyle(.secondary)
                    Text("\(Int(viewModel.metrics.battery.percentage))%")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    Text("Source").font(.caption2).foregroundStyle(.secondary)
                    Text(viewModel.metrics.battery.isCharging ? "AC" : "Battery")
                        .font(.caption.bold())
                }
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    Text("Cycles").font(.caption2).foregroundStyle(.secondary)
                    Text(viewModel.metrics.battery.cycleCount.map { "\($0)" } ?? "—")
                        .font(.caption.bold())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Temp").font(.caption2).foregroundStyle(.secondary)
                    Text(viewModel.metrics.battery.temperatureCelsius.map { String(format: "%.0f°C", $0) } ?? "—")
                        .font(.caption.bold())
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 18)
    }

    private func powerRailRow(title: String, watts: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption2)
                .frame(width: 44, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.06))
                    Capsule().fill(color)
                        .frame(width: max(2, min(geo.size.width, geo.size.width * CGFloat(watts / 25.0))))
                }
            }
            .frame(height: 5)
            Text(String(format: "%.2f W", watts))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .frame(width: 54, alignment: .trailing)
        }
    }

    // MARK: - 5. Network Card
    private var networkCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("NETWORK", systemImage: "network")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.red)
                Spacer()
            }

            let totalNet = viewModel.metrics.networkInBytesPerSec + viewModel.metrics.networkOutBytesPerSec
            Text(totalNet > 1024 * 1024
                 ? String(format: "%.1f MB/s", totalNet / (1024 * 1024))
                 : String(format: "%.0f KB/s", totalNet / 1024))
                .font(.system(size: 42, weight: .bold, design: .rounded))

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                    Text("in \(Int64(viewModel.metrics.networkInBytesPerSec).formattedByteCount())/s")
                }
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.caption2.bold())
                        .foregroundStyle(.pink)
                    Text("out \(Int64(viewModel.metrics.networkOutBytesPerSec).formattedByteCount())/s")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Dual Live Sparkline
            DualSparklineView(
                seriesA: viewModel.networkInHistory,
                colorA: .green,
                seriesB: viewModel.networkOutHistory,
                colorB: .pink
            )
            .frame(height: 54)
            .padding(.top, 4)
        }
        .padding(18)
        .glassCard(cornerRadius: 18)
    }

    // MARK: - 6. Disk Card
    private var diskCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("DISK", systemImage: "internaldrive")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.cyan)
                Spacer()
            }

            let totalIO = viewModel.metrics.diskReadBytesPerSec + viewModel.metrics.diskWriteBytesPerSec
            Text(totalIO > 1024 * 1024
                 ? String(format: "%.1f MB/s", totalIO / (1024 * 1024))
                 : String(format: "%.0f KB/s", totalIO / 1024))
                .font(.system(size: 42, weight: .bold, design: .rounded))

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.caption2.bold())
                        .foregroundStyle(.cyan)
                    Text("read \(Int64(viewModel.metrics.diskReadBytesPerSec).formattedByteCount())/s")
                }
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)
                    Text("write \(Int64(viewModel.metrics.diskWriteBytesPerSec).formattedByteCount())/s")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Boot volume bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("BOOT VOLUME")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(viewModel.metrics.diskPercent))%")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule().fill(Color.blue)
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(viewModel.metrics.diskPercent / 100.0))))
                    }
                }
                .frame(height: 6)

                HStack {
                    HStack(spacing: 5) {
                        Circle().fill(Color.blue).frame(width: 6, height: 6)
                        Text("Used \(Int64(viewModel.metrics.usedDisk).formattedByteCount())")
                    }
                    Spacer()
                    HStack(spacing: 5) {
                        Circle().fill(Color.primary.opacity(0.2)).frame(width: 6, height: 6)
                        Text("Free \(Int64(viewModel.metrics.freeDisk).formattedByteCount())")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(18)
        .glassCard(cornerRadius: 18)
    }

    // MARK: - History Content (Image 2)
    private var historyContent: some View {
        VStack(spacing: 16) {
            // Header with range selector
            HStack {
                Label("System timeline", systemImage: "chart.xyaxis.line")
                    .font(.system(size: 15, weight: .bold))

                Spacer()

                HStack(spacing: 4) {
                    ForEach(["1h", "6h", "24h"], id: \.self) { range in
                        Button {
                            selectedRange = range
                        } label: {
                            Text(range)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(selectedRange == range ? Color.accentColor : Color.clear)
                                .foregroundStyle(selectedRange == range ? Color.white : Color.primary.opacity(0.8))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(3)
                .background(Color.primary.opacity(0.06))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassCard(cornerRadius: 14)

            // Horizontal Metric Selector Tiles
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(HistoryMetricType.allCases) { type in
                        historyTile(type: type)
                    }
                }
                .padding(.horizontal, 2)
            }

            // Big Detail Chart Card
            bigHistoryChartCard

            // Anomalies Card
            anomaliesCard
        }
    }

    private func historyTile(type: HistoryMetricType) -> some View {
        let isSelected = selectedHistoryMetric == type
        let valStr: String = {
            switch type {
            case .cpu: return String(format: "%.0f%%", viewModel.metrics.cpuPercent)
            case .memory: return String(format: "%.0f%%", viewModel.metrics.memoryPercent)
            case .power: return String(format: "%.1f W", viewModel.metrics.systemPowerWatts)
            case .gpu: return String(format: "%.0f%%", viewModel.metrics.gpuPercent)
            case .disk: return String(format: "%.0f KB/s", (viewModel.metrics.diskReadBytesPerSec + viewModel.metrics.diskWriteBytesPerSec) / 1024)
            case .network: return String(format: "%.0f KB/s", (viewModel.metrics.networkInBytesPerSec + viewModel.metrics.networkOutBytesPerSec) / 1024)
            case .temp: return String(format: "%.0f°C", viewModel.metrics.cpuTemp)
            case .fan: return "\(viewModel.metrics.fanRPM) rpm"
            }
        }()

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedHistoryMetric = type }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: type.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.orange : Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(
                        (isSelected ? Color.orange : Color.accentColor).opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 8)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(valStr)
                        .font(.system(size: 13, weight: .bold))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isSelected ? Color.orange.opacity(0.12) : Color.primary.opacity(0.04)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.orange.opacity(0.4) : Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var bigHistoryChartCard: some View {
        let samples = viewModel.historySamples
        let values = samples.map { $0.value(for: selectedHistoryMetric) }
        let latest = values.last ?? 0
        let avg = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        let peak = values.max() ?? 0

        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label(selectedHistoryMetric.rawValue, systemImage: selectedHistoryMetric.icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.orange)
                Spacer()
            }

            // Stats row: Latest, Average, Peak
            HStack(spacing: 36) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Latest").font(.caption2).foregroundStyle(.secondary)
                    Text(String(format: "%.1f %@", latest, selectedHistoryMetric.unit))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Average").font(.caption2).foregroundStyle(.secondary)
                    Text(String(format: "%.1f %@", avg, selectedHistoryMetric.unit))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Peak").font(.caption2).foregroundStyle(.secondary)
                    Text(String(format: "%.1f %@", peak, selectedHistoryMetric.unit))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                }
                Spacer()
            }

            // Rich Line and Area Chart
            Chart {
                ForEach(Array(samples.enumerated()), id: \.offset) { idx, sample in
                    let v = sample.value(for: selectedHistoryMetric)
                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Value", v)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    AreaMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Value", v)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.01)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .chartYScale(domain: 0...max(10, (peak * 1.25)))
            .chartPlotStyle { $0.frame(height: 200) }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .foregroundStyle(Color.primary.opacity(0.1))
                    AxisValueLabel(format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .foregroundStyle(Color.primary.opacity(0.1))
                    AxisValueLabel {
                        if let d = value.as(Double.self) {
                            Text(String(format: "%.1f %@", d, selectedHistoryMetric.unit))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Divider().opacity(0.4)

            // Metadata footer: Coverage, Samples, Max gap, Last seen
            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    Text("Coverage").foregroundStyle(.secondary)
                    Text("100%").bold()
                }
                HStack(spacing: 4) {
                    Text("Samples").foregroundStyle(.secondary)
                    Text("\(samples.count)").bold()
                }
                HStack(spacing: 4) {
                    Text("Max gap").foregroundStyle(.secondary)
                    Text("2s").bold()
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("Last seen").foregroundStyle(.secondary)
                    Text("Live").bold().foregroundStyle(.green)
                }
            }
            .font(.caption2)
        }
        .padding(20)
        .glassCard(cornerRadius: 18)
    }

    // MARK: - Anomalies Card
    private var anomaliesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Anomalies")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Text("\(viewModel.anomalies.filter { $0.severity != "Optimal" }.count)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.08), in: Capsule())
            }

            VStack(spacing: 10) {
                ForEach(viewModel.anomalies) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(item.severity == "High" ? .red : (item.severity == "Medium" ? .orange : .green))
                            .frame(width: 32, height: 32)
                            .background(
                                (item.severity == "High" ? Color.red : (item.severity == "Medium" ? Color.orange : Color.green)).opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 8)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(item.title)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(item.severity)
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        (item.severity == "High" ? Color.red : (item.severity == "Medium" ? Color.orange : Color.green)).opacity(0.15),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(item.severity == "High" ? .red : (item.severity == "Medium" ? .orange : .green))
                            }
                            Text(item.description)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(item.valueString)
                                .font(.system(size: 12, weight: .bold))
                            Text(item.timeRange)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 18)
    }

    // MARK: - Settings Content
    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Monitor Preferences")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Text("Refresh Cadence")
                    .font(.subheadline.bold())
                Text("Sampling hardware sensors every 2 seconds balances fidelity and energy efficiency.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .glassCard(cornerRadius: 14)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.green)
                    Text("Charge Limiter (80%)")
                        .font(.subheadline.bold())
                    Spacer()
                    Toggle("", isOn: .constant(true)).labelsHidden().disabled(true)
                }
                Text("Optimizes battery longevity by holding charge at 80% when plugged into AC power.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .glassCard(cornerRadius: 14)
        }
    }
}

// MARK: - Dual Sparkline View (Green / Pink or Cyan / Red)
struct DualSparklineView: View {
    let seriesA: [Double]
    let colorA: Color
    let seriesB: [Double]
    let colorB: Color

    var body: some View {
        let maxVal = max(1.0, max(seriesA.max() ?? 1, seriesB.max() ?? 1))

        Chart {
            ForEach(Array(seriesA.enumerated()), id: \.offset) { idx, val in
                LineMark(x: .value("idx", idx), y: .value("a", val))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(colorA)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
            ForEach(Array(seriesB.enumerated()), id: \.offset) { idx, val in
                LineMark(x: .value("idx", idx), y: .value("b", val))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(colorB)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
        }
        .chartYScale(domain: 0...maxVal)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }
}

// MARK: - Menu Bar Popover Tray (Images 3 & 4: Peakmon / mac-usage / blip)
public struct MonitorHUDView: View {
    @ObservedObject var viewModel: MonitorViewModel
    var privacyMonitor: PrivacyMonitorViewModel?
    @State private var processSortMode: String = "CPU"
    @State private var showingFeatures = false

    public init(viewModel: MonitorViewModel, privacyMonitor: PrivacyMonitorViewModel? = nil) {
        self.viewModel = viewModel
        self.privacyMonitor = privacyMonitor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Health score header + device chips (mole.fit style)
            headerRow
            chipRow

            // 2-column tile grid
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                hudCPUCard
                hudGPUCard
                hudMemoryCard
                hudDiskCard
                hudNetworkCard
                hudFanCard
            }

            hudBatteryCard
            privacyRow
            hudTopProcessesCard

            DisclosureGroup(isExpanded: $showingFeatures) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(NavigationItem.allCases) { item in
                        Button {
                            NotificationCenter.default.post(name: .macPulseNavigate, object: item.rawValue)
                        } label: {
                            Label(item.localizedTitle, systemImage: item.systemImage)
                                .font(.system(size: 10, weight: .medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(item.tint)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, 6)
            } label: {
                Label("MacPulse Features", systemImage: "square.grid.2x2")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.8))
            }
            .tint(.white)

            // Footer bar: Open window & Quit
            hudFooterBar
        }
        .padding(14)
        .frame(width: 380)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(red: 0.13, green: 0.12, blue: 0.10)))
        .task { viewModel.start() }
    }

    // MARK: - Mole-style helpers

    private var issueCount: Int {
        viewModel.anomalies.filter { $0.severity != "Optimal" }.count
    }

    private var healthScore: Int {
        issueCount == 0 ? 100 : max(40, 100 - issueCount * 15)
    }

    private var osVersionShort: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(v.majorVersion).\(v.minorVersion)"
    }

    private func moleChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.65))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .lineLimit(1)
    }

    private func moleTile<Content: View>(
        title: String,
        icon: String,
        tint: Color,
        chip: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(chip)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .lineLimit(1)
            }
            content()
        }
        .padding(10)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func moleBar(_ fraction: Double, tint: Color) -> some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.white.opacity(0.10))
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(tint)
                        .frame(width: geo.size.width * min(1, max(0, fraction)))
                }
        }
        .frame(height: 4)
    }

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                moleChip(viewModel.metrics.macModel)
                moleChip(Int64(viewModel.metrics.totalMemory).formattedByteCount())
                moleChip(osVersionShort)
                moleChip("up \(viewModel.metrics.uptimeFormatted)")
                moleChip(viewModel.metrics.networkName)
            }
        }
    }

    private var privacyRow: some View {
        Group {
            if let privacyMonitor {
                HStack(spacing: 6) {
                    Image(systemName: privacyMonitor.cameraActive || privacyMonitor.micActive ? "eye.trianglebadge.exclamationmark" : "checkmark.shield")
                    Text(privacyMonitor.cameraActive || privacyMonitor.micActive ? "Camera or microphone active" : "Privacy idle")
                }
                .font(.caption)
                .foregroundStyle(privacyMonitor.cameraActive || privacyMonitor.micActive ? .red : .green)
            }
        }
    }

    // MARK: - Header Row (health score)
    private var headerRow: some View {
        HStack(spacing: 8) {
            Image(systemName: healthScore == 100 ? "sun.max.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundStyle(healthScore == 100 ? .green : .orange)
            Text("\(healthScore)")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(healthScore == 100 ? "All checks passed" : "\(issueCount) issue\(issueCount > 1 ? "s" : "") need attention")
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.6))
                .lineLimit(2)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                .buttonStyle(.plain)
                .help("Refresh metrics")
                Text(updatedLabel)
                    .font(.system(size: 8))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
        }
    }

    // MARK: - HUD CPU Card
    private var hudCPUCard: some View {
        moleTile(
            title: "CPU",
            icon: "cpu",
            tint: .green,
            chip: String(format: "%.0f°C", viewModel.metrics.cpuTemp)
        ) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.0f", viewModel.metrics.cpuPercent))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("%")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            SparklineView(values: viewModel.cpuHistory, color: .green)
                .frame(height: 26)
            Text("idle · Load \(String(format: "%.1f", viewModel.metrics.loadAverage.first ?? 0))/\(viewModel.metrics.activeProcessorCount)")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.45))
                .lineLimit(1)
        }
    }

    // MARK: - HUD Memory Card
    private var hudMemoryCard: some View {
        moleTile(
            title: "MEM",
            icon: "memorychip",
            tint: .green,
            chip: "PRS \(Int(viewModel.metrics.pressurePercent))%"
        ) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.0f", viewModel.metrics.memoryPercent))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("%")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            moleBar(viewModel.metrics.memoryPercent / 100, tint: .purple)
                .padding(.vertical, 8)
            Text("\(Int64(viewModel.metrics.freeMemory).formattedByteCount()) free · \(viewModel.metrics.pressureState)")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.45))
                .lineLimit(1)
        }
    }

    // MARK: - HUD GPU Card
    private var hudGPUCard: some View {
        moleTile(
            title: "GPU",
            icon: "square.grid.2x2.fill",
            tint: .orange,
            chip: String(format: "%.0f°C", viewModel.metrics.gpuTemp)
        ) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.0f", viewModel.metrics.gpuPercent))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("%")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            SparklineView(values: viewModel.gpuHistory, color: .orange, maxValue: 100)
                .frame(height: 26)
            Text("idle · \(viewModel.metrics.gpuCoreCount) cores")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.45))
                .lineLimit(1)
        }
    }

    // MARK: - HUD Fan Card
    private var hudFanCard: some View {
        moleTile(
            title: "FAN",
            icon: "fan.fill",
            tint: .orange,
            chip: thermalLabel
        ) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(viewModel.metrics.fanRPM)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("RPM")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            .padding(.vertical, 8)
            Text("Managed by macOS · \(String(format: "%.0fW", viewModel.metrics.systemPowerWatts))")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.45))
                .lineLimit(1)
        }
    }

    private var thermalLabel: String {
        switch viewModel.metrics.thermalState {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Nominal"
        }
    }

    // MARK: - HUD Disk Card
    private var hudDiskCard: some View {
        moleTile(
            title: "Disk",
            icon: "internaldrive",
            tint: .blue,
            chip: Int64(viewModel.metrics.totalDisk).formattedByteCount()
        ) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.0f", viewModel.metrics.diskPercent))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("%")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            moleBar(viewModel.metrics.diskPercent / 100, tint: .blue)
                .padding(.vertical, 8)
            Text("\(Int64(viewModel.metrics.freeDisk).formattedByteCount()) free")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.45))
                .lineLimit(1)
        }
    }

    // MARK: - HUD Network Card
    private var hudNetworkCard: some View {
        let totalNet = viewModel.metrics.networkInBytesPerSec + viewModel.metrics.networkOutBytesPerSec
        return moleTile(
            title: "Network",
            icon: "network",
            tint: .blue,
            chip: viewModel.metrics.networkName
        ) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(formatShortRate(totalNet).components(separatedBy: " ").first ?? "0")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(formatShortRate(totalNet).components(separatedBy: " ").dropFirst().joined(separator: " "))
                    .font(.system(size: 9))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            DualSparklineView(
                seriesA: viewModel.networkInHistory,
                colorA: .green,
                seriesB: viewModel.networkOutHistory,
                colorB: .blue
            )
            .frame(height: 26)
            Text("↓ \(formatShortRate(viewModel.metrics.networkInBytesPerSec)) · ↑ \(formatShortRate(viewModel.metrics.networkOutBytesPerSec))")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.45))
                .lineLimit(1)
        }
    }

    // MARK: - Battery Banner Card
    private var hudBatteryCard: some View {
        let battery = viewModel.metrics.battery
        let timeText: String? = {
            if battery.isCharging, let mins = battery.timeToFullMinutes {
                return "Full in \(mins / 60)h \(mins % 60)m"
            } else if !battery.isCharging, let mins = battery.timeToEmptyMinutes {
                return "\(mins / 60)h \(mins % 60)m remaining"
            }
            return nil
        }()
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("BATTERY", systemImage: "battery.100")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.green)
                    .lineLimit(1)
                Spacer()
                if let health = battery.healthPercent {
                    Text("\(Int(health))% Health")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .lineLimit(1)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(battery.percentage))%")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(battery.isCharging ? "Plugged In" : "On Battery")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            if let timeText {
                Text(timeText)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Top Processes Card
    private var hudTopProcessesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("TOP PROCESSES", systemImage: "chart.bar.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.55))
                Spacer()
                Text("CPU")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(processSortMode == "CPU" ? Color.white.opacity(0.8) : Color.white.opacity(0.3))
                    .onTapGesture { processSortMode = "CPU" }
                Text("Memory")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(processSortMode == "Memory" ? Color.white.opacity(0.8) : Color.white.opacity(0.3))
                    .onTapGesture { processSortMode = "Memory" }
            }

            let procs = processSortMode == "CPU"
                ? viewModel.topProcessesByCPU
                : viewModel.topProcessesByMemory

            if procs.isEmpty {
                Text("Collecting...")
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.4))
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 5) {
                    ForEach(procs) { p in
                        HStack {
                            Text(p.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.9))
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(String(format: "%.1f%%", p.cpuPercent))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.55))
                                .frame(width: 48, alignment: .trailing)
                            Text(p.memoryFormatted)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.55))
                                .frame(width: 72, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Footer Bar
    private var hudFooterBar: some View {
        HStack {
            Button {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
                    window.makeKeyAndOrderFront(nil)
                }
            } label: {
                Label("Open", systemImage: "macwindow")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Open MacPulse Dashboard")

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.red.opacity(0.9))
            }
            .buttonStyle(.plain)
            .help("Quit MacPulse")
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private var updatedLabel: String {
        let seconds = max(0, Int(Date().timeIntervalSince(viewModel.metrics.updatedAt)))
        return seconds < 2 ? "Updated now" : "Updated \(seconds)s ago"
    }

    private func formatShortRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1024 * 1024 {
            return String(format: "%.1f MB/s", bytesPerSec / (1024 * 1024))
        } else {
            return String(format: "%.0f KB/s", bytesPerSec / 1024)
        }
    }
}
