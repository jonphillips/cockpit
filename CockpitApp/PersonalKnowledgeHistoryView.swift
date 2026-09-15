import CockpitCore
import SwiftUI

struct PersonalKnowledgeHistorySection: View {
  let model: PersonalKnowledgeModel

  var body: some View {
    if !model.historicalClaims.isEmpty {
      Section {
        ForEach(model.historicalClaims) { claim in
          PersonalKnowledgeClaimRow(
            claim: claim,
            successor: model.claims.first { $0.id == claim.supersededByID },
            onCorrect: nil,
            onRetire: nil
          )
        }
      } header: {
        Text("History")
      } footer: {
        Text("Superseded and retired claims remain inspectable so Cockpit can explain its history.")
      }
    }
  }
}

struct PersonalKnowledgeClaimRow: View {
  let claim: PersonalKnowledgeRequest.Row
  let successor: PersonalKnowledgeRequest.Row?
  let onCorrect: (() -> Void)?
  let onRetire: (() -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(claim.claim)
      if let scope = claim.scope {
        Text(scope)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      Text("\(claim.kind.displayName) · \(claim.provenance.displayName)")
        .font(.caption)
        .foregroundStyle(.secondary)
      if claim.status == .superseded, let successor {
        Text("Superseded by: \(successor.claim)")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else if claim.status == .retired {
        Text("Retired")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      if let onCorrect, let onRetire {
        HStack {
          Button("Correct", action: onCorrect)
          Button("Retire", role: .destructive, action: onRetire)
        }
        .font(.subheadline)
      }
    }
    .accessibilityElement(children: .combine)
  }
}
