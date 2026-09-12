import Foundation
import OSLog
import Darwin

public actor DiskScanner {
    private let logger = Logger(subsystem: "input.MacPulse", category: "DiskScanner")

    private static let packageExtensions: Set<String> = [
        "app", "bundle", "framework", "plugin", "kext", "photoslibrary", "musiclibrary",
        "savedstate", "pkg", "dmg", "lproj", "workflow", "qlgenerator", "prefpane"
    ]

    private static let packageDirectoryNames: Set<String> = [
        "node_modules", "Pods", "DerivedData", ".build", "target", ".gradle",
        ".cargo", "vendor", ".venv", "venv", ".next", ".nuxt", ".svelte-kit", ".bundle"
    ]

    public init() {}

    /// Scans a directory and returns its hierarchical tree rooted at `directoryURL`.
    public func scan(
        directoryURL: URL,
        onProgress: @Sendable @escaping (String) -> Void
    ) async throws -> DiskItem {
        let rootURL = directoryURL.standardizedFileURL
        let fm = FileManager.default
        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .isPackageKey,
            .fileSizeKey,
            .totalFileAllocatedSizeKey,
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey,
            .contentModificationDateKey
        ]

        let rootNode = DirectoryNode(url: rootURL, name: rootURL.lastPathComponent, parentURL: nil)
        var directoryNodes: [URL: DirectoryNode] = [rootURL: rootNode]

        guard let enumerator = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            // Include hidden folders: macOS storage is concentrated in Library and dot-directories.
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return rootNode.toDiskItem()
        }

        var count = 0

        while let fileURL = enumerator.nextObject() as? URL {
            if Task.isCancelled { break }
            let standardURL = fileURL.standardizedFileURL

            if FileManager.shouldExclude(url: standardURL) {
                if (try? standardURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                    enumerator.skipDescendants()
                }
                continue
            }

            guard let values = try? standardURL.resourceValues(forKeys: Set(keys)) else { continue }

            // Skip dataless iCloud files to avoid triggering network downloads
            if let isUbiquitous = values.isUbiquitousItem, isUbiquitous {
                if values.ubiquitousItemDownloadingStatus == .notDownloaded {
                    if values.isDirectory == true {
                        enumerator.skipDescendants()
                    }
                    continue
                }
            }

            let isDir = values.isDirectory ?? false
            let lastComp = standardURL.lastPathComponent
            let ext = standardURL.pathExtension.lowercased()
            let isPackage = (values.isPackage ?? false) ||
                Self.packageExtensions.contains(ext) ||
                Self.packageDirectoryNames.contains(lastComp)

            if isDir && !isPackage {
                let parentURL = standardURL.deletingLastPathComponent().standardizedFileURL
                let parentNode = getOrCreateDirectoryNode(
                    url: parentURL,
                    rootURL: rootURL,
                    directoryNodes: &directoryNodes
                )
                let node = DirectoryNode(
                    url: standardURL,
                    name: lastComp,
                    parentURL: parentURL
                )
                directoryNodes[standardURL] = node
                parentNode.subdirectories[standardURL] = node
            } else if isDir && isPackage {
                enumerator.skipDescendants()
                let pkgSize = await calculatePackageSize(url: standardURL)
                let parentURL = standardURL.deletingLastPathComponent().standardizedFileURL
                let parentNode = getOrCreateDirectoryNode(
                    url: parentURL,
                    rootURL: rootURL,
                    directoryNodes: &directoryNodes
                )

                let item = DiskItem(
                    url: standardURL,
                    name: lastComp,
                    isDirectory: true,
                    isPackage: true,
                    size: pkgSize.size,
                    fileCount: pkgSize.fileCount,
                    fileType: Self.packageDirectoryNames.contains(lastComp) ? .archives : .apps,
                    parentURL: parentURL,
                    modifiedAt: values.contentModificationDate
                )
                parentNode.fileChildren.append(item)
            } else {
                let allocatedSize = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
                let parentURL = standardURL.deletingLastPathComponent().standardizedFileURL
                let parentNode = getOrCreateDirectoryNode(
                    url: parentURL,
                    rootURL: rootURL,
                    directoryNodes: &directoryNodes
                )

                let item = DiskItem(
                    url: standardURL,
                    name: lastComp,
                    isDirectory: false,
                    isPackage: false,
                    size: allocatedSize,
                    fileCount: 1,
                    fileType: FileCategory.from(url: standardURL),
                    parentURL: parentURL,
                    modifiedAt: values.contentModificationDate
                )
                parentNode.fileChildren.append(item)
            }

            count += 1
            if count % 1_000 == 0 {
                // Report the containing folder, not an opaque file identifier;
                // this keeps progress useful and avoids excessive MainActor hops.
                onProgress(standardURL.deletingLastPathComponent().lastPathComponent)
                await Task.yield()
            }
        }

        return rootNode.toDiskItem()
    }

    private func getOrCreateDirectoryNode(
        url: URL,
        rootURL: URL,
        directoryNodes: inout [URL: DirectoryNode]
    ) -> DirectoryNode {
        if let existing = directoryNodes[url] {
            return existing
        }

        let parentURL = url.deletingLastPathComponent().standardizedFileURL
        let parentNode: DirectoryNode?
        if url != rootURL && url.path.hasPrefix(rootURL.path) {
            parentNode = getOrCreateDirectoryNode(
                url: parentURL,
                rootURL: rootURL,
                directoryNodes: &directoryNodes
            )
        } else {
            parentNode = nil
        }

        let node = DirectoryNode(
            url: url,
            name: url.lastPathComponent,
            parentURL: parentNode?.url
        )
        directoryNodes[url] = node
        parentNode?.subdirectories[url] = node
        return node
    }

    private func calculatePackageSize(url: URL) async -> (size: Int64, fileCount: Int) {
        let path = url.path
        let cPath = path.withCString { strdup($0) }
        guard let cPath else { return (0, 1) }
        defer { free(cPath) }

        var paths: [UnsafeMutablePointer<CChar>?] = [cPath, nil]
        guard let tree = fts_open(&paths, FTS_PHYSICAL | FTS_NOCHDIR | FTS_XDEV, nil) else {
            let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey])
            let s = Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
            return (s, 1)
        }
        defer { fts_close(tree) }

        var totalSize: Int64 = 0
        var totalFiles = 0

        while let entry = fts_read(tree) {
            if totalFiles.isMultiple(of: 512), Task.isCancelled { break }
            let info = Int32(entry.pointee.fts_info)
            if info == FTS_F || info == FTS_NSOK {
                totalFiles += 1
                if let stat = entry.pointee.fts_statp {
                    totalSize += Int64(stat.pointee.st_blocks) * 512
                }
            }

            // Package directories can contain hundreds of thousands of files.
            // Yield periodically so cancellation and UI work are serviced
            // promptly instead of monopolising the cooperative executor.
            if totalFiles.isMultiple(of: 4_096) {
                await Task.yield()
            }
        }

        return (totalSize, max(1, totalFiles))
    }
}

private final class DirectoryNode: @unchecked Sendable {
    let url: URL
    let name: String
    let parentURL: URL?
    var fileChildren: [DiskItem] = []
    var subdirectories: [URL: DirectoryNode] = [:]

    init(url: URL, name: String, parentURL: URL?) {
        self.url = url
        self.name = name
        self.parentURL = parentURL
    }

    func toDiskItem() -> DiskItem {
        var allChildren: [DiskItem] = []
        var totalSize: Int64 = 0
        var totalFiles: Int = 0

        for file in fileChildren {
            totalSize += file.size
            totalFiles += file.fileCount
            allChildren.append(file)
        }

        for (_, subNode) in subdirectories {
            let subItem = subNode.toDiskItem()
            totalSize += subItem.size
            totalFiles += subItem.fileCount
            allChildren.append(subItem)
        }

        allChildren.sort { $0.size > $1.size }
        let newestChild = allChildren.compactMap(\.modifiedAt).max()

        return DiskItem(
            url: url,
            name: name.isEmpty ? "/" : name,
            isDirectory: true,
            isPackage: false,
            size: totalSize,
            fileCount: totalFiles,
            children: allChildren,
            fileType: .all,
            parentURL: parentURL,
            modifiedAt: newestChild
        )
    }
}
