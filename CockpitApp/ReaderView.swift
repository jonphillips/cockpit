import CockpitCore
import SwiftUI

struct ReaderView: View {
  @Bindable var model: EditionModel
  let entryID: EditionEntry.ID
  @Environment(\.dismiss) private var dismissScreen
  @Environment(\.openURL) private var openURL

  private var row: CurrentEditionRequest.Row? {
    model.entries.first { $0.id == entryID }
  }

  var body: some View {
    ScrollView {
      if let row {
        VStack(alignment: .leading, spacing: 16) {
          VStack(alignment: .leading, spacing: 4) {
            Text(row.title).font(.title2).bold()
            Text(row.publisher).foregroundStyle(.secondary)
          }

          if let rationale = row.rationale, !rationale.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
              Text("Why you're seeing this").font(.caption).foregroundStyle(.secondary)
              Text(rationale)
            }
            .padding()
            .background(.thinMaterial, in: .rect(cornerRadius: 12))
          }

          if let summary = row.summary, !summary.isEmpty {
            Text(summary)
          }

          if let isSubstantivePrimary = row.isSubstantivePrimary {
            HStack {
              Image(systemName: isSubstantivePrimary ? "doc.text.fill" : "list.bullet")
              Text(isSubstantivePrimary ? "Substantive primary piece" : "Accessory / not primary")
              Spacer()
              Button("Correct") {
                Task { await model.correctIsSubstantivePrimary(entryID, to: !isSubstantivePrimary) }
              }
              .font(.caption)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
          }

          if let bodyCompleteness = row.bodyCompleteness, bodyCompleteness != .full {
            Label(bodyCompleteness.readerLabel, systemImage: bodyCompleteness == .teaser ? "rectangle.slash" : "scissors")
              .font(.caption)
              .foregroundStyle(.orange)
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background(.orange.opacity(0.12), in: .capsule)
              .accessibilityLabel("Body completeness: \(bodyCompleteness.readerLabel)")
          }

          if let urlString = row.canonicalURL, let url = URL(string: urlString) {
            Button("Open Original", systemImage: "arrow.up.right.square") { openURL(url) }
          }

          Divider()

          HStack(spacing: 20) {
            Button("Dismiss", systemImage: "xmark.circle") {
              Task {
                await model.dismiss(entryID)
                dismissScreen()
              }
            }
            Button("Save for Later", systemImage: "clock") {
              Task { await model.saveForLater(entryID) }
            }
            Button("Add to Library", systemImage: "books.vertical") {
              Task { await model.addToLibrary(entryID) }
            }
          }
          .buttonStyle(.bordered)
          .font(.subheadline)
        }
        .padding()
      } else {
        ContentUnavailableView("Not Found", systemImage: "questionmark.circle")
      }
    }
    .navigationTitle("Reader")
    .navigationBarTitleDisplayMode(.inline)
    .task { await model.markSeen(entryID) }
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
