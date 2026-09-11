import SwiftUI

/// Circle-packing bubble chart matching DiskBuddy Bubbles mode (Screenshot 4).
public struct DiskBubblesView: View {
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
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let children = (root.children ?? []).filter { $0.size > 0 }.sorted { $0.size > $1.size }
            let bubbles = layoutBubbles(items: children, center: center, maxRadius: size * 0.46)

            ZStack {
                // Background subtle ring
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    .frame(width: size * 0.94, height: size * 0.94)
                    .position(center)

                // Render packed bubbles
                ForEach(bubbles) { bubble in
                    bubbleView(bubble: bubble)
                }
            }
        }
    }

    private struct BubbleNode: Identifiable {
        var id: UUID { item.id }
        let item: DiskItem
        let center: CGPoint
        let radius: CGFloat
        let childrenBubbles: [BubbleNode]
    }

    private func bubbleView(bubble: BubbleNode) -> some View {
        let isSelected = selectedItem?.id == bubble.item.id
        let color = DiskPalette.color(for: bubble.item, mode: coloringMode)

        return ZStack {
            // Main bubble circle
            Circle()
                .fill(color.opacity(0.45))
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.accentColor : color.opacity(0.8), lineWidth: isSelected ? 2.5 : 1)
                )
                .frame(width: bubble.radius * 2, height: bubble.radius * 2)

            // Nested child bubbles
            ForEach(bubble.childrenBubbles) { child in
                Circle()
                    .fill(DiskPalette.color(for: child.item, mode: coloringMode).opacity(0.55))
                    .frame(width: child.radius * 2, height: child.radius * 2)
                    .position(child.center)
            }

            // Title label
            if bubble.radius > 26 {
                VStack(spacing: 2) {
                    Text(bubble.item.name)
                        .font(.system(size: min(12, bubble.radius * 0.28), weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if bubble.radius > 38 {
                        Text(FileManager.formatSize(bubble.item.size))
                            .font(.system(size: min(10, bubble.radius * 0.22), weight: .medium, design: .rounded))
                            .foregroundStyle(Color.secondary)
                    }
                }
                .padding(4)
            }
        }
        .position(bubble.center)
        .contentShape(Circle())
        .onTapGesture {
            onSelect(bubble.item)
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                onOpen(bubble.item)
            }
        )
        .help("\(bubble.item.name) — \(FileManager.formatSize(bubble.item.size))")
    }

    /// Pack circles in spiral outward from center weighted by square root of size
    private func layoutBubbles(items: [DiskItem], center: CGPoint, maxRadius: CGFloat) -> [BubbleNode] {
        guard !items.isEmpty else { return [] }
        let total = items.reduce(0.0) { $0 + Double($1.size) }
        guard total > 0 else { return [] }

        var result: [BubbleNode] = []
        let topItems = Array(items.prefix(16))
        var currentAngle: Double = 0.0

        for (index, item) in topItems.enumerated() {
            let weight = Double(item.size) / total
            let bubbleRadius = max(18, min(maxRadius * 0.55, maxRadius * CGFloat(sqrt(weight)) * 1.1))

            let distance = index == 0 ? 0 : min(maxRadius - bubbleRadius, CGFloat(index) * (maxRadius * 0.16) + bubbleRadius * 0.6)
            let x = center.x + CGFloat(cos(currentAngle)) * distance
            let y = center.y + CGFloat(sin(currentAngle)) * distance
            currentAngle += 2.39996 // Golden ratio angle

            // Sub-bubbles for prominent children
            var subBubbles: [BubbleNode] = []
            if let children = item.children, !children.isEmpty, bubbleRadius > 35 {
                let subTotal = children.reduce(0.0) { $0 + Double($1.size) }
                if subTotal > 0 {
                    var subAngle = 0.0
                    for sub in children.prefix(4) {
                        let subWeight = Double(sub.size) / subTotal
                        let subRadius = max(6, bubbleRadius * CGFloat(sqrt(subWeight)) * 0.5)
                        let subDist = bubbleRadius * 0.45
                        let sx = bubbleRadius + CGFloat(cos(subAngle)) * subDist
                        let sy = bubbleRadius + CGFloat(sin(subAngle)) * subDist
                        subAngle += 1.8
                        subBubbles.append(BubbleNode(item: sub, center: CGPoint(x: sx, y: sy), radius: subRadius, childrenBubbles: []))
                    }
                }
            }

            result.append(BubbleNode(
                item: item,
                center: CGPoint(x: x, y: y),
                radius: bubbleRadius,
                childrenBubbles: subBubbles
            ))
        }

        return result
    }
}
