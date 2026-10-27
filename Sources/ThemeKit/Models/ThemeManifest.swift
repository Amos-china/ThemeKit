import Foundation
import UIKit

/// The JSON manifest stored at the root of every theme archive.
public struct ThemeManifest: Codable, Equatable, Sendable {
  public let schemaVersion: Int
  public let id: String
  public let name: String
  public let version: String
  public let colors: [String: String]
  public let images: [String: String]

  public init(
    schemaVersion: Int = 1,
    id: String,
    name: String,
    version: String,
    colors: [String: String],
    images: [String: String]
  ) {
    self.schemaVersion = schemaVersion
    self.id = id
    self.name = name
    self.version = version
    self.colors = colors
    self.images = images
  }
}

/// A validated theme whose resources have been installed into app storage.
public struct InstalledTheme: Equatable, Sendable {
  public let manifest: ThemeManifest
  public let directoryURL: URL
  public let installedAt: Date
  public let source: ThemeSource

  public init(
    manifest: ThemeManifest,
    directoryURL: URL,
    installedAt: Date,
    source: ThemeSource
  ) {
    self.manifest = manifest
    self.directoryURL = directoryURL
    self.installedAt = installedAt
    self.source = source
  }

  var cacheKey: String {
    directoryURL.standardizedFileURL.path
  }
}

/// Describes where an installed theme came from.
public enum ThemeSource: String, Codable, Sendable {
  case bundled
  case downloaded
}

struct ActiveThemeState: Codable, Sendable {
  let relativePath: String
  let installedAt: Date
  let source: ThemeSource
}

/// A decoded image and the scale of the PNG file that produced it.
public struct ThemeImage {
  public let image: UIImage
  public let resourcePath: String
  public let scale: CGFloat

  public init(image: UIImage, resourcePath: String, scale: CGFloat) {
    self.image = image
    self.resourcePath = resourcePath
    self.scale = scale
  }
}
