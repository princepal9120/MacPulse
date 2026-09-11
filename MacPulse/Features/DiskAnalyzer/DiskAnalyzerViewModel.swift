import Foundation
import SwiftUI
import Observation
import OSLog

/// How the scan result is drawn. One scan, 9 distinct perspectives.
public enum DiskViewMode: String, CaseIterable, Identifiable, Sendable {
    case folders
    case sunburst
    case flame
    case bubbles
    case mindMap
    case topSizes
    case ageMap
    case treemap
    case list

    public var id: String { rawValue }

    public var localizedName: String {
        switch self {
        case .folders: return "Folders"
        case .sunburst: return "Sunburst"
        case .flame: return "Flame"
        case .bubbles: return "Bubbles"
        case .mindMap: return "Mind Map"
        case .topSizes: return "Top Sizes"
        case .ageMap: return "Age Map"
        case .treemap: return "Treemap"
        case .list: return "List"
        }
    }

    public var subtitle: String {
        switch self {
        case .folders: return "Browse folder by folder, sized as you go"
        case .sunburst: return "Rings radiating out from the scan root"
        case .flame: return "Depth top to bottom, size left to right"
        case .bubbles: return "Nested bubbles, one per folder"
        case .mindMap: return "Branches from the root, sized by weight"
        case .topSizes: return "The biggest items, ranked"
        case .ageMap: return "Where your bytes sit on a timeline"
        case .treemap: return "Every file as a rectangle, sized by bytes"
        case .list: return "Detailed file and folder table"
        }
    }

    public var systemImage: String {
        switch self {
        case .folders: return "folder.fill"
        case .sunburst: return "sun.max.fill"
        case .flame: return "flame.fill"
        case .bubbles: return "circle.circle.fill"
        case .mindMap: return "point.3.connected.trianglepath.dotted"
        case .topSizes: return "chart.bar.xaxis"
        case .ageMap: return "calendar"
        case .treemap: return "rectangle.split.2x2.fill"
        case .list: return "list.bullet"
        }
    }
}

public enum TopSizesTab: String, CaseIterable, Identifiable, Sendable {
    case inThisFolder = "In this folder"
    case biggestFilesAnywhere = "Biggest files anywhere"
    case biggestFoldersAnywhere = "Biggest folders anywhere"

    public var id: String { rawValue }
}

public struct QuickWinItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let icon: String
    public let itemCount: Int
    public let bytes: Int64
    public let item: DiskItem?
}

public struct FileTypeBreakdownItem: Identifiable, Sendable {
    public var id: String { category.rawValue }
    public let category: FileCategory
    public let label: String
    public let bytes: Int64
    public let count: Int
    public let color: Color
}

@MainActor
@Observable
public final class DiskAnalyzerViewModel {
    private let logger = Logger(subsystem: "input.MacPulse", category: "DiskAnalyzerViewModel")
    private let scanner = DiskScanner()
    private let trashManager = TrashManager()

    public var isScanning = false
    public var currentScanningName = ""
    public var rootURL: URL?
    public var rootItem: DiskItem?
    public var pathTrail: [DiskItem] = []

    public var selectedItem: DiskItem?
    public var quickLookURL: URL?
    public var selectedCategory: FileCategory = .all
    public var searchQuery: String = ""
    public var viewMode: DiskViewMode = .folders
    public var coloringMode: ColoringMode = .byFolder
    public var depth: Int = 4
    public var topSizesTab: TopSizesTab = .inThisFolder
    public var scanDurationSeconds: Double = 0
    public var recentScans: [URL] = [FileManager.default.homeDirectoryForCurrentUser]
    public var stageNotificationMessage: String?
    public private(set) var scanErrorMessage: String?

    public private(set) var ageReport: DiskAgeReport?
    public private(set) var isBuildingAgeReport = false

    private var scanTask: Task<Void, Never>?
    private var ageTask: Task<Void, Never>?
    private var scanStartTime: Date?
    /// Bumped whenever a scan starts or is cancelled. A scan result whose
    /// generation no longer matches is stale and must not touch view state.
    private var scanGeneration = 0
    /// Bumped whenever an age report build starts, for the same reason.
    private var ageGeneration = 0

    public init() {}

    public var currentItem: DiskItem? {
        pathTrail.last ?? rootItem
    }

