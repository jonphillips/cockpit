import Foundation

// Entry point lives in a file *not* named `main.swift`: a `main.swift` is compiled as
// top-level code, which cannot coexist with `@main`. Some toolchains accept the clash and
// others reject it during module emission, so the filename is load-bearing, not cosmetic.
@main
struct JudgmentFixtureHarvest {
  static func main() async {
    do {
      try await dispatch(Array(CommandLine.arguments.dropFirst()))
    } catch {
      fputs("error: \(error.localizedDescription)\n", stderr)
      exit(1)
    }
  }

  private static func dispatch(_ arguments: [String]) async throws {
    guard let verb = arguments.first else { throw HarvestError.usage }
    let flags = Array(arguments.dropFirst())
    switch verb {
    case "discover":
      try await DiscoverCommand(arguments: flags).run()
    case "export":
      try await ExportCommand(arguments: flags).run()
    default:
      throw HarvestError.usage
    }
  }
}

struct ArgumentValues {
  let values: [String: String]

  init(arguments: [String]) throws {
    guard arguments.count.isMultiple(of: 2) else { throw HarvestError.usage }
    var values: [String: String] = [:]
    for index in stride(from: 0, to: arguments.count, by: 2) {
      let key = arguments[index]
      guard key.hasPrefix("--"), values[key] == nil else { throw HarvestError.usage }
      values[key] = arguments[index + 1]
    }
    self.values = values
  }

  func value(named name: String) throws -> String {
    guard let value = values[name], !value.isEmpty else { throw HarvestError.usage }
    return value
  }

  func value(named name: String, default fallback: String) -> String {
    values[name].flatMap { $0.isEmpty ? nil : $0 } ?? fallback
  }

  func fileURL(named name: String) throws -> URL {
    URL(fileURLWithPath: try value(named: name))
  }
}

enum HarvestError: LocalizedError {
  case usage
  case missingAccessToken
  case httpStatus(Int, String)

  var errorDescription: String? {
    switch self {
    case .usage:
      return """
        usage:
          JudgmentFixtureHarvest discover --seeds path --out path --after YYYY-MM-DD --before YYYY-MM-DD
          JudgmentFixtureHarvest export --config path --fixtures path --labels path --after YYYY-MM-DD --before YYYY-MM-DD
        """
    case .missingAccessToken:
      return "GMAIL_ACCESS_TOKEN is required for Gmail access. Mint one with: swift run GmailFixtureToken --client <desktop-client.json>"
    case let .httpStatus(status, body):
      return "Gmail request failed (HTTP \(status)): \(body)"
    }
  }
}

func requireAccessToken() throws -> String {
  let token = ProcessInfo.processInfo.environment["GMAIL_ACCESS_TOKEN"]
  guard let token, !token.isEmpty else { throw HarvestError.missingAccessToken }
  return token
}
