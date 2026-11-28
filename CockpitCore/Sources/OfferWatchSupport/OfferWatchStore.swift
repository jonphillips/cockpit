import Foundation

public struct OfferWatchStore {
  public let directory: URL
  public let watchedListURL: URL
  public private(set) var didUseLastGoodCopy = false
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

  public mutating func watchedAddresses() throws -> [String] {
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    didUseLastGoodCopy = false
    let cloud = cloudFolder.appending(path: "watched.txt")
    let source = fileManager.fileExists(atPath: cloud.path) ? cloud : watchedListURL
    guard fileManager.fileExists(atPath: source.path) else { return [] }
    let data: Data
    do { data = try Data(contentsOf: source) }
    catch {
      guard source == cloud, fileManager.fileExists(atPath: watchedListURL.path) else { throw error }
      data = try Data(contentsOf: watchedListURL)
      didUseLastGoodCopy = true
    }
    let text = String(decoding: data, as: UTF8.self)
    let addresses = text.split(whereSeparator: { $0.isNewline }).compactMap { line -> String? in
      let uncommented = line.split(separator: "#", maxSplits: 1).first.map(String.init) ?? ""
      let value = uncommented.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      guard Self.isMailboxAddress(value) else { return nil }
      return value
    }
    if source != watchedListURL && !didUseLastGoodCopy { try data.write(to: watchedListURL, options: .atomic) }
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
}

extension JSONEncoder {
  fileprivate static var offerWatch: JSONEncoder { let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; return encoder }
}
extension JSONDecoder {
  fileprivate static var offerWatch: JSONDecoder { let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return decoder }
}
