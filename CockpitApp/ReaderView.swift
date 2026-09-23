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
  @FocusState private var isTeachingReasonFocused: Bool

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
    _originalWebViewStore = State(
      initialValue: originalWebViewStore ?? TodayOriginalWebViewStore())
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
            OfflineAvailabilityStatus(presentation: model.offlinePresentation)
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
            openURL: openURL,
            originalWebViewStore: originalWebViewStore
          )

          if isReachableStreamPiece { ReaderCustodyLine() }

          Divider()

          ReaderTeachingField(
            model: model,
            isFocused: $isTeachingReasonFocused
          )
        }
        .padding()
      } else {
        ContentUnavailableView("Not Found", systemImage: "questionmark.circle")
      }
    }
    .navigationTitle("Reader")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ReaderDispositionToolbar(
        model: model,
        editionContext: editionContext,
        queueContext: queueContext,
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

private struct ReaderTeachingField: View {
  @Bindable var model: ContentPieceReaderModel
  let isFocused: FocusState<Bool>.Binding

  var body: some View {
    HStack(spacing: 8) {
      TextField("Tell Cockpit why this matters", text: $model.teachingReason)
        .textFieldStyle(.roundedBorder)
        .focused(isFocused)
        .submitLabel(.send)
        .disabled(model.isReviewingTeaching)
        .onSubmit { submit() }

      if model.isReviewingTeaching {
        ProgressView()
          .controlSize(.small)
          .accessibilityLabel("Reviewing teaching")
      }

      Button {
        submit()
      } label: {
        Image(systemName: "arrow.up.circle.fill")
          .font(.title2)
      }
      .buttonStyle(.plain)
      .disabled(
        model.isReviewingTeaching
          || model.teachingReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      )
      .accessibilityLabel("Submit why this matters")
    }
  }

  private func submit() {
    guard !model.isReviewingTeaching else { return }
    Task { await model.submitTeachingReason() }
  }
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
