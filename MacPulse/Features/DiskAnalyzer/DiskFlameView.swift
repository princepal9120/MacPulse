import SwiftUI

/// Hierarchical icicle / flamegraph chart (Screenshot 3).
/// Depth top to bottom, size left to right.
public struct DiskFlameView: View {
    let root: DiskItem
    let maxDepth: Int
    let selectedItem: DiskItem?
    let coloringMode: ColoringMode
    let onSelect: (DiskItem) -> Void
    let onOpen: (DiskItem) -> Void

    public init(
        root: DiskItem,
        maxDepth: Int = 4,
        selectedItem: DiskItem?,
        coloringMode: ColoringMode = .byFolder,
        onSelect: @escaping (DiskItem) -> Void,
        onOpen: @escaping (DiskItem) -> Void
    ) {
        self.root = root
        self.maxDepth = max(1, min(7, maxDepth))
        self.selectedItem = selectedItem
        self.coloringMode = coloringMode
        self.onSelect = onSelect
        self.onOpen = onOpen
    }

    public var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let availableHeight = geometry.size.height
            let rowHeight = max(28, availableHeight / CGFloat(maxDepth + 1))

            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 2) {
                    // Level 0: Root bar
                    flameBar(item: root, width: availableWidth, height: rowHeight, isRoot: true)

                    // Levels 1...maxDepth
                    ForEach(1...maxDepth, id: \.self) { level in
                        let nodesAtLevel = nodes(at: level, under: root)
                        if !nodesAtLevel.isEmpty {
                            HStack(spacing: 2) {
                                ForEach(nodesAtLevel) { node in
                                    let nodeWidth = max(2, availableWidth * CGFloat(Double(node.item.size) / Double(max(1, root.size))))
                                    flameBar(item: node.item, width: nodeWidth, height: rowHeight, isRoot: false)
                                }
                            }
                        }
                    }
                }
                .frame(minWidth: availableWidth, alignment: .topLeading)
                .padding(8)
            }
        }
    }

    private struct NodeLevel: Identifiable {
        var id: UUID { item.id }
        let item: DiskItem
    }

    private func nodes(at targetLevel: Int, under current: DiskItem, currentLevel: Int = 0) -> [NodeLevel] {
        if currentLevel == targetLevel {
            return [NodeLevel(item: current)]
        }
        guard let children = current.children, !children.isEmpty else { return [] }
        var result: [NodeLevel] = []
        for child in children.sorted(by: { $0.size > $1.size }) where child.size > 0 {
            result.append(contentsOf: nodes(at: targetLevel, under: child, currentLevel: currentLevel + 1))
        }
        return result
    }

    private func flameBar(item: DiskItem, width: CGFloat, height: CGFloat, isRoot: Bool) -> some View {
        let isSelected = selectedItem?.id == item.id
        let color = DiskPalette.color(for: item, mode: coloringMode)

        return Button(action: {
            onSelect(item)
        }) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isSelected ? Color.accentColor : Color.black.opacity(0.08), lineWidth: isSelected ? 2 : 1)
                    )

                if width > 36 {
                    Text(item.name)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 6)
                }
            }
            .frame(width: max(2, width), height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                onOpen(item)
            }
        )
        .help("\(item.name) — \(FileManager.formatSize(item.size))")
    }
}
