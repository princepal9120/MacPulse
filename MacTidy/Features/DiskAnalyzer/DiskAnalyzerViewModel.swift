import Foundation
import SwiftUI
import Observation
import OSLog

/// How the scan result is drawn. One scan, several readings of it.
public enum DiskViewMode: String, CaseIterable, Identifiable, Sendable {
    case list
    case treemap
    case sunburst
    case ageMap

    public var id: String { rawValue }

    public var localizedName: String {
        switch self {
        case .list: return "disk_view_mode_list".localized
        case .treemap: return "disk_view_mode_treemap".localized
        case .sunburst: return "disk_view_mode_sunburst".localized
        case .ageMap: return "disk_view_mode_age_map".localized
        }
    }

    public var systemImage: String {
        switch self {
        case .list: return "list.bullet"
        case .treemap: return "square.grid.2x2"
        case .sunburst: return "chart.pie"
        case .ageMap: return "calendar"
        }
    }
}

@MainActor
@Observable
public final class DiskAnalyzerViewModel {
    private let logger = Logger(subsystem: "input.MacTidy", category: "DiskAnalyzerViewModel")
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
    public var viewMode: DiskViewMode = .list
    public private(set) var ageReport: DiskAgeReport?
    public private(set) var isBuildingAgeReport = false

    private var scanTask: Task<Void, Never>?
    private var ageTask: Task<Void, Never>?
    
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
        scanTask?.cancel()
        
        rootURL = url
        isScanning = true
        currentScanningName = ""
        rootItem = nil
        pathTrail = []
        selectedItem = nil
        quickLookURL = nil
        ageTask?.cancel()
        ageReport = nil
        
        scanTask = Task {
            do {
                let scannedRoot = try await scanner.scan(directoryURL: url) { [weak self] folderName in
                    guard let self else { return }
                    Task { @MainActor in
                        self.currentScanningName = folderName
                    }
                }
                
                self.rootItem = scannedRoot
                self.pathTrail = [scannedRoot]
                self.isScanning = false
                self.buildAgeReport(for: scannedRoot)
            } catch {
                self.logger.error("Scan failed: \(error.localizedDescription)")
                self.isScanning = false
            }
        }
    }
    
    /// The walk is O(files), so it runs off the main actor once a scan lands.
    private func buildAgeReport(for root: DiskItem) {
        ageTask?.cancel()
        isBuildingAgeReport = true
        ageTask = Task {
            let report = await Task.detached(priority: .utility) {
                DiskAgeAnalyzer().analyze(root: root)
            }.value
            guard !Task.isCancelled else { return }
            self.ageReport = report
            self.isBuildingAgeReport = false
        }
    }

    /// Trashes every big-and-untouched file in one pass, then rebuilds the report
    /// from whatever survived.
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
        selectedItem = nil
    }
    
    public func navigateUp() {
        guard pathTrail.count > 1 else { return }
        pathTrail.removeLast()
        selectedItem = nil
    }
    
    public func navigateTo(item: DiskItem) {
        guard let index = pathTrail.firstIndex(where: { $0.url == item.url }) else { return }
        pathTrail = Array(pathTrail.prefix(through: index))
        selectedItem = nil
    }
    
    public func toggleQuickLook(for item: DiskItem? = nil) {
        let target = item ?? selectedItem
        if let target {
            if quickLookURL == target.url {
                quickLookURL = nil
            } else {
                quickLookURL = target.url
            }
        } else {
            quickLookURL = nil
        }
    }
    
    public func moveToTrash(item: DiskItem) {
        Task {
            do {
                _ = try await trashManager.trashItem(at: item.url)
                
                // Remove item from currentItem's children in memory
                removeItemFromTree(item: item)
                dropFromAgeReport(item: item)
            } catch {
                self.logger.error("Failed to move item to trash: \(error.localizedDescription)")
            }
        }
    }
    
    public func showInFinder(item: DiskItem) {
        NSWorkspace.shared.selectFile(item.url.path, inFileViewerRootedAtPath: "")
    }
    
    private func dropFromAgeReport(item: DiskItem) {
        guard let report = ageReport, report.bigAndUntouched.contains(where: { $0.url == item.url }) else { return }
        ageReport = DiskAgeReport(
            slices: report.slices,
            months: report.months,
            bigAndUntouched: report.bigAndUntouched.filter { $0.url != item.url },
            totalBytes: report.totalBytes,
            datedFileCount: report.datedFileCount
        )
    }

    private func removeItemFromTree(item: DiskItem) {
        guard var curr = pathTrail.last else { return }
        let freedSize = item.size
        let freedFiles = item.isDirectory ? item.fileCount : 1
        
        curr.children?.removeAll { $0.url == item.url }
        curr.size = max(0, curr.size - freedSize)
        curr.fileCount = max(0, curr.fileCount - freedFiles)
        pathTrail[pathTrail.count - 1] = curr
        
        // Propagate size reduction up the trail
        for i in (0..<(pathTrail.count - 1)).reversed() {
            var ancestor = pathTrail[i]
            ancestor.size = max(0, ancestor.size - freedSize)
            ancestor.fileCount = max(0, ancestor.fileCount - freedFiles)
            if let childIndex = ancestor.children?.firstIndex(where: { $0.url == pathTrail[i + 1].url }) {
                ancestor.children?[childIndex] = pathTrail[i + 1]
            }
            pathTrail[i] = ancestor
        }
        
        if let first = pathTrail.first {
            rootItem = first
        }
        
        if selectedItem?.url == item.url {
            selectedItem = nil
        }
        if quickLookURL == item.url {
            quickLookURL = nil
        }
    }
}

