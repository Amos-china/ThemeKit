import UIKit

@MainActor
final class ThemeImageRepository {
  private struct CacheKey: Hashable {
    let themeKey: String
    let name: String
    let scale: CGFloat

    var storageKey: String {
      "\(themeKey)|\(name)|\(scale)"
    }
  }

  private let cache = NSCache<NSString, UIImage>()
  private let fileManager: FileManager

  init(fileManager: FileManager = .default) {
    self.fileManager = fileManager
    cache.countLimit = 128
  }

  func image(
    named name: String,
    in theme: InstalledTheme,
    screenScale: CGFloat
  ) throws -> ThemeImage {
    guard let relativePath = theme.manifest.images[name] else {
      throw ThemeKitError.imageNotFound(name)
    }

    for candidate in ThemePath.imageCandidates(for: relativePath, screenScale: screenScale) {
      guard
        let fileURL = ThemePath.containedURL(
          relativePath: candidate.path,
          root: theme.directoryURL
        ),
        fileManager.fileExists(atPath: fileURL.path)
      else {
        continue
      }

      let actualScale = ThemePath.nativeScaleForImageFile(candidate.path) ?? candidate.scale
      let key =
        CacheKey(
          themeKey: theme.cacheKey,
          name: name,
          scale: actualScale
        ).storageKey as NSString

      if let cached = cache.object(forKey: key) {
        return ThemeImage(
          image: cached,
          resourcePath: candidate.path,
          scale: actualScale
        )
      }

      guard let image = UIImage(contentsOfFile: fileURL.path),
        let cgImage = image.cgImage
      else {
        throw ThemeKitError.invalidPNG(candidate.path)
      }

      // Files outside an asset catalog carry no scale metadata.
      let scaledImage = UIImage(
        cgImage: cgImage,
        scale: actualScale,
        orientation: image.imageOrientation
      )
      scaledImage.accessibilityIdentifier = name
      scaledImage.accessibilityLabel = name
      cache.setObject(scaledImage, forKey: key)

      return ThemeImage(
        image: scaledImage,
        resourcePath: candidate.path,
        scale: actualScale
      )
    }

    throw ThemeKitError.imageNotFound(relativePath)
  }

  func removeAll() {
    cache.removeAllObjects()
  }
}
