import Foundation

public struct StubJudgment: Equatable, Sendable {
  public let admits: Bool
  public let isSubstantivePrimary: Bool
  public let cost: Decimal

  public init(admits: Bool, isSubstantivePrimary: Bool, cost: Decimal = 0) {
    self.admits = admits
    self.isSubstantivePrimary = isSubstantivePrimary
    self.cost = cost
  }
}

public struct JudgmentEvaluationReport: Equatable, Sendable {
  public let agreementRate: Double?
  public let essentialFalseQuietRate: Double?
  public let falseSurfaceRate: Double?
  public let substantivePrimaryAccuracy: Double?
  public let meanPiecesAdmitted: Double
  public let costPerComposition: Decimal
  public let incompleteFixtureCount: Int

  public init(
    agreementRate: Double?,
    essentialFalseQuietRate: Double?,
    falseSurfaceRate: Double?,
    substantivePrimaryAccuracy: Double?,
    meanPiecesAdmitted: Double,
    costPerComposition: Decimal,
    incompleteFixtureCount: Int
  ) {
    self.agreementRate = agreementRate
    self.essentialFalseQuietRate = essentialFalseQuietRate
    self.falseSurfaceRate = falseSurfaceRate
    self.substantivePrimaryAccuracy = substantivePrimaryAccuracy
    self.meanPiecesAdmitted = meanPiecesAdmitted
    self.costPerComposition = costPerComposition
    self.incompleteFixtureCount = incompleteFixtureCount
  }

  public var rendered: String {
    [
      "agreement=\(agreementRate.rendered)",
      "essentialFalseQuiet=\(essentialFalseQuietRate.rendered)",
      "falseSurface=\(falseSurfaceRate.rendered)",
      "substantivePrimaryAccuracy=\(substantivePrimaryAccuracy.rendered)",
      "meanPiecesAdmitted=\(meanPiecesAdmitted)",
      "costPerComposition=\(costPerComposition)",
      "incompleteFixtures=\(incompleteFixtureCount)",
    ].joined(separator: " ")
  }
}

public enum JudgmentEvaluation {
  public static func evaluate(
    fixtures: [JudgmentFixture],
    labels: [JudgmentFixtureLabel],
    judge: (JudgmentFixture) -> StubJudgment
  ) -> JudgmentEvaluationReport {
    let labelsByID = Dictionary(uniqueKeysWithValues: labels.map { ($0.id, $0) })
    let rows = fixtures.map { fixture in (fixture, labelsByID[fixture.id], judge(fixture)) }
    let complete = rows.filter { $0.1?.label != nil && $0.1?.isSubstantivePrimary != nil }
    let agreement = rate(complete) { row in row.2.admits == (row.1?.label == .surface) }
    let essential = complete.filter { $0.0.stream.isEssential && $0.1?.isSubstantivePrimary == true }
    let falseQuiet = rate(essential) { row in row.2.admits == false }
    let nonSurface = complete.filter { $0.1?.label != .surface }
    let falseSurface = rate(nonSurface) { row in row.2.admits }
    let substantive = rate(complete) { row in row.2.isSubstantivePrimary == row.1?.isSubstantivePrimary }

    return JudgmentEvaluationReport(
      agreementRate: agreement,
      essentialFalseQuietRate: falseQuiet,
      falseSurfaceRate: falseSurface,
      substantivePrimaryAccuracy: substantive,
      meanPiecesAdmitted: Double(rows.filter { $0.2.admits }.count),
      costPerComposition: rows.reduce(0) { $0 + $1.2.cost },
      incompleteFixtureCount: rows.count - complete.count
    )
  }

  private static func rate(
    _ rows: [(JudgmentFixture, JudgmentFixtureLabel?, StubJudgment)],
    matching predicate: ((JudgmentFixture, JudgmentFixtureLabel?, StubJudgment)) -> Bool
  ) -> Double? {
    guard !rows.isEmpty else { return nil }
    return Double(rows.count(where: predicate)) / Double(rows.count)
  }
}

private extension Optional where Wrapped == Double {
  var rendered: String {
    map { String(format: "%.3f", $0) } ?? "n/a"
  }
}
