import CockpitCore
import LazyState
import SwiftUI

struct ReaderView: View {
  let contentPieceID: ContentPiece.ID
  let editionContext: EditionReaderContext?
  let isReachableStreamPiece: Bool
  @LazyState private var model: ContentPieceReaderModel
  @Environment(\.dismiss) private var dismissScreen
  @Environment(\.openURL) private var openURL
  @State private var correctingClaim: PersonalKnowledgeRequest.Row?
  @State private var offlineSheet: OfflineAvailabilitySheet?

  init(
    contentPieceID: ContentPiece.ID,
    editionContext: EditionReaderContext? = nil,
    isReachableStreamPiece: Bool = false
  ) {
    self.contentPieceID = contentPieceID
    self.editionContext = editionContext
    self.isReachableStreamPiece = isReachableStreamPiece
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

          ReaderSummaryView(
            summary: row.summary,
            isCompactPreview: row.isSubstantivePrimary == false
          )

          ReaderClassificationStatus(
            isSubstantivePrimary: row.isSubstantivePrimary,
            bodyCompleteness: row.bodyCompleteness,
            correct: { value in
              Task { await model.correctIsSubstantivePrimary(to: value) }
            }
          )

          ReaderBodyView(
            presentation: model.bodyPresentation,
            canonicalURL: row.canonicalURL,
            openURL: openURL
          )

          if isReachableStreamPiece { ReaderCustodyLine() }

          Divider()

          ReaderActionControls(
            editionContext: editionContext,
            dismissScreen: dismissScreen,
            saveForLater: saveForLaterButtonTapped,
            addToLibrary: addToLibraryButtonTapped,
            offlinePresentation: model.offlinePresentation,
            chooseOfflineUntil: {
              offlineSheet = .until
            },
            keepOffline: { Task { await model.keepOffline() } },
            releaseOffline: { Task { await model.releaseOffline() } },
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
    .toolbar { ReaderDispositionToolbar(model: model) }
    .task { await readerAppeared() }
    .sheet(item: $model.teachingStage) { stage in
      ReaderTeachingView(model: model, stage: stage)
    }
    .sheet(item: $correctingClaim) { claim in
      ReaderPersonalKnowledgeCorrectionView(claim: claim)
    }
    .sheet(item: $offlineSheet) { sheet in
      switch sheet {
      case .until:
        OfflineUntilSheet(model: model)
      }
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

}

private extension ReaderView {
  func readerAppeared() async {
    try? await model.$content.load()
    try? await model.$readerTeaching.load()
    try? await model.$matchedPersonalKnowledge.load()
    if let editionContext {
      await editionContext.model.markSeen(editionContext.entryID)
    }
  }

  func saveForLaterButtonTapped() async {
    if let editionContext {
      await editionContext.model.saveForLater(editionContext.entryID)
      if editionContext.model.errorMessage == nil {
        editionContext.clearSelection()
      }
    } else {
      await model.saveForLater()
    }
  }

  func addToLibraryButtonTapped() async {
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
  /// The parent list owns split-view selection. Clearing it after a terminal tail action prevents
  /// a regular-width detail column from re-rendering the resolved row as a plain Reader.
  let clearSelection: @MainActor () -> Void
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
  let offlinePresentation: OfflineAvailabilityPresentation
  let chooseOfflineUntil: () -> Void
  let keepOffline: () -> Void
  let releaseOffline: () -> Void
  let beginTeaching: () -> Void
  let readerTaughtClaim: PersonalKnowledgeRequest.Row?
  let correctClaim: (PersonalKnowledgeRequest.Row) -> Void

  var body: some View {
    HStack(spacing: 20) {
      if let editionContext {
        Button("Dismiss", systemImage: "xmark.circle") {
          Task {
            await editionContext.model.dismiss(editionContext.entryID)
            if editionContext.model.errorMessage == nil {
              editionContext.clearSelection()
              dismissScreen()
            }
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

    OfflineAvailabilityControls(
      presentation: offlinePresentation,
      chooseOfflineUntil: chooseOfflineUntil,
      keepOffline: keepOffline,
      releaseOffline: releaseOffline
    )

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
