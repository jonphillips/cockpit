import CockpitCore
import LazyState
import SwiftUI

struct ReaderView: View {
  let contentPieceID: ContentPiece.ID
  let editionContext: EditionReaderContext?
  let queueContext: ReaderQueueContext?
  let isReachableStreamPiece: Bool
  @State var originalWebViewStore: TodayOriginalWebViewStore
  @LazyState private var model: ContentPieceReaderModel
  @Environment(\.dismiss) var dismissScreen
  @Environment(\.openURL) var openURL
  @State var correctingClaim: PersonalKnowledgeRequest.Row?
  @State var offlineSheet: OfflineAvailabilitySheet?
  @State var replySheet: ReaderReplySheet?
  @FocusState var isTeachingReasonFocused: Bool

  var readerModel: ContentPieceReaderModel { model }

  var body: some View {
    @Bindable var model = model
    ScrollView {
      readerDocument
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
        correctClaim: { correctingClaim = $0 },
        emailZoomStep: model.emailZoomAdjustmentStep,
        emailZoom: currentEmailZoom,
        showsEmailTextSize: isHTMLReaderBody,
        canIncreaseEmailZoom: EmailFitZoom.canIncrease(
          designWidth: originalWebViewStore.designWidth,
          viewportWidth: Double(originalWebViewStore.viewportWidth),
          adjustmentStep: model.emailZoomAdjustmentStep
        ),
        canDecreaseEmailZoom: EmailFitZoom.canDecrease(
          designWidth: originalWebViewStore.designWidth,
          viewportWidth: Double(originalWebViewStore.viewportWidth),
          adjustmentStep: model.emailZoomAdjustmentStep
        ),
        smallerEmailText: { model.smallerEmailText(
          designWidth: originalWebViewStore.designWidth,
          viewportWidth: Double(originalWebViewStore.viewportWidth)
        ) },
        largerEmailText: { model.largerEmailText(
          designWidth: originalWebViewStore.designWidth,
          viewportWidth: Double(originalWebViewStore.viewportWidth)
        ) },
        resetEmailText: model.resetEmailTextSize
      )
    }
    .background {
      VStack {
        Button("Larger Text") { adjustEmailText(by: 1) }
          .keyboardShortcut("+", modifiers: .command)
          .disabled(isTeachingReasonFocused)
        Button("Smaller Text") { adjustEmailText(by: -1) }
          .keyboardShortcut("-", modifiers: .command)
          .disabled(isTeachingReasonFocused)
        Button("Fit Text") { model.resetEmailTextSize() }
          .keyboardShortcut("0", modifiers: .command)
          .disabled(isTeachingReasonFocused)
      }
      .frame(width: 1, height: 1)
      .opacity(0)
      .accessibilityHidden(true)
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

struct ReaderReplySheet: Identifiable {
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

struct ReaderRationaleView: View {
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
