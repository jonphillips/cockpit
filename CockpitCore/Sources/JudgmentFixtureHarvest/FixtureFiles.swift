import Foundation
import JudgmentFixtureSupport

/// Writes a JSON output file, creating its parent directory first. `Data.write(to:)` does not create
/// intermediate directories, so the frozen-corpus paths (e.g. Tests/Fixtures/judgment/) fail on a
/// clean checkout without this.
enum OutputFile {
  static func write(_ data: Data, to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url)
  }
}

enum LabelStore {
  static func load(from url: URL) throws -> [JudgmentFixtureLabel] {
    guard FileManager.default.fileExists(atPath: url.path) else { return [] }
    return try JSONDecoder.fixture.decode(JudgmentLabelExport.self, from: Data(contentsOf: url)).labels
  }

  static func merging(
    _ oldLabels: [JudgmentFixtureLabel],
    with harvested: HarvestedFixtures
  ) -> [JudgmentFixtureLabel] {
    let oldByID = Dictionary(uniqueKeysWithValues: oldLabels.map { ($0.id, $0) })
    return harvested.rows.map { row in
      let previous = oldByID[row.fixture.id]
      return JudgmentFixtureLabel(
        id: row.fixture.id,
        label: previous?.label,
        isSubstantivePrimary: previous?.isSubstantivePrimary,
        dispositionPrior: row.prior,
        gmailDisposition: row.gmailDisposition,
        gmailReadState: row.gmailReadState
      )
    }
  }
}

extension JSONDecoder {
  static let fixture: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()
}

extension JSONEncoder {
  static let fixture: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return encoder
  }()
}