    public var displayedItems: [DiskItem] {
        guard let current = currentItem else { return [] }
        let baseItems: [DiskItem]
        if selectedCategory == .all {
            baseItems = current.children ?? []
        } else {
            baseItems = current.allDescendantFiles(matching: selectedCategory)
        }

        if searchQuery.isEmpty {
            return baseItems
        }

        return baseItems.filter { item in
            item.name.localizedCaseInsensitiveContains(searchQuery) ||
            item.url.path.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    public var biggestFilesAnywhere: [DiskItem] {
        guard let root = rootItem else { return [] }
        return Array(root.allDescendantFiles().prefix(50))
    }

    public var biggestFoldersAnywhere: [DiskItem] {
        guard let root = rootItem else { return [] }
        return Array(root.allDescendantFolders().prefix(50))
    }

    public var quickWins: [QuickWinItem] {
        guard let root = rootItem else { return [] }
        var wins: [QuickWinItem] = []
        let allFiles = root.allDescendantFiles()
        let allFolders = root.allDescendantFolders()

        // 1. Downloads
        if let downloads = allFolders.first(where: { $0.name.lowercased() == "downloads" }) {
            wins.append(QuickWinItem(
                id: "downloads",
                title: "Downloads",
                icon: "arrow.down.circle.fill",
                itemCount: downloads.children?.count ?? 0,
                bytes: downloads.size,
                item: downloads
            ))
        }

        // 2. Caches & logs
        let cacheFolders = allFolders.filter {
            let n = $0.name.lowercased()
            return n == "caches" || n == "logs" || n.hasPrefix(".cache")
        }
        let cacheBytes = cacheFolders.reduce(0) { $0 + $1.size }
        let cacheCount = cacheFolders.reduce(0) { $0 + ($1.children?.count ?? 0) }
        if cacheBytes > 0 {
            wins.append(QuickWinItem(
                id: "caches",
                title: "Caches & logs",
                icon: "clock.arrow.circlepath",
                itemCount: max(1, cacheCount),
                bytes: cacheBytes,
                item: cacheFolders.first
            ))
        }

        // 3. iOS Simulators
        let simFolders = allFolders.filter { $0.name.lowercased().contains("coresimulator") || $0.name.lowercased().contains("devices") }
        let simBytes = simFolders.reduce(0) { $0 + $1.size }
        if simBytes > 0 {
            wins.append(QuickWinItem(
                id: "simulators",
                title: "iOS Simulators",
                icon: "iphone",
                itemCount: max(1, simFolders.count),
                bytes: simBytes,
                item: simFolders.first
            ))
        }

        // 4. Large media (>100MB video/audio)
        let largeMedia = allFiles.filter { ($0.fileType == .video || $0.fileType == .audio) && $0.size > 100 * 1024 * 1024 }
        let mediaBytes = largeMedia.reduce(0) { $0 + $1.size }
        if !largeMedia.isEmpty {
            wins.append(QuickWinItem(
                id: "large_media",
                title: "Large media",
                icon: "film.fill",
                itemCount: largeMedia.count,
                bytes: mediaBytes,
                item: largeMedia.first
            ))
        }

        // 5. node_modules
        let nodeModules = allFolders.filter { $0.name == "node_modules" }
        let nmBytes = nodeModules.reduce(0) { $0 + $1.size }
        if nmBytes > 0 {
            wins.append(QuickWinItem(
                id: "node_modules",
                title: "node_modules",
                icon: "shippingbox.fill",
                itemCount: nodeModules.count,
                bytes: nmBytes,
                item: nodeModules.first
            ))
        }

        // 6. Build artifacts
        let buildDirs = allFolders.filter {
            let n = $0.name.lowercased()
            return n == ".build" || n == "target" || n == "dist" || n == "build"
        }
        let buildBytes = buildDirs.reduce(0) { $0 + $1.size }
        if buildBytes > 0 {
            wins.append(QuickWinItem(
                id: "build_artifacts",
                title: "Build artifacts",
                icon: "cube.box.fill",
                itemCount: buildDirs.count,
                bytes: buildBytes,
                item: buildDirs.first
            ))
        }

        // 7. Xcode DerivedData
        let xcodeDirs = allFolders.filter { $0.name == "DerivedData" || $0.name.contains("Archives") }
        let xcodeBytes = xcodeDirs.reduce(0) { $0 + $1.size }
        if xcodeBytes > 0 {
            wins.append(QuickWinItem(
                id: "xcode_derived",
                title: "Xcode DerivedData",
                icon: "hammer.fill",
                itemCount: xcodeDirs.count,
                bytes: xcodeBytes,
                item: xcodeDirs.first
            ))
        }

        return wins
    }

    public var fileTypesBreakdown: [FileTypeBreakdownItem] {
        guard let root = rootItem else { return [] }
        let files = root.allDescendantFiles()
        var counts: [FileCategory: (bytes: Int64, count: Int)] = [:]

        for file in files {
            let current = counts[file.fileType, default: (0, 0)]
            counts[file.fileType] = (current.bytes + file.size, current.count + 1)
        }

        let categories: [FileCategory] = [.video, .audio, .photo, .docs, .apps, .archives]
        return categories.compactMap { cat in
            let data = counts[cat, default: (0, 0)]
            guard data.bytes > 0 else { return nil }
            return FileTypeBreakdownItem(
                category: cat,
                label: labelForCategory(cat),
                bytes: data.bytes,
                count: data.count,
                color: DiskPalette.typeColor(for: cat)
            )
        }
    }

    private func labelForCategory(_ category: FileCategory) -> String {
        switch category {
        case .video: return "Video"
        case .audio: return "Audio"
        case .photo: return "Image"
        case .docs: return "Document"
        case .apps: return "Developer"
        case .archives: return "Archive"
        case .all: return "All"
        }
    }

    public var canNavigateUp: Bool {
        pathTrail.count > 1
    }

    public func selectFolderAndScan() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/")
        panel.message = "disk_analyzer_select_folder".localized
        panel.prompt = "disk_analyzer_scan".localized

        if panel.runModal() == .OK, let url = panel.url {
            startScan(for: url)
        }
    }

    public func startScan(for url: URL) {
        scanGeneration &+= 1
        let generation = scanGeneration
        scanTask?.cancel()
        ageTask?.cancel()
        isBuildingAgeReport = false
        ageReport = nil

        rootURL = url
        scanErrorMessage = nil
        isScanning = true
        currentScanningName = ""
        rootItem = nil
        pathTrail = []
        selectedItem = nil
        quickLookURL = nil
        scanStartTime = Date()

        if !recentScans.contains(url) {
            recentScans.insert(url, at: 0)
            if recentScans.count > 5 { recentScans.removeLast() }
        }

        scanTask = Task { [weak self] in
            guard let self else { return }
            do {
                let scannedRoot = try await self.scanner.scan(directoryURL: url) { [weak self] folderName in
                    Task { @MainActor in
                        guard let self, self.scanGeneration == generation else { return }
                        self.currentScanningName = folderName
                    }
                }

                // A newer scan (or a cancel) supersedes this result; drop it.
                guard self.scanGeneration == generation, !Task.isCancelled else { return }

                self.rootItem = scannedRoot
                self.pathTrail = [scannedRoot]
                self.selectedItem = scannedRoot
                self.isScanning = false
                if let start = self.scanStartTime {
                    self.scanDurationSeconds = Date().timeIntervalSince(start)
                }
                self.buildAgeReport(for: scannedRoot)
            } catch {
                guard self.scanGeneration == generation else { return }
                self.logger.error("Scan failed: \(error.localizedDescription)")
                self.scanErrorMessage = error.localizedDescription
                self.isScanning = false
            }
        }
    }

    public func cancelScan() {
        // Invalidate any in-flight scan so its partial result can't land.
        scanGeneration &+= 1
        scanTask?.cancel()
        scanTask = nil
        ageTask?.cancel()
        ageTask = nil
        isBuildingAgeReport = false
        isScanning = false
        currentScanningName = ""
    }

    func buildAgeReport(for root: DiskItem) {
        ageTask?.cancel()
        ageGeneration &+= 1
        let generation = ageGeneration
        isBuildingAgeReport = true
        ageTask = Task { [weak self] in
            let report = await Task.detached(priority: .utility) {
                DiskAgeAnalyzer().analyze(root: root)
            }.value
            // Cancelled or superseded: never reset or overwrite the live build.
            guard let self, self.ageGeneration == generation, !Task.isCancelled else { return }
            self.ageReport = report
            self.isBuildingAgeReport = false
        }
    }

    public func trashAllUntouched() {
        guard let report = ageReport, !report.bigAndUntouched.isEmpty else { return }
        Task {
            for item in report.bigAndUntouched {
                do {
                    _ = try await trashManager.trashItem(at: item.url)
                    removeItemFromTree(item: item)
                } catch {
                    self.logger.error("Failed to trash \(item.url.path): \(error.localizedDescription)")
                }
            }
            if let root = rootItem {
                buildAgeReport(for: root)
            }
        }
    }

    public func drillDown(into item: DiskItem) {
        guard item.isDirectory && !item.isPackage else { return }
        pathTrail.append(item)
        selectedItem = item
    }

    public func navigateUp() {
        guard pathTrail.count > 1 else { return }
        pathTrail.removeLast()
        selectedItem = pathTrail.last
    }

    public func navigateTo(item: DiskItem) {
        guard let index = pathTrail.firstIndex(where: { $0.url == item.url }) else { return }
        pathTrail = Array(pathTrail.prefix(through: index))
        selectedItem = item
    }

    public func toggleQuickLook(for item: DiskItem? = nil) {
        let target = item ?? selectedItem
        if let target {
            if quickLookURL == target.url {
                quickLookURL = nil
            } else {
                quickLookURL = target.url
            }
        }
    }

    public func showInFinder(item: DiskItem? = nil) {
        let target = item ?? selectedItem
        if let target {
            NSWorkspace.shared.activateFileViewerSelecting([target.url])
        }
    }

    public func copyPath(for item: DiskItem? = nil) {
        let target = item ?? currentItem
        if let target {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(target.url.path, forType: .string)
        }
    }

    public func moveToTrash(item: DiskItem? = nil) {
        guard let target = item ?? selectedItem else { return }
        Task {
            do {
                _ = try await trashManager.trashItem(at: target.url)
                removeItemFromTree(item: target)
                if selectedItem?.url == target.url {
                    selectedItem = nil
                }
            } catch {
                logger.error("Failed to trash \(target.url.path): \(error.localizedDescription)")
            }
        }
    }

    public func stageSelectedForCleanup() {
        guard let target = selectedItem ?? currentItem else { return }
        stageNotificationMessage = "Staged \(target.name) for cleanup"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.stageNotificationMessage = nil
        }
    }

