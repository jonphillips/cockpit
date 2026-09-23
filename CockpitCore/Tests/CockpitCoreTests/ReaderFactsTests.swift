import Foundation
import Testing
@testable import CockpitCore

struct ReaderFactsTests {
  @Test("Sender display names remove email addresses and unquote names")
  func senderDisplayNames() {
    #expect(SenderDisplayName.make(from: "\"Matthew Yglesias\" <m@x.com>") == "Matthew Yglesias")
    #expect(SenderDisplayName.make(from: "Name <addr>") == "Name")
    #expect(SenderDisplayName.make(from: "<addr>") == "addr")
    #expect(SenderDisplayName.make(from: "bare@example.com") == "bare@example.com")
    #expect(SenderDisplayName.make(from: "\"A \\\"quoted\\\" Name\" <a@example.com>") == "A \"quoted\" Name")
    #expect(SenderDisplayName.make(from: "  ") == "")
    #expect(SenderDisplayName.make(from: nil) == "")
    #expect(SenderDisplayName.make(from: "not a header") == "not a header")
  }

  @Test("Received age labels use calendar days and only show hours for today")
  func receivedAgeLabels() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let today = try date(2026, 9, 23, 0, 0, calendar: calendar)
    let time0001 = try date(2026, 9, 23, 0, 1, calendar: calendar)
    let time2359 = try date(2026, 9, 23, 23, 59, calendar: calendar)
    #expect(ReceivedAgeLabel.text(received: time0001, now: time2359, calendar: calendar) == "Today · 23 hours ago")
    #expect(ReceivedAgeLabel.text(
      received: today.addingTimeInterval(59), now: today.addingTimeInterval(118), calendar: calendar
    ) == "Today · Just now")
    #expect(ReceivedAgeLabel.text(
      received: time0001, now: try date(2026, 9, 23, 1, 0, calendar: calendar), calendar: calendar
    ) == "Today · 59 minutes ago")
    #expect(ReceivedAgeLabel.text(
      received: today.addingTimeInterval(60), now: today.addingTimeInterval(3_660), calendar: calendar
    ) == "Today · 1 hour ago")
    let yesterday = try date(2026, 9, 22, 23, 59, calendar: calendar)
    #expect(ReceivedAgeLabel.text(received: yesterday, now: try date(2026, 9, 23, 0, 1, calendar: calendar), calendar: calendar)
      == "Yesterday · Sep 22")
    let fourDaysAgo = try date(2026, 9, 19, 12, 0, calendar: calendar)
    #expect(ReceivedAgeLabel.text(
      received: fourDaysAgo, now: try date(2026, 9, 23, 12, 0, calendar: calendar), calendar: calendar
    ) == "4 days ago · Sep 19")
    let priorYear = try date(2025, 9, 19, 12, 0, calendar: calendar)
    #expect(ReceivedAgeLabel.text(
      received: priorYear, now: try date(2026, 9, 23, 12, 0, calendar: calendar), calendar: calendar
    ) == "369 days ago · Sep 19, 2025")
  }

  @Test("Received date falls back from publication to newest artifact to creation")
  func receivedDateFallbacks() throws {
    let created = Date(timeIntervalSince1970: 1)
    let artifact = Date(timeIntervalSince1970: 2)
    let published = Date(timeIntervalSince1970: 3)
    #expect(ReceivedDate.resolve(publishedAt: published, artifactAcquiredAt: artifact, createdAt: created) == published)
    #expect(ReceivedDate.resolve(publishedAt: nil, artifactAcquiredAt: artifact, createdAt: created) == artifact)
    #expect(ReceivedDate.resolve(publishedAt: nil, artifactAcquiredAt: nil, createdAt: created) == created)
  }

  @Test("Email links leave the Reader only through user-activated web and mail schemes")
  func emailLinkPolicy() {
    for value in [
      "javascript:alert(1)", "file:///tmp/message.html", "data:text/html,hello", "cid:part1",
      "about:blank",
    ] {
      #expect(EmailLinkPolicy.externalURL(for: URL(string: value), isUserActivated: true) == nil)
    }
    #expect(EmailLinkPolicy.externalURL(for: URL(string: "https://example.com/unsubscribe"), isUserActivated: false) == nil)
    #expect(EmailLinkPolicy.externalURL(for: URL(string: "https://example.com/unsubscribe"), isUserActivated: true)?.absoluteString == "https://example.com/unsubscribe")
    #expect(EmailLinkPolicy.externalURL(for: URL(string: "mailto:help@example.com"), isUserActivated: true)?.scheme == "mailto")
    #expect(EmailLinkPolicy.externalURL(for: URL(string: "https:invalid"), isUserActivated: true) == nil)
  }

  private func date(
    _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int,
    calendar: Calendar
  ) throws -> Date {
    try #require(calendar.date(from: DateComponents(
      year: year, month: month, day: day, hour: hour, minute: minute
    )))
  }
}
