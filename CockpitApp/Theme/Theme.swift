import SwiftUI

enum Theme {
  static let paper = Color("Paper")
  static let paperSecondary = Color("PaperSecondary")
  static let ink = Color("Ink")
  static let inkSecondary = Color("InkSecondary")
  static let inkTertiary = Color("InkTertiary")
  static let rule = Color("Rule")
  static let ground = Color("Ground")

  static let accent = Color.accentColor

  // These blends use the semantic endpoints so the chips follow both accent appearances.
  static let accentSoft = accent.mix(with: paper, by: 0.86)
  static let accentInk = accent.mix(with: ink, by: 0.24)

  // These values follow the mockup's section and row spacing in points.
  static let sectionSpacing: CGFloat = 14
  static let sectionLabelRuleSpacing: CGFloat = 5
  static let rowTopPadding: CGFloat = 6
  static let rowBottomPadding: CGFloat = 7
  static let rowBylineSpacing: CGFloat = 1

  static let readingMeasure: CGFloat = 620

  static let masthead = Font.custom("Newsreader16pt-Italic", size: 40, relativeTo: .largeTitle)
  static let leadHeadline = Font.custom("Newsreader16pt-Regular", size: 23, relativeTo: .title)
    .weight(.medium)
  static let headline = Font.custom("Newsreader16pt-Regular", size: 16, relativeTo: .headline)
    .weight(.medium)
  static let queueHeadline = Font.custom("Newsreader16pt-Regular", size: 14.5, relativeTo: .subheadline)
    .weight(.medium)
  static let queueTitle = Font.custom("Newsreader16pt-Italic", size: 24, relativeTo: .title)
    .weight(.medium)
  static let articleTitle = Font.custom("Newsreader16pt-Regular", size: 30, relativeTo: .largeTitle)
    .weight(.medium)
  static let nextHeadline = Font.custom("Newsreader16pt-Regular", size: 21, relativeTo: .title)
    .weight(.medium)
  static let lede = Font.custom("Newsreader16pt-Italic", size: 15.5, relativeTo: .body)

  static let sectionLabel = Font.caption2.weight(.bold)
  static let byline = Font.caption
  static let meta = Font.caption2.monospacedDigit()
}
