import Foundation

/// Resource limits applied before and while extracting an archive.
public struct ThemeLimits: Equatable, Sendable {
  public var maxArchiveBytes: Int64
  public var maxUncompressedBytes: Int64
  public var maxArchiveEntryCount: Int
  public var maxImageCount: Int

  public init(
    maxArchiveBytes: Int64 = 80 * 1_024 * 1_024,
    maxUncompressedBytes: Int64 = 200 * 1_024 * 1_024,
    maxArchiveEntryCount: Int = 2_000,
    maxImageCount: Int = 64
  ) {
    self.maxArchiveBytes = maxArchiveBytes
    self.maxUncompressedBytes = maxUncompressedBytes
    self.maxArchiveEntryCount = maxArchiveEntryCount
    self.maxImageCount = maxImageCount
  }
}
