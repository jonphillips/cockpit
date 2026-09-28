import CockpitCore
import SwiftUI

extension ReaderView {
  @ViewBuilder
  var readerDocument: some View {
    if let row = readerModel.row {
      let emailHTML = htmlBody
      let isEmail = row.kind == .email
      VStack(alignment: .leading, spacing: 16) {
        if isEmail {
          ReaderEmailMasthead(
            row: row,
            kind: emailHTML.map(EmailPresentation.kind) ?? .letter,
            roleName: queueContext?.row.role.displayName ?? readerModel.currentTreatment?.displayName ?? "Message",
            zoom: currentEmailZoom,
            adjustText: { adjustEmailText(by: $0) },
            fitText: { readerModel.resetEmailTextSize() }
          )
            .readerEmailColumn(width: emailColumnWidth)
        } else {
          ReaderHeader(row: row, offlinePresentation: readerModel.offlinePresentation)
            .readerEmailColumn(width: emailColumnWidth)
        }

        if !isEmail, let rationale = editionContext?.rationale, !rationale.isEmpty {
          ReaderRationaleView(rationale: rationale, matchedClaim: readerModel.matchedClaim) {
            correctingClaim = $0
          }
          .readerEmailColumn(width: emailColumnWidth)
        }

        if !isEmail {
          ReaderSummaryView(
            summary: row.summary,
            isCompactPreview: row.isSubstantivePrimary == false
          )
          .readerEmailColumn(width: emailColumnWidth)
        }

        if !isEmail, let find = readerModel.pendingFind {
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

        if !isEmail {
          ReaderClassificationStatus(
            isSubstantivePrimary: row.isSubstantivePrimary,
            bodyCompleteness: row.bodyCompleteness,
            correct: { value in
              Task { await readerModel.correctIsSubstantivePrimary(to: value) }
            }
          )
          .readerEmailColumn(width: emailColumnWidth)
        }

        ReaderBodyView(
          presentation: readerModel.bodyPresentation,
          canonicalURL: row.canonicalURL,
          openURL: openURL,
          originalWebViewStore: originalWebViewStore,
          emailKind: isEmail ? (emailHTML.map(EmailPresentation.kind) ?? .letter) : nil,
          emailZoom: currentEmailZoom,
          zoomAdjustmentStep: readerModel.emailZoomAdjustmentStep,
          isZoomPreferenceLoaded: readerModel.isEmailZoomPreferenceLoaded,
          magnify: handleEmailMagnification
        )
        .readerEmailColumn(width: emailColumnWidth)

        if isReachableStreamPiece || queueContext != nil {
          ReaderCustodyLine().readerEmailColumn(width: emailColumnWidth)
        }
        if let queueContext, queueContext.showsNextCard {
          ProcessNextCardView(
            selectedRow: queueContext.row,
            next: ProcessNextCard.after(queueContext.row.id, in: queueContext.model.rows),
            actionTitle: editionContext == nil ? "Archive and continue" : "Dismiss and continue",
            action: {
              Task {
                if editionContext != nil { await queueContext.dismissTailAndContinue?() }
                else { await queueContext.archive() }
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
    let kind = htmlBody.map(EmailPresentation.kind) ?? .letter
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

  var htmlBody: String? {
    guard case let .html(html) = readerModel.bodyPresentation else { return nil }
    return html
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
