import ThemeKit
import UIKit
import XCTest

final class ThemeKitDemoTests: XCTestCase {
  func testBundledThemesArePackaged() {
    XCTAssertNotNil(Bundle.main.url(forResource: "ThemeEmber", withExtension: "zip"))
    XCTAssertNotNil(Bundle.main.url(forResource: "ThemeTide", withExtension: "zip"))
  }

  @MainActor
  func testDemoManagerInstallsBundledTheme() async throws {
    let storage = FileManager.default.temporaryDirectory
      .appendingPathComponent("ThemeKitDemoTests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: storage) }

    let manager = ThemeManager(
      configuration: ThemeKitConfiguration(storageDirectory: storage)
    )
    let archive = try XCTUnwrap(
      Bundle.main.url(forResource: "ThemeEmber", withExtension: "zip")
    )

    let theme = try await manager.install(archiveURL: archive)
    XCTAssertEqual(theme.manifest.id, "ember")
    XCTAssertEqual(try manager.image(named: "hero", screenScale: 3).scale, 3)
  }

}
