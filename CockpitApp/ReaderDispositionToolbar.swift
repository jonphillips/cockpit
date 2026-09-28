import CockpitCore
import SwiftUI

/// Reader actions stay in system toolbar chrome. The leading action is the one primary act for the
/// current piece; the remaining disposition, destination, text, teaching, and overflow actions follow.
struct ReaderDispositionToolbar: ToolbarContent {
  let model: ContentPieceReaderModel
  let editionContext: EditionReaderContext?
  var queueContext: ReaderQueueContext? = nil
  var openReply: () -> Void = {}
  var openMail: () -> Void = {}
  var requestTransactionalCorrection: () -> Void = {}
  var openTeaching: () -> Void = {}
  var sendToYesChef: () async -> Void = {}
  var archiveSource: () async -> Void = {}
  var trashSource: () async -> Void = {}
  let isTextEntrySheetPresented: Bool
  let dismissEdition: () async -> Void
  let saveForLater: () async -> Void
  let addToLibrary: () async -> Void
  let chooseOfflineUntil: () -> Void
  let keepOffline: () -> Void
  let releaseOffline: () -> Void
  let correctClaim: (PersonalKnowledgeRequest.Row) -> Void
  let emailZoomStep: Int
  let emailZoom: Double
  let showsEmailTextSize: Bool
  let canIncreaseEmailZoom: Bool
  let canDecreaseEmailZoom: Bool
  let smallerEmailText: () -> Void
  let largerEmailText: () -> Void
  let resetEmailText: () -> Void

  var body: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
      if editionContext != nil {
        Button("Dismiss", systemImage: "xmark.circle") {
          Task { await dismissEdition() }
        }
        .buttonStyle(.borderedProminent)
      } else if model.isReplyAvailable {
        Button("Reply", systemImage: "arrowshape.turn.up.left", action: openReply)
          .buttonStyle(.borderedProminent)
      } else if model.isGmailSource {
        if isTextEntrySheetPresented {
          Button("Archive", systemImage: "archivebox") {
            Task { await archive() }
          }
          .buttonStyle(.borderedProminent)
        } else {
          Button("Archive", systemImage: "archivebox") {
            Task { await archive() }
          }
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.delete, modifiers: [])
        }
      }
    }

    ToolbarItemGroup(placement: .topBarTrailing) {
      Button("Later", systemImage: "clock") {
        Task { await saveForLater() }
      }
      Button("Library", systemImage: "books.vertical") {
        Task { await addToLibrary() }
      }

      if model.isGmailSource && model.isReplyAvailable {
        if isTextEntrySheetPresented {
          Button("Archive", systemImage: "archivebox") {
            Task { await archive() }
          }
        } else {
          Button("Archive", systemImage: "archivebox") {
            Task { await archive() }
          }
          .keyboardShortcut(.delete, modifiers: [])
        }
      }

      if model.isGmailSource {
        Button("Trash", systemImage: "trash", role: .destructive) {
          Task { await trash() }
        }
      }
    }
    .visibilityPriority(.high)

    if showsEmailTextSize {
      ToolbarItem(placement: .topBarTrailing) {
        textSizeMenu
      }
    }

    if model.row != nil {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Teach Cockpit", systemImage: "lightbulb", action: openTeaching)
      }
    }

    ToolbarItem(placement: .topBarTrailing) {
      moreActions
    }
  }
}

private extension ReaderDispositionToolbar {
  var textSizeMenu: some View {
    EmailTextSizeMenu(
      label: "Text Size · \(Int((emailZoom * 100).rounded()))%",
      canIncrease: canIncreaseEmailZoom,
      canDecrease: canDecreaseEmailZoom,
      canFit: emailZoomStep != 0,
      smaller: smallerEmailText,
      larger: largerEmailText,
      fit: resetEmailText
    )
  }

  @ViewBuilder
  var moreActions: some View {
    Menu {
      if model.mailMessageURL != nil {
        Button("Open in Mail", systemImage: "envelope", action: openMail)
        Divider()
      }

      if let title = model.yesChefReaderActionTitle {
        Button(title, systemImage: "arrow.up.forward.app") {
          Task { await sendToYesChef() }
        }
        .disabled(!model.canSendToYesChefFromReader)
        Divider()
      }

      if model.isGmailSource {
        if !model.isUnread {
          Button("Mark as Unread", systemImage: "envelope.badge") {
            Task { await model.markUnread() }
          }
          Divider()
        }
        MoveToSectionMenu(
          currentRole: model.currentRoutingRule?.role ?? model.resolvedContentRole ?? .forYou,
          isTransactional: model.currentTreatment == .transactional,
          isTransactionalCorrection: model.isTransactionalCorrection,
          isAvailable: model.resolvedRoutingLocator != nil,
          canCorrectSender: model.currentSenderKey != nil
        ) { role in
          Task { await model.moveToSection(to: role) }
        } requestTransactionalCorrection: {
          requestTransactionalCorrection()
        } removeTransactionalCorrection: {
          Task { await model.removeTransactionalCorrection() }
        }
        Divider()
      }

      Menu("Offline", systemImage: "arrow.down.circle") {
        Button("Offline until", systemImage: "calendar") { chooseOfflineUntil() }
        Button("Keep Offline", systemImage: "pin") { keepOffline() }
        if model.offlinePresentation.isActivePromise {
          Button("Stop Keeping Offline", systemImage: "pin.slash") { releaseOffline() }
        }
      }

      if let readerTaughtClaim = model.readerTaughtClaim {
        Divider()
        Button("Correct this understanding", systemImage: "pencil") {
          correctClaim(readerTaughtClaim)
        }
      }

      if model.isGmailSource {
        Divider()
        Button("Undo disposition", systemImage: "arrow.uturn.backward") {
          Task { await model.undoDisposition() }
        }
      }
    } label: {
      Image(systemName: "ellipsis.circle")
    }
    .accessibilityLabel("More Reader actions")
  }

  private func archive() async {
    if let queueContext { await queueContext.archive() }
    else { await archiveSource() }
  }

  private func trash() async {
    if let queueContext { await queueContext.trash() }
    else { await trashSource() }
  }
}
