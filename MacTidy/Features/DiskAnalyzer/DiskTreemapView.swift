import SwiftUI

/// Squarified treemap layout — tiles stay close to square so small items remain
/// clickable instead of collapsing into slivers.
struct TreemapLayout {
    struct Tile: Identifiable {
        let item: DiskItem
        let rect: CGRect
        let depth: Int
        var id: UUID { item.id }
    }

    static func tiles(for items: [DiskItem], in bounds: CGRect, maxDepth: Int = 3, currentDepth: Int = 1) -> [Tile] {
        let ranked = items.filter { $0.size > 0 }.sorted { $0.size > $1.size }
        guard !ranked.isEmpty, bounds.width > 2, bounds.height > 2 else { return [] }

        let total = ranked.reduce(0.0) { $0 + Double($1.size) }
        guard total > 0 else { return [] }

        let scale = Double(bounds.width) * Double(bounds.height) / total
        let areas = ranked.map { Double($0.size) * scale }

        var tiles: [Tile] = []
        var rect = bounds
        var rowStart = 0
        var index = 0

        while index < areas.count {
            let shortSide = Double(min(rect.width, rect.height))
            guard shortSide > 0 else { break }

            let currentRow = Array(areas[rowStart..<index])
            let widened = Array(areas[rowStart...index])

            if currentRow.isEmpty || worstAspect(widened, side: shortSide) <= worstAspect(currentRow, side: shortSide) {
                index += 1
            } else {
                tiles.append(contentsOf: place(currentRow, items: ranked, from: rowStart, in: &rect, depth: currentDepth))
                rowStart = index
            }
        }

        if rowStart < areas.count {
            let lastRow = Array(areas[rowStart...])
            tiles.append(contentsOf: place(lastRow, items: ranked, from: rowStart, in: &rect, depth: currentDepth))
        }

        // Recursive sub-tiling for large folders up to maxDepth
        if currentDepth < maxDepth {
            var subTiles: [Tile] = []
            for tile in tiles where tile.item.isDirectory && !tile.item.isPackage {
                if let children = tile.item.children, !children.isEmpty, tile.rect.width > 75, tile.rect.height > 75 {
                    let innerBounds = CGRect(
                        x: tile.rect.minX + 4,
                        y: tile.rect.minY + 28,
                        width: max(0, tile.rect.width - 8),
                        height: max(0, tile.rect.height - 32)
                    )
                    subTiles.append(contentsOf: TreemapLayout.tiles(for: children, in: innerBounds, maxDepth: maxDepth, currentDepth: currentDepth + 1))
                }
            }
            tiles.append(contentsOf: subTiles)
        }

        return tiles
    }

    private static func worstAspect(_ row: [Double], side: Double) -> Double {
        guard let maxArea = row.max(), let minArea = row.min(), maxArea > 0, minArea > 0 else { return .infinity }
        let sum = row.reduce(0, +)
        guard sum > 0 else { return .infinity }
        let sideSquared = side * side
        let sumSquared = sum * sum
        return max(sideSquared * maxArea / sumSquared, sumSquared / (sideSquared * minArea))
    }

    private static func place(_ row: [Double], items: [DiskItem], from startIndex: Int, in rect: inout CGRect, depth: Int) -> [Tile] {
        guard !row.isEmpty else { return [] }
        let sum = row.reduce(0, +)
        guard sum > 0 else { return [] }

        var tiles: [Tile] = []
        let alongWidth = rect.width < rect.height

        if alongWidth {
            let rowWidth = CGFloat(sum) / rect.height
            var y = rect.minY
            for (offset, area) in row.enumerated() {
                let height = CGFloat(area) / rowWidth
                tiles.append(Tile(
                    item: items[startIndex + offset],
                    rect: CGRect(x: rect.minX, y: y, width: rowWidth, height: height),
                    depth: depth
                ))
                y += height
            }
            rect = CGRect(x: rect.minX + rowWidth, y: rect.minY, width: max(0, rect.width - rowWidth), height: rect.height)
        } else {
            let rowHeight = CGFloat(sum) / rect.width
            var x = rect.minX
            for (offset, area) in row.enumerated() {
                let width = CGFloat(area) / rowHeight
                tiles.append(Tile(
                    item: items[startIndex + offset],
                    rect: CGRect(x: x, y: rect.minY, width: width, height: rowHeight),
                    depth: depth
                ))
                x += width
            }
            rect = CGRect(x: rect.minX, y: rect.minY + rowHeight, width: rect.width, height: max(0, rect.height - rowHeight))
        }

        return tiles
    }
}

