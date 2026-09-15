import SQLiteData

public enum BodyCompleteness: String, Codable, QueryBindable, Sendable {
  case full
  case truncated
  case teaser

  public var readerLabel: String {
    switch self {
    case .full: "Full body"
    case .truncated: "Body truncated"
    case .teaser: "Teaser only"
    }
  }
}
