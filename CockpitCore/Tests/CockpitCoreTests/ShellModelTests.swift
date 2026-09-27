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

  @Test("Process selects the destination, targets an ID, and preserves selection for nil")
  func processRouting() {
    let model = ShellModel()
    let first = UUID(4_201)
    var selectedID: ContentPiece.ID?

    model.connectProcessSelection { contentPieceID in
      if let contentPieceID { selectedID = contentPieceID }
    }

    model.process(from: first)
    expectNoDifference(model.selection, .process)
    expectNoDifference(selectedID, first)

    model.process(from: nil)
    expectNoDifference(model.selection, .process)
    expectNoDifference(selectedID, first)
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

  @Test("A conditional pop removes the route only while it is still on top")
  func conditionalSettingsPop() {
    let model = ShellModel()
    let reader = SettingsRoute.reader(contentPieceID: UUID(7))

    model.pushSettings(.pendingFinds)
    model.pushSettings(reader)
    model.popSettings(ifShowing: reader)
    expectNoDifference(model.settingsPath, [.pendingFinds])

    // Jon already tapped Back before the disposition finished: the Finds list stays.
    model.popSettings(ifShowing: reader)
    expectNoDifference(model.settingsPath, [.pendingFinds])

    model.pushSettings(.reader(contentPieceID: UUID(8)))
    model.popSettings(ifShowing: reader)
    expectNoDifference(model.settingsPath, [.pendingFinds, .reader(contentPieceID: UUID(8))])
  }

  @Test("An empty Edition starts with no materialized rows")
  func absentEditionHasNoRows() {
    let model = EditionModel()
    #expect(model.edition == nil)
    #expect(model.entries.isEmpty)
  }
}
