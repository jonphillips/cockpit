import Foundation

/// Shared arrival-date rule for message lists and the Reader.
public enum ReceivedDate {
  public static func resolve(
    publishedAt: Date?, artifactAcquiredAt: Date?, createdAt: Date
  ) -> Date {
    publishedAt ?? artifactAcquiredAt ?? createdAt
  }
}

/// Short, calendar-aware age note for the top of the Reader.
public enum ReceivedAgeLabel {
  public static func text(
    received: Date,
    now: Date,
    calendar: Calendar = .current
  ) -> String {
    let receivedDay = calendar.startOfDay(for: received)
    let currentDay = calendar.startOfDay(for: now)
    let dayDistance = calendar.dateComponents([.day], from: receivedDay, to: currentDay).day ?? 0
    if dayDistance <= 0 {
      let seconds = max(0, now.timeIntervalSince(received))
      let age: String
      if seconds < 60 {
        age = "Just now"
      } else if seconds < 3_600 {
        age = "\(Int(seconds / 60)) minutes ago"
      } else {
        let hours = Int(seconds / 3_600)
        age = hours == 1 ? "1 hour ago" : "\(hours) hours ago"
      }
      return "Today · \(age)"
    }

    if dayDistance == 1 {
      return "Yesterday · \(dateText(received, calendar: calendar, includeYear: false))"
    }
    let includeYear = calendar.component(.year, from: received) != calendar.component(.year, from: now)
    let receivedDate = dateText(received, calendar: calendar, includeYear: includeYear)
    return "\(dayDistance) days ago · \(receivedDate)"
  }

  private static func dateText(
    _ date: Date, calendar: Calendar, includeYear: Bool
  ) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = includeYear ? "MMM d, yyyy" : "MMM d"
    return formatter.string(from: date)
  }
}
