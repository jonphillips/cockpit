import CockpitCore
import SwiftUI

struct ReaderHeader: View {
  let row: ContentPieceReaderRequest.Row
  let offlinePresentation: OfflineAvailabilityPresentation

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(row.title).font(.title2).bold()
      Text(row.sender).foregroundStyle(.secondary)
      Text(ReceivedAgeLabel.text(received: row.receivedAt, now: .now))
        .font(.caption)
        .foregroundStyle(.secondary)
      OfflineAvailabilityStatus(presentation: offlinePresentation)
    }
  }
}

struct ReaderTeachingField: View {
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

struct PendingFindProposalCard: View {
  let find: PendingFind
  let save: () -> Void
  let dismiss: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(find.kind.capitalized).font(.caption).foregroundStyle(.secondary)
        Spacer()
        Text("Proposed Find").font(.caption2).foregroundStyle(.secondary)
      }
      Text(find.name).font(.headline)
      if !find.descriptor.isEmpty { Text(find.descriptor).font(.subheadline) }
      HStack {
        Button("Not This", action: dismiss).buttonStyle(.bordered)
        Button("Save Find", action: save).buttonStyle(.borderedProminent)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    .accessibilityElement(children: .contain)
  }
}
