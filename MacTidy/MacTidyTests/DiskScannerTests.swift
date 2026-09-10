import XCTest
@testable import MacTidy

final class DiskScannerTests: XCTestCase {
    private var tempDir: URL!
    
    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    func testDiskScanner_scansDirectoryTreeHierarchically() async throws {
        // Create subdirectories
        let docsDir = tempDir.appendingPathComponent("Documents", isDirectory: true)
        let subDocsDir = docsDir.appendingPathComponent("Work", isDirectory: true)
        let mediaDir = tempDir.appendingPathComponent("Media", isDirectory: true)
        
        try FileManager.default.createDirectory(at: subDocsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)
        
        // Create dummy files
        let file1 = tempDir.appendingPathComponent("root_file.txt")
        try "Hello World".write(to: file1, atomically: true, encoding: .utf8)
        
        let file2 = docsDir.appendingPathComponent("doc1.pdf")
        try Data(repeating: 0x41, count: 10000).write(to: file2)
        
        let file3 = subDocsDir.appendingPathComponent("work_notes.txt")
        try Data(repeating: 0x42, count: 25000).write(to: file3)
        
        let file4 = mediaDir.appendingPathComponent("video.mp4")
        try Data(repeating: 0x43, count: 50000).write(to: file4)
        
        let scanner = DiskScanner()
        let root = try await scanner.scan(directoryURL: tempDir) { _ in }
        
        XCTAssertEqual(root.url.standardizedFileURL, tempDir.standardizedFileURL)
        XCTAssertTrue(root.isDirectory)
        XCTAssertFalse(root.isPackage)
        XCTAssertGreaterThan(root.size, 0)
        XCTAssertEqual(root.fileCount, 4)
        
        let children = root.children ?? []
        XCTAssertEqual(children.count, 3) // Media, Documents, root_file.txt
        
        // Items sorted by size descending: Media (50KB) > Documents (35KB) > root_file.txt
        XCTAssertEqual(children[0].name, "Media")
        XCTAssertEqual(children[0].fileType, .all)
        XCTAssertEqual(children[0].fileCount, 1)
        
        XCTAssertEqual(children[1].name, "Documents")
        XCTAssertEqual(children[1].fileCount, 2)
        
        // Check nested drill-down under Documents
        let docChildren = children[1].children ?? []
        XCTAssertEqual(docChildren.count, 2) // Work, doc1.pdf
    }
    
