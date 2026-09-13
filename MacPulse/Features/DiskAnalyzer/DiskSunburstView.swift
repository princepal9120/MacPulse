import SwiftUI

/// Concentric rings radiating from the folder you are standing in: ring 1 is its
/// children, ring 2 their children, and so on.
struct SunburstLayout {
    struct Slice: Identifiable {
        let item: DiskItem
        let depth: Int
        let startAngle: Double
        let endAngle: Double
        var id: UUID { item.id }
        var sweep: Double { endAngle - startAngle }
    }

    /// Below this angle (~1.5 degrees) a wedge is too narrow to be visible or interactive
    private static let minimumSweep: Double = .pi / 180 * 1.5

    static func slices(for root: DiskItem, maxDepth: Int = 4) -> [Slice] {
        var result: [Slice] = []
        guard root.size > 0, let children = root.children, !children.isEmpty else { return result }

        appendRing(
            children: children,
            depth: 1,
            startAngle: -.pi / 2,
            availableSweep: 2 * .pi,
            parentAllocatedSize: root.size,
            maxDepth: maxDepth,
            into: &result
        )
        return result
    }

    private static func appendRing(
        children: [DiskItem],
        depth: Int,
        startAngle: Double,
        availableSweep: Double,
        parentAllocatedSize: Int64,
        maxDepth: Int,
        into result: inout [Slice]
    ) {
        guard depth <= maxDepth, parentAllocatedSize > 0, availableSweep >= minimumSweep else { return }

        // Sort children by size descending for clean, readable hierarchy
        let sortedChildren = children.filter { $0.size > 0 }.sorted { $0.size > $1.size }
        let totalChildSize = sortedChildren.reduce(0) { $0 + $1.size }
        guard totalChildSize > 0 else { return }

        // The parent allocated size is used as the denominator so children proportionally fill the parent's wedge
        let denominator = Double(max(totalChildSize, parentAllocatedSize))

        var currentAngle = startAngle
        for child in sortedChildren {
            let fraction = Double(child.size) / denominator
            let sweep = availableSweep * fraction
            guard sweep >= minimumSweep else { continue }

            let endAngle = currentAngle + sweep
            result.append(Slice(item: child, depth: depth, startAngle: currentAngle, endAngle: endAngle))

            if let subChildren = child.children, !subChildren.isEmpty {
                appendRing(
                    children: subChildren,
                    depth: depth + 1,
                    startAngle: currentAngle,
                    availableSweep: sweep,
                    parentAllocatedSize: child.size,
                    maxDepth: maxDepth,
                    into: &result
                )
            }
            currentAngle = endAngle
        }
    }
}

public struct DiskSunburstView: View {
    let root: DiskItem
    let maxDepth: Int
    let selectedItem: DiskItem?
    let coloringMode: ColoringMode
    let onSelect: (DiskItem) -> Void
    let onOpen: (DiskItem) -> Void

    @State private var hovered: DiskItem?

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
            let slices = SunburstLayout.slices(for: root, maxDepth: maxDepth)
            let metrics = Metrics(size: geometry.size, depthCount: maxDepth)

