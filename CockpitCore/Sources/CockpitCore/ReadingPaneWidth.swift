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

  /// The list stays fixed while a drag is in progress. Commit only a genuinely changed width.
  public static func committedWidth(current: CGFloat, translation: CGFloat) -> CGFloat? {
    let result = clamped(current + translation)
    return result == current ? nil : result
  }
}
