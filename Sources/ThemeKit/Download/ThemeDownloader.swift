import Alamofire
import Foundation

final class ThemeDownloader {
  private let session: Session
  private let fileManager: FileManager
  private let configuration: ThemeKitConfiguration
  private let stateQueue = DispatchQueue(label: "com.themekit.downloader.state")
  private var activeRequest: DownloadRequest?

  init(
    configuration: ThemeKitConfiguration,
    fileManager: FileManager = .default
  ) {
    self.configuration = configuration
    self.fileManager = fileManager

    let sessionConfiguration = URLSessionConfiguration.af.default
    sessionConfiguration.timeoutIntervalForRequest = configuration.requestTimeout
    sessionConfiguration.timeoutIntervalForResource = configuration.resourceTimeout
    session = Session(configuration: sessionConfiguration)
  }

  func download(
    from endpoint: String,
    progress: @escaping ThemeManager.ProgressHandler
  ) async throws -> URL {
    guard let url = Self.validatedURL(from: endpoint) else {
      throw ThemeKitError.invalidEndpoint
    }

    let destinationURL = fileManager.temporaryDirectory
      .appendingPathComponent("themekit-\(UUID().uuidString).zip")

    var headers = HTTPHeaders.default
    headers.add(.accept("application/zip, application/octet-stream, */*"))

    let request = session.download(
      url,
      method: .get,
      headers: headers,
      requestModifier: { request in
        request.cachePolicy = .reloadIgnoringLocalCacheData
      },
      to: { _, _ in
        (destinationURL, [.removePreviousFile, .createIntermediateDirectories])
      }
    )

    stateQueue.sync {
      activeRequest = request
    }

    request.downloadProgress(queue: .main) { progressValue in
      progress(
        ThemeDownloadProgress(
          completedBytes: max(progressValue.completedUnitCount, 0),
          totalBytes: progressValue.totalUnitCount > 0
            ? progressValue.totalUnitCount
            : nil
        )
      )
    }

    do {
      let response = await request.serializingDownloadedFileURL(
        automaticallyCancelling: false
      ).response
      clearActiveRequest()

      if Task.isCancelled {
        throw CancellationError()
      }
      if let error = response.error {
        if error.isExplicitlyCancelledError {
          throw CancellationError()
        }
        throw ThemeKitError.downloadFailed(
          error.errorDescription ?? error.localizedDescription
        )
      }
      guard let statusCode = response.response?.statusCode,
        (200..<300).contains(statusCode)
      else {
        throw ThemeKitError.unexpectedResponse
      }

      let fileSize = try destinationURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
      guard fileSize > 0 else {
        throw ThemeKitError.unexpectedResponse
      }
      guard fileSize <= configuration.limits.maxArchiveBytes else {
        throw ThemeKitError.archiveTooLarge(configuration.limits.maxArchiveBytes)
      }
      return destinationURL
    } catch {
      clearActiveRequest()
      try? fileManager.removeItem(at: destinationURL)
      throw error
    }
  }

  func cancel() {
    stateQueue.sync { activeRequest }?.cancel()
  }

  private func clearActiveRequest() {
    stateQueue.sync {
      activeRequest = nil
    }
  }

  private static func validatedURL(from value: String) -> URL? {
    guard let url = URL(string: value),
      let scheme = url.scheme?.lowercased(),
      scheme == "https" || scheme == "http",
      url.host != nil
    else {
      return nil
    }
    return url
  }
}
