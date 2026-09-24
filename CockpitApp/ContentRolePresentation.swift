import CockpitCore
import SwiftUI

extension ContentRole {
  var color: Color {
    switch self {
    case .forYou: .accentColor
    case .transactional: .indigo
    case .dailyNews: .blue
    case .opinion: .orange
    case .grabBag: .teal
    case .arts: .purple
    case .food: .green
    case .wine: .red
    case .offers: .brown
    }
  }

  var symbolName: String {
    switch self {
    case .forYou: "person.crop.circle"
    case .transactional: "creditcard"
    case .dailyNews: "newspaper"
    case .opinion: "quote.bubble"
    case .grabBag: "square.grid.2x2"
    case .arts: "paintpalette"
    case .food: "fork.knife"
    case .wine: "wineglass"
    case .offers: "tag"
    }
  }
}
