import Foundation
import GmailDesktopAuth

/// Prints only a fresh access token to stdout, preserving the fixture harvest's shell contract.
@main
struct GmailFixtureToken {
  static func main() async {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard let index = arguments.firstIndex(of: "--client"), arguments.indices.contains(index + 1) else {
      fputs("usage: swift run GmailFixtureToken --client <desktop-client.json> [--scope <scope>]\n", stderr)
      exit(1)
    }
    let path = arguments[index + 1]
    let scope = arguments.firstIndex(of: "--scope").flatMap {
      arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil
    } ?? "https://www.googleapis.com/auth/gmail.readonly"
    do {
      print(try await GmailDesktopAuthorization.accessToken(
        clientFile: URL(fileURLWithPath: path), scope: scope))
    } catch {
      fputs("error: \(error.localizedDescription)\n", stderr)
      exit(1)
    }
  }
}
