@testable import CockpitCore
import Dependencies
import LLMClientKit
import Testing

@MainActor
struct AISettingsTests {
  @Test("Saving a key persists it, masks it, and clears the draft")
  func saveKey() {
    withDependencies {
      $0.apiKeyStore = .testValue
    } operation: {
      let model = AISettingsModel()
      model.refresh()
      #expect(model.maskedKeys.isEmpty)

      model.draftKey = "sk-ant-secret-value-1234567890"
      model.saveButtonTapped()

      #expect(model.draftKey.isEmpty)
      #expect(model.maskedKeys[.anthropic] != nil)
      // The stored preview never reveals the whole secret.
      #expect(model.maskedKeys[.anthropic]?.contains("secret") == false)
      #expect(model.statusMessage != nil)
    }
  }

  @Test("Blank input does not write a key")
  func blankInputIgnored() {
    withDependencies {
      $0.apiKeyStore = .testValue
    } operation: {
      let model = AISettingsModel()
      model.draftKey = "   "
      model.saveButtonTapped()
      #expect(model.maskedKeys.isEmpty)
    }
  }

  @Test("Removing a key clears it from the store")
  func removeKey() {
    withDependencies {
      $0.apiKeyStore = .testValue
    } operation: {
      let model = AISettingsModel()
      model.draftKey = "sk-ant-secret-value-1234567890"
      model.saveButtonTapped()
      #expect(model.maskedKeys[.anthropic] != nil)

      model.clearButtonTapped(.anthropic)
      #expect(model.maskedKeys[.anthropic] == nil)
    }
  }

  @Test("The active provider selection persists and reloads")
  func providerPreferencePersists() {
    let store = FrontierPreferenceStore.testValue
    withDependencies {
      $0.apiKeyStore = .testValue
      $0.frontierPreferenceStore = store
    } operation: {
      let model = AISettingsModel()
      model.provider = .openai
      model.persistPreferredProvider()
    }
    #expect(store.preferred() == .openai)

    let reloaded = withDependencies {
      $0.apiKeyStore = .testValue
      $0.frontierPreferenceStore = store
    } operation: { () -> FrontierProvider in
      let model = AISettingsModel()
      model.refresh()
      return model.provider
    }
    #expect(reloaded == .openai)
  }
}

@Suite
struct ImportProviderResolutionTests {
  @Test("Preferred provider wins when it has a key")
  func preferredWithKey() {
    let provider = PersonalKnowledgeModel.resolveImportProvider(
      preferred: .openai,
      isConfigured: { $0 == .openai || $0 == .anthropic }
    )
    #expect(provider == .openai)
  }

  @Test("Falls back to the first configured provider when the preferred one has no key")
  func preferredWithoutKeyFallsBack() {
    let provider = PersonalKnowledgeModel.resolveImportProvider(
      preferred: .openai,
      isConfigured: { $0 == .anthropic }
    )
    #expect(provider == .anthropic)
  }

  @Test("Resolves to nil when nothing is configured, so the call degrades to on-device")
  func noneConfigured() {
    let provider = PersonalKnowledgeModel.resolveImportProvider(
      preferred: nil,
      isConfigured: { _ in false }
    )
    #expect(provider == nil)
  }

  @Test("With no preference, the first configured provider is used")
  func noPreferenceUsesFirstConfigured() {
    let provider = PersonalKnowledgeModel.resolveImportProvider(
      preferred: nil,
      isConfigured: { $0 == .openai }
    )
    #expect(provider == .openai)
  }
}
