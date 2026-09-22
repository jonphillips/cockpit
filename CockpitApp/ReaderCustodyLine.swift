import SwiftUI

struct ReaderCustodyLine: View {
  var body: some View {
    Label(
      "When you leave, the source email may trash automatically — this issue stays in its stream, custody intact.",
      systemImage: "shield.lefthalf.filled"
    )
    .font(.caption)
    .foregroundStyle(.secondary)
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(.thinMaterial, in: .rect(cornerRadius: 10))
  }
}
