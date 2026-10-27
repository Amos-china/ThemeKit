import Foundation

/// Download progress reported by the Alamofire downloader.
public struct ThemeDownloadProgress: Sendable {
  public let completedBytes: Int64
  public let totalBytes: Int64?

  public init(completedBytes: Int64, totalBytes: Int64?) {
    self.completedBytes = completedBytes
    self.totalBytes = totalBytes
  }

  public var fraction: Double? {
    guard let totalBytes, totalBytes > 0 else { return nil }
    return min(max(Double(completedBytes) / Double(totalBytes), 0), 1)
  }
}
