import UIKit
import XCTest

@testable import ThemeKit

final class ThemeManifestTests: XCTestCase {
  func testManifestAcceptsArbitraryColorTokens() {
    let manifest = ThemeManifest(
      id: "ocean",
      name: "Ocean",
      version: "1.0.0",
      colors: [
        "brand": "#006C67",
        "surface": "#F4FAF8",
      ],
      images: ["hero": "images/hero.png"]
    )

    let palette = ThemePalette(manifest: manifest, fallback: .black)
    XCTAssertEqual(palette["brand"], UIColor(themeHex: "#006C67"))
    XCTAssertEqual(palette["missing"], .black)
  }

  func testHexColorSupportsAlpha() {
    let color = UIColor(themeHex: "#FF000080")
    XCTAssertNotNil(color)
    var alpha: CGFloat = 0
    XCTAssertTrue(color?.getRed(nil, green: nil, blue: nil, alpha: &alpha) == true)
    XCTAssertEqual(
      alpha,
      128.0 / 255.0,
      accuracy: 0.001
    )
    XCTAssertNil(UIColor(themeHex: "#GG0000"))
  }
}
