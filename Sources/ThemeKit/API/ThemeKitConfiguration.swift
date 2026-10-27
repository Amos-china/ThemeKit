import Foundation

/// Runtime configuration for a ThemeKit manager.
public struct ThemeKitConfiguration: Sendable {
  /// Root directory for active state, installed themes, and staging files.
  public var storageDirectory: URL
  /// Fallback color used when a requested manifest token is absent.
  public var fallbackColorHex: String
  public var limits: ThemeLimits
  public var requestTimeout: TimeInterval
  public var resourceTimeout: TimeInterval

  public init(
    storageDirectory: URL,
    fallbackColorHex: String = "#FFFFFF",
    limits: ThemeLimits = ThemeLimits(),
    requestTimeout: TimeInterval = 30,
    resourceTimeout: TimeInterval = 180
  ) {
    self.storageDirectory = storageDirectory
    self.fallbackColorHex = fallbackColorHex
    self.limits = limits
    self.requestTimeout = requestTimeout
    self.resourceTimeout = resourceTimeout
  }

  public static func applicationSupport(
    namespace: String = "ThemeResources",
    fileManager: FileManager = .default
  ) -> ThemeKitConfiguration {
    let base =
      fileManager.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first ?? fileManager.temporaryDirectory

    return ThemeKitConfiguration(
      storageDirectory: base.appendingPathComponent(namespace, isDirectory: true)
    )
  }
}
