import Observation
import SQLiteData

/// Owns the reachable-first Stream surface. It has no Gmail dependency and does not mutate Edition,
/// Today attention, or provider disposition when a piece is opened.
@MainActor
@Observable
public final class StreamHandlingModel {
  @ObservationIgnored @Fetch public var content = StreamHandlingRequest.Value()

  public init(streamID: Stream.ID) {
    _content = Fetch(wrappedValue: .init(), StreamHandlingRequest(streamID: streamID))
  }

  public var stream: Stream? { content.stream }
  public var rows: [StreamHandlingRequest.Row] { content.rows }
}
