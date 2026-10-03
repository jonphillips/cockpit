import Foundation

public struct ListedFeedDayGroup: Equatable, Identifiable, Sendable {
  public let id: Date
  public let title: String
  public let items: [ListedFeedsRequest.Item]
}

public enum ListedFeedGrouping {
  public static func dayGroups(
    _ items: [ListedFeedsRequest.Item], now: Date, calendar: Calendar
  ) -> [ListedFeedDayGroup] {
    let grouped = Dictionary(grouping: items) { calendar.startOfDay(for: $0.listedDate) }
    return grouped.keys.sorted(by: >).compactMap { day in
      guard let dayItems = grouped[day] else { return nil }
      return ListedFeedDayGroup(
        id: day, title: dayTitle(for: day, now: now, calendar: calendar),
        items: dayItems.sorted { $0.listedDate > $1.listedDate })
    }
  }

  public static func dayTitle(for date: Date, now: Date, calendar: Calendar) -> String {
    if calendar.isDate(date, inSameDayAs: now) { return "Today" }
    if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
      calendar.isDate(date, inSameDayAs: yesterday)
    { return "Yesterday" }
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = .current
    formatter.dateFormat = "EEEE"
    return formatter.string(from: date)
  }
}
