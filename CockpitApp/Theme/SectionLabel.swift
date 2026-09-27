import SwiftUI

struct SectionLabel: View {
  let title: String
  let count: Int

  var body: some View {
    VStack(alignment: .leading, spacing: Theme.sectionLabelRuleSpacing) {
      Rectangle()
        .fill(Theme.ink)
        .frame(height: 1)

      HStack {
        Text(title.uppercased())
          .font(Theme.sectionLabel)
          .tracking(1.6)
          .foregroundStyle(Theme.ink)
        Spacer(minLength: 8)
        Text(count, format: .number)
          .font(Theme.sectionLabel)
          .tracking(0.4)
          .foregroundStyle(Theme.inkTertiary)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

#Preview("Section label · light") {
  SectionLabel(title: "Daily news", count: 6)
    .padding()
    .background(Theme.paper)
    .preferredColorScheme(.light)
}

#Preview("Section label · dark") {
  SectionLabel(title: "Daily news", count: 6)
    .padding()
    .background(Theme.paper)
    .preferredColorScheme(.dark)
}