    func removeItemFromTree(item: DiskItem) {
        guard let root = rootItem else { return }
        // The scan root is the anchor of the tree; it can't be removed from itself.
        guard root.url != item.url else { return }

        // Always resolve the item against the root-anchored tree, never against
        // `pathTrail.last` — an Age Map row can point anywhere in the tree, not
        // just under the folder the user happens to be browsing.
        rootItem = remove(item: item, from: root)
        rebuildPathTrail()
        dropFromAgeReport(item: item)
    }

    /// Re-anchors `pathTrail` onto the post-removal tree. If an ancestor was
    /// removed, the trail is truncated at that point instead of skipping a level.
    private func rebuildPathTrail() {
        guard let root = rootItem else {
            pathTrail = []
            return
        }

        var rebuilt: [DiskItem] = []
        for trailItem in pathTrail {
            guard let found = findItem(with: trailItem.url, in: root) else { break }
            rebuilt.append(found)
        }

        pathTrail = rebuilt.isEmpty ? [root] : rebuilt
    }

    private func dropFromAgeReport(item: DiskItem) {
        guard let report = ageReport,
              report.bigAndUntouched.contains(where: { $0.url == item.url }) else { return }
        ageReport = DiskAgeReport(
            slices: report.slices,
            months: report.months,
            bigAndUntouched: report.bigAndUntouched.filter { $0.url != item.url },
            totalBytes: report.totalBytes,
            datedFileCount: report.datedFileCount
        )
    }