public struct DiskTreemapView: View {
    let items: [DiskItem]
    let maxDepth: Int
    let selectedItem: DiskItem?
    let coloringMode: ColoringMode
    let onSelect: (DiskItem) -> Void
    let onOpen: (DiskItem) -> Void

    @State private var hoveredID: UUID?

    private let inset: CGFloat = 1.0
    private let labelMinWidth: CGFloat = 50
    private let labelMinHeight: CGFloat = 26

    public init(
        items: [DiskItem],
        maxDepth: Int = 4,
        selectedItem: DiskItem?,
        coloringMode: ColoringMode = .byFolder,
        onSelect: @escaping (DiskItem) -> Void,
        onOpen: @escaping (DiskItem) -> Void
    ) {
        self.items = items
        self.maxDepth = max(1, min(7, maxDepth))
        self.selectedItem = selectedItem
        self.coloringMode = coloringMode
        self.onSelect = onSelect
        self.onOpen = onOpen
    }

    public var body: some View {
        GeometryReader { geometry in
            let bounds = CGRect(origin: .zero, size: geometry.size)
            let tiles = TreemapLayout.tiles(for: items, in: bounds, maxDepth: maxDepth)

            Canvas { context, _ in
                for tile in tiles {
                    draw(tile, in: &context)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    hoveredID = tiles.last { $0.rect.contains(point) }?.id
                case .ended:
                    hoveredID = nil
                }
            }
            .gesture(
                SpatialTapGesture(count: 2).onEnded { event in
                    if let tile = tiles.last(where: { $0.rect.contains(event.location) }) {
                        onOpen(tile.item)
                    }
                }
            )
            .gesture(
                SpatialTapGesture().onEnded { event in
                    if let tile = tiles.last(where: { $0.rect.contains(event.location) }) {
                        onSelect(tile.item)
                    }
                }
            )
        }
    }

    private func draw(_ tile: TreemapLayout.Tile, in context: inout GraphicsContext) {
        let rect = tile.rect.insetBy(dx: inset, dy: inset)
        guard rect.width > 2, rect.height > 2 else { return }

        let path = Path(roundedRect: rect, cornerRadius: max(2, 6 - CGFloat(tile.depth)))
        let base = DiskPalette.color(for: tile.item, mode: coloringMode)
        let isHovered = hoveredID == tile.item.id
        let isSelected = selectedItem?.id == tile.item.id

        let alpha = tile.depth == 1 ? (isHovered ? 0.90 : 0.65) : (isHovered ? 0.95 : 0.80)
        context.fill(path, with: .color(base.opacity(alpha)))
        context.stroke(
            path,
            with: .color(isSelected ? Color.accentColor : Color.black.opacity(tile.depth == 1 ? 0.20 : 0.10)),
            lineWidth: isSelected ? 2.5 : 0.8
        )

        guard rect.width >= labelMinWidth, rect.height >= labelMinHeight else { return }

        let label = context.resolve(
            Text(tile.item.name)
                .font(.system(size: max(9, min(12, rect.width * 0.12)), weight: .semibold, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.85))
        )
        context.draw(label, in: CGRect(x: rect.minX + 5, y: rect.minY + 4, width: rect.width - 10, height: 14))

        if rect.height >= 40 {
            let size = context.resolve(
                Text(FileManager.formatSize(tile.item.size))
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.secondary)
            )
            context.draw(size, in: CGRect(x: rect.minX + 5, y: rect.minY + 18, width: rect.width - 10, height: 12))
        }
    }
}
