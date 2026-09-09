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

    static let maxDepth = 3
    /// Below this a wedge is a hairline nobody can hit — drop it and its subtree.
    private static let minimumSweep: Double = .pi / 180 * 1.2

    static func slices(for root: DiskItem, maxDepth: Int = maxDepth) -> [Slice] {
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

struct DiskSunburstView: View {
    let root: DiskItem
    let selectedItem: DiskItem?
    let onSelect: (DiskItem) -> Void
    let onOpen: (DiskItem) -> Void

    @State private var hovered: DiskItem?

    var body: some View {
        GeometryReader { geometry in
            let slices = SunburstLayout.slices(for: root)
            let metrics = Metrics(size: geometry.size)

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

                centerLabel
                    .frame(width: metrics.innerRadius * 1.7)
                    .allowsHitTesting(false)
            }
        }
    }

    private var centerLabel: some View {
        let focus = hovered ?? root
        return VStack(spacing: 2) {
            Text(focus.name.isEmpty ? "/" : focus.name)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(focus.size.formattedByteCount())
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private struct Metrics {
        let center: CGPoint
        let innerRadius: CGFloat
        let ringWidth: CGFloat

        init(size: CGSize) {
            center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = max(40, min(size.width, size.height) / 2 - 10)
            innerRadius = outer * 0.24
            ringWidth = (outer - innerRadius) / CGFloat(SunburstLayout.maxDepth)
        }

        func radii(forDepth depth: Int) -> (inner: CGFloat, outer: CGFloat) {
            let inner = innerRadius + ringWidth * CGFloat(depth - 1)
            return (inner, inner + ringWidth)
        }
    }

    private func draw(_ slice: SunburstLayout.Slice, metrics: Metrics, in context: inout GraphicsContext) {
        let radii = metrics.radii(forDepth: slice.depth)
        let path = wedgePath(slice, metrics: metrics)

        let base = DiskPalette.color(for: slice.item)
        let isHovered = hovered?.id == slice.item.id
        let isSelected = selectedItem?.id == slice.item.id
        let fade = 0.75 - Double(slice.depth - 1) * 0.16

        context.fill(path, with: .color(base.opacity(isHovered ? 0.95 : fade)))
        context.stroke(path, with: .color(Color.black.opacity(0.22)), lineWidth: 0.5)
        if isSelected {
            context.stroke(path, with: .color(Color.primary), lineWidth: 2)
        }

        // Only the outermost readable wedges get a label; the rest live in the hub.
        guard slice.sweep > .pi / 9, radii.outer - radii.inner > 22 else { return }
        let mid = (slice.startAngle + slice.endAngle) / 2
        let radius = (radii.inner + radii.outer) / 2
        let point = CGPoint(
            x: metrics.center.x + cos(mid) * radius,
            y: metrics.center.y + sin(mid) * radius
        )
        let label = context.resolve(
            Text(slice.item.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white)
        )
        context.draw(label, at: point, anchor: .center)
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
        let radius = sqrt(dx * dx + dy * dy)
        guard radius > metrics.innerRadius else { return nil }

        let depth = Int((radius - metrics.innerRadius) / metrics.ringWidth) + 1
        guard depth >= 1, depth <= SunburstLayout.maxDepth else { return nil }

        // Wedge angles run from -90°, so normalise the hit angle into the same turn.
        var angle = atan2(dy, dx)
        if angle < -.pi / 2 { angle += 2 * .pi }

        return slices.first { $0.depth == depth && angle >= $0.startAngle && angle < $0.endAngle }
    }
}
