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
            DiskAnalyzerSidebarView(viewModel: viewModel)

            Divider()

            VStack(spacing: 0) {
                topHeaderControls

                ZStack {
                    Color.clear
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.045), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .center
                )
            )

            Divider()

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
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                if viewModel.canNavigateUp {
                    Button {
                        viewModel.navigateUp()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.currentItem?.name ?? "Disk Analyzer")
                        .font(.headline)
                        .lineLimit(1)
                    if let current = viewModel.currentItem {
                        Text("\(FileManager.formatSize(current.size)) · \(current.fileCount.formatted()) files · \(current.folderCount.formatted()) folders")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Filter by name...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.callout)
                        .frame(width: 170)
                    if !viewModel.searchQuery.isEmpty {
                        Button { viewModel.searchQuery = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }

            HStack(spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                    ForEach(DiskViewMode.allCases) { mode in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.viewMode = mode
                            }
                        } label: {
                            Image(systemName: mode.systemImage)
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 28, height: 26)
                                .contentShape(Rectangle())
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(viewModel.viewMode == mode ? Color.accentColor : Color.clear)
                                )
                                .foregroundStyle(viewModel.viewMode == mode ? .white : .secondary)
                            }
                        .buttonStyle(.plain)
                        .help(mode.localizedName)
                    }
                }
                    .padding(3)
                }
                .fixedSize(horizontal: false, vertical: true)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                Text(viewModel.viewMode.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                if [.sunburst, .flame, .treemap].contains(viewModel.viewMode) {
                    HStack(spacing: 6) {
                        Text("Depth")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: Binding(
                            get: { Double(viewModel.depth) },
                            set: { viewModel.depth = Int($0) }
                        ), in: 1...7, step: 1)
                        .frame(width: 64)
                        Text("\(viewModel.depth)")
                            .font(.caption.monospacedDigit())
                            .frame(width: 12)
                    }
                }

                Picker("Color", selection: $viewModel.coloringMode) {
                    ForEach(ColoringMode.allCases) { mode in
                        Label(mode.localizedName, systemImage: mode.icon).tag(mode)
                        }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Divider().opacity(0.55) }
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
        stateCard(icon: "internaldrive.fill", color: .accentColor) {
            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.large)
                Text("Scanning disk space…")
                    .font(.title3.weight(.semibold))
                Text(viewModel.currentScanningName.isEmpty ? "Calculating folder sizes" : viewModel.currentScanningName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 320)
                Button("Cancel") { viewModel.cancelScan() }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
            }
        }
    }

    private func scanErrorView(_ message: String) -> some View {
        stateCard(icon: "exclamationmark.triangle.fill", color: .orange) {
            VStack(spacing: 10) {
                Text("Couldn’t scan this location")
                    .font(.title3.weight(.semibold))
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                HStack {
                    Button("Choose Folder…") { viewModel.selectFolderAndScan() }
                        .buttonStyle(.borderedProminent)
                    Button("Retry") {
                        if let url = viewModel.rootURL { viewModel.startScan(for: url) }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var initialPromptView: some View {
        stateCard(icon: "internaldrive", color: .accentColor) {
            VStack(spacing: 10) {
                Text("See what’s using your storage")
                    .font(.title3.weight(.semibold))
                Text("Scan your home folder or choose another location to explore files by size, type, and age.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
                HStack {
                    Button("Scan Home") {
                        viewModel.startScan(for: FileManager.default.homeDirectoryForCurrentUser)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Choose Folder…") { viewModel.selectFolderAndScan() }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private func stateCard<Content: View>(
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 58, height: 58)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            content()
        }
        .padding(30)
        .frame(minWidth: 420)
        .glassCard(cornerRadius: 22)
        .padding(32)
    }
}
