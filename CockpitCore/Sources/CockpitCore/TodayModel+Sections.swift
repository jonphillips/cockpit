extension TodayModel {
  public func rows(for role: ContentRole) -> [TodayRequest.Row] {
    content.rows.filter {
      $0.role == role && !OfferPieces.isOffer(role: $0.role, treatment: $0.treatment)
    }
  }
}
