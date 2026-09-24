import CockpitCore
import Observation
import SwiftUI

struct ReadingDividerHandle: View {
  let currentWidth: CGFloat
  let dragState: ReadingDividerDragState
  let onCommitWidth: (CGFloat?) -> Void

  var body: some View {
    Rectangle()
      .fill(.clear)
      .frame(width: 24)
      .contentShape(Rectangle())
      .overlay {
        Capsule()
          .fill(.quaternary)
          .frame(width: 4, height: 36)
      }
      .gesture(
        DragGesture(minimumDistance: 1)
          .onChanged { value in
            dragState.update(currentWidth: currentWidth, translation: value.translation.width)
          }
          .onEnded { value in
            onCommitWidth(dragState.finish(translation: value.translation.width))
          }
      )
      .accessibilityElement()
      .accessibilityLabel("Reading list divider")
      .accessibilityHint("Drag to resize the reading list")
  }
}

@Observable
@MainActor
final class ReadingDividerDragState {
  struct Preview: Equatable {
    let startWidth: CGFloat
    var translation: CGFloat
  }

  var preview: Preview?

  func update(currentWidth: CGFloat, translation: CGFloat) {
    if preview == nil {
      preview = Preview(startWidth: currentWidth, translation: translation)
    } else {
      preview?.translation = translation
    }
  }

  func finish(translation: CGFloat) -> CGFloat? {
    guard let preview else { return nil }
    let width = ReadingPaneWidth.committedWidth(
      current: preview.startWidth, translation: translation)
    self.preview = nil
    return width
  }
}

struct ReadingDividerPreviewLine: View {
  @Bindable var dragState: ReadingDividerDragState

  var body: some View {
    GeometryReader { geometry in
      if let preview = dragState.preview {
        Rectangle()
          .fill(.primary.opacity(0.85))
          .frame(width: 2)
          .shadow(color: .black.opacity(0.35), radius: 3)
          .position(
            x: ReadingPaneWidth.clamped(preview.startWidth + preview.translation),
            y: geometry.size.height / 2
          )
      }
    }
    .allowsHitTesting(false)
  }
}
