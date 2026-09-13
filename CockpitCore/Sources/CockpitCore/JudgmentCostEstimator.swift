import Foundation
import LLMClientKit

/// Cockpit-owned Sonnet price sheet, in USD per million tokens. S2's judgment request does not
/// enable prompt caching, but its distinct cache buckets remain explicit for future changes.
public struct JudgmentPriceSheet: Equatable, Sendable {
  public let inputPerMillion: Decimal
  public let outputPerMillion: Decimal
  public let cacheReadInputPerMillion: Decimal
  public let cacheCreationInputPerMillion: Decimal

  public init(
    inputPerMillion: Decimal, outputPerMillion: Decimal, cacheReadInputPerMillion: Decimal,
    cacheCreationInputPerMillion: Decimal
  ) {
    self.inputPerMillion = inputPerMillion
    self.outputPerMillion = outputPerMillion
    self.cacheReadInputPerMillion = cacheReadInputPerMillion
    self.cacheCreationInputPerMillion = cacheCreationInputPerMillion
  }

  /// Claude Sonnet 5 standard API pricing, checked 2026-09-13: $2 input / $10 output per MTok.
  /// Anthropic's standard 5-minute cache multipliers are 0.1x reads and 1.25x writes.
  public static let sonnet5 = Self(
    inputPerMillion: 2, outputPerMillion: 10,
    cacheReadInputPerMillion: 0.2, cacheCreationInputPerMillion: 2.5
  )
}

public enum JudgmentCostEstimator {
  public static func estimate(
    usage: ModelUsage?, requestedProvider: FrontierProvider,
    priceSheet: JudgmentPriceSheet = .sonnet5
  ) -> Decimal? {
    guard let usage else { return nil }
    switch requestedProvider {
    case .anthropic:
      return cost(usage.inputTokens, at: priceSheet.inputPerMillion)
        + cost(usage.outputTokens, at: priceSheet.outputPerMillion)
        + cost(usage.cacheReadInputTokens ?? 0, at: priceSheet.cacheReadInputPerMillion)
        + cost(usage.cacheCreationInputTokens ?? 0, at: priceSheet.cacheCreationInputPerMillion)
    case .openai:
      // This is a Sonnet-only price sheet. A future OpenAI judgment configuration must supply
      // its own price sheet and retain OpenAI's "cache read is a subset" accounting rule.
      return nil
    }
  }

  private static func cost(_ tokens: Int, at perMillion: Decimal) -> Decimal {
    Decimal(tokens) * perMillion / 1_000_000
  }
}
