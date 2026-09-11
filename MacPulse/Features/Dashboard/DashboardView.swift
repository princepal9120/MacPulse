import SwiftUI
import Charts

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    let monitorViewModel: MonitorViewModel?
    let privacyMonitor: PrivacyMonitorViewModel?

    init(
        journal: TransactionJournal,
        monitorViewModel: MonitorViewModel? = nil,
        privacyMonitor: PrivacyMonitorViewModel? = nil
    ) {
        _viewModel = StateObject(wrappedValue: DashboardViewModel(journal: journal))
        self.monitorViewModel = monitorViewModel
        self.privacyMonitor = privacyMonitor
    }

    var body: some View {
        GlassEffectContainer {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 20) {
                        diskUsageCard
                        rightColumn
                    }

                    if let monitorVM = monitorViewModel {
                        DashboardLiveMonitorSection(viewModel: monitorVM)
                    }

                    HStack(alignment: .top, spacing: 20) {
                        if let monitorVM = monitorViewModel {
                            DashboardTopProcessesCard(viewModel: monitorVM)
                                .frame(maxWidth: .infinity)
                        }

                        VStack(spacing: 16) {
                            if let privacy = privacyMonitor {
                                DashboardPrivacyCard(viewModel: privacy)
                            }
                            recentOperationsSection
                        }
                        .frame(maxWidth: monitorViewModel != nil ? 420 : .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .padding(.top, 8)
            }
        }
        .task {
            await viewModel.refresh()
            monitorViewModel?.start()
            privacyMonitor?.start()
        }
    }
    
    // Right column: Stats + System Info stacked (Compact width to give diskUsageCard maximum space)
    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            statsCard
            systemInfoCard
        }
        .frame(width: 260)
    }
    
    private var systemInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("dashboard_system_info".localized, systemImage: "info.circle")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 10) {
                SystemInfoItem(title: "dashboard_model".localized, value: viewModel.systemInfo.model, icon: "laptopcomputer")
                SystemInfoItem(title: "dashboard_os_version".localized, value: viewModel.systemInfo.osVersion, icon: "info.circle")
                SystemInfoItem(title: "dashboard_processor".localized, value: viewModel.systemInfo.processor, icon: "cpu")
                SystemInfoItem(title: "dashboard_memory".localized, value: viewModel.systemInfo.memory, icon: "memorychip")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
    
    private var diskUsageCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.isCategoriesLoading {
                VStack(spacing: 12) {
                    LiquidGlassLoaderView(size: 48)
                    Text("disk_analyzer_scanning".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                DiskRingsChartView(
                    items: viewModel.diskCategories,
                    totalUsed: viewModel.usedDiskSpace,
                    totalDisk: viewModel.totalDiskSpace
                )
                .frame(maxHeight: .infinity)
            }
        }
        .padding()
        .frame(maxHeight: .infinity)
        .glassCard()
    }
    
    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("dashboard_statistics".localized, systemImage: "chart.bar")
                .font(.headline)
            
            VStack(spacing: 12) {
                StatRow(title: "dashboard_total_freed".localized, value: viewModel.totalFreedBytes.formattedByteCount(), icon: "trash")
                StatRow(title: "dashboard_cleanups".localized, value: "\(viewModel.cleanupCount)", icon: "arrow.counterclockwise")
                StatRow(title: "dashboard_status".localized, value: "dashboard_healthy".localized, icon: "checkmark.circle", color: .green)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
    
    private var recentOperationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("dashboard_recent_operations".localized, systemImage: "clock")
                .font(.headline)

            if viewModel.recentTransactions.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 26, weight: .light))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("dashboard_no_recent_operations".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 32)
            } else {
                VStack(spacing: 2) {
                    ForEach(viewModel.recentTransactions) { transaction in
                        TransactionRow(transaction: transaction)
                        if transaction.id != viewModel.recentTransactions.last?.id {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

struct StatRow: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .accentColor
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline)
            }
            Spacer()
        }
    }
}

struct TransactionRow: View {
    let transaction: CleanupTransaction
    @State private var isHovered = false

    var totalFreed: Int64 {
        transaction.operations.reduce(0) { $0 + $1.bytesFreed }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(.green)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.timestamp.formatted(.dateTime.year().month().day().locale(LanguageManager.shared.currentLocale)))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(transaction.timestamp.formatted(.dateTime.hour().minute().locale(LanguageManager.shared.currentLocale)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(String(format: "dashboard_freed_prefix".localized, totalFreed.formattedByteCount()))
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundColor(.green)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(isHovered ? 0.05 : 0))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
        }
    }
}

