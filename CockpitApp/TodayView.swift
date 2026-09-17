import CockpitCore
import SwiftUI

struct TodayView: View {
  @Bindable var model: TodayModel
  @Bindable var tailModel: EditionModel
  @State private var isConfirmingTailRecompose = false

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
        if !tailRows.isEmpty {
          Section("From the Tail") {
            ForEach(tailRows) { row in
              TailRowView(row: row)
                .tag(row.contentPieceID)
            }
          }
        }
      }
      .overlay {
        if model.tiers.isEmpty && tailRows.isEmpty && !tailModel.isComposing {
          ContentUnavailableView(
            "Nothing to Review", systemImage: "sun.max",
            description: Text("Gmail messages and screened tail stories will appear here."))
        }
      }
      .navigationTitle("Today")
    } detail: {
      if let contentPieceID = model.selectedContentPieceID {
        if let tailRow = tailRows.first(where: { $0.contentPieceID == contentPieceID }) {
          ReaderView(
            contentPieceID: contentPieceID,
            editionContext: EditionReaderContext(
              model: tailModel, entryID: tailRow.id, rationale: tailRow.rationale,
              matchedPersonalKnowledgeClaimID: tailRow.matchedPersonalKnowledgeClaimID
            ))
            .id(contentPieceID)
        } else {
          // No Edition context means curated email cannot acquire rationale or Dismiss affordances.
          ReaderView(contentPieceID: contentPieceID)
            .id(contentPieceID)
        }
      } else {
        ContentUnavailableView("Select Something", systemImage: "sun.max")
      }
    }
    .task {
      try? await model.$content.load()
      await tailModel.composeIfNeeded()
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        if tailModel.isComposing {
          ProgressView()
        } else if tailModel.edition == nil {
          Button("Compose Tail", systemImage: "sparkles") {
            Task { await tailModel.composeIfNeeded() }
          }
        } else {
          Button("Recompose Tail", systemImage: "arrow.clockwise") {
            isConfirmingTailRecompose = true
          }
        }
      }
    }
    .confirmationDialog(
      "Recompose the tail?", isPresented: $isConfirmingTailRecompose, titleVisibility: .visible
    ) {
      Button("Recompose Tail", role: .destructive) { Task { await tailModel.recompose() } }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This discards today's screened tail and judges its candidates again from scratch.")
    }
    .safeAreaInset(edge: .bottom) {
      if model.errorMessage != nil || tailModel.errorMessage != nil {
        HStack {
          Text(model.errorMessage ?? tailModel.errorMessage ?? "")
          Spacer()
          Button("Dismiss") {
            model.errorMessage = nil
            tailModel.errorMessage = nil
          }
        }
        .padding()
        .background(.regularMaterial)
      }
    }
  }

  private var tailRows: [CurrentEditionRequest.Row] {
    tailModel.entries.filter { $0.entryState == .admitted || $0.entryState == .seen }
  }
}

private struct TailRowView: View {
  let row: CurrentEditionRequest.Row

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(row.title).font(.headline)
      Text(row.publisher).font(.subheadline).foregroundStyle(.secondary)
      if let rationale = row.rationale, !rationale.isEmpty {
        Text(rationale).font(.caption).foregroundStyle(.secondary).lineLimit(2)
      }
      if row.entryState == .seen {
        Text("Seen").font(.caption2).foregroundStyle(.tertiary)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityHint("Open in Reader.")
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
      if let treatmentSummary = row.treatmentSummary {
        Text(treatmentSummary)
          .font(.subheadline)
          .foregroundStyle(.primary)
          .lineLimit(2)
      }
      if let summary = row.summary, !summary.isEmpty {
        Text(summary)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(row.treatment == .personal ? 3 : 2)
      }
      if !row.grabBagItems.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          ForEach(row.grabBagItems) { item in
            VStack(alignment: .leading, spacing: 2) {
              Text(item.title).font(.subheadline.weight(.semibold))
              Text(item.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
          }
        }
        .padding(.top, 4)
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
