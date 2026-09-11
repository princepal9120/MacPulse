import SwiftUI

/// Responsive folder grid for the primary Disk Analyzer browsing mode.
public struct DiskFoldersGridView: View {
    let items: [DiskItem]
    let selectedItem: DiskItem?
    let coloringMode: ColoringMode
    let onSelect: (DiskItem) -> Void
    let onOpen: (DiskItem) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 210, maximum: 280), spacing: 16)
    ]

    public init(
        items: [DiskItem],
        selectedItem: DiskItem?,
        coloringMode: ColoringMode = .byFolder,
        onSelect: @escaping (DiskItem) -> Void,
        onOpen: @escaping (DiskItem) -> Void
    ) {
        self.items = items.sorted { $0.size > $1.size }
        self.selectedItem = selectedItem
        self.coloringMode = coloringMode
        self.onSelect = onSelect
        self.onOpen = onOpen
    }

    public var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items) { item in
                    folderCard(for: item)
                }
            }
            .padding(20)
        }
    }

    private func folderCard(for item: DiskItem) -> some View {
        let isSelected = selectedItem?.id == item.id
        let baseColor = DiskPalette.color(for: item, mode: coloringMode)

        return Button(action: {
            onSelect(item)
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Top header: Folder icon tab
                HStack {
                    ZStack(alignment: .topLeading) {
                        // Folder notch accent
                        RoundedRectangle(cornerRadius: 4)
                            .fill(baseColor.opacity(0.85))
                            .frame(width: 32, height: 8)
                            .offset(y: -4)

                        Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(baseColor)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.accentColor)
                    }
                }

                // Folder Name
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 4)

                // Bottom row: items count pill and size
                HStack(alignment: .lastTextBaseline) {
                    // Dot pills for content types
                    HStack(spacing: 4) {
                        Circle().fill(Color.teal).frame(width: 6, height: 6)
                        Circle().fill(Color.orange).frame(width: 6, height: 6)
                        Circle().fill(Color.purple).frame(width: 6, height: 6)

                        Text("\(item.fileCount > 0 ? item.fileCount.formatted() : (item.children?.count ?? 0).formatted()) items")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.secondary)
                    }

                    Spacer()

                    Text(FileManager.formatSize(item.size))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(0.85))
                }
            }
            .padding(16)
            .frame(height: 136)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(baseColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .glassCard(cornerRadius: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : baseColor.opacity(0.35), lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                onOpen(item)
            }
        )
    }
}
