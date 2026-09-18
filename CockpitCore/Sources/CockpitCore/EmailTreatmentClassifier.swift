import Foundation

enum EmailTreatmentClassifier {
  struct Classification {
    let treatment: EmailTreatment
    let transactionalKind: EmailTransactionalKind?
  }

  static func classify(
    piece: ContentPiece,
    provenance: GmailArtifactProvenance?,
    stream: Stream?,
    override: EmailSenderTreatmentOverride?
  ) -> Classification {
    if isClearlyHumanOneToOne(provenance) { return .init(treatment: .personal, transactionalKind: nil) }
    if let kind = transactionalKind(for: piece, provenance: provenance) {
      return .init(treatment: .transactional, transactionalKind: kind)
    }
    if hasAutomatedSenderShape(provenance), !isPublication(provenance) {
      return .init(treatment: .transactional, transactionalKind: .reference)
    }
    if let override { return .init(treatment: override.treatment, transactionalKind: nil) }
    guard isPublication(provenance) else { return .init(treatment: .personal, transactionalKind: nil) }
    if stream?.isGrabBag == true { return .init(treatment: .grabBag, transactionalKind: nil) }
    if hasPromotionalSignal(piece) { return .init(treatment: .offer, transactionalKind: nil) }
    return .init(treatment: .newsletter, transactionalKind: nil)
  }
}

private extension EmailTreatmentClassifier {
  /// A clearly human one-to-one sender wins before any subject marker. That keeps a person's
  /// "hotel confirmation" forward in the personal tier; ambiguous machine mail remains visible
  /// and is corrected through the explicit sender override when necessary.
  private static func isClearlyHumanOneToOne(_ provenance: GmailArtifactProvenance?) -> Bool {
    guard let provenance, !isPublication(provenance), !hasAutomatedSenderShape(provenance) else {
      return false
    }
    return provenance.toRecipientCount + provenance.ccRecipientCount <= 2
  }

  /// A missing or unreadable provenance record fails conservatively to publication. S4 rows retain
  /// it, but a legacy/malformed Artifact must not be promoted to personal just because evidence is
  /// absent. In particular, List-Unsubscribe always makes the message publication mail.
  private static func isPublication(_ provenance: GmailArtifactProvenance?) -> Bool {
    guard let provenance else { return true }
    if provenance.listUnsubscribe?.trimmedNonEmpty != nil || provenance.listID?.trimmedNonEmpty != nil {
      return true
    }
    if provenance.precedence?.lowercased().split(separator: ",").contains(where: {
      $0.trimmingCharacters(in: .whitespacesAndNewlines) == "bulk"
    }) == true {
      return true
    }
    if let domain = provenance.sendingDomain ?? provenance.dkimDomain,
      isEmailServiceProvider(domain)
    {
      return true
    }
    // A human sender addressed only to a small set is the deterministic personal default. Wider
    // recipient lists are safely routed to the visible newsletter tier until Jon corrects them.
    return provenance.toRecipientCount + provenance.ccRecipientCount > 2
  }

  private static func isEmailServiceProvider(_ domain: String) -> Bool {
    let domains = [
      "amazonses.com", "beehiiv.com", "cmail1.com", "constantcontact.com",
      "convertkit-mail.com", "hubspotemail.net", "klaviyomail.com", "mailchimpapp.net",
      "mailgun.org", "mandrillapp.com", "sendgrid.net", "substack.com",
    ]
    return domains.contains { domain == $0 || domain.hasSuffix(".\($0)") }
  }

  /// Retained sender shape and subject/type markers give transactional mail a deterministic home.
  /// This deliberately remains a small classifier: it does not inspect Contacts or retain any
  /// sender reputation. A sender correction wins for the ambiguous residue below.
  private static func transactionalKind(
    for piece: ContentPiece, provenance: GmailArtifactProvenance?
  ) -> EmailTransactionalKind? {
    let haystack = typeHaystack(for: piece)
    if ephemeralMarkers.contains(where: haystack.contains) { return .ephemeral }
    if financeStrongMarkers.contains(where: haystack.contains)
      || (financeWeakMarkers.contains(where: haystack.contains) && hasFinanceSenderShape(provenance))
    {
      return .finance
    }
    if hasShipmentMarker(in: haystack), hasShipmentSenderShape(provenance) {
      return .shipment
    }
    if referenceMarkers.contains(where: haystack.contains) { return .reference }
    if referenceWithAutomatedSenderMarkers.contains(where: haystack.contains),
      hasAutomatedSenderShape(provenance)
    {
      return .reference
    }
    return nil
  }
}

private extension EmailTreatmentClassifier {
  private static func hasAutomatedSenderShape(_ provenance: GmailArtifactProvenance?) -> Bool {
    guard let provenance else { return false }
    let normalized = senderLocalPart(provenance) ?? ""
    let automatedLocalParts = [
      "account", "accounts", "autopay", "automated", "billpay", "billing", "deposit", "deposits",
      "dispatch", "ebill", "fulfillment", "notification", "notifications", "order", "orders",
      "reservation", "reservations", "shipping", "shippingnotification", "tracking", "delivery",
      "mailerdaemon",
    ]
    return normalized.contains("noreply") || normalized.contains("donotreply")
      || automatedLocalParts.contains(normalized) || hasCareOrHealthDomain(provenance)
      || hasFinanceSenderShape(provenance) || hasShipmentSenderShape(provenance)
  }

