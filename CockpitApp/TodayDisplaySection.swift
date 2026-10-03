import CockpitCore

struct TodayDisplaySection: Identifiable {
  enum Content {
    case role(TodayModel.RoleSection)
    case offers([TodayModel.OfferDoor])
    case feedsDoor(TodayModel.FeedsDoor)
    case tail(title: String, rows: [CurrentEditionRequest.Row], showsComposition: Bool)
  }

  let layout: TodayColumnLayout.Section
  let content: Content
  var id: String { layout.id }
}
