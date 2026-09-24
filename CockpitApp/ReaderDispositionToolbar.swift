import CockpitCore
import SwiftUI

/// Reader actions live in one trailing toolbar group. Gmail disposition remains queue-aware while
/// Later/Library Readers fall back to the ContentPieceReaderModel's source operations.
struct ReaderDispositionToolbar: ToolbarContent {
  let model: ContentPieceReaderModel
  let editionContext: EditionReaderContext?
  var queueContext: ReaderQueueContext? = nil
  var openReply: () -> Void = {}
  var openMail: () -> Void = {}
  let isTeachingReasonFocused: Bool
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
    ToolbarItemGroup(placement: .topBarTrailing) {
      if model.isReplyAvailable {
        Button("Reply", systemImage: "arrowshape.turn.up.left", action: openReply)
      }

      if model.mailMessageURL != nil {
        Button("Open in Mail", systemImage: "envelope", action: openMail)
      }

      if editionContext != nil {
        Button("Dismiss", systemImage: "xmark.circle") {
          Task { await dismissEdition() }
        }
      }

      if model.isGmailSource {
        archiveButton
        Button("Trash", systemImage: "trash", role: .destructive) {
          Task { await trash() }
        }
      }

      Menu {
        if showsEmailTextSize {
          Menu("Text Size · \(Int((emailZoom * 100).rounded()))%", systemImage: "textformat.size") {
            Button("Smaller", systemImage: "textformat.size.smaller", action: smallerEmailText)
              .disabled(!canDecreaseEmailZoom)
            Button("Larger", systemImage: "textformat.size.larger", action: largerEmailText)
              .disabled(!canIncreaseEmailZoom)
            Divider()
            Button("Fit", systemImage: "arrow.left.and.right", action: resetEmailText)
              .disabled(emailZoomStep == 0)
          }
          Divider()
        }

        Button("Save for Later", systemImage: "clock") {
          Task { await saveForLater() }
        }
        Button("Add to Library", systemImage: "books.vertical") {
          Task { await addToLibrary() }
        }
        Divider()

        if model.isGmailSource {
          MoveToSectionMenu(
            currentRole: model.currentRoutingRule?.role ?? model.resolvedContentRole ?? .forYou,
            isTransactional: model.currentTreatment == .transactional,
            isAvailable: model.resolvedRoutingLocator != nil
          ) { role in
            Task { await model.moveToSection(to: role) }
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
  }

  @ViewBuilder
  private var archiveButton: some View {
    if isTeachingReasonFocused {
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

  private func archive() async {
    if let queueContext { await queueContext.archive() }
    else { await model.archiveSource() }
  }

  private func trash() async {
    if let queueContext { await queueContext.trash() }
    else { await model.trashSource() }
  }
}
