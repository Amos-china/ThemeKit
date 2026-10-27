import Foundation

/// Errors surfaced by ThemeKit.
public enum ThemeKitError: LocalizedError, Equatable, Sendable {
  case invalidEndpoint
  case operationInProgress
  case archiveTooLarge(Int64)
  case invalidArchive
  case tooManyArchiveEntries(Int)
  case archiveExpandsTooMuch(Int64)
  case unsafeArchiveEntry(String)
  case symlinkNotAllowed(String)
  case duplicateArchiveEntry(String)
  case unsupportedArchiveEntry(String)
  case manifestMissing
  case manifestAmbiguous(Int)
  case manifestMustBeAtArchiveRoot
  case invalidManifest(String)
  case invalidColor(String)
  case imageNotFound(String)
  case invalidPNG(String)
  case fileOperationFailed(String)
  case downloadFailed(String)
  case unexpectedResponse
  case missingCurrentTheme

  public var errorDescription: String? {
    switch self {
    case .invalidEndpoint:
      return "The theme URL must use HTTP or HTTPS."
    case .operationInProgress:
      return "Another theme operation is already in progress."
    case .archiveTooLarge(let limit):
      return "The theme archive exceeds the \(Self.formattedBytes(limit)) limit."
    case .invalidArchive:
      return "The theme archive is not a valid ZIP file or is corrupted."
    case .tooManyArchiveEntries(let limit):
      return "The theme archive contains more than \(limit) entries."
    case .archiveExpandsTooMuch(let limit):
      return "The expanded theme archive exceeds the \(Self.formattedBytes(limit)) limit."
    case .unsafeArchiveEntry(let path):
      return "The theme archive contains an unsafe path: \(path)"
    case .symlinkNotAllowed(let path):
      return "The theme archive contains a symbolic link: \(path)"
    case .duplicateArchiveEntry(let path):
      return "The theme archive contains a duplicate path: \(path)"
    case .unsupportedArchiveEntry(let path):
      return "The theme archive contains an unsupported file: \(path)"
    case .manifestMissing:
      return "The theme archive does not contain a JSON manifest."
    case .manifestAmbiguous(let count):
      return "The theme archive contains \(count) JSON files; exactly one is required."
    case .manifestMustBeAtArchiveRoot:
      return "manifest.json must be placed directly at the archive root."
    case .invalidManifest(let reason):
      return "The theme manifest is invalid: \(reason)"
    case .invalidColor(let value):
      return "Invalid color \(value). Use #RRGGBB or #RRGGBBAA."
    case .imageNotFound(let name):
      return "Theme image not found: \(name)"
    case .invalidPNG(let path):
      return "Invalid PNG file: \(path)"
    case .fileOperationFailed(let reason):
      return "Theme file operation failed: \(reason)"
    case .downloadFailed(let reason):
      return "Theme download failed: \(reason)"
    case .unexpectedResponse:
      return "The theme server returned an unexpected response."
    case .missingCurrentTheme:
      return "No theme has been installed or activated yet."
    }
  }

  private static func formattedBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
  }
}
