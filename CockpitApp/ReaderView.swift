import CockpitCore
import LazyState
import SwiftUI

struct ReaderView: View {
  let contentPieceID: ContentPiece.ID
  let editionContext: EditionReaderContext?
  @LazyState private var model: ContentPieceReaderModel
  @Environment(\.dismiss) private var dismissScreen
  @Environment(\.openURL) private var openURL
  @State private var correctingClaim: PersonalKnowledgeRequest.Row?

  init(contentPieceID: ContentPiece.ID, editionContext: EditionReaderContext? = nil) {
    self.contentPieceID = contentPieceID
    self.editionContext = editionContext
    _model = LazyState {
      ContentPieceReaderModel(
        contentPieceID: contentPieceID,
        matchedPersonalKnowledgeClaimID: editionContext?.matchedPersonalKnowledgeClaimID
      )
    }
  }

  var body: some View {
    @Bindable var model = model
    ScrollView {
      if let row = model.row {
        VStack(alignment: .leading, spacing: 16) {
          VStack(alignment: .leading, spacing: 4) {
            Text(row.title).font(.title2).bold()
            Text(row.publisher).foregroundStyle(.secondary)
          }

          if let rationale = editionContext?.rationale, !rationale.isEmpty {
            ReaderRationaleView(rationale: rationale, matchedClaim: model.matchedClaim) {
              correctingClaim = $0
            }
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
                Task { await model.correctIsSubstantivePrimary(to: !isSubstantivePrimary) }
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

          ReaderActionControls(
            editionContext: editionContext,
            dismissScreen: dismissScreen,
            saveForLater: saveForLaterButtonTapped,
            addToLibrary: addToLibraryButtonTapped,
            beginTeaching: model.beginTeaching,
            readerTaughtClaim: model.readerTaughtClaim,
            correctClaim: { correctingClaim = $0 }
          )
        }
        .padding()
      } else {
        ContentUnavailableView("Not Found", systemImage: "questionmark.circle")
      }
    }
    .navigationTitle("Reader")
    .navigationBarTitleDisplayMode(.inline)
    .task { await readerAppeared() }
    .sheet(item: $model.teachingStage) { stage in
      ReaderTeachingView(model: model, stage: stage)
    }
    .sheet(item: $correctingClaim) { claim in
      ReaderPersonalKnowledgeCorrectionView(claim: claim)
    }
    .safeAreaInset(edge: .bottom) {
      if let error = model.errorMessage ?? editionContext?.model.errorMessage {
        HStack {
          Text(error)
          Spacer()
          Button("Dismiss") {
            model.errorMessage = nil
            editionContext?.model.errorMessage = nil
          }
        }
        .padding()
        .background(.regularMaterial)
      }
    }
  }

  private func readerAppeared() async {
    try? await model.$content.load()
    try? await model.$readerTeaching.load()
    try? await model.$matchedPersonalKnowledge.load()
    if let editionContext {
      await editionContext.model.markSeen(editionContext.entryID)
    }
  }

  private func saveForLaterButtonTapped() async {
    if let editionContext {
      await editionContext.model.saveForLater(editionContext.entryID)
    } else {
      await model.saveForLater()
    }
  }

  private func addToLibraryButtonTapped() async {
    if let editionContext {
      await editionContext.model.addToLibrary(editionContext.entryID)
    } else {
      await model.addToLibrary()
    }
  }
}

struct EditionReaderContext {
  let model: EditionModel
  let entryID: EditionEntry.ID
  let rationale: String?
  let matchedPersonalKnowledgeClaimID: PersonalKnowledgeClaim.ID?
}

private struct ReaderRationaleView: View {
  let rationale: String
  let matchedClaim: PersonalKnowledgeRequest.Row?
  let correctClaim: (PersonalKnowledgeRequest.Row) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Why you're seeing this").font(.caption).foregroundStyle(.secondary)
      Text(rationale)
      if let matchedClaim {
        Button("Correct this understanding", systemImage: "pencil") {
          correctClaim(matchedClaim)
        }
        .font(.caption)
        .accessibilityHint("Correct the Personal Knowledge claim named by this explanation")
      }
    }
    .padding()
    .background(.thinMaterial, in: .rect(cornerRadius: 12))
  }
}

private struct ReaderActionControls: View {
  let editionContext: EditionReaderContext?
  let dismissScreen: DismissAction
  let saveForLater: () async -> Void
  let addToLibrary: () async -> Void
  let beginTeaching: () -> Void
  let readerTaughtClaim: PersonalKnowledgeRequest.Row?
  let correctClaim: (PersonalKnowledgeRequest.Row) -> Void

  var body: some View {
    HStack(spacing: 20) {
      if let editionContext {
        Button("Dismiss", systemImage: "xmark.circle") {
          Task {
            await editionContext.model.dismiss(editionContext.entryID)
            dismissScreen()
          }
        }
      }
      Button("Save for Later", systemImage: "clock") {
        Task { await saveForLater() }
      }
      Button("Add to Library", systemImage: "books.vertical") {
        Task { await addToLibrary() }
      }
    }
    .buttonStyle(.bordered)
    .font(.subheadline)

    VStack(alignment: .leading, spacing: 8) {
      Button("Tell Cockpit why this matters", systemImage: "lightbulb", action: beginTeaching)
      if let readerTaughtClaim {
        Button("Correct this understanding", systemImage: "pencil") {
          correctClaim(readerTaughtClaim)
        }
      }
    }
    .buttonStyle(.bordered)
    .font(.subheadline)
  }
}