  private static func hasFinanceSenderShape(_ provenance: GmailArtifactProvenance?) -> Bool {
    let financeDomains = [
      "americanexpress.com", "att.com", "bankofamerica.com", "bofa.com", "capitalone.com",
      "chase.com", "citi.com", "discover.com", "paypal.com", "wellsfargo.com",
    ]
    let financeDomainTokens = ["bank", "banking", "bill", "billing", "ebill", "invoice", "payment"]
    let financeLocalParts = [
      "account", "accounts", "autopay", "billpay", "billing", "deposit", "deposits", "ebill",
      "payment", "payments", "statement", "statements",
    ]
    let domains = senderDomains(provenance)
    let localPart = senderLocalPart(provenance)
    return domains.contains { domain in
      financeDomains.contains { domain == $0 || domain.hasSuffix(".\($0)") }
        || financeDomainTokens.contains { domain.contains($0) }
    } || localPart.map { local in financeLocalParts.contains { local == $0 || local.contains($0) } } == true
  }

  private static func hasShipmentSenderShape(_ provenance: GmailArtifactProvenance?) -> Bool {
    let carrierDomains = ["dhl.com", "fedex.com", "ontrac.com", "ups.com", "usps.com"]
    let commerceDomainTokens = ["commerce", "fulfillment", "orders", "retail", "shop", "store"]
    let shipmentLocalParts = [
      "delivery", "dispatch", "fulfillment", "order", "orders", "shipping", "shippingnotification",
      "tracking",
    ]
    let domains = senderDomains(provenance)
    let localPart = senderLocalPart(provenance)
    return domains.contains { domain in
      carrierDomains.contains { domain == $0 || domain.hasSuffix(".\($0)") }
        || domain.split(separator: ".").contains { label in
          commerceDomainTokens.contains(String(label))
        }
    } || localPart.map { local in shipmentLocalParts.contains { local == $0 || local.contains($0) } } == true
  }

  private static func hasCareOrHealthDomain(_ provenance: GmailArtifactProvenance?) -> Bool {
    let careHealthDomainTokens = ["care", "chart", "clinic", "health", "hospital", "medical", "patient"]
    return senderDomains(provenance).contains { domain in
      domain.split(separator: ".").contains { label in
        careHealthDomainTokens.contains(String(label))
      }
    }
  }

  private static func senderDomains(_ provenance: GmailArtifactProvenance?) -> [String] {
    [provenance?.sendingDomain, provenance?.dkimDomain].compactMap { $0?.lowercased() }
  }

  private static func senderLocalPart(_ provenance: GmailArtifactProvenance?) -> String? {
    guard let address = provenance?.senderAddress,
      let localPart = address.split(separator: "@", maxSplits: 1).first else { return nil }
    return localPart.lowercased().filter(\.isLetter)
  }

  private static func hasShipmentMarker(in haystack: String) -> Bool {
    shipmentMarkers.contains(where: haystack.contains) || hasOrderOrTrackingNumber(in: haystack)
  }

  private static func hasOrderOrTrackingNumber(in haystack: String) -> Bool {
    let pattern = #"(?i)\b(?:order|tracking|shipment|package)\s*(?:#|no\.?|number|id)\s*[:\-]?\s*[a-z0-9][a-z0-9\-]{3,}\b"#
    guard let expression = try? NSRegularExpression(pattern: pattern) else { return false }
    return expression.firstMatch(in: haystack, range: NSRange(haystack.startIndex..., in: haystack)) != nil
  }

  private static func typeHaystack(for piece: ContentPiece) -> String {
    let subjects = (try? JSONDecoder().decode(
      [String].self, from: Data((piece.subjects ?? "").utf8)
    ))?.joined(separator: " ") ?? ""
    return [piece.title, piece.summary ?? "", subjects].joined(separator: " ").lowercased()
  }

  private static let ephemeralMarkers = [
    "verification code", "sign-in code", "signin code", "security code", "one-time code",
    "one time code", "login code", "your code is", "otp",
  ]

  private static let referenceMarkers = [
    "booking confirmation", "confirmation number", "delivery update", "delivery notice",
    "hotel confirmation", "invoice", "order confirmation", "payment received", "receipt",
    "reservation confirmation", "shipment", "shipping notice", "trade-in",
  ]

  private static let referenceWithAutomatedSenderMarkers = ["appointment", "estimate", "visit"]

  private static let financeStrongMarkers = [
    "amount due", "autopay", "e-bill", "ebill", "mobile check deposit", "statement",
  ]

  private static let financeWeakMarkers = ["account notice", "bill", "deposit", "invoice", "payment"]

  private static let shipmentMarkers = [
    "delivery", "on its way", "order confirmation", "order has been received", "order received",
    "out for delivery", "package", "shipped", "tracking", "your order",
  ]

  /// The existing type pass supplies `summary` and `subjects`; these cheap deterministic markers
  /// distinguish promotional publication from an ordinary think-piece without another model call.
  private static func hasPromotionalSignal(_ piece: ContentPiece) -> Bool {
    let haystack = typeHaystack(for: piece)
    let markers = [
      "allocation", "case sale", "discount", "free shipping", "limited release", "new arrival",
      "offer", "pre-order", "sale", "save ", "shop now", "wine club",
    ]
    return markers.contains { haystack.contains($0) }
  }
}
