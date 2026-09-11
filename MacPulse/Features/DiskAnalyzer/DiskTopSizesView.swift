import SwiftUI

/// Ranked horizontal bar chart list matching DiskBuddy Top Sizes mode (Screenshot 6).
public struct DiskTopSizesView: View {
    @Binding var currentTab: TopSizesTab
    let currentFolderItems: [DiskItem]
    let biggestFiles: [DiskItem]
    let biggestFolders: [DiskItem]
    let selectedItem: DiskItem?
    let coloringMode: ColoringMode
    let onSelect: (DiskItem) -> Void
    let onOpen: (DiskItem) -> Void

    public init(
        currentTab: Binding<TopSizesTab>,
        currentFolderItems: [DiskItem],
        biggestFiles: [DiskItem],
        biggestFolders: [DiskItem],
        selectedItem: DiskItem?,
        coloringMode: ColoringMode = .byFolder,
        onSelect: @escaping (DiskItem) -> Void,
        onOpen: @escaping (DiskItem) -> Void
    ) {
        self._currentTab = currentTab
        self.currentFolderItems = currentFolderItems
        self.biggestFiles = biggestFiles
        self.biggestFolders = biggestFolders
        self.selectedItem = selectedItem
        self.coloringMode = coloringMode
        self.onSelect = onSelect
        self.onOpen = onOpen
    }

    private var activeList: [DiskItem] {
        switch currentTab {
        case .inThisFolder:
            return currentFolderItems.sorted { $0.size > $1.size }
        case .biggestFilesAnywhere:
            return biggestFiles
        case .biggestFoldersAnywhere:
            return biggestFolders
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Filter segmented tabs
            HStack(spacing: 8) {
                ForEach(TopSizesTab.allCases) { tab in
                    Button(action: {
                        currentTab = tab
                    }) {
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: currentTab == tab ? .semibold : .regular))
                            .foregroundStyle(currentTab == tab ? Color.white : Color.primary.opacity(0.75))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(currentTab == tab ? Color.primary.opacity(0.85) : Color.primary.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Text("\(activeList.count) shown")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Divider()

            // Ranked List
            ScrollView {
                LazyVStack(spacing: 6) {
                    let totalSize = activeList.first?.size ?? 1
                    ForEach(Array(activeList.enumerated()), id: \.element.id) { index, item in
                        rankedRow(index: index + 1, item: item, maxRelativeSize: totalSize)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private func rankedRow(index: Int, item: DiskItem, maxRelativeSize: Int64) -> some View {
        let isSelected = selectedItem?.id == item.id
        let percent = maxRelativeSize > 0 ? Double(item.size) / Double(maxRelativeSize) : 0.0
        let barColor = DiskPalette.color(for: item, mode: coloringMode)

        return Button(action: {
            onSelect(item)
        }) {
            HStack(spacing: 12) {
                // Rank number
                Text("\(index)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 24, alignment: .trailing)

                // Icon
                Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(barColor)
                    .frame(width: 20)

                // Name
                Text(item.name)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: 140, alignment: .leading)

                // Relative filled horizontal bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.primary.opacity(0.05))

                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor.opacity(0.65))
                            .frame(width: max(4, geo.size.width * CGFloat(percent)))
                    }
                }
                .frame(height: 12)

                // Stats: file count & percentage
                HStack(spacing: 8) {
                    if item.fileCount > 0 {
                        Text("\(item.fileCount.formatted()) files")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                            .frame(width: 90, alignment: .trailing)
                    }

                    Text(String(format: "%.1f%%", percent * 100))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 50, alignment: .trailing)

                    // Formatted bytes size
                    Text(FileManager.formatSize(item.size))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .frame(width: 75, alignment: .trailing)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                onOpen(item)
            }
        )
    }
}
