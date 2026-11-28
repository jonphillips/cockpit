import Foundation

public enum WatchedListSource: Sendable, Equatable {
  case iCloudDrive
  case local
  case lastGoodCopy
}

public struct WatchedAddressList: Sendable, Equatable {
  public let addresses: [String]
  public let source: WatchedListSource
  public var usedFallback: Bool { source == .lastGoodCopy }
}

public enum WatchedListError: Error, LocalizedError {
  case unreadable
  public var errorDescription: String? { "watched.txt could not be read and no last-good copy is available." }
}

public struct OfferWatchStore: @unchecked Sendable {
  public let directory: URL
  public let watchedListURL: URL
  private let cloudFolder: URL
  private let fileManager: FileManager

  public init(directory: URL, cloudFolder: URL? = nil, fileManager: FileManager = .default) {
    self.directory = directory
    watchedListURL = directory.appending(path: "watched.txt")
    self.cloudFolder = cloudFolder ?? fileManager.homeDirectoryForCurrentUser
      .appending(path: "Library/Mobile Documents/com~apple~CloudDocs/Offer Watch", directoryHint: .isDirectory)
    self.fileManager = fileManager
  }

  public static var standard: Self {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appending(path: "OfferWatch", directoryHint: .isDirectory)
    return Self(directory: base)
  }

  public func watchedAddresses() throws -> WatchedAddressList {
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    let cloud = cloudFolder.appending(path: "watched.txt")
    let source = fileManager.fileExists(atPath: cloud.path) ? cloud : watchedListURL
    guard fileManager.fileExists(atPath: source.path) else {
      return WatchedAddressList(addresses: [], source: .local)
    }
    let data: Data
    let listSource: WatchedListSource
    do {
      data = try Data(contentsOf: source)
      listSource = source == watchedListURL ? .local : .iCloudDrive
    } catch {
      guard source == cloud, fileManager.fileExists(atPath: watchedListURL.path) else { throw WatchedListError.unreadable }
      data = try Data(contentsOf: watchedListURL)
      listSource = .lastGoodCopy
    }
    let addresses = Self.parseAddresses(String(decoding: data, as: UTF8.self))
    if listSource == .iCloudDrive { try data.write(to: watchedListURL, options: .atomic) }
    return WatchedAddressList(addresses: addresses, source: listSource)
  }

  public static func parseAddresses(_ text: String) -> [String] {
    let addresses = text.split(whereSeparator: { $0.isNewline }).compactMap { line -> String? in
      let uncommented = line.split(separator: "#", maxSplits: 1).first.map(String.init) ?? ""
      let value = uncommented.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      guard isMailboxAddress(value) else { return nil }
      return value
    }
    return Array(Set(addresses)).sorted()
  }

  private static func isMailboxAddress(_ value: String) -> Bool {
    let parts = value.split(separator: "@", omittingEmptySubsequences: false)
    guard parts.count == 2, !parts[0].isEmpty, parts[1].contains(".") else { return false }
    let localAllowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.!#$%&'*+-/=?^_`{|}~")
    let domainAllowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-")
    return parts[0].unicodeScalars.allSatisfy(localAllowed.contains)
      && parts[1].unicodeScalars.allSatisfy(domainAllowed.contains)
      && !parts[1].hasPrefix(".") && !parts[1].hasSuffix(".")
  }

  public func loadState(now: Date = .now) throws -> OfferWatchState {
    let url = directory.appending(path: "state.json")
    guard fileManager.fileExists(atPath: url.path) else { return OfferWatchState(now: now) }
    return try JSONDecoder.offerWatch.decode(OfferWatchState.self, from: Data(contentsOf: url))
  }

  public func save(_ state: OfferWatchState) throws {
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    let data = try JSONEncoder.offerWatch.encode(state)
    try data.write(to: directory.appending(path: "state.json"), options: .atomic)
  }

  public func loadPairings() throws -> [OfferWatchPairing] {
    let url = directory.appending(path: "pairings.json")
    guard fileManager.fileExists(atPath: url.path) else { return [] }
    return try JSONDecoder.offerWatch.decode([OfferWatchPairing].self, from: Data(contentsOf: url))
  }

  public func savePairings(_ pairings: [OfferWatchPairing]) throws {
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    let data = try JSONEncoder.offerWatch.encode(pairings)
    try data.write(to: directory.appending(path: "pairings.json"), options: .atomic)
  }

  /// Re-reads immediately before mutation so a concurrent `pair` command is preserved.
  public func removePairings(ids: Set<String>) throws {
    let current = try loadPairings()
    try savePairings(current.filter { !ids.contains($0.id) })
  }
}

extension JSONEncoder {
  fileprivate static var offerWatch: JSONEncoder { let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; return encoder }
}
extension JSONDecoder {
  fileprivate static var offerWatch: JSONDecoder { let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return decoder }
}
