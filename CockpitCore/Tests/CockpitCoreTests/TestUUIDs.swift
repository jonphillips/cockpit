import Foundation

extension UUID {
  /// A distinct, deterministic id for the Artifact a test seeds alongside this ContentPiece.
  ///
  /// Inverts every byte of the piece id, so it is injective (distinct pieces never share an
  /// artifact id) and never collides with the small `UUID(n)` ids tests seed directly.
  /// `hashValue` is randomly seeded per process and must not be used for this.
  var seededArtifactID: UUID {
    var bytes = uuid
    withUnsafeMutableBytes(of: &bytes) { raw in
      for index in raw.indices { raw[index] = ~raw[index] }
    }
    return UUID(uuid: bytes)
  }
}
