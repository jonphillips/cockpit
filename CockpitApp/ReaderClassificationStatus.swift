import CockpitCore
import SwiftUI

struct ReaderClassificationStatus: View {
  let isSubstantivePrimary: Bool?
  let bodyCompleteness: BodyCompleteness?
  let correct: (Bool) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let isSubstantivePrimary {
        HStack {
          Image(systemName: isSubstantivePrimary ? "doc.text.fill" : "list.bullet")
          Text(isSubstantivePrimary ? "Substantive primary piece" : "Accessory / not primary")
          Spacer()
          Button("Correct") { correct(!isSubstantivePrimary) }
            .font(.caption)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      if isSubstantivePrimary != false,
        let bodyCompleteness, bodyCompleteness != .full
      {
        Label(
          bodyCompleteness.readerLabel,
          systemImage: bodyCompleteness == .teaser ? "rectangle.slash" : "scissors"
        )
        .font(.caption)
        .foregroundStyle(.orange)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.orange.opacity(0.12), in: .capsule)
        .accessibilityLabel("Body completeness: \(bodyCompleteness.readerLabel)")
      }
    }
  }
}