            ZStack {
                Canvas { context, _ in
                    for slice in slices {
                        draw(slice, metrics: metrics, in: &context)
                    }
                }
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let point):
                        hovered = slice(at: point, in: slices, metrics: metrics)?.item
                    case .ended:
                        hovered = nil
                    }
                }
                .gesture(
                    SpatialTapGesture(count: 2).onEnded { event in
                        if let hit = slice(at: event.location, in: slices, metrics: metrics) {
                            onOpen(hit.item)
                        }
                    }
                )
                .gesture(
                    SpatialTapGesture().onEnded { event in
                        if let hit = slice(at: event.location, in: slices, metrics: metrics) {
                            onSelect(hit.item)
                        }
                    }
                )

                centerDisc(metrics: metrics)
            }
        }
    }

    private func centerDisc(metrics: Metrics) -> some View {
        let focus = hovered ?? selectedItem ?? root
        return ZStack {
            Circle()
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.94))
                .overlay(
                    Circle().stroke(Color.white.opacity(0.16), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.55), radius: 14, x: 0, y: 4)

            VStack(spacing: 3) {
                Text(focus.name.isEmpty ? "/" : focus.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(FileManager.formatSize(focus.size))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.accentColor)

                if focus.id != root.id {
                    let percent = root.size > 0 ? Double(focus.size) / Double(root.size) * 100 : 0
                    Text(String(format: "%.1f%%", percent))
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.secondary)
                }
            }
            .padding(8)
        }
        .frame(width: metrics.innerRadius * 1.9, height: metrics.innerRadius * 1.9)
        .position(metrics.center)
        .allowsHitTesting(false)
    }

    private struct Metrics {
        let center: CGPoint
        let innerRadius: CGFloat
        let ringWidth: CGFloat
        let depthCount: Int

        init(size: CGSize, depthCount: Int) {
            self.depthCount = depthCount
            center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = max(40, min(size.width, size.height) / 2 - 14)
            innerRadius = outer * 0.22
            ringWidth = (outer - innerRadius) / CGFloat(max(1, depthCount))
        }

        func radii(forDepth depth: Int) -> (inner: CGFloat, outer: CGFloat) {
            let inner = innerRadius + ringWidth * CGFloat(depth - 1)
            return (inner, inner + ringWidth)
        }
    }

    private func draw(_ slice: SunburstLayout.Slice, metrics: Metrics, in context: inout GraphicsContext) {
        let radii = metrics.radii(forDepth: slice.depth)
        let path = wedgePath(slice, metrics: metrics)

        let base = DiskPalette.color(for: slice.item, mode: coloringMode)
        let isHovered = hovered?.id == slice.item.id
        let isSelected = selectedItem?.id == slice.item.id

        let depthOpacity: Double = {
            switch slice.depth {
            case 1: return 0.90
            case 2: return 0.82
            case 3: return 0.74
            default: return 0.65
            }
        }()

        context.fill(path, with: .color(base.opacity(isHovered ? 1.0 : depthOpacity)))
        context.stroke(path, with: .color(Color.black.opacity(0.40)), lineWidth: 1.0)

        if isSelected {
            context.stroke(path, with: .color(Color.white), lineWidth: 2.5)
        } else if isHovered {
            context.stroke(path, with: .color(Color.white.opacity(0.85)), lineWidth: 1.5)
        }

        // Draw text label on sufficiently large wedges without colliding
        let midRadius = (radii.inner + radii.outer) / 2
        let arcLength = midRadius * slice.sweep
        let ringThickness = radii.outer - radii.inner

        if slice.sweep >= (.pi / 180 * 15), arcLength >= 48, ringThickness >= 16 {
            let midAngle = (slice.startAngle + slice.endAngle) / 2
            let point = CGPoint(
                x: metrics.center.x + cos(midAngle) * midRadius,
                y: metrics.center.y + sin(midAngle) * midRadius
            )

            let charLimit = max(3, Int(arcLength / 7.0) - 2)
            let displayName: String
            if slice.item.name.count > charLimit {
                displayName = String(slice.item.name.prefix(charLimit)) + "…"
            } else {
                displayName = slice.item.name
            }

            let label = context.resolve(
                Text(displayName)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.95))
            )
            context.draw(label, at: point, anchor: .center)
        }
    }

    private func wedgePath(_ slice: SunburstLayout.Slice, metrics: Metrics) -> Path {
        let radii = metrics.radii(forDepth: slice.depth)
        var path = Path()
        path.addArc(
            center: metrics.center,
            radius: radii.outer,
            startAngle: .radians(slice.startAngle),
            endAngle: .radians(slice.endAngle),
            clockwise: false
        )
        path.addArc(
            center: metrics.center,
            radius: radii.inner,
            startAngle: .radians(slice.endAngle),
            endAngle: .radians(slice.startAngle),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }

    private func slice(at point: CGPoint, in slices: [SunburstLayout.Slice], metrics: Metrics) -> SunburstLayout.Slice? {
        let dx = point.x - metrics.center.x
        let dy = point.y - metrics.center.y
        let distance = sqrt(dx * dx + dy * dy)

        var angle = atan2(dy, dx)
        if angle < -.pi / 2 {
            angle += 2 * .pi
        }

        let depth = Int((distance - metrics.innerRadius) / metrics.ringWidth) + 1
        guard depth >= 1, depth <= metrics.depthCount else { return nil }

        return slices.first {
            $0.depth == depth && angle >= $0.startAngle && angle < $0.endAngle
        }
    }
}
