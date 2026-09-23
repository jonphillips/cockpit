import CockpitCore
import LazyState
import SwiftUI

struct ReaderView: View {
  let contentPieceID: ContentPiece.ID
  let editionContext: EditionReaderContext?
  let queueContext: ReaderQueueContext?
  let isReachableStreamPiece: Bool
  @State private var originalWebViewStore: TodayOriginalWebViewStore
  @LazyState private var model: ContentPieceReaderModel
  @Environment(\.dismiss) private var dismissScreen
  @Environment(\.openURL) private var openURL
  @State private var correctingClaim: PersonalKnowledgeRequest.Row?
  @State private var offlineSheet: OfflineAvailabilitySheet?
  @State private var replySheet: ReaderReplySheet?
  @FocusState private var isTeachingReasonFocused: Bool

  var body: some View {
    @Bindable var model = model
    ScrollView {
      if let row = model.row {
        VStack(alignment: .leading, spacing: 16) {
          ReaderHeader(row: row, offlinePresentation: model.offlinePresentation)

          if let rationale = editionContext?.rationale, !rationale.isEmpty {
            ReaderRationaleView(rationale: rationale, matchedClaim: model.matchedClaim) {
              correctingClaim = $0
            }
          }

          ReaderSummaryView(
            summary: row.summary,
            isCompactPreview: row.isSubstantivePrimary == false
          )

          if let find = model.pendingFind {
            PendingFindProposalCard(
              find: find,
              save: { Task { await model.confirmPendingFind() } },
              dismiss: { Task { await model.dismissPendingFind() } }
            )
          }

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
            openURL: openURL,
            originalWebViewStore: originalWebViewStore
          )

          if isReachableStreamPiece { ReaderCustodyLine() }
        }
        .padding()
      } else {
        ContentUnavailableView("Not Found", systemImage: "questionmark.circle")
      }
    }
    .toolbar {
      ReaderDispositionToolbar(
        model: model,
        editionContext: editionContext,
        queueContext: queueContext,
        openReply: openReply,
        isTeachingReasonFocused: isTeachingReasonFocused,
        dismissEdition: dismissEditionButtonTapped,
        saveForLater: saveForLaterButtonTapped,
        addToLibrary: addToLibraryButtonTapped,
        chooseOfflineUntil: { offlineSheet = .until },
        keepOffline: { Task { await model.keepOffline() } },
        releaseOffline: { Task { await model.releaseOffline() } },
        correctClaim: { correctingClaim = $0 }
      )
    }
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
    .sheet(item: $replySheet) { sheet in
      ReaderReplyView(model: sheet.model, sendAndArchive: sendReplyAndArchive)
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if model.row != nil {
        VStack(spacing: 0) {
          Divider()
          ReaderTeachingField(model: model, isFocused: $isTeachingReasonFocused)
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.regularMaterial)
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

extension ReaderView {
  init(
    contentPieceID: ContentPiece.ID,
    editionContext: EditionReaderContext? = nil,
    queueContext: ReaderQueueContext? = nil,
    isReachableStreamPiece: Bool = false,
    originalWebViewStore: TodayOriginalWebViewStore? = nil
  ) {
    self.contentPieceID = contentPieceID
    self.editionContext = editionContext
    self.queueContext = queueContext
    self.isReachableStreamPiece = isReachableStreamPiece
    _originalWebViewStore = State(initialValue: originalWebViewStore ?? TodayOriginalWebViewStore())
    _model = LazyState {
      ContentPieceReaderModel(
        contentPieceID: contentPieceID,
        matchedPersonalKnowledgeClaimID: editionContext?.matchedPersonalKnowledgeClaimID
      )
    }
  }
}

private extension ReaderView {
  func readerAppeared() async {
    try? await model.$content.load()
    try? await model.$readerTeaching.load()
    try? await model.$matchedPersonalKnowledge.load()
    try? await model.$pendingFindContent.load()
    await model.loadRoutingResolution()
    if let editionContext {
      await editionContext.model.markSeen(editionContext.entryID)
    }
  }

  func dismissEditionButtonTapped() async {
    guard let editionContext else { return }
    await editionContext.model.dismiss(editionContext.entryID)
    if editionContext.model.errorMessage == nil {
      editionContext.clearSelection()
      dismissScreen()
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

  func openReply() {
    guard model.isReplyAvailable, let id = model.row?.id else { return }
    replySheet = ReaderReplySheet(model: ReaderReplyModel(contentPieceID: id))
  }

  func sendReplyAndArchive() async {
    if let queueContext { await queueContext.archive() }
    else { await model.archiveSource() }
  }
}

private struct ReaderReplySheet: Identifiable {
  let id = UUID()
  let model: ReaderReplyModel
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

struct ReaderQueueContext {
  let archive: @MainActor () async -> Void
  let trash: @MainActor () async -> Void
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
