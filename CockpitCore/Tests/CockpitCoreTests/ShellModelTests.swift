@testable import CockpitCore
import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
import Testing

@Suite(.dependencies {
  try $0.bootstrapDatabase()
})
@MainActor
struct ShellModelTests {
  @Test("The shell starts at Today and selects every primary destination")
  func primaryDestinationSelection() {
    let model = ShellModel()
    expectNoDifference(model.selection, .today)

    for destination in ShellModel.Destination.allCases {
      model.select(destination)
      expectNoDifference(model.selection, destination)
    }
  }

  @Test("Settings routes push, pop, and preserve a Personal Knowledge claim payload")
  func settingsRoutes() {
    let model = ShellModel()
    let claimID = UUID(42)

    model.pushSettings(.personalKnowledge(claimID: claimID))
    model.pushSettings(.following)
    expectNoDifference(model.selection, .settings)
    expectNoDifference(model.settingsPath, [.personalKnowledge(claimID: claimID), .following])

    model.popSettings()
    expectNoDifference(model.settingsPath, [.personalKnowledge(claimID: claimID)])
    model.popToSettingsRoot()
    expectNoDifference(model.settingsPath, [])
    model.popSettings()
    expectNoDifference(model.settingsPath, [])
  }

  @Test("An empty Edition starts with no materialized rows")
  func absentEditionHasNoRows() {
    let model = EditionModel()
    #expect(model.edition == nil)
    #expect(model.entries.isEmpty)
  }
}
