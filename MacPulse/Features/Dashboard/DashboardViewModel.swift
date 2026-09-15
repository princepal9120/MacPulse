import SwiftUI
import Foundation
import OSLog

private extension Logger {
    static let dashboard = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.macpulse", category: "DashboardViewModel")
}

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var totalDiskSpace: Int64 = 0
    @Published var freeDiskSpace: Int64 = 0
    @Published var totalFreedBytes: Int64 = 0
    @Published var cleanupCount: Int = 0
    @Published var recentTransactions: [CleanupTransaction] = []
    @Published var systemInfo: SystemInfo = .current

    @Published var isCategoriesLoading: Bool = true
    @Published var diskCategories: [DiskCategoryItem] = []

    private let journal: TransactionJournal
    private static let categoryCacheKey = "com.macpulse.dashboard.categorySizes"
    // Skip ~/Pictures — deep walk triggers Photos Library TCC on launch.
    private static let categoryRoots: [(key: String, paths: [String])] = {
        let home = NSHomeDirectory()
        return [
            ("caches", ["\(home)/Library/Caches", "/Library/Caches"]),
            ("logs",   ["\(home)/Library/Logs", "/Library/Logs"]),
            ("dev",    ["\(home)/Library/Developer"]),
            ("apps",   ["/Applications", "\(home)/Applications", "/System/Applications"]),
            ("media",  ["\(home)/Music", "\(home)/Movies"]),
        ]
    }()

    init(journal: TransactionJournal) {
        self.journal = journal
        // Instant paint from last scan while fresh sizes compute in background.
        if let cached = Self.loadCachedSizes() {
            diskCategories = Self.buildItems(
                caches: cached["caches", default: 0],
                logs: cached["logs", default: 0],
                dev: cached["dev", default: 0],
                apps: cached["apps", default: 0],
                media: cached["media", default: 0],
                usedDiskSpace: max(0, totalDiskSpace - freeDiskSpace)
            )
            isCategoriesLoading = diskCategories.isEmpty
        }
    }

    func refresh() async {
        await fetchDiskUsage()
        await fetchHistory()
        await fetchCategoryData()
    }

    private func fetchDiskUsage() async {
        let fileManager = FileManager.default
        let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!

        do {
            let values = try url.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey,
            ])
            totalDiskSpace = Int64(values.volumeTotalCapacity ?? 0)
            if let important = values.volumeAvailableCapacityForImportantUsage {
                freeDiskSpace = important
            } else {
                freeDiskSpace = Int64(values.volumeAvailableCapacity ?? 0)
            }
        } catch {
            Logger.dashboard.error("Failed to fetch disk usage: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func fetchHistory() async {
        do {
            let allTransactions = try await journal.loadAll()
            // Prefer transactions that freed space; exclude empty 0-byte stubs when real records exist
            let positiveTransactions = allTransactions.filter { transaction in
                transaction.operations.reduce(0) { $0 + $1.bytesFreed } > 0
            }
            let displayList = positiveTransactions.isEmpty ? allTransactions : positiveTransactions
            recentTransactions = Array(displayList.reversed().prefix(5))
            totalFreedBytes = allTransactions.reduce(0) { sum, transaction in
                sum + transaction.operations.reduce(0) { $0 + $1.bytesFreed }
            }
            cleanupCount = positiveTransactions.isEmpty ? allTransactions.count : positiveTransactions.count
        } catch {
            Logger.dashboard.error("Failed to load history: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func fetchCategoryData() async {
        if diskCategories.isEmpty {
            isCategoriesLoading = true
        }

        var calculatedSizes: [String: Int64] = [:]
        // One task per root path — du is C-fast; fan out hard.
        await withTaskGroup(of: (String, Int64).self) { group in
            for entry in Self.categoryRoots {
                for path in entry.paths {
                    group.addTask {
                        (entry.key, Self.duBytes(path))
                    }
                }
            }
            for await (key, size) in group {
                calculatedSizes[key, default: 0] += size
            }
        }

        let cachesSize = calculatedSizes["caches", default: 0]
        let logsSize = calculatedSizes["logs", default: 0]
        let devSize = calculatedSizes["dev", default: 0]
        let appsSize = calculatedSizes["apps", default: 0]
        let mediaSize = calculatedSizes["media", default: 0]

        Self.saveCachedSizes([
            "caches": cachesSize,
            "logs": logsSize,
            "dev": devSize,
            "apps": appsSize,
            "media": mediaSize,
        ])

        diskCategories = Self.buildItems(
            caches: cachesSize,
            logs: logsSize,
            dev: devSize,
            apps: appsSize,
            media: mediaSize,
            usedDiskSpace: usedDiskSpace
        )
        isCategoriesLoading = false
    }

    private static func buildItems(
        caches: Int64,
        logs: Int64,
        dev: Int64,
        apps: Int64,
        media: Int64,
        usedDiskSpace: Int64
    ) -> [DiskCategoryItem] {
        let identifiedSum = caches + logs + dev + apps + media
        let otherUsed = max(0, usedDiskSpace - identifiedSum)

        var items: [DiskCategoryItem] = []
        if caches >= 0 {
            items.append(DiskCategoryItem(
                label: "dashboard_radar_caches".localized,
                bytes: caches,
                color: Color(red: 0.0, green: 0.75, blue: 0.95),
                gradientColors: [Color(red: 0.0, green: 0.75, blue: 0.95), Color(red: 0.0, green: 0.55, blue: 0.85)],
                iconName: "archivebox.fill"
            ))
        }
        if logs >= 0 {
            items.append(DiskCategoryItem(
                label: "dashboard_radar_logs".localized,
                bytes: logs,
                color: Color(red: 1.0, green: 0.6, blue: 0.0),
                gradientColors: [Color(red: 1.0, green: 0.6, blue: 0.0), Color(red: 0.95, green: 0.45, blue: 0.0)],
                iconName: "doc.text.fill"
            ))
        }
        if dev >= 0 {
            items.append(DiskCategoryItem(
                label: "dashboard_radar_dev".localized,
                bytes: dev,
                color: Color(red: 0.15, green: 0.55, blue: 1.0),
                gradientColors: [Color(red: 0.15, green: 0.55, blue: 1.0), Color(red: 0.35, green: 0.35, blue: 0.95)],
                iconName: "hammer.fill"
            ))
        }
        if apps >= 0 {
            items.append(DiskCategoryItem(
                label: "dashboard_radar_apps".localized,
                bytes: apps,
                color: Color(red: 0.65, green: 0.35, blue: 0.95),
                gradientColors: [Color(red: 0.65, green: 0.35, blue: 0.95), Color(red: 0.45, green: 0.2, blue: 0.85)],
                iconName: "app.badge.fill"
            ))
        }
        if media >= 0 {
            items.append(DiskCategoryItem(
                label: "dashboard_radar_media".localized,
                bytes: media,
                color: Color(red: 0.95, green: 0.3, blue: 0.55),
                gradientColors: [Color(red: 0.95, green: 0.3, blue: 0.55), Color(red: 0.9, green: 0.2, blue: 0.35)],
                iconName: "photo.stack.fill"
            ))
        }
        if otherUsed >= 0 {
            items.append(DiskCategoryItem(
                label: "dashboard_radar_other".localized,
                bytes: otherUsed,
                color: Color(red: 0.45, green: 0.5, blue: 0.6),
                gradientColors: [Color(red: 0.45, green: 0.5, blue: 0.6), Color(red: 0.3, green: 0.35, blue: 0.45)],
                iconName: "square.grid.2x2.fill"
            ))
        }
        return items
    }

    /// Native `du -sk` — far faster than Swift FileManager walks for dashboard overview.
    private nonisolated static func duBytes(_ path: String) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return 0 }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", path]
        let out = Pipe()
        process.standardOutput = out
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                return FileManager.default.getDirectorySize(url: URL(fileURLWithPath: path))
            }
            let data = out.fileHandleForReading.readDataToEndOfFile()
            guard let raw = String(data: data, encoding: .utf8) else { return 0 }
            let token = raw.split(whereSeparator: { $0 == "\t" || $0 == " " || $0 == "\n" }).first
            guard let token, let kb = Int64(token) else {
                return FileManager.default.getDirectorySize(url: URL(fileURLWithPath: path))
            }
            return kb * 1024
        } catch {
            return FileManager.default.getDirectorySize(url: URL(fileURLWithPath: path))
        }
    }

    private static func loadCachedSizes() -> [String: Int64]? {
        guard let dict = UserDefaults.standard.dictionary(forKey: categoryCacheKey) as? [String: Int] else {
            return nil
        }
        return dict.mapValues { Int64($0) }
    }

    private static func saveCachedSizes(_ sizes: [String: Int64]) {
        let boxed = sizes.mapValues { Int(clamping: $0) }
        UserDefaults.standard.set(boxed, forKey: categoryCacheKey)
    }

    var usedDiskSpace: Int64 {
        totalDiskSpace - freeDiskSpace
    }

    var usedDiskPercentage: Double {
        guard totalDiskSpace > 0 else { return 0 }
        return Double(usedDiskSpace) / Double(totalDiskSpace)
    }
}
