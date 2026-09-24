import SwiftUI

/// The reading list's resize handle. The list resizes live under the finger: the parent owns the drag
/// state and writes the stored width as the drag moves.
struct ReadingDividerHandle: View {
  let isDragging: Bool
  let onChanged: (CGFloat) -> Void
  let onEnded: () -> Void

  var body: some View {
    Rectangle()
      .fill(.clear)
      .frame(width: 24)
      .contentShape(Rectangle())
      .overlay {
        Capsule()
          .fill(isDragging ? .secondary : .quaternary)
          .frame(width: 4, height: 36)
      }
      .gesture(
        DragGesture(minimumDistance: 1)
          .onChanged { onChanged($0.translation.width) }
          .onEnded { _ in onEnded() }
      )
      .accessibilityElement()
      .accessibilityLabel("Reading list divider")
      .accessibilityHint("Drag to resize the reading list")
  }
}
