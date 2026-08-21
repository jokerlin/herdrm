import AppKit
import SwiftUI

/// A two-pane split that actually opens at 50/50. AppKit's `HSplitView` sizes
/// panes from their intrinsic preferences on first layout — with terminals
/// (no intrinsic size) the second pane collapsed to its minimum — so this
/// lays the panes out from an explicit ratio instead, with a draggable
/// background-colored divider.
///
/// `showSecond` collapses the split to just the first pane *without changing
/// the view tree's structure*: the first pane keeps its identity (and its
/// live terminal NSView) as splits open and close. Swapping whole layout
/// shapes instead used to rebuild the agent terminal — a full re-attach and
/// a white flash — on every ⌘D.
struct DraggableSplit<First: View, Second: View>: View {
    enum Axis { case horizontal, vertical }

    let axis: Axis
    let showSecond: Bool
    @ViewBuilder let first: () -> First
    @ViewBuilder let second: () -> Second

    @State private var ratio: CGFloat = 0.5
    @State private var dragBase: CGFloat?

    private static var dividerThickness: CGFloat { 8 }
    private static var minFraction: CGFloat { 0.15 }

    var body: some View {
        GeometryReader { proxy in
            let full = axis == .horizontal ? proxy.size.width : proxy.size.height
            let total = max(0, full - Self.dividerThickness)
            let firstLength = showSecond ? (total * ratio).rounded() : full
            if axis == .horizontal {
                HStack(spacing: 0) {
                    first().frame(width: firstLength)
                    if showSecond {
                        divider(total: total)
                        second().frame(width: total - firstLength)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    first().frame(height: firstLength)
                    if showSecond {
                        divider(total: total)
                        second().frame(height: total - firstLength)
                    }
                }
            }
        }
    }

    private func divider(total: CGFloat) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(
                width: axis == .horizontal ? Self.dividerThickness : nil,
                height: axis == .vertical ? Self.dividerThickness : nil
            )
            .contentShape(Rectangle())
            .onHover { inside in
                if inside {
                    (axis == .horizontal ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard total > 0 else { return }
                        let base = dragBase ?? ratio
                        dragBase = base
                        let delta = axis == .horizontal ? value.translation.width : value.translation.height
                        ratio = min(max(base + delta / total, Self.minFraction), 1 - Self.minFraction)
                    }
                    .onEnded { _ in dragBase = nil }
            )
    }
}
