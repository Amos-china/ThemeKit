import XCTest

@testable import ThemeKit

final class ThemePathTests: XCTestCase {
  func testRejectsTraversalAndAbsolutePaths() {
    XCTAssertNil(ThemePath.sanitizedArchivePath("../manifest.json"))
    XCTAssertNil(ThemePath.sanitizedArchivePath("images/../../manifest.json"))
    XCTAssertNil(ThemePath.sanitizedArchivePath("/manifest.json"))
    XCTAssertNil(ThemePath.sanitizedArchivePath("images//hero.png"))
    XCTAssertNil(ThemePath.sanitizedArchivePath("images/./hero.png"))
  }

  func testNormalizesImageScalePaths() {
    XCTAssertEqual(ThemePath.basePNGPath(for: "images/hero@2x.png"), "images/hero.png")
    XCTAssertEqual(ThemePath.basePNGPath(for: "images/hero@3x.png"), "images/hero.png")
    XCTAssertEqual(ThemePath.basePNGPath(for: "images/hero.png"), "images/hero.png")
    XCTAssertNil(ThemePath.basePNGPath(for: "images/hero.jpg"))
  }

  func testChoosesScreenScaleWithFallback() {
    XCTAssertEqual(
      ThemePath.imageCandidates(for: "images/hero.png", screenScale: 3).map(\.path),
      ["images/hero@3x.png", "images/hero@2x.png", "images/hero.png"]
    )
    XCTAssertEqual(
      ThemePath.imageCandidates(for: "images/hero.png", screenScale: 2).map(\.path),
      ["images/hero@2x.png", "images/hero.png", "images/hero@3x.png"]
    )
    XCTAssertEqual(
      ThemePath.imageCandidates(for: "images/hero.png", screenScale: 1).map(\.path),
      ["images/hero.png", "images/hero@2x.png", "images/hero@3x.png"]
    )
  }
}
