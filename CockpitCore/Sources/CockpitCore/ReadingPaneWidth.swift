import CoreGraphics

/// The bounded width contract for the Today reading queue. The view persists the user's last
/// width, while this pure value keeps a bad stored value or an over-eager drag from collapsing the
/// queue or crowding the Reader.
public enum ReadingPaneWidth {
  public static let minimum: CGFloat = 268
  public static let maximum: CGFloat = 560
  public static let defaultValue: CGFloat = 344

  public static func clamped(_ width: CGFloat) -> CGFloat {
    min(max(width, minimum), maximum)
  }

  /// The live width for a divider drag, or nil when the clamp leaves the current width unchanged,
  /// so a drag pinned at either bound writes nothing.
  public static func draggedWidth(start: CGFloat, translation: CGFloat, current: CGFloat) -> CGFloat? {
    let result = clamped(start + translation)
    return result == current ? nil : result
  }
}
