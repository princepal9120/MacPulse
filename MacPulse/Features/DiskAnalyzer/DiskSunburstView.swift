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

    /// Below this a wedge is a hairline nobody can hit — drop it and its subtree.
    private static let minimumSweep: Double = .pi / 180 * 1.0

    static func slices(for root: DiskItem, maxDepth: Int = 4) -> [Slice] {
        var result: [Slice] = []
        appendRing(children: root.children ?? [], parentSize: root.size, depth: 1, from: -.pi / 2, maxDepth: maxDepth, into: &result)
        return result
    }

    private static func appendRing(
        children: [DiskItem],
        parentSize: Int64,
        depth: Int,
        from startAngle: Double,
        maxDepth: Int,
        into result: inout [Slice]
    ) {
        guard depth <= maxDepth, parentSize > 0 else { return }

        var angle = startAngle
        for child in children where child.size > 0 {
            let sweep = 2 * .pi * Double(child.size) / Double(parentSize)
            guard sweep >= minimumSweep else { continue }

            result.append(Slice(item: child, depth: depth, startAngle: angle, endAngle: angle + sweep))
            appendRing(
                children: child.children ?? [],
                parentSize: child.size,
                depth: depth + 1,
                from: angle,
                maxDepth: maxDepth,
                into: &result
            )
            angle += sweep
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
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(
                    Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )

            VStack(spacing: 3) {
                Text(focus.name.isEmpty ? "/" : focus.name)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(FileManager.formatSize(focus.size))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.secondary)
            }
            .padding(6)
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

        context.fill(path, with: .color(base.opacity(isHovered ? 0.95 : 0.70)))
        context.stroke(path, with: .color(Color.black.opacity(0.15)), lineWidth: 0.5)
        if isSelected {
            context.stroke(path, with: .color(Color.accentColor), lineWidth: 2.5)
        }

        // Draw text label on sufficiently large wedges
        if slice.sweep > .pi / 8, (radii.outer - radii.inner) > 16 {
            let mid = (slice.startAngle + slice.endAngle) / 2
            let radius = (radii.inner + radii.outer) / 2
            let point = CGPoint(
                x: metrics.center.x + cos(mid) * radius,
                y: metrics.center.y + sin(mid) * radius
            )
            let label = context.resolve(
                Text(slice.item.name)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.85))
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
