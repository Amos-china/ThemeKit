import ThemeKit
import UIKit

final class DemoViewController: UIViewController {
  private let manager = ThemeManager(
    configuration: .applicationSupport(namespace: "ThemeKitDemo")
  )

  private let titleLabel = UILabel()
  private let statusLabel = UILabel()
  private let imageView = UIImageView()
  private let progressView = UIProgressView(progressViewStyle: .default)
  private let urlField = UITextField()
  private let installButton = UIButton(type: .system)
  private let cancelButton = UIButton(type: .system)
  private let emberButton = UIButton(type: .system)
  private let tideButton = UIButton(type: .system)

  override func viewDidLoad() {
    super.viewDidLoad()
    buildUI()

    Task { @MainActor in
      do {
        if try await manager.restore() == nil {
          try await installBundledTheme(named: "ThemeEmber")
        }
        renderTheme()
      } catch {
        show(error)
      }
    }
  }

  private func buildUI() {
    view.backgroundColor = .systemBackground

    titleLabel.font = .systemFont(ofSize: 32, weight: .black)
    titleLabel.numberOfLines = 0

    statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
    statusLabel.numberOfLines = 0
    statusLabel.textColor = .secondaryLabel

    imageView.contentMode = .scaleAspectFill
    imageView.clipsToBounds = true
    imageView.layer.cornerRadius = 22
    imageView.backgroundColor = .secondarySystemBackground

    urlField.placeholder = "https://example.com/theme.zip"
    urlField.borderStyle = .roundedRect
    urlField.keyboardType = .URL
    urlField.autocapitalizationType = .none
    urlField.autocorrectionType = .no

    installButton.setTitle("Download and apply", for: .normal)
    installButton.addTarget(self, action: #selector(downloadTapped), for: .touchUpInside)

    cancelButton.setTitle("Cancel", for: .normal)
    cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    cancelButton.isHidden = true

    emberButton.setTitle("Ember", for: .normal)
    emberButton.addTarget(self, action: #selector(emberTapped), for: .touchUpInside)

    tideButton.setTitle("Tide", for: .normal)
    tideButton.addTarget(self, action: #selector(tideTapped), for: .touchUpInside)

    let bundledButtons = UIStackView(arrangedSubviews: [emberButton, tideButton])
    bundledButtons.distribution = .fillEqually

    let downloadButtons = UIStackView(arrangedSubviews: [installButton, cancelButton])
    downloadButtons.spacing = 8
    downloadButtons.distribution = .fillEqually

    let stack = UIStackView(arrangedSubviews: [
      titleLabel,
      statusLabel,
      imageView,
      urlField,
      downloadButtons,
      progressView,
      bundledButtons,
    ])
    stack.axis = .vertical
    stack.spacing = 16
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
      stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      imageView.heightAnchor.constraint(equalToConstant: 260),
      progressView.heightAnchor.constraint(equalToConstant: 4),
    ])
  }

  @objc private func downloadTapped() {
    let endpoint = urlField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !endpoint.isEmpty else {
      statusLabel.text = "Enter a ZIP URL first."
      return
    }

    setLoading(true)
    Task { @MainActor in
      do {
        try await manager.downloadAndInstall(from: endpoint) { [weak self] progress in
          Task { @MainActor in
            self?.progressView.setProgress(Float(progress.fraction ?? 0), animated: true)
            self?.statusLabel.text = "Downloading \(progress.completedBytes) bytes"
          }
        }
        progressView.setProgress(1, animated: true)
        renderTheme()
        statusLabel.text = "Theme applied."
      } catch is CancellationError {
        statusLabel.text = "Download cancelled. Current theme was preserved."
      } catch {
        show(error)
      }
      setLoading(false)
    }
  }

  @objc private func cancelTapped() {
    manager.cancelDownload()
  }

  @objc private func emberTapped() {
    installBundled("ThemeEmber")
  }

  @objc private func tideTapped() {
    installBundled("ThemeTide")
  }

  private func installBundled(_ name: String) {
    setLoading(true)
    Task { @MainActor in
      do {
        try await installBundledTheme(named: name)
        renderTheme()
        statusLabel.text = "Bundled theme applied."
      } catch {
        show(error)
      }
      setLoading(false)
    }
  }

  private func installBundledTheme(named name: String) async throws {
    guard let url = Bundle.main.url(forResource: name, withExtension: "zip") else {
      throw DemoError.missingBundledTheme(name)
    }
    _ = try await manager.install(archiveURL: url)
  }

  private func renderTheme() {
    guard let theme = manager.currentTheme,
      let palette = manager.palette
    else {
      return
    }

    titleLabel.text = theme.manifest.name
    titleLabel.textColor = palette.color("textPrimary", fallback: .label)
    view.backgroundColor = palette.color("background", fallback: .systemBackground)
    statusLabel.textColor = palette.color("textSecondary", fallback: .secondaryLabel)
    installButton.tintColor = palette.color("primary", fallback: .systemBlue)
    emberButton.tintColor = palette.color("primary", fallback: .systemBlue)
    tideButton.tintColor = palette.color("primary", fallback: .systemBlue)
    imageView.image = try? manager.image(named: "hero").image
  }

  private func setLoading(_ loading: Bool) {
    installButton.isEnabled = !loading
    emberButton.isEnabled = !loading
    tideButton.isEnabled = !loading
    cancelButton.isHidden = !loading
  }

  private func show(_ error: Error) {
    statusLabel.text =
      (error as? LocalizedError)?.errorDescription
      ?? error.localizedDescription
  }
}

private enum DemoError: LocalizedError {
  case missingBundledTheme(String)

  var errorDescription: String? {
    switch self {
    case .missingBundledTheme(let name):
      return "Missing bundled theme \(name).zip."
    }
  }
}