struct DiskStatItem: View {
    let title: String
    let value: Int64
    let color: Color?
    var alignment: HorizontalAlignment = .leading
    
    var body: some View {
        VStack(alignment: alignment) {
            HStack(spacing: 4) {
                if let color = color {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value.formattedByteCount())
                .fontWeight(.medium)
        }
    }
}

struct SystemInfoItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
    }
}

#Preview {
    DashboardView(journal: TransactionJournal())
}

// MARK: - Dashboard Live Monitor Section
struct DashboardLiveMonitorSection: View {
    @ObservedObject var viewModel: MonitorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Label("Live System Performance", systemImage: "waveform.path.ecg")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)

                Spacer()

                HStack(spacing: 8) {
                    Text(viewModel.metrics.macModel)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption2)
                        Text(viewModel.metrics.uptimeFormatted)
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.12), in: Capsule())

                    if let issue = viewModel.anomalies.first, issue.severity != "Optimal" {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                            Text(issue.title)
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                    }
                }
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ], spacing: 14) {
                cpuCard
                memoryCard
                gpuCard
                powerCard
                networkCard
                diskCard
            }
        }
        .padding()
        .glassCard()
    }

    private var cpuCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("CPU", systemImage: "cpu")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.blue)
                Spacer()
                Text(String(format: "%.0f°C", viewModel.metrics.cpuTemp))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(String(format: "%.1f%%", viewModel.metrics.cpuPercent))
                .font(.system(size: 24, weight: .bold, design: .rounded))

            HStack(spacing: 6) {
                Text("User \(Int(viewModel.metrics.userPercent))%")
                    .font(.caption2)
                    .foregroundStyle(.cyan)
                Text("•")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Sys \(Int(viewModel.metrics.systemPercent))%")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }

            SparklineView(values: viewModel.cpuHistory, color: .blue, maxValue: 100)
                .frame(height: 24)
        }
        .padding(12)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
    }

    private var memoryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Memory", systemImage: "memorychip")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.purple)
                Spacer()
                HStack(spacing: 3) {
                    Circle()
                        .fill(viewModel.metrics.pressureState == "Critical" ? Color.red : (viewModel.metrics.pressureState == "Warning" ? Color.orange : Color.green))
                        .frame(width: 5, height: 5)
                    Text(viewModel.metrics.pressureState)
                        .font(.caption2.bold())
                }
            }

            Text(String(format: "%.0f%%", viewModel.metrics.memoryPercent))
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text("\(Int64(viewModel.metrics.usedMemory).formattedByteCount()) of \(Int64(viewModel.metrics.totalMemory).formattedByteCount())")
                .font(.caption2)
                .foregroundStyle(.secondary)

            SparklineView(values: viewModel.memoryHistory, color: .purple, maxValue: 100)
                .frame(height: 24)
        }
        .padding(12)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
    }

    private var gpuCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("GPU", systemImage: "square.grid.2x2.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.indigo)
                Spacer()
                Text(String(format: "%.0f°C", viewModel.metrics.gpuTemp))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(String(format: "%.0f%%", viewModel.metrics.gpuPercent))
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text("\(viewModel.metrics.gpuName) (\(viewModel.metrics.gpuCoreCount) cores)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            SparklineView(values: viewModel.gpuHistory, color: .indigo, maxValue: 100)
                .frame(height: 24)
        }
        .padding(12)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
    }

    private var powerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Power", systemImage: "bolt.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.yellow)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: viewModel.metrics.battery.isCharging ? "battery.100.bolt" : "battery.75")
                    Text("\(Int(viewModel.metrics.battery.percentage))%")
                        .font(.caption2.bold())
                }
                .foregroundStyle(.green)
            }

            Text(String(format: "%.0fW", viewModel.metrics.systemPowerWatts))
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text(viewModel.metrics.battery.isCharging ? "Plugged In" : "On Battery")
                .font(.caption2)
                .foregroundStyle(.secondary)

            SparklineView(values: viewModel.powerHistory, color: .yellow)
                .frame(height: 24)
        }
        .padding(12)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
    }

    private var networkCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Network", systemImage: "network")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.green)
                Spacer()
                Text(viewModel.metrics.networkName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            let totalNet = viewModel.metrics.networkInBytesPerSec + viewModel.metrics.networkOutBytesPerSec
            Text(formatShortRate(totalNet))
                .font(.system(size: 24, weight: .bold, design: .rounded))

            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 8))
                    Text(formatShortRate(viewModel.metrics.networkInBytesPerSec))
                }
                .font(.caption2)
                .foregroundStyle(.green)

                HStack(spacing: 3) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 8))
                    Text(formatShortRate(viewModel.metrics.networkOutBytesPerSec))
                }
                .font(.caption2)
                .foregroundStyle(.pink)
            }

            SparklineView(values: viewModel.networkInHistory, color: .green)
                .frame(height: 24)
        }
        .padding(12)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
    }

    private var diskCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Disk I/O", systemImage: "internaldrive")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.cyan)
                Spacer()
                Text(Int64(viewModel.metrics.freeDisk).formattedByteCount() + " Free")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            let totalIO = viewModel.metrics.diskReadBytesPerSec + viewModel.metrics.diskWriteBytesPerSec
            Text(formatShortRate(totalIO))
                .font(.system(size: 24, weight: .bold, design: .rounded))

            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Text("R:")
                    Text(formatShortRate(viewModel.metrics.diskReadBytesPerSec))
                }
                .font(.caption2)
                .foregroundStyle(.cyan)

                HStack(spacing: 3) {
                    Text("W:")
                    Text(formatShortRate(viewModel.metrics.diskWriteBytesPerSec))
                }
                .font(.caption2)
                .foregroundStyle(.red)
            }

            SparklineView(values: viewModel.diskReadHistory, color: .cyan)
                .frame(height: 24)
        }
        .padding(12)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
    }

    private func formatShortRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1024 * 1024 {
            return String(format: "%.1f MB/s", bytesPerSec / (1024 * 1024))
        } else {
            return String(format: "%.0f KB/s", bytesPerSec / 1024)
        }
    }
}

