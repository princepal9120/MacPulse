import SwiftUI

/// Scan controls and context for the current Disk Analyzer workspace.
public struct DiskAnalyzerSidebarView: View {
    @Bindable var viewModel: DiskAnalyzerViewModel

    public init(viewModel: DiskAnalyzerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 1. Scan Actions
            scanButtons

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    // 2. Recent Scans
                    recentScansSection

                    Divider()

                    // 3. Disk Storage Circular Gauge
                    diskStorageSection

                    Divider()

                    // 4. Current View Card
                    currentViewSection

                    Divider()

                    // 5. Quick Wins
                    quickWinsSection

                    Divider()

                    // 6. File Types Stacked Bar & Legend
                    fileTypesSection
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .frame(width: 250)
        .background(.thinMaterial)
    }

    // MARK: - Scan Buttons

    private var scanButtons: some View {
        VStack(spacing: 8) {
            Button(action: {
                viewModel.startScan(for: URL(fileURLWithPath: "/"))
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "display")
                        .font(.system(size: 13, weight: .bold))
                    Text("Scan Full Mac")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentColor)
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isScanning)

            HStack(spacing: 6) {
                Button(action: {
                    viewModel.startScan(for: FileManager.default.homeDirectoryForCurrentUser)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 11))
                        Text("Home")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)

                Button(action: {
                    viewModel.selectFolderAndScan()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 11))
                        Text("Folder...")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
            }
            .disabled(viewModel.isScanning)
        }
    }

    // MARK: - Recent Scans

    private var recentScansSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RECENT")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(viewModel.recentScans, id: \.self) { url in
                Button(action: {
                    viewModel.startScan(for: url)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.secondary)
                        Text(url.lastPathComponent.isEmpty ? "Macintosh HD" : url.lastPathComponent)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Disk Storage Gauge

    private var diskStorageSection: some View {
        let (total, free) = diskSpace()
        let used = max(0, total - free)
        let percent = total > 0 ? Double(used) / Double(total) : 0.0

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("DISK STORAGE")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Macintosh HD")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary)
            }

            HStack(spacing: 12) {
                // Ring progress
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: CGFloat(percent))
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 1) {
                        Text(String(format: "%.1f%%", percent * 100))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                        Text("USED")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                    }
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Total").font(.system(size: 10)).foregroundStyle(Color.secondary)
                        Spacer()
                        Text(FileManager.formatSize(total)).font(.system(size: 10, weight: .semibold))
                    }
                    HStack {
                        Text("Used").font(.system(size: 10)).foregroundStyle(Color.secondary)
                        Spacer()
                        Text(FileManager.formatSize(used)).font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.red.opacity(0.8))
                    }
                    HStack {
                        Text("Free").font(.system(size: 10)).foregroundStyle(Color.secondary)
                        Spacer()
                        Text(FileManager.formatSize(free)).font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.green)
                    }
                }
            }
        }
    }

    private func diskSpace() -> (total: Int64, free: Int64) {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") {
            let total = (attrs[.systemSize] as? Int64) ?? 0
            let free = (attrs[.systemFreeSize] as? Int64) ?? 0
            return (total, free)
        }
        return (0, 0)
    }

    // MARK: - Current View Card

    private var currentViewSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("CURRENT VIEW")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if viewModel.scanDurationSeconds > 0 {
                    Text(String(format: "%.1fs scan", viewModel.scanDurationSeconds))
                        .font(.system(size: 9))
                        .foregroundStyle(Color.secondary)
                }
            }

            Text(viewModel.currentItem?.name ?? "Home")
                .font(.callout.weight(.semibold))
                .lineLimit(1)

            Text(viewModel.currentItem?.url.path ?? "")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 6) {
                Button(action: {
                    viewModel.showInFinder()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 9))
                        Text("Reveal")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)

                Button(action: {
                    viewModel.copyPath()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9))
                        Text("Copy Path")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Quick Wins

    private var quickWinsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            let totalWins = viewModel.quickWins.reduce(0) { $0 + $1.bytes }
            HStack {
                Text("QUICK WINS")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(FileManager.formatSize(totalWins))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.secondary)
            }

            ForEach(viewModel.quickWins) { win in
                Button(action: {
                    if let target = win.item {
                        viewModel.drillDown(into: target)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: win.icon)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 14)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(win.title)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.primary)
                                .lineLimit(1)
                            Text("\(win.itemCount) items")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.secondary)
                        }

                        Spacer()

                        Text(FileManager.formatSize(win.bytes))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.primary.opacity(0.85))

                        Image(systemName: "chevron.right")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.secondary.opacity(0.6))
                    }
                    .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - File Types Breakdown

    private var fileTypesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FILE TYPES")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            let totalBytes = max(1, viewModel.fileTypesBreakdown.reduce(0) { $0 + $1.bytes })

            // Segmented colored bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(viewModel.fileTypesBreakdown) { type in
                        let width = max(3, geo.size.width * CGFloat(Double(type.bytes) / Double(totalBytes)))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(type.color)
                            .frame(width: width)
                    }
                }
            }
            .frame(height: 8)

            // Legend
            VStack(alignment: .leading, spacing: 4) {
                ForEach(viewModel.fileTypesBreakdown) { type in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(type.color)
                            .frame(width: 6, height: 6)

                        Text(type.label)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.primary.opacity(0.85))

                        Spacer()

                        Text(FileManager.formatSize(type.bytes))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
        }
    }
}
