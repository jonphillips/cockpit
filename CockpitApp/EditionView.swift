import CockpitCore
import SwiftUI

struct EditionView: View {
  @Bindable var model: EditionModel
  @State private var isConfirmingRecompose = false

  var body: some View {
    NavigationSplitView {
      List(selection: $model.selectedEntryID) {
        if let edition = model.edition {
          Section {
            LabeledContent("State", value: edition.state.rawValue.capitalized)
            if let cost = edition.estimatedCostUSD {
              LabeledContent("Estimated cost", value: cost, format: .currency(code: "USD"))
            }
          }
        }

        ForEach(sections, id: \.self) { section in
          let rows = model.entries.filter { $0.section == section && $0.entryState != .dismissed }
          if !rows.isEmpty {
            Section(sectionTitle(section)) {
              ForEach(rows) { row in
                EditionRowView(row: row)
                  .tag(row.id)
              }
            }
          }
        }
      }
      .overlay {
        if model.isComposing {
          // No overlay — the toolbar's ProgressView already communicates this, and a real
          // composition can take 60–120s (S2 measurement).
        } else if model.edition == nil {
          ContentUnavailableView(
            "No Edition Yet", systemImage: "newspaper",
            description: Text("Compose today's Edition to see what's worth reading."))
        } else if model.entries.isEmpty {
          ContentUnavailableView {
            Label("Nothing Admitted", systemImage: "newspaper")
          } description: {
            Text("Today's Edition composed, but nothing met the bar for admission.")
          } actions: {
            Button("Recompose") { isConfirmingRecompose = true }
          }
        }
      }
      .navigationTitle("Edition")
    } detail: {
      if let entryID = model.selectedEntryID,
        let row = model.entries.first(where: { $0.id == entryID })
      {
        ReaderView(
          contentPieceID: row.contentPieceID,
          editionContext: EditionReaderContext(
            model: model, entryID: row.id, rationale: row.rationale,
            matchedPersonalKnowledgeClaimID: row.matchedPersonalKnowledgeClaimID
          ))
          .id(row.contentPieceID)
      } else {
        ContentUnavailableView("Select a Story", systemImage: "newspaper")
      }
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        if model.isComposing {
          ProgressView()
        } else if model.edition == nil {
          Button("Compose", systemImage: "sparkles") {
            Task { await model.composeIfNeeded() }
          }
        } else {
          Button("Recompose", systemImage: "arrow.clockwise") {
            isConfirmingRecompose = true
          }
        }
      }
    }
    .confirmationDialog(
      "Recompose today's Edition?", isPresented: $isConfirmingRecompose, titleVisibility: .visible
    ) {
      Button("Recompose", role: .destructive) { Task { await model.recompose() } }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This discards today's Edition and judges the day's candidates again from scratch.")
    }
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

  private var sections: [JudgmentSection] {
    [.essentials, .forYou, .interestArea, .essentialBacklog]
  }

  private func sectionTitle(_ section: JudgmentSection) -> String {
    switch section {
    case .essentials: "Essentials"
    case .forYou: "For You"
    case .interestArea: "Interest Areas"
    case .essentialBacklog: "Essential Backlog"
    }
  }
}

private struct EditionRowView: View {
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
  }
}