// MARK: - Dashboard Top Processes Card
struct DashboardTopProcessesCard: View {
    @ObservedObject var viewModel: MonitorViewModel
    @State private var sortMode: String = "CPU"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Top Active Processes", systemImage: "list.bullet.rectangle")
                    .font(.headline)

                Spacer()

                Picker("", selection: $sortMode) {
                    Text("by CPU").tag("CPU")
                    Text("by Memory").tag("Memory")
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }

            let procs = sortMode == "CPU" ? viewModel.topProcessesByCPU : viewModel.topProcessesByMemory
            if procs.isEmpty {
                Text("Collecting live process metrics...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 6) {
                    HStack {
                        Text("PROCESS")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("MEMORY")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .trailing)
                        Text("CPU")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .trailing)
                    }
                    .padding(.horizontal, 6)

                    Divider().opacity(0.4)

                    ForEach(procs.prefix(6)) { p in
                        HStack(spacing: 8) {
                            Text(p.name)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)

                            Text("\(p.id)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(p.memoryFormatted)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .frame(width: 80, alignment: .trailing)

                            Text(String(format: "%.1f%%", p.cpuPercent))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(p.cpuPercent > 20 ? Color.orange : Color.primary)
                                .frame(width: 60, alignment: .trailing)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

// MARK: - Dashboard Privacy Card
struct DashboardPrivacyCard: View {
    @ObservedObject var viewModel: PrivacyMonitorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Privacy Protection", systemImage: "shield.checkered")
                .font(.headline)

            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.cameraActive ? Color.red : Color.green)
                        .frame(width: 8, height: 8)
                    Text(viewModel.cameraActive ? "Camera in use" : "Camera idle")
                        .font(.caption.bold())
                        .foregroundStyle(viewModel.cameraActive ? Color.red : Color.primary)
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.micActive ? Color.red : Color.green)
                        .frame(width: 8, height: 8)
                    Text(viewModel.micActive ? "Microphone in use" : "Microphone idle")
                        .font(.caption.bold())
                        .foregroundStyle(viewModel.micActive ? Color.red : Color.primary)
                }

                Spacer()

                Image(systemName: viewModel.cameraActive || viewModel.micActive ? "eye.trianglebadge.exclamationmark" : "checkmark.shield.fill")
                    .foregroundStyle(viewModel.cameraActive || viewModel.micActive ? Color.red : Color.green)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}
