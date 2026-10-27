import UIKit
import XCTest

@testable import ThemeKit

@MainActor
final class ThemeKitIntegrationTests: XCTestCase {
  private var storageURL: URL!
  private var manager: ThemeManager!

  override func setUpWithError() throws {
    storageURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("ThemeKitTests-\(UUID().uuidString)", isDirectory: true)
    manager = ThemeManager(
      configuration: ThemeKitConfiguration(
        storageDirectory: storageURL,
        fallbackColorHex: "#FFFFFF"
      )
    )
  }

  override func tearDownWithError() throws {
    if let storageURL {
      try? FileManager.default.removeItem(at: storageURL)
    }
  }

  func testInstallsRestoresAndLoadsScaledImage() async throws {
    let theme = try await manager.install(archiveURL: fixtureURL())

    XCTAssertEqual(theme.manifest.id, "ember")
    XCTAssertEqual(manager.currentTheme, theme)
    XCTAssertNotNil(manager.palette?["background"])

    let image = try manager.image(named: "hero", screenScale: 3)
    XCTAssertEqual(image.resourcePath, "images/hero@3x.png")
    XCTAssertEqual(image.scale, 3)

    let secondManager = ThemeManager(
      configuration: ThemeKitConfiguration(storageDirectory: storageURL)
    )
    let restored = try await secondManager.restore()
    XCTAssertEqual(restored?.manifest, theme.manifest)
    XCTAssertEqual(restored?.source, .bundled)
  }

  func testFailedInstallPreservesActiveTheme() async throws {
    let active = try await manager.install(archiveURL: fixtureURL())

    let invalidArchive = storageURL
      .deletingLastPathComponent()
      .appendingPathComponent("invalid-\(UUID().uuidString).zip")
    try Data("not a zip".utf8).write(to: invalidArchive)
    defer { try? FileManager.default.removeItem(at: invalidArchive) }

    do {
      _ = try await manager.install(archiveURL: invalidArchive)
      XCTFail("Expected invalid archive to fail")
    } catch {
      XCTAssertEqual(error as? ThemeKitError, .invalidArchive)
    }

    XCTAssertEqual(manager.currentTheme, active)
    let restored = try await ThemeManager(
      configuration: ThemeKitConfiguration(storageDirectory: storageURL)
    ).restore()
    XCTAssertEqual(restored?.manifest.id, active.manifest.id)
  }

  func testRejectsDownloadWithoutHTTP() async {
    do {
      _ = try await manager.downloadAndInstall(from: "file:///tmp/theme.zip")
      XCTFail("Expected invalid endpoint to fail")
    } catch {
      XCTAssertEqual(error as? ThemeKitError, .invalidEndpoint)
    }
  }

  private func fixtureURL() -> URL {
    if let bundled = Bundle(for: Self.self).url(
      forResource: "ThemeEmber",
      withExtension: "zip"
    ) {
      return bundled
    }

    return URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("ThemeKitDemoTests/Fixtures/ThemeEmber.zip")
  }
}
