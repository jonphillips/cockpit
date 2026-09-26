import Foundation

/// The shared boundary for email offers shown in the review surface and processed for extraction.
public enum OfferPieces {
  public static func isOffer(role: ContentRole?, treatment: EmailTreatment?) -> Bool {
    guard role != .grabBag else { return false }
    return role == .offers || treatment == .offer
  }
}
