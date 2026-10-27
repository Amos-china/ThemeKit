import Foundation
import UIKit

/// Owns the active theme and coordinates download, installation, and lookup.
@MainActor
public final class ThemeManager {
  public typealias ProgressHandler = @Sendable (ThemeDownloadProgress) -> Void

  public let configuration: ThemeKitConfiguration
  public private(set) var currentTheme: InstalledTheme?
  public private(set) var palette: ThemePalette?

  private let installer: ThemeInstaller
  private let downloader: ThemeDownloader
  private let imageRepository: ThemeImageRepository
  private var isOperationInProgress = false

  public init(configuration: ThemeKitConfiguration) {
    self.configuration = configuration
    installer = ThemeInstaller(configuration: configuration)
    downloader = ThemeDownloader(configuration: configuration)
    imageRepository = ThemeImageRepository()
  }

  /// Restores the last active theme from app storage.
  ///
  /// Returns `nil` when no valid active theme exists. Corrupt active state is
  /// removed so the app can continue with its own default appearance.
  @discardableResult
  public func restore() async throws -> InstalledTheme? {
    do {
      let restored = try await installer.restoreActiveTheme()
      apply(restored)
      return restored
    } catch {
      try? await installer.clearActiveState()
      currentTheme = nil
      palette = nil
      imageRepository.removeAll()
      throw error
    }
  }

  /// Installs and activates a ZIP file already available on disk.
  @discardableResult
  public func install(
    archiveURL: URL,
    source: ThemeSource = .bundled
  ) async throws -> InstalledTheme {
    try beginOperation()
    defer { endOperation() }

    let installed = try await installer.install(
      archiveURL: archiveURL,
      source: source
    )
    do {
      try await installer.activate(installed)
    } catch {
      await installer.discard(installed)
      throw error
    }

    apply(installed)
    return installed
  }

  /// Downloads a ZIP over HTTP(S), validates it, installs it, and activates it.
  @discardableResult
  public func downloadAndInstall(
    from endpoint: String,
    progress: @escaping ProgressHandler = { _ in }
  ) async throws -> InstalledTheme {
    try beginOperation()
    defer { endOperation() }

    let archiveURL = try await downloader.download(
      from: endpoint,
      progress: progress
    )
    defer {
      try? FileManager.default.removeItem(at: archiveURL)
    }

    let installed = try await installer.install(
      archiveURL: archiveURL,
      source: .downloaded
    )
    do {
      try await installer.activate(installed)
    } catch {
      await installer.discard(installed)
      throw error
    }

    apply(installed)
    return installed
  }

  public func cancelDownload() {
    downloader.cancel()
  }

  /// Reads an image from the current theme using its logical manifest name.
  public func image(
    named name: String,
    screenScale: CGFloat
  ) throws -> ThemeImage {
    guard let currentTheme else {
      throw ThemeKitError.missingCurrentTheme
    }
    return try imageRepository.image(
      named: name,
      in: currentTheme,
      screenScale: screenScale
    )
  }

  /// Convenience overload for UIKit call sites that want the main screen scale.
  public func image(named name: String) throws -> ThemeImage {
    try image(named: name, screenScale: UIScreen.main.scale)
  }

  public func clearImageCache() {
    imageRepository.removeAll()
  }

  private func apply(_ theme: InstalledTheme?) {
    currentTheme = theme
    if let theme {
      let fallback = UIColor(themeHex: configuration.fallbackColorHex) ?? .clear
      palette = ThemePalette(manifest: theme.manifest, fallback: fallback)
    } else {
      palette = nil
    }
    imageRepository.removeAll()
  }

  private func beginOperation() throws {
    guard !isOperationInProgress else {
      throw ThemeKitError.operationInProgress
    }
    isOperationInProgress = true
  }

  private func endOperation() {
    isOperationInProgress = false
  }
}