    private func remove(item: DiskItem, from parent: DiskItem) -> DiskItem {
        guard var children = parent.children else { return parent }

        if let index = children.firstIndex(where: { $0.url == item.url }) {
            let removed = children.remove(at: index)
            let freedFiles = removed.isDirectory ? removed.fileCount : 1
            var updatedParent = parent
            updatedParent.children = children
            updatedParent.size = max(0, updatedParent.size - removed.size)
            updatedParent.fileCount = max(0, updatedParent.fileCount - freedFiles)
            return updatedParent
        }

        var updatedChildren: [DiskItem] = []
        var totalSize: Int64 = 0
        var totalFiles: Int = 0
        for child in children {
            let updatedChild = remove(item: item, from: child)
            updatedChildren.append(updatedChild)
            totalSize += updatedChild.size
            totalFiles += updatedChild.fileCount
        }

        var updatedParent = parent
        updatedParent.children = updatedChildren
        updatedParent.size = totalSize
        updatedParent.fileCount = totalFiles
        return updatedParent
    }

    private func findItem(with url: URL, in current: DiskItem?) -> DiskItem? {
        guard let current else { return nil }
        if current.url == url { return current }
        if let children = current.children {
            for child in children {
                if let match = findItem(with: url, in: child) {
                    return match
                }
            }
        }
        return nil
    }
}
