import Foundation
import UIKit

enum ThemePath {
  static func sanitizedArchivePath(_ rawPath: String) -> String? {
    let path = rawPath.replacingOccurrences(of: "\\", with: "/")
    guard !path.isEmpty,
      !path.hasPrefix("/"),
      !path.contains("\0")
    else {
      return nil
    }

    let rawComponents = path.split(separator: "/", omittingEmptySubsequences: false)
    var components: [Substring] = []
    components.reserveCapacity(rawComponents.count)

    for (index, component) in rawComponents.enumerated() {
      if component.isEmpty {
        let isTrailingSeparator = index == rawComponents.count - 1 && path.hasSuffix("/")
        guard isTrailingSeparator else { return nil }
        continue
      }

      guard component != ".", component != ".." else { return nil }
      components.append(component)
    }

    guard !components.isEmpty else { return nil }
    return components.joined(separator: "/")
  }

  static func shouldIgnoreArchiveEntry(_ path: String) -> Bool {
    let components = path.split(separator: "/").map(String.init)
    guard let first = components.first else { return true }

    return first == "__MACOSX"
      || components.contains(where: { $0.hasPrefix(".") })
  }

  static func containedURL(relativePath: String, root: URL) -> URL? {
    guard let sanitized = sanitizedArchivePath(relativePath) else { return nil }

    let rootURL = root.standardizedFileURL
    let candidate =
      rootURL
      .appendingPathComponent(sanitized, isDirectory: false)
      .standardizedFileURL
    let rootPrefix = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"

    guard candidate.path.hasPrefix(rootPrefix) else { return nil }
    return candidate
  }

  static func isValidIdentifier(_ value: String, maximumLength: Int) -> Bool {
    guard !value.isEmpty, value.count <= maximumLength else { return false }

    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
    return value.unicodeScalars.allSatisfy { allowed.contains($0) }
  }

  static func isSafeResourceIdentifier(_ value: String, maximumLength: Int) -> Bool {
    guard !value.isEmpty, value.count <= maximumLength else { return false }
    return value.unicodeScalars.allSatisfy { !$0.properties.isWhitespace }
  }

  static func isValidHexColor(_ value: String) -> Bool {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("#") else { return false }

    let digits = trimmed.dropFirst()
    guard digits.count == 6 || digits.count == 8 else { return false }
    return digits.allSatisfy(\.isHexDigit)
  }

  /// Normalizes `images/hero@2x.png` to the logical resource path `images/hero.png`.
  static func basePNGPath(for path: String) -> String? {
    guard path.lowercased().hasSuffix(".png") else { return nil }

    var stem = String(path.dropLast(4))
    let lowercasedStem = stem.lowercased()
    if lowercasedStem.hasSuffix("@3x") {
      stem.removeLast(3)
    } else if lowercasedStem.hasSuffix("@2x") {
      stem.removeLast(3)
    }

    guard !stem.isEmpty else { return nil }
    return stem + ".png"
  }

  static func allPNGVariants(for path: String) -> [(path: String, scale: CGFloat)] {
    guard let base = basePNGPath(for: path) else { return [] }
    let stem = String(base.dropLast(4))
    return [
      (stem + "@3x.png", 3),
      (stem + "@2x.png", 2),
      (base, 1),
    ]
  }

  static func imageCandidates(
    for path: String,
    screenScale: CGFloat
  ) -> [(path: String, scale: CGFloat)] {
    guard let base = basePNGPath(for: path) else { return [] }
    let stem = String(base.dropLast(4))

    if screenScale >= 3 {
      return [
        (stem + "@3x.png", 3),
        (stem + "@2x.png", 2),
        (base, 1),
      ]
    }

    if screenScale >= 2 {
      return [
        (stem + "@2x.png", 2),
        (base, 1),
        (stem + "@3x.png", 3),
      ]
    }

    return [
      (base, 1),
      (stem + "@2x.png", 2),
      (stem + "@3x.png", 3),
    ]
  }

  static func nativeScaleForImageFile(_ path: String) -> CGFloat? {
    guard path.lowercased().hasSuffix(".png") else { return nil }
    let stem = String(path.dropLast(4)).lowercased()
    if stem.hasSuffix("@3x") { return 3 }
    if stem.hasSuffix("@2x") { return 2 }
    return 1
  }
}
