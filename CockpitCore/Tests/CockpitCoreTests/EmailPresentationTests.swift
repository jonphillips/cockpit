import Foundation
import CockpitCore
import Testing

struct EmailPresentationTests {
  @Test("presentation follows the detected design width")
  func kind() {
    #expect(EmailPresentation.kind(html: "<table width='600'><tr><td>News</td></tr></table>") == .designed(width: 600))
    #expect(EmailPresentation.kind(html: "<p>Hello</p><ul><li>There</li></ul>") == .letter)
    #expect(EmailPresentation.kind(html: "plain text") == .letter)
  }

  @Test("dark support is detected without rewriting email HTML")
  func darkSupport() {
    #expect(EmailPresentation.supportsDarkAppearance(html: "<meta name='color-scheme' content='light dark'>"))
    #expect(EmailPresentation.supportsDarkAppearance(html: "<style>@media (prefers-color-scheme: dark) { body { color: white } }</style>"))
    #expect(!EmailPresentation.supportsDarkAppearance(html: "<p>Hello</p>"))
  }

  @Test("letter self-coloring is limited to body and paragraph inline styles")
  func ownColors() {
    #expect(!EmailPresentation.letterSetsOwnColors(html: "<p>Hello</p>"))
    #expect(EmailPresentation.letterSetsOwnColors(html: "<body style='color: #123'><p>Hello</p></body>"))
    #expect(EmailPresentation.letterSetsOwnColors(html: "<p style='background: white'>Hello</p>"))
    #expect(!EmailPresentation.letterSetsOwnColors(html: "<div style='color:red'><p>Hello</p></div>"))
  }
}

struct ProcessNextCardTests {
  @Test("next card position is within the next row's role")
  func nextRowAndRolePosition() {
    let first = row(1, .forYou)
    let second = row(2, .opinion)
    let third = row(3, .opinion)
    let fourth = row(4, .food)

    let card = ProcessNextCard.after(first.id, in: [first, second, third, fourth])

    #expect(card?.row == second)
    #expect(card?.roleIndex == 1)
    #expect(card?.roleCount == 2)
  }

  @Test("last selected row has no next card")
  func queueClear() {
    let row = row(1, .forYou)
    #expect(ProcessNextCard.after(row.id, in: [row]) == nil)
    #expect(ProcessNextCard.after(UUID(), in: [row]) == nil)
  }

  private func row(_ value: UInt8, _ role: ContentRole) -> TodayReadingQueueRequest.Row {
    TodayReadingQueueRequest.Row(
      id: ContentPiece.ID(uuidString: "00000000-0000-0000-0000-00000000000\(value)")!,
      title: "Issue \(value)", publisher: "The Example", role: role,
      arrivedAt: Date(timeIntervalSince1970: TimeInterval(value))
    )
  }
}
