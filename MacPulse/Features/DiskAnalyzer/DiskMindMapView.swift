import SwiftUI

/// Radial node-link tree chart matching DiskBuddy Mind Map mode (Screenshot 5).
/// Branches from the root, sized by weight.
public struct DiskMindMapView: View {
    let root: DiskItem
    let selectedItem: DiskItem?
    let coloringMode: ColoringMode
    let onSelect: (DiskItem) -> Void
    let onOpen: (DiskItem) -> Void

    public init(
        root: DiskItem,
        selectedItem: DiskItem?,
        coloringMode: ColoringMode = .byFolder,
        onSelect: @escaping (DiskItem) -> Void,
        onOpen: @escaping (DiskItem) -> Void
    ) {
        self.root = root
        self.selectedItem = selectedItem
        self.coloringMode = coloringMode
        self.onSelect = onSelect
        self.onOpen = onOpen
    }

    public var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let maxRadius = min(geometry.size.width, geometry.size.height) * 0.44
            let tree = layoutMindMap(root: root, center: center, maxRadius: maxRadius)

            ZStack {
                // Connecting branch lines
                Canvas { context, _ in
                    for branch in tree.branches {
                        var path = Path()
                        path.move(to: branch.start)
                        path.addQuadCurve(to: branch.end, control: branch.control)
                        context.stroke(
                            path,
                            with: .color(branch.color.opacity(0.4)),
                            lineWidth: max(1, branch.width)
                        )
                    }
                }

                // Center root hub node
                centerHub(center: center)

                // Outer branch nodes
                ForEach(tree.nodes) { node in
                    nodeView(node: node)
                }
            }
        }
    }

    private struct MindNode: Identifiable {
        var id: UUID { item.id }
        let item: DiskItem
        let center: CGPoint
        let radius: CGFloat
        let labelAngle: Double
    }

    private struct BranchLine: Identifiable {
        let id = UUID()
        let start: CGPoint
        let end: CGPoint
        let control: CGPoint
        let color: Color
        let width: CGFloat
    }

    private struct MindTree {
        let nodes: [MindNode]
        let branches: [BranchLine]
    }

    private func centerHub(center: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(Color.primary.opacity(0.88))
                .frame(width: 72, height: 72)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.2), lineWidth: 2)
                )

            VStack(spacing: 2) {
                Text(root.name)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                Text(FileManager.formatSize(root.size))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.75))
            }
            .padding(4)
        }
        .position(center)
    }

    private func nodeView(node: MindNode) -> some View {
        let isSelected = selectedItem?.id == node.item.id
        let color = DiskPalette.color(for: node.item, mode: coloringMode)

        return HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: node.radius * 2, height: node.radius * 2)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.6), lineWidth: isSelected ? 2.5 : 1)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(node.item.name)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                Text(FileManager.formatSize(node.item.size))
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(Color.secondary)
            }
        }
        .position(node.center)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(node.item)
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                onOpen(node.item)
            }
        )
        .help("\(node.item.name) — \(FileManager.formatSize(node.item.size))")
    }

    private func layoutMindMap(root: DiskItem, center: CGPoint, maxRadius: CGFloat) -> MindTree {
        guard let children = root.children?.filter({ $0.size > 0 }), !children.isEmpty else {
            return MindTree(nodes: [], branches: [])
        }

        var nodes: [MindNode] = []
        var branches: [BranchLine] = []

        let topChildren = Array(children.sorted(by: { $0.size > $1.size }).prefix(12))
        let count = topChildren.count
        let total = topChildren.reduce(0.0) { $0 + Double($1.size) }

        for (index, child) in topChildren.enumerated() {
            let angle = (Double(index) / Double(count)) * 2 * .pi - (.pi / 2)
            let r1 = maxRadius * 0.55
            let p1 = CGPoint(
                x: center.x + CGFloat(cos(angle)) * r1,
                y: center.y + CGFloat(sin(angle)) * r1
            )

            let weight = total > 0 ? Double(child.size) / total : 0.1
            let radius1 = max(8, min(24, CGFloat(sqrt(weight) * 32)))
            let color = DiskPalette.color(for: child, mode: coloringMode)

            // Branch from root to child
            let ctrl = CGPoint(
                x: center.x + CGFloat(cos(angle + 0.15)) * (r1 * 0.5),
                y: center.y + CGFloat(sin(angle + 0.15)) * (r1 * 0.5)
            )
            branches.append(BranchLine(
                start: center,
                end: p1,
                control: ctrl,
                color: color,
                width: max(1.5, CGFloat(weight * 5))
            ))

            nodes.append(MindNode(
                item: child,
                center: p1,
                radius: radius1,
                labelAngle: angle
            ))

            // Sub-branches (Level 2)
            if let subChildren = child.children?.prefix(3), !subChildren.isEmpty {
                for (sIdx, sub) in subChildren.enumerated() {
                    let subAngle = angle + (Double(sIdx - 1) * 0.22)
                    let r2 = maxRadius * 0.90
                    let p2 = CGPoint(
                        x: center.x + CGFloat(cos(subAngle)) * r2,
                        y: center.y + CGFloat(sin(subAngle)) * r2
                    )
                    let subRadius: CGFloat = 6

                    let subCtrl = CGPoint(
                        x: p1.x + CGFloat(cos(subAngle)) * ((r2 - r1) * 0.5),
                        y: p1.y + CGFloat(sin(subAngle)) * ((r2 - r1) * 0.5)
                    )
                    branches.append(BranchLine(
                        start: p1,
                        end: p2,
                        control: subCtrl,
                        color: color.opacity(0.7),
                        width: 1.2
                    ))

                    nodes.append(MindNode(
                        item: sub,
                        center: p2,
                        radius: subRadius,
                        labelAngle: subAngle
                    ))
                }
            }
        }

        return MindTree(nodes: nodes, branches: branches)
    }
}
