import Foundation

enum ThemeManifestValidator {
  static func decodeAndValidate(
    data: Data,
    directoryURL: URL,
    limits: ThemeLimits,
    fileManager: FileManager = .default
  ) throws -> ThemeManifest {
    let manifest: ThemeManifest
    do {
      manifest = try JSONDecoder().decode(ThemeManifest.self, from: data)
    } catch {
      throw ThemeKitError.invalidManifest(
        "JSON does not match the manifest schema (\(error.localizedDescription))"
      )
    }

    guard manifest.schemaVersion == 1 else {
      throw ThemeKitError.invalidManifest("schemaVersion must be 1")
    }
    guard ThemePath.isValidIdentifier(manifest.id, maximumLength: 64) else {
      throw ThemeKitError.invalidManifest(
        "id may contain only letters, numbers, dots, underscores, and hyphens, with a maximum length of 64"
      )
    }
    guard !manifest.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      manifest.name.count <= 80
    else {
      throw ThemeKitError.invalidManifest("name must not be empty and may not exceed 80 characters")
    }
    guard ThemePath.isValidIdentifier(manifest.version, maximumLength: 64) else {
      throw ThemeKitError.invalidManifest(
        "version may contain only letters, numbers, dots, underscores, and hyphens"
      )
    }
    guard !manifest.colors.isEmpty else {
      throw ThemeKitError.invalidManifest("colors must contain at least one token")
    }
    guard !manifest.images.isEmpty, manifest.images.count <= limits.maxImageCount else {
      throw ThemeKitError.invalidManifest(
        "images must contain between 1 and \(limits.maxImageCount) entries"
      )
    }

    for (name, value) in manifest.colors {
      guard ThemePath.isSafeResourceIdentifier(name, maximumLength: 64) else {
        throw ThemeKitError.invalidManifest("color token \(name) is invalid")
      }
      guard ThemePath.isValidHexColor(value) else {
        throw ThemeKitError.invalidColor("\(name)=\(value)")
      }
    }

    var referencedFiles = Set<String>()
    for (name, path) in manifest.images {
      guard ThemePath.isSafeResourceIdentifier(name, maximumLength: 64) else {
        throw ThemeKitError.invalidManifest("image name \(name) is invalid")
      }
      guard let sanitized = ThemePath.sanitizedArchivePath(path),
        sanitized == path,
        ThemePath.basePNGPath(for: path) != nil
      else {
        throw ThemeKitError.invalidManifest(
          "image \(name) must use a canonical logical PNG path, such as images/hero.png"
        )
      }

      var existingVariantCount = 0
      for variant in ThemePath.allPNGVariants(for: path) {
        guard let url = ThemePath.containedURL(relativePath: variant.path, root: directoryURL),
          fileManager.fileExists(atPath: url.path)
        else {
          continue
        }

        existingVariantCount += 1
        guard referencedFiles.insert(variant.path.lowercased()).inserted else {
          throw ThemeKitError.invalidManifest(
            "multiple image names reference the same file: \(variant.path)"
          )
        }
      }

      guard existingVariantCount > 0 else {
        throw ThemeKitError.imageNotFound(path)
      }
    }

    return manifest
  }

  static func validatePNGs(
    in directoryURL: URL,
    fileManager: FileManager = .default
  ) throws {
    let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
    guard
      let enumerator = fileManager.enumerator(
        at: directoryURL,
        includingPropertiesForKeys: keys,
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
      )
    else {
      throw ThemeKitError.fileOperationFailed("unable to enumerate theme resources")
    }

    for case let fileURL as URL in enumerator {
      let values = try fileURL.resourceValues(forKeys: Set(keys))
      guard values.isRegularFile == true else { continue }

      let ext = fileURL.pathExtension.lowercased()
      if ext == "png" {
        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        guard PNGInspector.isValid(data) else {
          throw ThemeKitError.invalidPNG(fileURL.lastPathComponent)
        }
      } else if ext != "json" {
        throw ThemeKitError.unsupportedArchiveEntry(fileURL.lastPathComponent)
      }
    }
  }
}

private enum PNGInspector {
  private static let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

  static func isValid(_ data: Data) -> Bool {
    guard data.count >= 24, Array(data.prefix(8)) == signature else {
      return false
    }
    guard Array(data[12..<16]) == Array("IHDR".utf8) else {
      return false
    }

    let width = data[16..<20].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    let height = data[20..<24].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    return width > 0 && height > 0
  }
}
