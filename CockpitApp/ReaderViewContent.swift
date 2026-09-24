import CockpitCore
import SwiftUI

extension ReaderView {
  @ViewBuilder
  var readerDocument: some View {
    if let row = readerModel.row {
      VStack(alignment: .leading, spacing: 16) {
        ReaderHeader(row: row, offlinePresentation: readerModel.offlinePresentation)
          .readerEmailColumn(width: emailColumnWidth)

        if let rationale = editionContext?.rationale, !rationale.isEmpty {
          ReaderRationaleView(rationale: rationale, matchedClaim: readerModel.matchedClaim) {
            correctingClaim = $0
          }
          .readerEmailColumn(width: emailColumnWidth)
        }

        ReaderSummaryView(
          summary: row.summary,
          isCompactPreview: row.isSubstantivePrimary == false
        )
        .readerEmailColumn(width: emailColumnWidth)

        if let find = readerModel.pendingFind {
          PendingFindProposalCard(
            find: find,
            save: {
              Task {
                guard await readerModel.confirmPendingFind() else { return }
                if let queueContext { await queueContext.trash() }
                else { await readerModel.trashSource() }
              }
            },
            dismiss: { Task { await readerModel.dismissPendingFind() } }
          )
          .readerEmailColumn(width: emailColumnWidth)
        }

        ReaderClassificationStatus(
          isSubstantivePrimary: row.isSubstantivePrimary,
          bodyCompleteness: row.bodyCompleteness,
          correct: { value in
            Task { await readerModel.correctIsSubstantivePrimary(to: value) }
          }
        )
        .readerEmailColumn(width: emailColumnWidth)

        ReaderBodyView(
          presentation: readerModel.bodyPresentation,
          canonicalURL: row.canonicalURL,
          openURL: openURL,
          originalWebViewStore: originalWebViewStore,
          zoomAdjustmentStep: readerModel.emailZoomAdjustmentStep,
          isZoomPreferenceLoaded: readerModel.isEmailZoomPreferenceLoaded,
          magnify: handleEmailMagnification
        )

        if isReachableStreamPiece { ReaderCustodyLine().readerEmailColumn(width: emailColumnWidth) }
      }
      .padding()
    } else {
      ContentUnavailableView("Not Found", systemImage: "questionmark.circle")
    }
  }

  var emailColumnWidth: CGFloat? {
    guard case .html = readerModel.bodyPresentation, originalWebViewStore.viewportWidth > 0 else { return nil }
    return CGFloat(EmailColumn.width(
      designWidth: originalWebViewStore.designWidth,
      viewportWidth: Double(originalWebViewStore.viewportWidth),
      adjustmentStep: readerModel.emailZoomAdjustmentStep
    ))
  }

  var isHTMLReaderBody: Bool {
    if case .html = readerModel.bodyPresentation { return true }
    return false
  }

  var currentEmailZoom: Double {
    EmailFitZoom.bandedZoom(
      designWidth: originalWebViewStore.designWidth,
      viewportWidth: Double(originalWebViewStore.viewportWidth),
      adjustmentStep: readerModel.emailZoomAdjustmentStep
    )
  }

  func adjustEmailText(by delta: Int) {
    guard !isTeachingReasonFocused else { return }
    if delta > 0 {
      readerModel.largerEmailText(
        designWidth: originalWebViewStore.designWidth,
        viewportWidth: Double(originalWebViewStore.viewportWidth)
      )
    } else {
      readerModel.smallerEmailText(
        designWidth: originalWebViewStore.designWidth,
        viewportWidth: Double(originalWebViewStore.viewportWidth)
      )
    }
  }

  func handleEmailMagnification(_ magnification: CGFloat) {
    guard magnification.isFinite, magnification > 0 else { return }
    let requestedChange = (log(Double(magnification)) / log(1.1)).rounded()
    let change = Int(min(8, max(-8, requestedChange)))
    guard change != 0 else { return }
    readerModel.adjustEmailZoom(
      by: change,
      designWidth: originalWebViewStore.designWidth,
      viewportWidth: Double(originalWebViewStore.viewportWidth)
    )
  }

  func readerAppeared() async {
    await readerModel.loadEmailZoomPreference()
    try? await readerModel.$content.load()
    try? await readerModel.$readerTeaching.load()
    try? await readerModel.$matchedPersonalKnowledge.load()
    try? await readerModel.$pendingFindContent.load()
    await readerModel.loadRoutingResolution()
    await readerModel.loadMailMessageLink()
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
      await readerModel.saveForLater()
    }
  }

  func addToLibraryButtonTapped() async {
    if let editionContext {
      await editionContext.model.addToLibrary(editionContext.entryID)
    } else {
      await readerModel.addToLibrary()
    }
  }

  func openReply() {
    guard readerModel.isReplyAvailable, let id = readerModel.row?.id else { return }
    replySheet = ReaderReplySheet(model: ReaderReplyModel(contentPieceID: id))
  }

  func sendReplyAndArchive() async {
    if let queueContext { await queueContext.archive() }
    else { await readerModel.archiveSource() }
  }
}
