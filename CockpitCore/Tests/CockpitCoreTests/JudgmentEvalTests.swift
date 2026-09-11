import Foundation
import JudgmentFixtureSupport
import Testing

@Suite("JudgmentEval")
struct JudgmentEvalTests {
  @Test("reports all six metrics without reading behavioral priors")
  func reportsMetrics() {
    let essential = fixture(id: UUID(1), essential: true)
    let ordinary = fixture(id: UUID(2), essential: false)
    let labels = [
      JudgmentFixtureLabel(
        id: essential.id, label: .surface, isSubstantivePrimary: true, dispositionPrior: .never
      ),
      JudgmentFixtureLabel(
        id: ordinary.id, label: .quiet, isSubstantivePrimary: false, dispositionPrior: .surface
      ),
    ]
    let report = JudgmentEvaluation.evaluate(fixtures: [essential, ordinary], labels: labels) { fixture in
      fixture.id == ordinary.id
        ? StubJudgment(admits: true, isSubstantivePrimary: false, cost: 0.03)
        : StubJudgment(admits: false, isSubstantivePrimary: true, cost: 0.02)
    }

    #expect(report.agreementRate == 0)
    #expect(report.essentialFalseQuietRate == 1)
    #expect(report.falseSurfaceRate == 1)
    #expect(report.substantivePrimaryAccuracy == 1)
    #expect(report.meanPiecesAdmitted == 1)
    #expect(report.costPerComposition == 0.05)
    #expect(report.incompleteFixtureCount == 0)
    print(report.rendered)
  }

  @Test("requires both human confirmations before including a fixture in label metrics")
  func excludesUnconfirmedLabels() {
    let fixture = fixture(id: UUID(3), essential: false)
    let labels = [JudgmentFixtureLabel(id: fixture.id, dispositionPrior: .surface)]
    let report = JudgmentEvaluation.evaluate(fixtures: [fixture], labels: labels) {
      _ in StubJudgment(admits: true, isSubstantivePrimary: true)
    }

    #expect(report.agreementRate == nil)
    #expect(report.substantivePrimaryAccuracy == nil)
    #expect(report.incompleteFixtureCount == 1)
  }

  private func fixture(id: UUID, essential: Bool) -> JudgmentFixture {
    JudgmentFixture(
      id: id,
      kind: "article",
      title: "Fixture \(id)",
      publisher: "Publisher",
      normalizedText: "Real material is frozen before a judgment model can see it.",
      stream: StreamContext(
        name: "Stream", handling: "following", handlingGuidance: "Editorial context.",
        isEssential: essential
      ),
      interestArea: InterestAreaContext(name: "Area", guidance: "Context.")
    )
  }
}
