import CockpitCore
import SwiftUI

struct TodayView: View {
  @Bindable var model: TodayModel

  var body: some View {
    NavigationSplitView {
      List(selection: $model.selectedContentPieceID) {
        ForEach(model.tiers) { tier in
          Section(tier.title) {
            ForEach(tier.rows) { row in
              TodayRowView(row: row)
                .tag(row.id)
                .swipeActions {
                  Button("Clear", systemImage: "checkmark.circle", role: .destructive) {
                    Task { await model.clear(row) }
                  }
                }
            }
          }
        }
      }
      .overlay {
        if model.tiers.isEmpty {
          ContentUnavailableView(
            "Nothing to Review", systemImage: "sun.max",
            description: Text("Gmail messages will appear here by their treatment."))
        }
      }
      .navigationTitle("Today")
    } detail: {
      if let contentPieceID = model.selectedContentPieceID {
        // No Edition context means email pieces cannot acquire rationale or Dismiss affordances.
        ReaderView(contentPieceID: contentPieceID)
          .id(contentPieceID)
      } else {
        ContentUnavailableView("Select a Message", systemImage: "envelope")
      }
    }
    .task { try? await model.$content.load() }
    .safeAreaInset(edge: .bottom) {
      if let error = model.errorMessage {
        HStack {
          Text(error)
          Spacer()
          Button("Dismiss") { model.errorMessage = nil }
        }
        .padding()
        .background(.regularMaterial)
      }
    }
  }
}

private struct TodayRowView: View {
  let row: TodayRequest.Row

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(row.title)
        .font(row.treatment == .personal ? .title3.weight(.semibold) : .headline)
      Text(row.publisher)
        .font(.subheadline)
        .foregroundStyle(.secondary)
      if let summary = row.summary, !summary.isEmpty {
        Text(summary)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(row.treatment == .personal ? 3 : 2)
      }
      Text(row.arrivedAt, format: .dateTime.month().day().hour().minute())
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
    .padding(row.treatment == .personal ? 8 : 0)
    .background {
      if row.treatment == .personal {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(.thinMaterial)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityHint("Open in Reader. Swipe for Clear.")
  }
}
