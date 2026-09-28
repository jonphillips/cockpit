import CockpitCore
import SwiftUI

extension ReaderView {
  @ViewBuilder
  var readerDocument: some View {
    if let row = readerModel.row {
      let isEmail = row.kind == .email
      VStack(alignment: .leading, spacing: 16) {
        if isEmail {
          ReaderEmailMasthead(
            row: row,
            kind: emailPresentationKind ?? .letter,
            roleName: queueContext?.row.role.displayName ?? readerModel.currentTreatment?.displayName ?? "Message",
            offlinePresentation: readerModel.offlinePresentation,
            zoom: currentEmailZoom,
            adjustText: { adjustEmailText(by: $0) },
            fitText: { readerModel.resetEmailTextSize() },
            canIncrease: canIncreaseEmailZoom,
            canDecrease: canDecreaseEmailZoom,
            canFit: readerModel.emailZoomAdjustmentStep != 0
          )
            .readerEmailColumn(width: emailColumnWidth)
        } else {
          ReaderHeader(row: row, offlinePresentation: readerModel.offlinePresentation)
        }

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
                else { await trashReaderSource() }
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
          emailKind: isEmail ? emailPresentationKind : nil,
          emailZoom: currentEmailZoom,
          zoomAdjustmentStep: readerModel.emailZoomAdjustmentStep,
          isZoomPreferenceLoaded: readerModel.isEmailZoomPreferenceLoaded,
          magnify: handleEmailMagnification
        )
        .readerEmailColumn(width: emailColumnWidth, kind: emailPresentationKind)

        if isReachableStreamPiece {
          ReaderCustodyLine().readerEmailColumn(width: emailColumnWidth)
        }
        if let queueContext, queueContext.showsNextCard {
          let isTail = queueContext.row.editionEntryID != nil
          let actionTitle: String? = if isTail {
            "Dismiss and continue"
          } else if queueContext.row.isGmailSource {
            "Archive and continue"
          } else {
            nil
          }
          ProcessNextCardView(
            selectedRow: queueContext.row,
            next: ProcessNextCard.after(queueContext.row.id, in: queueContext.model.rows),
            actionTitle: actionTitle,
            action: {
              Task {
                if isTail { await dismissEditionButtonTapped() }
                else if queueContext.row.isGmailSource { await queueContext.archive() }
              }
            }
          )
          .readerEmailColumn(width: emailColumnWidth)
        }
      }
      .padding()
    } else {
      ContentUnavailableView("Not Found", systemImage: "questionmark.circle")
    }
  }

  var emailColumnWidth: CGFloat? {
    guard readerModel.row?.kind == .email else { return nil }
    guard let kind = emailPresentationKind else { return nil }
    if case .letter = kind {
      return Theme.readingMeasure * CGFloat(currentEmailZoom)
    }
    guard originalWebViewStore.viewportWidth > 0 else { return nil }
    return CGFloat(EmailColumn.width(
      designWidth: originalWebViewStore.designWidth,
      viewportWidth: Double(originalWebViewStore.viewportWidth),
      adjustmentStep: readerModel.emailZoomAdjustmentStep
    ))
  }

  var emailPresentationKind: EmailPresentation.Kind? {
    guard readerModel.row?.kind == .email else { return nil }
    guard case .html = readerModel.bodyPresentation else { return .letter }
    return originalWebViewStore.emailPresentationKind ?? .letter
  }

  var canIncreaseEmailZoom: Bool {
    EmailFitZoom.canIncrease(
      designWidth: originalWebViewStore.designWidth,
      viewportWidth: Double(originalWebViewStore.viewportWidth),
      adjustmentStep: readerModel.emailZoomAdjustmentStep
    )
  }

  var canDecreaseEmailZoom: Bool {
    EmailFitZoom.canDecrease(
      designWidth: originalWebViewStore.designWidth,
      viewportWidth: Double(originalWebViewStore.viewportWidth),
      adjustmentStep: readerModel.emailZoomAdjustmentStep
    )
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
    await readerModel.markReadOnOpenIfNeeded()
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
      if let didDismiss = editionContext.didDismiss {
        await didDismiss()
      } else {
        editionContext.clearSelection()
      }
      dismissScreen()
    }
  }

  func sendReaderFindToYesChef() async {
    guard await readerModel.sendToYesChefFromReader() else { return }
    if let queueContext { await queueContext.trash() }
    else { await trashReaderSource() }
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
    else { await archiveReaderSource() }
  }
}
