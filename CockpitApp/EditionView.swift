import CockpitCore
import SwiftUI

struct EditionView: View {
  @Bindable var model: EditionModel

  var body: some View {
    List {
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
              NavigationLink {
                ReaderView(model: model, entryID: row.id)
              } label: {
                EditionRowView(row: row)
              }
            }
          }
        }
      }
    }
    .overlay {
      if model.edition == nil, !model.isComposing {
        ContentUnavailableView(
          "No Edition Yet", systemImage: "newspaper",
          description: Text("Compose today's Edition to see what's worth reading."))
      }
    }
    .navigationTitle("Edition")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        if model.isComposing {
          ProgressView()
        } else {
          Button("Compose", systemImage: "arrow.clockwise") {
            Task { await model.composeIfNeeded() }
          }
        }
      }
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
