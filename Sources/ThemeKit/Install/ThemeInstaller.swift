import Foundation
import ZIPFoundation

actor ThemeInstaller {
  private let fileManager: FileManager
  private let configuration: ThemeKitConfiguration
  private let rootURL: URL
  private let themesURL: URL
  private let stagingRootURL: URL
  private let stateURL: URL

  init(
    configuration: ThemeKitConfiguration,
    fileManager: FileManager = .default
  ) {
    self.configuration = configuration
    self.fileManager = fileManager

    rootURL = configuration.storageDirectory
    themesURL = rootURL.appendingPathComponent("themes", isDirectory: true)
    stagingRootURL = rootURL.appendingPathComponent("staging", isDirectory: true)
    stateURL = rootURL.appendingPathComponent("active-theme.json", isDirectory: false)
  }

  func install(archiveURL: URL, source: ThemeSource) throws -> InstalledTheme {
    try prepareDirectories()
    try validateArchiveFile(archiveURL)
    try removeStaleStagingDirectories()

    let stagingURL = stagingRootURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let extractedURL = stagingURL.appendingPathComponent("extracted", isDirectory: true)
    try fileManager.createDirectory(at: extractedURL, withIntermediateDirectories: true)

    defer {
      try? fileManager.removeItem(at: stagingURL)
    }

    let archive = try openArchive(at: archiveURL)
    let entries = Array(archive)
    try validate(entries: entries)
    try ensureManifestIsAtArchiveRoot(entries: entries)
    try extract(entries: entries, archive: archive, to: extractedURL)

    let manifest = try ThemeManifestValidator.decodeAndValidate(
      data: try Data(contentsOf: extractedURL.appendingPathComponent("manifest.json")),
      directoryURL: extractedURL,
      limits: configuration.limits,
      fileManager: fileManager
    )
    try ThemeManifestValidator.validatePNGs(
      in: extractedURL,
      fileManager: fileManager
    )

    let destinationURL =
      themesURL
      .appendingPathComponent(manifest.id, isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(
      at: destinationURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try fileManager.moveItem(at: extractedURL, to: destinationURL)
    try excludeFromBackup(destinationURL)

    return InstalledTheme(
      manifest: manifest,
      directoryURL: destinationURL,
      installedAt: Date(),
      source: source
    )
  }

  func activate(_ theme: InstalledTheme) throws {
    try prepareDirectories()

    guard let relativePath = relativeThemePath(for: theme.directoryURL),
      fileManager.fileExists(atPath: theme.directoryURL.path)
    else {
      throw ThemeKitError.fileOperationFailed("the theme installation directory does not exist")
    }

    let state = ActiveThemeState(
      relativePath: relativePath,
      installedAt: theme.installedAt,
      source: theme.source
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(state)
    try data.write(to: stateURL, options: .atomic)
    try excludeFromBackup(stateURL)
    try cleanupThemes(keeping: theme.directoryURL)
  }

  func restoreActiveTheme() throws -> InstalledTheme? {
    try prepareDirectories()
    guard fileManager.fileExists(atPath: stateURL.path) else { return nil }

    let state = try JSONDecoder().decode(
      ActiveThemeState.self,
      from: Data(contentsOf: stateURL)
    )
    guard
      let directoryURL = ThemePath.containedURL(
        relativePath: state.relativePath,
        root: themesURL
      )
    else {
      throw ThemeKitError.invalidManifest("the active theme path is invalid")
    }

    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      return nil
    }

    let manifest = try ThemeManifestValidator.decodeAndValidate(
      data: try Data(contentsOf: directoryURL.appendingPathComponent("manifest.json")),
      directoryURL: directoryURL,
      limits: configuration.limits,
      fileManager: fileManager
    )
    return InstalledTheme(
      manifest: manifest,
      directoryURL: directoryURL,
      installedAt: state.installedAt,
      source: state.source
    )
  }

  func discard(_ theme: InstalledTheme) {
    guard let relativePath = relativeThemePath(for: theme.directoryURL) else { return }
    guard relativePath.split(separator: "/").count == 2 else { return }
    try? fileManager.removeItem(at: theme.directoryURL)
  }

  func clearActiveState() {
    try? fileManager.removeItem(at: stateURL)
  }

  private func prepareDirectories() throws {
    do {
      try fileManager.createDirectory(at: themesURL, withIntermediateDirectories: true)
      try fileManager.createDirectory(at: stagingRootURL, withIntermediateDirectories: true)
      try excludeFromBackup(rootURL)
    } catch {
      throw ThemeKitError.fileOperationFailed(error.localizedDescription)
    }
  }

  private func validateArchiveFile(_ archiveURL: URL) throws {
    guard fileManager.fileExists(atPath: archiveURL.path) else {
      throw ThemeKitError.invalidArchive
    }

    let values = try archiveURL.resourceValues(forKeys: [.fileSizeKey])
    let fileSize = Int64(values.fileSize ?? 0)
    guard fileSize > 0 else {
      throw ThemeKitError.invalidArchive
    }
    guard fileSize <= configuration.limits.maxArchiveBytes else {
      throw ThemeKitError.archiveTooLarge(configuration.limits.maxArchiveBytes)
    }
  }

  private func openArchive(at archiveURL: URL) throws -> Archive {
    do {
      return try Archive(url: archiveURL, accessMode: .read)
    } catch {
      throw ThemeKitError.invalidArchive
    }
  }

  private func validate(entries: [Entry]) throws {
    guard entries.count <= configuration.limits.maxArchiveEntryCount else {
      throw ThemeKitError.tooManyArchiveEntries(
        configuration.limits.maxArchiveEntryCount
      )
    }

    var totalUncompressedSize: UInt64 = 0
    var paths = Set<String>()
    var jsonCount = 0

    for entry in entries {
      guard let path = ThemePath.sanitizedArchivePath(entry.path) else {
        throw ThemeKitError.unsafeArchiveEntry(entry.path)
      }
      if ThemePath.shouldIgnoreArchiveEntry(path) {
        continue
      }

      guard entry.type != .symlink else {
        throw ThemeKitError.symlinkNotAllowed(entry.path)
      }
      guard paths.insert(path.lowercased()).inserted else {
        throw ThemeKitError.duplicateArchiveEntry(entry.path)
      }

      let sizeResult = totalUncompressedSize.addingReportingOverflow(entry.uncompressedSize)
      guard !sizeResult.overflow else {
        throw ThemeKitError.archiveExpandsTooMuch(
          configuration.limits.maxUncompressedBytes
        )
      }
      totalUncompressedSize = sizeResult.partialValue
      guard totalUncompressedSize <= UInt64(configuration.limits.maxUncompressedBytes) else {
        throw ThemeKitError.archiveExpandsTooMuch(
          configuration.limits.maxUncompressedBytes
        )
      }

      if entry.type == .file {
        switch (path as NSString).pathExtension.lowercased() {
        case "json":
          jsonCount += 1
        case "png":
          break
        default:
          throw ThemeKitError.unsupportedArchiveEntry(path)
        }
      }
    }

    guard jsonCount > 0 else {
      throw ThemeKitError.manifestMissing
    }
    guard jsonCount == 1 else {
      throw ThemeKitError.manifestAmbiguous(jsonCount)
    }
  }

  private func extract(entries: [Entry], archive: Archive, to destinationURL: URL) throws {
    do {
      for entry in entries {
        guard let path = ThemePath.sanitizedArchivePath(entry.path),
          !ThemePath.shouldIgnoreArchiveEntry(path),
          let entryURL = ThemePath.containedURL(relativePath: path, root: destinationURL)
        else {
          continue
        }

        let checksum = try archive.extract(entry, to: entryURL)
        if entry.type != .directory, checksum != entry.checksum {
          throw ThemeKitError.invalidArchive
        }
      }
    } catch let error as ThemeKitError {
      throw error
    } catch {
      throw ThemeKitError.invalidArchive
    }
  }

  private func ensureManifestIsAtArchiveRoot(entries: [Entry]) throws {
    let manifestPath = entries.lazy
      .filter { $0.type == .file }
      .map(\.path)
      .first { path in
        let sanitized = ThemePath.sanitizedArchivePath(path)
        return sanitized?.lowercased().hasSuffix(".json") == true
      }

    guard let manifestPath,
      let sanitized = ThemePath.sanitizedArchivePath(manifestPath),
      !sanitized.contains("/")
    else {
      throw ThemeKitError.manifestMustBeAtArchiveRoot
    }
  }

  private func relativeThemePath(for directoryURL: URL) -> String? {
    let themePath = directoryURL.standardizedFileURL.path
    let rootPath = themesURL.standardizedFileURL.path
    let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
    guard themePath.hasPrefix(prefix) else { return nil }
    return String(themePath.dropFirst(prefix.count))
  }

  private func cleanupThemes(keeping activeURL: URL) throws {
    let activePath = activeURL.standardizedFileURL.path
    let children = try fileManager.contentsOfDirectory(
      at: themesURL,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    )

    for themeIDDirectory in children {
      let themeChildren =
        (try? fileManager.contentsOfDirectory(
          at: themeIDDirectory,
          includingPropertiesForKeys: nil,
          options: [.skipsHiddenFiles]
        )) ?? []
      for themeVersionDirectory in themeChildren
      where themeVersionDirectory.standardizedFileURL.path != activePath {
        try? fileManager.removeItem(at: themeVersionDirectory)
      }

      let remaining =
        (try? fileManager.contentsOfDirectory(
          at: themeIDDirectory,
          includingPropertiesForKeys: nil,
          options: [.skipsHiddenFiles]
        )) ?? []
      if remaining.isEmpty {
        try? fileManager.removeItem(at: themeIDDirectory)
      }
    }
  }

  private func removeStaleStagingDirectories() throws {
    guard
      let children = try? fileManager.contentsOfDirectory(
        at: stagingRootURL,
        includingPropertiesForKeys: nil
      )
    else {
      return
    }
    for child in children {
      try? fileManager.removeItem(at: child)
    }
  }

  private func excludeFromBackup(_ url: URL) throws {
    var mutableURL = url
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try mutableURL.setResourceValues(values)
  }
}
