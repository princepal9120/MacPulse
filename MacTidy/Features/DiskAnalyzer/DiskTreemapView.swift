import SwiftUI

/// Shared colouring so a folder keeps the same colour in every visual mode.
enum DiskPalette {
    private static let folderHues: [Color] = [.blue, .indigo, .teal, .cyan, .mint, .purple]

    static func color(for item: DiskItem) -> Color {
        if item.isDirectory && !item.isPackage {
            let index = abs(item.name.hashValue) % folderHues.count
            return folderHues[index]
        }
        switch item.fileType {
        case .video: return .purple
        case .audio: return .pink
        case .photo: return .orange
        case .apps: return .blue
        case .docs: return .teal
        case .archives: return .brown
        case .all: return .gray
        }
    }
}

/// Squarified treemap layout — tiles stay close to square so small items remain
/// clickable instead of collapsing into slivers.
struct TreemapLayout {
    struct Tile: Identifiable {
        let item: DiskItem
        let rect: CGRect
        var id: UUID { item.id }
    }

    static func tiles(for items: [DiskItem], in bounds: CGRect) -> [Tile] {
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
                tiles.append(contentsOf: place(currentRow, items: ranked, from: rowStart, in: &rect))
                rowStart = index
            }
        }

        if rowStart < areas.count {
            let lastRow = Array(areas[rowStart...])
            tiles.append(contentsOf: place(lastRow, items: ranked, from: rowStart, in: &rect))
        }

        return tiles
    }

    /// Ratio of the least square-like tile in the row; lower is better.
    private static func worstAspect(_ row: [Double], side: Double) -> Double {
        guard let maxArea = row.max(), let minArea = row.min(), maxArea > 0, minArea > 0 else { return .infinity }
        let sum = row.reduce(0, +)
        guard sum > 0 else { return .infinity }
        let sideSquared = side * side
        let sumSquared = sum * sum
        return max(sideSquared * maxArea / sumSquared, sumSquared / (sideSquared * minArea))
    }

    /// Lays the row along the short edge of `rect` and shrinks `rect` by what it consumed.
    private static func place(
        _ row: [Double],
        items: [DiskItem],
        from startIndex: Int,
        in rect: inout CGRect
    ) -> [Tile] {
        let sum = row.reduce(0, +)
        guard sum > 0 else { return [] }

        var tiles: [Tile] = []
        let isVerticalRow = rect.width >= rect.height

        if isVerticalRow {
            let rowWidth = CGFloat(sum) / rect.height
            var y = rect.minY
            for (offset, area) in row.enumerated() {
                let height = CGFloat(area) / rowWidth
                tiles.append(Tile(
                    item: items[startIndex + offset],
                    rect: CGRect(x: rect.minX, y: y, width: rowWidth, height: height)
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
                    rect: CGRect(x: x, y: rect.minY, width: width, height: rowHeight)
                ))
                x += width
            }
            rect = CGRect(x: rect.minX, y: rect.minY + rowHeight, width: rect.width, height: max(0, rect.height - rowHeight))
        }

        return tiles
    }
}

struct DiskTreemapView: View {
    let items: [DiskItem]
    let selectedItem: DiskItem?
    let onSelect: (DiskItem) -> Void
    let onOpen: (DiskItem) -> Void

    @State private var hoveredID: UUID?

    private let inset: CGFloat = 1.5
    private let labelMinWidth: CGFloat = 68
    private let labelMinHeight: CGFloat = 34

    var body: some View {
        GeometryReader { geometry in
            let bounds = CGRect(origin: .zero, size: geometry.size)
            let tiles = TreemapLayout.tiles(for: items, in: bounds)

            Canvas { context, _ in
                for tile in tiles {
                    draw(tile, in: &context)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    hoveredID = tiles.first { $0.rect.contains(point) }?.id
                case .ended:
                    hoveredID = nil
                }
            }
            .gesture(
                SpatialTapGesture(count: 2).onEnded { event in
                    if let tile = tiles.first(where: { $0.rect.contains(event.location) }) {
                        onOpen(tile.item)
                    }
                }
            )
            .gesture(
                SpatialTapGesture().onEnded { event in
                    if let tile = tiles.first(where: { $0.rect.contains(event.location) }) {
                        onSelect(tile.item)
                    }
                }
            )
            .help("disk_analyzer_treemap_hint".localized)
        }
    }

    private func draw(_ tile: TreemapLayout.Tile, in context: inout GraphicsContext) {
        let rect = tile.rect.insetBy(dx: inset, dy: inset)
        guard rect.width > 1, rect.height > 1 else { return }

        let isHovered = hoveredID == tile.id
        let isSelected = selectedItem?.id == tile.item.id
        let base = DiskPalette.color(for: tile.item)
        let path = Path(roundedRect: rect, cornerRadius: min(5, rect.height / 3))

        context.fill(path, with: .color(base.opacity(isHovered ? 0.85 : 0.55)))
        context.stroke(
            path,
            with: .color(isSelected ? Color.primary : Color.black.opacity(0.25)),
            lineWidth: isSelected ? 2 : 0.5
        )

        guard rect.width >= labelMinWidth, rect.height >= labelMinHeight else { return }

        let label = context.resolve(
            Text(tile.item.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
        )
        let size = context.resolve(
            Text(tile.item.size.formattedByteCount())
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.white.opacity(0.85))
        )

        context.draw(label, in: CGRect(x: rect.minX + 6, y: rect.minY + 5, width: rect.width - 12, height: 14))
        context.draw(size, in: CGRect(x: rect.minX + 6, y: rect.minY + 20, width: rect.width - 12, height: 13))
    }
}
