import CockpitCore
import SwiftUI

struct FollowingView: View {
  @Bindable var model: FollowingModel
  @State private var isPresentingAddStream = false

  var body: some View {
    List {
      ForEach(model.rows) { row in
        Section(row.interestAreaName ?? "General") {
          VStack(alignment: .leading, spacing: 6) {
            HStack {
              Text(row.name).font(.headline)
              if row.isEssential {
                Image(systemName: "exclamationmark.circle.fill")
                  .foregroundStyle(.orange)
                  .accessibilityLabel("Essential")
              }
              Spacer()
              Menu {
                Button("Following") {
                  Task { await model.followStateButtonTapped(.active, for: row.id) }
                }
                Button("Pause") {
                  Task { await model.followStateButtonTapped(.paused, for: row.id) }
                }
                Button("Stop Following", role: .destructive) {
                  Task { await model.followStateButtonTapped(.stopped, for: row.id) }
                }
              } label: {
                Text(followStateLabel(row.followState))
                  .font(.caption)
              }
            }
            Text(row.publisher).foregroundStyle(.secondary)
            if !row.handlingGuidance.isEmpty {
              Text(row.handlingGuidance)
                .font(.subheadline)
                .lineLimit(3)
            }
            if row.effectiveHealth == .failed {
              Label(
                row.lastFailureDescription ?? "Feed acquisition failed",
                systemImage: "exclamationmark.triangle.fill"
              )
              .font(.caption)
              .foregroundStyle(.red)
              if row.failureCount > 1 {
                Text("Failed \(row.failureCount) consecutive times")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
          }
          .contentShape(.rect)
          .onTapGesture { model.editButtonTapped(row) }
        }
      }
    }
    .navigationTitle("Following")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Add Stream", systemImage: "plus") { isPresentingAddStream = true }
      }
    }
    .refreshable { await model.acquireOnLaunchOrRefresh() }
    .sheet(isPresented: $isPresentingAddStream) {
      AddStreamView(model: model, isPresented: $isPresentingAddStream)
    }
    .sheet(item: $model.editingStream) { _ in
      StreamEditorView(
        title: "Edit Stream",
        draft: $model.editingStream,
        save: { Task { await model.saveEditingButtonTapped() } }
      )
    }
    .safeAreaInset(edge: .bottom) {
      if let error = model.errorMessage {
        HStack {
          Text(error)
          Spacer()
          Button("Dismiss") { model.errorMessage = nil }
        }
        .padding()
        .background(.regularMaterial)
      }
    }
  }

  private func followStateLabel(_ state: StreamFollowState) -> String {
    switch state {
    case .active: "Following"
    case .paused: "Paused"
    case .stopped: "Stopped"
    }
  }
}

private struct AddStreamView: View {
  @Bindable var model: FollowingModel
  @Binding var isPresented: Bool

  var body: some View {
    NavigationStack {
      Form {
        Section("Known URL") {
          TextField("Website or RSS/Atom URL", text: $model.addURL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
          Button("Find Feed") { Task { await model.discoverButtonTapped() } }
        }
        if model.proposedStream != nil {
          StreamEditorFields(draft: $model.proposedStream)
        }
      }
      .navigationTitle("Add Stream")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { isPresented = false }
        }
        if model.proposedStream != nil {
          ToolbarItem(placement: .confirmationAction) {
            Button("Follow") {
              Task {
                if await model.followButtonTapped() {
                  isPresented = false
                }
              }
            }
          }
        }
      }
    }
  }
}

private struct StreamEditorView: View {
  let title: String
  @Binding var draft: StreamDraft?
  let save: () -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form { StreamEditorFields(draft: $draft) }
        .navigationTitle(title)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
              save()
              dismiss()
            }
          }
        }
    }
  }
}

private struct StreamEditorFields: View {
  @Binding var draft: StreamDraft?

  var body: some View {
    if let draft = Binding($draft) {
      Section("Stream") {
        TextField("Name", text: draft.name)
        TextField("Publisher / Creator", text: draft.publisher)
        TextField("Interest Area", text: draft.interestAreaName)
      }
      Section("How Cockpit should handle this") {
        TextEditor(text: draft.handlingGuidance)
          .frame(minHeight: 120)
        Toggle("Essential", isOn: draft.isEssential)
      }
    }
  }
}
