import CockpitCore
import SwiftUI

struct ReaderReplyView: View {
  @Bindable var model: ReaderReplyModel
  let sendAndArchive: @MainActor () async -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section {
          LabeledContent("To", value: model.recipientSummary)
          LabeledContent("Subject", value: model.subject)
        }

        Section("Message") {
          TextEditor(text: $model.body)
            .frame(minHeight: 180)
            .accessibilityLabel("Reply message")
        }

        if model.isLoading { ProgressView("Loading message headers…") }
        if let error = model.errorMessage { Text(error).foregroundStyle(.red) }
      }
      .navigationTitle("Reply")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItemGroup(placement: .confirmationAction) {
          Button("Send & Archive") {
            Task {
              await model.send(thenArchive: true, archive: sendAndArchive)
              if model.didSend { dismiss() }
            }
          }
          .disabled(!model.canSend)

          Button("Send") {
            Task {
              await model.send(thenArchive: false)
              if model.didSend { dismiss() }
            }
          }
          .disabled(!model.canSend)
          .keyboardShortcut(.return, modifiers: .command)
        }
      }
      .task { await model.load() }
    }
    .interactiveDismissDisabled(!model.body.isEmpty)
  }
}
