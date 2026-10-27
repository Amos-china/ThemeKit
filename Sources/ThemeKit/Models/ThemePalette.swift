import UIKit

/// Maps manifest color tokens to UIKit colors.
///
/// ThemeKit deliberately does not know an app's color vocabulary. A manifest
/// can contain any tokens, and callers use the ones their UI needs.
public struct ThemePalette: Equatable, Sendable {
  public let colors: [String: UIColor]
  public let fallback: UIColor

  public init(
    manifest: ThemeManifest,
    fallback: UIColor = .clear
  ) {
    var decoded: [String: UIColor] = [:]
    for (name, value) in manifest.colors {
      if let color = UIColor(themeHex: value) {
        decoded[name] = color
      }
    }
    colors = decoded
    self.fallback = fallback
  }

  public subscript(_ token: String) -> UIColor {
    colors[token] ?? fallback
  }

  public func color(_ token: String, fallback customFallback: UIColor? = nil) -> UIColor {
    colors[token] ?? customFallback ?? fallback
  }
}

public extension UIColor {
  convenience init?(themeHex value: String) {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("#") else { return nil }

    let digits = String(trimmed.dropFirst())
    guard digits.count == 6 || digits.count == 8,
      let number = UInt64(digits, radix: 16)
    else {
      return nil
    }

    if digits.count == 6 {
      self.init(
        red: CGFloat((number >> 16) & 0xFF) / 255,
        green: CGFloat((number >> 8) & 0xFF) / 255,
        blue: CGFloat(number & 0xFF) / 255,
        alpha: 1
      )
    } else {
      self.init(
        red: CGFloat((number >> 24) & 0xFF) / 255,
        green: CGFloat((number >> 16) & 0xFF) / 255,
        blue: CGFloat((number >> 8) & 0xFF) / 255,
        alpha: CGFloat(number & 0xFF) / 255
      )
    }
  }

  /// Useful for selecting a light or dark keyboard/status-bar appearance.
  var isLightThemeColor: Bool {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0

    guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
      return true
    }

    let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
    return luminance > 0.58
  }
}
