import SwiftUI

/// Right inspector panel for Disk Analyzer matching the DiskBuddy screenshots.
public struct DiskAnalyzerInspectorView: View {
    @Bindable var viewModel: DiskAnalyzerViewModel

    public init(viewModel: DiskAnalyzerViewModel) {
        self.viewModel = viewModel
    }

    private var targetItem: DiskItem? {
        viewModel.selectedItem ?? viewModel.currentItem
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let item = targetItem {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        // 1. Header with icon, name, badge and path
                        headerSection(for: item)

                        // 2. Hero Size & Share
                        heroSizeSection(for: item)

                        Divider()

                        // 3. Details Grid
                        detailsGrid(for: item)

                        Divider()

                        // 4. Largest Inside
                        if item.isDirectory, let children = item.children, !children.isEmpty {
                            largestInsideSection(children: children, parentSize: item.size)
                            Divider()
                        }

                        // 5. Actions: Reveal, Quick Look, Focus, Copy Path
                        actionButtons(for: item)

                        // 6. Add to Cleanup CTA
                        cleanupButton(for: item)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                emptyState
            }
        }
        .padding(14)
        .frame(width: 270)
        .background(Color.primary.opacity(0.025))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.secondary.opacity(0.5))
            Text("Select any file or folder to view details")
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Header

    private func headerSection(for item: DiskItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(DiskPalette.color(for: item, mode: viewModel.coloringMode))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .lineLimit(2)
                        .truncationMode(.middle)

                    Text(item.isDirectory ? "Folder" : (item.fileType.rawValue.capitalized + " File"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }
            }

            Text(item.url.path)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }

    // MARK: - Hero Size

    private func heroSizeSection(for item: DiskItem) -> some View {
        let rootSize = viewModel.rootItem?.size ?? 1
        let scanPercent = rootSize > 0 ? (Double(item.size) / Double(rootSize)) * 100 : 0

        return HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(FileManager.formatSize(item.size))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)

            Text(String(format: "%.1f%% of scan", scanPercent))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.secondary)
        }
    }

    // MARK: - Details Grid

    private func detailsGrid(for item: DiskItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DETAILS")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color.secondary)

            detailRow(title: "Size on disk", value: FileManager.formatSize(item.size))
            detailRow(title: "Logical size", value: FileManager.formatSize(item.size))
            detailRow(title: "Compressed by", value: "0 B")
            if item.fileCount > 0 {
                detailRow(title: "Files", value: item.fileCount.formatted())
            }
            if item.isDirectory {
                detailRow(title: "Folders", value: item.folderCount.formatted())
            }

            if let parent = item.parentURL, let current = viewModel.currentItem, current.url == parent {
                let parentPercent = current.size > 0 ? (Double(item.size) / Double(current.size)) * 100 : 0
                detailRow(title: "Of parent", value: String(format: "%.1f%%", parentPercent))
            }

            if let modDate = item.modifiedAt {
                detailRow(title: "Modified", value: modDate.formatted(.dateTime.day().month().year()))
            }
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.primary.opacity(0.85))
        }
    }

    // MARK: - Largest Inside

    private func largestInsideSection(children: [DiskItem], parentSize: Int64) -> some View {
        let topChildren = Array(children.sorted { $0.size > $1.size }.prefix(8))

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("LARGEST INSIDE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.secondary)
                Spacer()
                Text("\(children.count) items")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.secondary)
            }

            ForEach(topChildren) { child in
                Button(action: {
                    viewModel.selectedItem = child
                }) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(DiskPalette.color(for: child, mode: viewModel.coloringMode))
                            .frame(width: 6, height: 6)

                        Text(child.name)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(FileManager.formatSize(child.size))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Action Buttons

    private func actionButtons(for item: DiskItem) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Button(action: {
                    viewModel.showInFinder(item: item)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 10))
                        Text("Reveal")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)

                Button(action: {
                    viewModel.toggleQuickLook(for: item)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 10))
                        Text("Quick Look")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                if item.isDirectory && !item.isPackage {
                    Button(action: {
                        viewModel.drillDown(into: item)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "viewfinder")
                                .font(.system(size: 10))
                            Text("Focus")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }

                Button(action: {
                    viewModel.copyPath(for: item)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                        Text("Copy Path")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Cleanup Button

    private func cleanupButton(for item: DiskItem) -> some View {
        VStack(spacing: 4) {
            Button(action: {
                viewModel.stageSelectedForCleanup()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 12))
                    Text("Add to Cleanup")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.88))
                )
            }
            .buttonStyle(.plain)

            if let message = viewModel.stageNotificationMessage {
                Text(message)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.green)
                    .transition(.opacity)
            }
        }
        .padding(.top, 4)
    }
}
