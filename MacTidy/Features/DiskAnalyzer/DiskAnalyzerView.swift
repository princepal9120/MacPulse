import SwiftUI
import QuickLook

public struct DiskAnalyzerView: View {
    let settings: AppSettings
    @State private var viewModel = DiskAnalyzerViewModel()

    public init(settings: AppSettings) {
        self.settings = settings
    }

    public var body: some View {
        HStack(spacing: 0) {
            // 1. Left Sidebar
            DiskAnalyzerSidebarView(viewModel: viewModel)

            Divider()

            // 2. Center Stage Canvas
            VStack(spacing: 0) {
                topHeaderControls
                Divider()

                if viewModel.isScanning {
                    scanningView
                } else if let error = viewModel.scanErrorMessage {
                    scanErrorView(error)
                } else if viewModel.currentItem == nil {
                    initialPromptView
                } else {
                    modeContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // 3. Right Inspector Panel
            DiskAnalyzerInspectorView(viewModel: viewModel)
        }
        .quickLookPreview($viewModel.quickLookURL)
        .task {
            if viewModel.rootItem == nil && !viewModel.isScanning {
                viewModel.startScan(for: FileManager.default.homeDirectoryForCurrentUser)
            }
        }
    }

    // MARK: - Top Header Controls

    private var topHeaderControls: some View {
        VStack(spacing: 8) {
            // Row 1: Path Breadcrumbs, Mode Switcher, Search
            HStack(spacing: 12) {
                // Navigation / Breadcrumbs
                if viewModel.canNavigateUp {
                    Button(action: {
                        viewModel.navigateUp()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .semibold))
                            Text(viewModel.currentItem?.name ?? "Back")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }

                // Folder title & statistics
                if let current = viewModel.currentItem {
                    HStack(spacing: 6) {
                        Text(current.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Text(FileManager.formatSize(current.size))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.secondary)
                        Text("·")
                            .foregroundStyle(Color.secondary.opacity(0.5))
                        Text("\(current.fileCount.formatted()) files")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                        Text("·")
                            .foregroundStyle(Color.secondary.opacity(0.5))
                        Text("\(current.folderCount.formatted()) folders")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                    }
                }

                Spacer()

                // Search box
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                    TextField("Filter by name...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .frame(width: 140)
                    if !viewModel.searchQuery.isEmpty {
                        Button(action: { viewModel.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
            }

            // Row 2: Visual Mode Picker, Subtitle, and Controls
            HStack(spacing: 12) {
                // View Mode Icons Picker
                HStack(spacing: 3) {
                    ForEach(DiskViewMode.allCases) { mode in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.viewMode = mode
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: mode.systemImage)
                                    .font(.system(size: 12))
                                if viewModel.viewMode == mode {
                                    Text(mode.localizedName)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                }
                            }
                            .padding(.horizontal, viewModel.viewMode == mode ? 8 : 6)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(viewModel.viewMode == mode ? Color.primary.opacity(0.88) : Color.clear)
                            )
                            .foregroundStyle(viewModel.viewMode == mode ? Color.white : Color.primary.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .help(mode.localizedName)
                    }
                }
                .padding(3)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))

                // Subtitle explanation
                Text(viewModel.viewMode.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)

                Spacer()

                // Depth slider for hierarchical charts
                if [.sunburst, .flame, .treemap].contains(viewModel.viewMode) {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.secondary)
                        Slider(value: Binding(
                            get: { Double(viewModel.depth) },
                            set: { viewModel.depth = Int($0) }
                        ), in: 1...7, step: 1)
                        .frame(width: 70)
                        Text("\(viewModel.depth)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .frame(width: 14)
                    }
                }

                // Coloring Mode picker
                HStack(spacing: 4) {
                    ForEach(ColoringMode.allCases) { mode in
                        Button(action: {
                            viewModel.coloringMode = mode
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 10))
                                Text(mode.localizedName)
                                    .font(.system(size: 10, weight: viewModel.coloringMode == mode ? .semibold : .regular))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(viewModel.coloringMode == mode ? Color.primary.opacity(0.10) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Center Content by Mode

    @ViewBuilder
    private var modeContent: some View {
        switch viewModel.viewMode {
        case .folders:
            DiskFoldersGridView(
                items: viewModel.displayedItems,
                selectedItem: viewModel.selectedItem,
                coloringMode: viewModel.coloringMode,
                onSelect: { viewModel.selectedItem = $0 },
                onOpen: { drillOrSelect($0) }
            )

        case .sunburst:
            if let current = viewModel.currentItem {
                DiskSunburstView(
                    root: current,
                    maxDepth: viewModel.depth,
                    selectedItem: viewModel.selectedItem,
                    coloringMode: viewModel.coloringMode,
                    onSelect: { viewModel.selectedItem = $0 },
                    onOpen: { drillOrSelect($0) }
                )
            }

        case .flame:
            if let current = viewModel.currentItem {
                DiskFlameView(
                    root: current,
                    maxDepth: viewModel.depth,
                    selectedItem: viewModel.selectedItem,
                    coloringMode: viewModel.coloringMode,
                    onSelect: { viewModel.selectedItem = $0 },
                    onOpen: { drillOrSelect($0) }
                )
            }

        case .bubbles:
            if let current = viewModel.currentItem {
                DiskBubblesView(
                    root: current,
                    selectedItem: viewModel.selectedItem,
                    coloringMode: viewModel.coloringMode,
                    onSelect: { viewModel.selectedItem = $0 },
                    onOpen: { drillOrSelect($0) }
                )
            }

        case .mindMap:
            if let current = viewModel.currentItem {
                DiskMindMapView(
                    root: current,
                    selectedItem: viewModel.selectedItem,
                    coloringMode: viewModel.coloringMode,
                    onSelect: { viewModel.selectedItem = $0 },
                    onOpen: { drillOrSelect($0) }
                )
            }

        case .topSizes:
            DiskTopSizesView(
                currentTab: $viewModel.topSizesTab,
                currentFolderItems: viewModel.displayedItems,
                biggestFiles: viewModel.biggestFilesAnywhere,
                biggestFolders: viewModel.biggestFoldersAnywhere,
                selectedItem: viewModel.selectedItem,
                coloringMode: viewModel.coloringMode,
                onSelect: { viewModel.selectedItem = $0 },
                onOpen: { drillOrSelect($0) }
            )

        case .ageMap:
            if viewModel.isBuildingAgeReport {
                scanningView
            } else {
                DiskAgeMapView(
                    report: viewModel.ageReport ?? DiskAgeReport(slices: [], months: [], bigAndUntouched: [], totalBytes: 0, datedFileCount: 0),
                    selectedItem: viewModel.selectedItem,
                    onSelect: { viewModel.selectedItem = $0 },
                    onQuickLook: { viewModel.toggleQuickLook(for: $0) },
                    onShowInFinder: { viewModel.showInFinder(item: $0) },
                    onTrash: { viewModel.moveToTrash(item: $0) },
                    onTrashAllUntouched: { viewModel.trashAllUntouched() }
                )
            }

        case .treemap:
            DiskTreemapView(
                items: viewModel.displayedItems,
                maxDepth: viewModel.depth,
                selectedItem: viewModel.selectedItem,
                coloringMode: viewModel.coloringMode,
                onSelect: { viewModel.selectedItem = $0 },
                onOpen: { drillOrSelect($0) }
            )

        case .list:
            classicListView
        }
    }

    private func drillOrSelect(_ item: DiskItem) {
        if item.isDirectory && !item.isPackage {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.drillDown(into: item)
            }
        } else {
            viewModel.selectedItem = item
        }
    }

    // MARK: - Classic List View

    private var classicListView: some View {
        Table(viewModel.displayedItems, selection: Binding(
            get: { viewModel.selectedItem?.id },
            set: { id in viewModel.selectedItem = viewModel.displayedItems.first { $0.id == id } }
        )) {
            TableColumn("Name") { item in
                HStack(spacing: 6) {
                    Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                        .foregroundStyle(DiskPalette.color(for: item, mode: viewModel.coloringMode))
                    Text(item.name)
                }
            }
            TableColumn("Size") { item in
                Text(FileManager.formatSize(item.size))
                    .font(.system(.body, design: .monospaced))
            }
            TableColumn("Items") { item in
                Text(item.isDirectory ? "\(item.fileCount) items" : "-")
                    .foregroundStyle(Color.secondary)
            }
        }
    }

    // MARK: - Scanning & Empty States

    private var scanningView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Scanning disk space...")
                .font(.headline)
            if !viewModel.currentScanningName.isEmpty {
                Text(viewModel.currentScanningName)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Button("Cancel") {
                viewModel.cancelScan()
            }
            .buttonStyle(.bordered)
            Spacer()
        }
    }

    private func scanErrorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(.orange)
            Text("Couldn’t scan this location")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            HStack {
                Button("Choose Folder…") { viewModel.selectFolderAndScan() }
                    .buttonStyle(.borderedProminent)
                Button("Retry") {
                    if let url = viewModel.rootURL { viewModel.startScan(for: url) }
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var initialPromptView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "internaldrive")
                .font(.system(size: 40))
                .foregroundStyle(Color.secondary)
            Text("Select a folder to start scanning")
                .font(.headline)
            Button("Choose Folder...") {
                viewModel.selectFolderAndScan()
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }
}
