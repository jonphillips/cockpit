import Observation
import SQLiteData

@MainActor
@Observable
public final class PendingFindListModel {
  @ObservationIgnored @Fetch(PendingFindListRequest()) public var content = .init()

  public init() {}

  public var rows: [PendingFindListRequest.Row] { content.rows }
}
