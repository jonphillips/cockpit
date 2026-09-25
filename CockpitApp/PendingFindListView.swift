import CockpitCore
import SwiftUI

struct PendingFindListView: View {
  let model: PendingFindListModel

  var body: some View {
    List {
      if !model.needsDecisionRows.isEmpty {
        Section {
          ForEach(model.needsDecisionRows) { row in PendingFindListRow(row: row, model: model) }
        } header: {
          Text("Needs a decision")
        } footer: {
          findsFooter
        }
      }

      if !model.savedRows.isEmpty {
        Section {
          ForEach(model.savedRows) { row in PendingFindListRow(row: row, model: model) }
        } header: {
          Text("Saved")
        } footer: {
          if model.needsDecisionRows.isEmpty { findsFooter }
        }
      }

      if !model.resolvedRows.isEmpty {
        Section {
          ForEach(model.resolvedRows) { row in PendingFindListRow(row: row, model: model) }
        } header: {
          Text("Resolved")
        } footer: {
          if model.needsDecisionRows.isEmpty && model.savedRows.isEmpty { findsFooter }
        }
      }

      if model.showDismissed && !model.dismissedRows.isEmpty {
        Section {
          ForEach(model.dismissedRows) { row in PendingFindListRow(row: row, model: model) }
        } header: {
          Text("Dismissed")
        } footer: {
          if model.needsDecisionRows.isEmpty && model.savedRows.isEmpty && model.resolvedRows.isEmpty {
            findsFooter
          }
        }
      }
    }
    .overlay {
      if model.rows.isEmpty {
        ContentUnavailableView(
          "No Finds", systemImage: "sparkle.magnifyingglass",
          description: Text("Useful things extracted from judgment will appear here."))
      }
    }
    .navigationTitle("Finds")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Toggle("Show Dismissed", isOn: Binding(
            get: { model.showDismissed },
            set: { show in model.setShowDismissed(show) }
          ))
        } label: {
          Image(systemName: "ellipsis.circle")
        }
      }
    }
    .alert(model.errorTitle, isPresented: Binding(
      get: { model.errorMessage != nil },
      set: { if !$0 { model.errorMessage = nil } }
    )) {
      Button("OK", role: .cancel) { model.errorMessage = nil }
    } message: {
      Text(model.errorMessage ?? "Please try again.")
    }
    .task(id: model.showDismissed) {
      await model.load()
    }
    .task {
      await model.refreshHandoffState()
    }
  }

  private var findsFooter: some View {
    Text("Finds wait here until an app can take them. Recipes can go to Yes Chef now; the rest stay until an app exists.")
  }

}

private struct PendingFindListRow: View {
  let row: PendingFindListRequest.Row
  let model: PendingFindListModel

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      NavigationLink(value: SettingsRoute.reader(contentPieceID: row.contentPieceID)) {
        PendingFindRowLabel(row: row, strand: model.strandedReferrals[row.id])
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      PendingFindRowActions(row: row, model: model)
    }
    .swipeActions(edge: .trailing) {
      if row.state == .pending {
        Button("Dismiss", systemImage: "xmark", role: .destructive) {
          Task { await model.dismiss(row.id) }
        }
        Button("Save", systemImage: "bookmark.fill") {
          Task { await model.confirm(row.id) }
        }
        .tint(.accentColor)
      } else if row.state == .dismissed {
        Button("Save", systemImage: "bookmark.fill") {
          Task { await model.confirm(row.id) }
        }
        .tint(.accentColor)
      }
    }
  }
}

private struct PendingFindRowLabel: View {
  let row: PendingFindListRequest.Row
  let strand: FindReferralStrand?

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(row.name).font(.headline)
        Spacer()
        VStack(alignment: .trailing, spacing: 2) {
          Text(row.kind.capitalized).font(.caption).foregroundStyle(.secondary)
          Text(stateLabel).font(.caption2).foregroundStyle(.secondary)
        }
      }
      if !row.descriptor.isEmpty { Text(row.descriptor).font(.subheadline) }
      if !row.rationale.isEmpty {
        Text(row.rationale).font(.caption).foregroundStyle(.secondary).lineLimit(2)
      }
      if let strand {
        Text(strandMessage(strand))
          .font(.caption)
          .foregroundStyle(.orange)
      }
    }
  }

  private var stateLabel: String {
    switch row.state {
    case .pending: "Needs a decision"
    case .confirmed: "Saved"
    case .referred: "Sent to Yes Chef"
    case .handedOff: "Added to Yes Chef"
    case .declined: "Declined by Yes Chef"
    case .dismissed: "Dismissed"
    }
  }

  private func strandMessage(_ strand: FindReferralStrand) -> String {
    switch strand {
    case .unconsumed: "Yes Chef hasn't picked up this referral yet."
    case .unreadableReply: "Yes Chef's reply couldn't be read."
    }
  }
}

private struct PendingFindRowActions: View {
  let row: PendingFindListRequest.Row
  let model: PendingFindListModel

  var body: some View {
    if hasDecisionActions {
      HStack(spacing: 12) {
        if row.state == .pending || row.state == .dismissed {
          Button("Save", systemImage: "bookmark.fill") {
            Task { await model.confirm(row.id) }
          }
          .tint(.accentColor)
        }
        if row.state == .pending {
          Button("Dismiss", systemImage: "xmark", role: .destructive) {
            Task { await model.dismiss(row.id) }
          }
        }
        if canSendToYesChef {
          Button("Send to Yes Chef", systemImage: "arrow.up.forward.app") {
            Task { await model.sendToYesChef(row.id) }
          }
        }
      }
      .font(.subheadline)
      .buttonStyle(.borderless)
    }

    if let strand = model.strandedReferrals[row.id] {
      HStack {
        if case .unconsumed = strand {
          Button("Open Yes Chef Again", systemImage: "arrow.clockwise") {
            Task { await model.retryStrandedReferral(for: row.id) }
          }
        }
        Button("Return to Confirmed", systemImage: "arrow.uturn.backward") {
          Task { await model.returnStrandedReferralToConfirmed(for: row.id) }
        }
        .tint(.secondary)
      }
      .font(.caption)
      .buttonStyle(.borderless)
      .accessibilityIdentifier("stranded-referral-\(strand.referralID.uuidString.lowercased())")
    }
  }

  private var canSendToYesChef: Bool {
    RecipeCandidateKind.matches(row.kind) && (row.state == .pending || row.state == .confirmed)
  }

  private var hasDecisionActions: Bool {
    row.state == .pending || row.state == .dismissed || canSendToYesChef
  }
}
