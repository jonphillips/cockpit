import CockpitCore
import SwiftUI

enum OfflineAvailabilitySheet: Identifiable {
  case until

  var id: String { "offline-until" }
}

struct OfflineAvailabilityControls: View {
  let presentation: OfflineAvailabilityPresentation
  let chooseOfflineUntil: () -> Void
  let keepOffline: () -> Void
  let releaseOffline: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      status
      HStack(spacing: 12) {
        Button("Offline until", systemImage: "calendar") { chooseOfflineUntil() }
        Button("Keep Offline", systemImage: "pin") { keepOffline() }
        if presentation.isActivePromise {
          Button("Stop Keeping Offline", systemImage: "pin.slash") { releaseOffline() }
        }
      }
      .buttonStyle(.bordered)
      .font(.subheadline)
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Offline availability")
  }

  @ViewBuilder
  private var status: some View {
    switch presentation {
    case let .offlineUntil(expiry):
      Label("Available offline until \(expiry.formatted(date: .abbreviated, time: .omitted))", systemImage: "checkmark.circle.fill")
        .foregroundStyle(.green)
    case .keptOffline:
      Label("Kept offline on this device", systemImage: "pin.fill")
        .foregroundStyle(.green)
    case let .expired(expiry):
      Label("Offline availability expired \(expiry.formatted(date: .abbreviated, time: .omitted))", systemImage: "clock.badge.exclamationmark")
        .foregroundStyle(.secondary)
    case .ordinaryCache:
      EmptyView()
    }
  }
}

struct OfflineUntilSheet: View {
  @Environment(\.dismiss) private var dismiss
  let model: ContentPieceReaderModel
  @State private var expiry: Date

  init(model: ContentPieceReaderModel) {
    self.model = model
    _expiry = State(initialValue: OfflineAvailabilityDate.defaultExpiry(from: .now))
  }

  var body: some View {
    NavigationStack {
      Form {
        DatePicker(
          "Available until", selection: $expiry,
          in: firstAvailableDate...,
          displayedComponents: .date)
        Text("Cockpit will retain the local substance through this date.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      .navigationTitle("Offline Availability")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Keep Offline") {
            Task { await model.keepOffline(until: expiry) }
            dismiss()
          }
        }
      }
    }
  }

  private var firstAvailableDate: Date {
    Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
  }
}

private enum OfflineAvailabilityDate {
  static func defaultExpiry(from date: Date) -> Date {
    Calendar.current.date(byAdding: .day, value: 30, to: date) ?? date
  }
}