    func testDiskScanner_recognizesPackages() async throws {
        let appBundle = tempDir.appendingPathComponent("SampleApp.app", isDirectory: true)
        let contentsDir = appBundle.appendingPathComponent("Contents", isDirectory: true)
        let macosDir = contentsDir.appendingPathComponent("MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: macosDir, withIntermediateDirectories: true)
        
        let binary = macosDir.appendingPathComponent("SampleBinary")
        try Data(repeating: 0xAA, count: 30000).write(to: binary)
        
        let scanner = DiskScanner()
        let root = try await scanner.scan(directoryURL: tempDir) { _ in }
        
        let children = root.children ?? []
        XCTAssertEqual(children.count, 1)
        
        let appItem = children[0]
        XCTAssertEqual(appItem.name, "SampleApp.app")
        XCTAssertTrue(appItem.isDirectory)
        XCTAssertTrue(appItem.isPackage)
        XCTAssertEqual(appItem.fileType, .apps)
        XCTAssertGreaterThan(appItem.size, 0)
        XCTAssertNil(appItem.children) // Package internal folders are not expanded as child folders
    }
    
    func testFileCategory_classification() {
        XCTAssertEqual(FileCategory.from(url: URL(fileURLWithPath: "/test/movie.mp4")), .video)
        XCTAssertEqual(FileCategory.from(url: URL(fileURLWithPath: "/test/track.mp3")), .audio)
        XCTAssertEqual(FileCategory.from(url: URL(fileURLWithPath: "/test/photo.jpg")), .photo)
        XCTAssertEqual(FileCategory.from(url: URL(fileURLWithPath: "/test/Test.app")), .apps)
        XCTAssertEqual(FileCategory.from(url: URL(fileURLWithPath: "/test/doc.pdf")), .docs)
        XCTAssertEqual(FileCategory.from(url: URL(fileURLWithPath: "/test/archive.zip")), .archives)
        XCTAssertEqual(FileCategory.from(url: URL(fileURLWithPath: "/test/unknown.xyz")), .all)
    }
    
    @MainActor
    func testDiskAnalyzerViewModel_treeNavigation() async throws {
        let docsDir = tempDir.appendingPathComponent("Docs", isDirectory: true)
        try FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)
        let file = docsDir.appendingPathComponent("test.txt")
        try "test content".write(to: file, atomically: true, encoding: .utf8)
        
        let viewModel = DiskAnalyzerViewModel()
        viewModel.startScan(for: tempDir)
        
        // Wait for scan to finish
        var attempts = 0
        while viewModel.isScanning && attempts < 50 {
            try await Task.sleep(nanoseconds: 50_000_000)
            attempts += 1
        }
        
        XCTAssertFalse(viewModel.isScanning)
        XCTAssertNotNil(viewModel.rootItem)
        XCTAssertEqual(viewModel.pathTrail.count, 1)
        XCTAssertFalse(viewModel.canNavigateUp)
        
        let displayed = viewModel.displayedItems
        XCTAssertEqual(displayed.count, 1)
        XCTAssertEqual(displayed[0].name, "Docs")
        
        // Drill down into Docs
        viewModel.drillDown(into: displayed[0])
        XCTAssertTrue(viewModel.canNavigateUp)
        XCTAssertEqual(viewModel.pathTrail.count, 2)
        XCTAssertEqual(viewModel.currentItem?.name, "Docs")
        XCTAssertEqual(viewModel.displayedItems.count, 1)
        XCTAssertEqual(viewModel.displayedItems[0].name, "test.txt")
        
        // Navigate up
        viewModel.navigateUp()
        XCTAssertFalse(viewModel.canNavigateUp)
        XCTAssertEqual(viewModel.pathTrail.count, 1)
        XCTAssertEqual(viewModel.currentItem?.name, tempDir.lastPathComponent)
    }
    
    @MainActor
    func testDiskAnalyzerViewModel_categoryFiltering() async throws {
        let mediaDir = tempDir.appendingPathComponent("Media", isDirectory: true)
        try FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)
        let videoFile = mediaDir.appendingPathComponent("clip.mov")
        let docFile = mediaDir.appendingPathComponent("readme.pdf")
        try "video bytes".write(to: videoFile, atomically: true, encoding: .utf8)
        try "doc bytes".write(to: docFile, atomically: true, encoding: .utf8)
        
        let viewModel = DiskAnalyzerViewModel()
        viewModel.startScan(for: tempDir)
        
        var attempts = 0
        while viewModel.isScanning && attempts < 50 {
            try await Task.sleep(nanoseconds: 50_000_000)
            attempts += 1
        }
        
        // When .all is selected: shows Media folder
        viewModel.selectedCategory = .all
        XCTAssertEqual(viewModel.displayedItems.count, 1)
        XCTAssertEqual(viewModel.displayedItems[0].name, "Media")
        
        // When .video is selected: recursively finds clip.mov
        viewModel.selectedCategory = .video
        XCTAssertEqual(viewModel.displayedItems.count, 1)
        XCTAssertEqual(viewModel.displayedItems[0].name, "clip.mov")
        XCTAssertEqual(viewModel.displayedItems[0].fileType, .video)
        
        // When .docs is selected: recursively finds readme.pdf
        viewModel.selectedCategory = .docs
        XCTAssertEqual(viewModel.displayedItems.count, 1)
        XCTAssertEqual(viewModel.displayedItems[0].name, "readme.pdf")
        XCTAssertEqual(viewModel.displayedItems[0].fileType, .docs)
        
        // When .photo is selected: returns empty
        viewModel.selectedCategory = .photo
        XCTAssertEqual(viewModel.displayedItems.count, 0)
    }

    @MainActor
    func testVisualModes_and_breakdowns() async throws {
        XCTAssertEqual(DiskViewMode.allCases.count, 9)
        XCTAssertEqual(ColoringMode.allCases.count, 3)

        let downloads = tempDir.appendingPathComponent("Downloads", isDirectory: true)
        let buildDir = tempDir.appendingPathComponent("build", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)

        let sampleMovie = downloads.appendingPathComponent("movie.mp4")
        let sampleZip = downloads.appendingPathComponent("archive.zip")
        let artifact = buildDir.appendingPathComponent("output.bin")
        try Data(repeating: 0x1, count: 1024).write(to: sampleMovie)
        try Data(repeating: 0x2, count: 2048).write(to: sampleZip)
        try Data(repeating: 0x3, count: 512).write(to: artifact)

        let viewModel = DiskAnalyzerViewModel()
        viewModel.startScan(for: tempDir)

        var attempts = 0
        while viewModel.isScanning && attempts < 50 {
            try await Task.sleep(nanoseconds: 50_000_000)
            attempts += 1
        }

        XCTAssertEqual(viewModel.viewMode, .folders)
        XCTAssertEqual(viewModel.coloringMode, .byFolder)
        XCTAssertEqual(viewModel.depth, 4)

        // Quick wins should detect Downloads and Build artifacts
        let wins = viewModel.quickWins
        XCTAssertTrue(wins.contains(where: { $0.id == "downloads" }))
        XCTAssertTrue(wins.contains(where: { $0.id == "build_artifacts" }))

        // File types breakdown should register video and archive
        let fileTypes = viewModel.fileTypesBreakdown
        XCTAssertTrue(fileTypes.contains(where: { $0.category == .video }))
        XCTAssertTrue(fileTypes.contains(where: { $0.category == .archives }))

        // Biggest files anywhere should find the files
        XCTAssertFalse(viewModel.biggestFilesAnywhere.isEmpty)
        XCTAssertFalse(viewModel.biggestFoldersAnywhere.isEmpty)
    }

    // MARK: - Root-anchored removal (Age Map trash)

    @MainActor
    func testRemoveItemFromTree_usesRootAnchor_notPathTrailLast() throws {
        let rootURL = URL(fileURLWithPath: "/scan/root")
        let fileA1 = DiskItem(url: rootURL.appendingPathComponent("A/a1.bin"), name: "a1.bin", isDirectory: false, size: 120, fileCount: 1, fileType: .all)
        let fileA2 = DiskItem(url: rootURL.appendingPathComponent("A/a2.bin"), name: "a2.bin", isDirectory: false, size: 80, fileCount: 1, fileType: .all)
        let folderA = DiskItem(url: rootURL.appendingPathComponent("A"), name: "A", isDirectory: true, size: 200, fileCount: 2, children: [fileA1, fileA2], fileType: .all)
        let fileB = DiskItem(url: rootURL.appendingPathComponent("B/b.bin"), name: "b.bin", isDirectory: false, size: 100, fileCount: 1, fileType: .all)
        let folderB = DiskItem(url: rootURL.appendingPathComponent("B"), name: "B", isDirectory: true, size: 100, fileCount: 1, children: [fileB], fileType: .all)
        let root = DiskItem(url: rootURL, name: "root", isDirectory: true, size: 300, fileCount: 3, children: [folderA, folderB], fileType: .all)

        let viewModel = DiskAnalyzerViewModel()
        viewModel.rootItem = root
        viewModel.pathTrail = [root]
        // The user is browsing B; the removed item lives under A. A pathTrail-last
        // implementation would target B and corrupt its totals.
        viewModel.drillDown(into: folderB)
        XCTAssertEqual(viewModel.pathTrail.count, 2)

        viewModel.removeItemFromTree(item: fileA2)

        let newRoot = try XCTUnwrap(viewModel.rootItem)
        XCTAssertEqual(newRoot.size, 220)
        XCTAssertEqual(newRoot.fileCount, 2)

        let newA = try XCTUnwrap(newRoot.children?.first { $0.name == "A" })
        XCTAssertEqual(newA.children?.count, 1)
        XCTAssertEqual(newA.children?.first?.name, "a1.bin")
        XCTAssertEqual(newA.size, 120)
        XCTAssertEqual(newA.fileCount, 1)

        // B is untouched.
        let newB = try XCTUnwrap(newRoot.children?.first { $0.name == "B" })
        XCTAssertEqual(newB.size, 100)
        XCTAssertEqual(newB.fileCount, 1)
        XCTAssertEqual(newB.children?.count, 1)

        // Path trail survives and stays anchored to the rebuilt tree.
        XCTAssertEqual(viewModel.pathTrail.count, 2)
        XCTAssertEqual(viewModel.pathTrail.last?.name, "B")
        XCTAssertEqual(viewModel.currentItem?.name, "B")
    }

    @MainActor
    func testRemoveItemFromTree_truncatesTrailWhenAncestorRemoved() throws {
        let rootURL = URL(fileURLWithPath: "/scan/root")
        let nested = DiskItem(url: rootURL.appendingPathComponent("A/deep/x.bin"), name: "x.bin", isDirectory: false, size: 10, fileCount: 1, fileType: .all)
        let deep = DiskItem(url: rootURL.appendingPathComponent("A/deep"), name: "deep", isDirectory: true, size: 10, fileCount: 1, children: [nested], fileType: .all)
        let folderA = DiskItem(url: rootURL.appendingPathComponent("A"), name: "A", isDirectory: true, size: 10, fileCount: 1, children: [deep], fileType: .all)
        let root = DiskItem(url: rootURL, name: "root", isDirectory: true, size: 10, fileCount: 1, children: [folderA], fileType: .all)

        let viewModel = DiskAnalyzerViewModel()
        viewModel.rootItem = root
        viewModel.pathTrail = [root]
        viewModel.drillDown(into: folderA)
        viewModel.drillDown(into: deep)
        XCTAssertEqual(viewModel.pathTrail.map(\.name), ["root", "A", "deep"])

        // Removing an ancestor of the current trail must not leave a hole.
        viewModel.removeItemFromTree(item: folderA)

        XCTAssertEqual(viewModel.pathTrail.count, 1)
        XCTAssertEqual(viewModel.pathTrail.first?.name, "root")
    }

    // MARK: - Stale scan results

    @MainActor
    func testStaleScanResult_doesNotOverwriteNewerScan() async throws {
        let dirA = tempDir.appendingPathComponent("A", isDirectory: true)
        let dirB = tempDir.appendingPathComponent("B", isDirectory: true)
        try FileManager.default.createDirectory(at: dirA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dirB, withIntermediateDirectories: true)
        try "a".write(to: dirA.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "b".write(to: dirB.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)

        let viewModel = DiskAnalyzerViewModel()
        viewModel.startScan(for: dirA)
        // Supersede A before its result can land.
        viewModel.startScan(for: dirB)

        var attempts = 0
        while (viewModel.isScanning || viewModel.isBuildingAgeReport) && attempts < 200 {
            try await Task.sleep(nanoseconds: 20_000_000)
            attempts += 1
        }

        XCTAssertFalse(viewModel.isScanning)
        XCTAssertFalse(viewModel.isBuildingAgeReport)
        XCTAssertEqual(viewModel.rootItem?.url.standardizedFileURL, dirB.standardizedFileURL)
        XCTAssertEqual(viewModel.rootItem?.children?.first?.name, "b.txt")
    }

    // MARK: - Age-report build flag

    @MainActor
    func testIsBuildingAgeReport_resetsOnCancelAndOnNewScan() {
        let viewModel = DiskAnalyzerViewModel()
        let root = DiskItem(url: tempDir, name: "root", isDirectory: true, size: 0, children: [], fileType: .all)
        viewModel.rootItem = root

        viewModel.buildAgeReport(for: root)
        XCTAssertTrue(viewModel.isBuildingAgeReport)

        viewModel.cancelScan()
        XCTAssertFalse(viewModel.isBuildingAgeReport)

        viewModel.buildAgeReport(for: root)
        XCTAssertTrue(viewModel.isBuildingAgeReport)

        viewModel.startScan(for: tempDir)
        XCTAssertFalse(viewModel.isBuildingAgeReport)
    }
}
