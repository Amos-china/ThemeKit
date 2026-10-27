# ThemeKit

ThemeKit is a small UIKit library for downloading ZIP theme packages with
Alamofire, installing them safely with ZIPFoundation, and loading scale-aware
PNG resources from the app sandbox.

It is designed for apps that need to change colors and images without shipping
a new binary. ThemeKit does not contain a demo theme, brand palette, or global
singleton; each app supplies its own configuration and color tokens.

## Requirements

- iOS 15.0+
- Swift 5.0+
- UIKit
- CocoaPods 1.16+

## Installation

### CocoaPods

```ruby
platform :ios, '15.0'
use_frameworks!

target 'YourApp' do
  pod 'ThemeKit', :git => 'https://github.com/Amos-china/ThemeKit.git', :tag => '0.1.0'
end
```

During local development:

```ruby
pod 'ThemeKit', :path => '../ThemeKit'
```

Then run:

```bash
pod install
open YourApp.xcworkspace
```

## Quick Start

Create one manager for the app, usually during dependency composition:

```swift
import ThemeKit
import UIKit

@MainActor
final class ThemeCoordinator {
    let manager = ThemeManager(
        configuration: .applicationSupport(namespace: "AppThemes")
    )
}
```

Restore the last active theme at launch:

```swift
do {
    if try await manager.restore() == nil {
        // No previous theme. Apply your app's default appearance.
    }
} catch {
    // The stored theme was invalid and has been discarded.
}
```

Install a bundled ZIP:

```swift
let archiveURL = Bundle.main.url(
    forResource: "ThemeOcean",
    withExtension: "zip"
)!
try await manager.install(archiveURL: archiveURL, source: .bundled)
```

Download and install a remote ZIP:

```swift
try await manager.downloadAndInstall(from: zipURL) { progress in
    Task { @MainActor in
        progressView.setProgress(Float(progress.fraction ?? 0), animated: true)
    }
}
```

Read an image:

```swift
let themeImage = try manager.image(named: "hero")
imageView.image = themeImage.image
```

For non-UIKit tests or previews, pass the scale explicitly:

```swift
let image = try manager.image(named: "hero", screenScale: 2)
```

Read color tokens:

```swift
let palette = manager.palette!
view.backgroundColor = palette.color("background", fallback: .systemBackground)
label.textColor = palette.color("textPrimary", fallback: .label)
button.tintColor = palette.color("primary", fallback: .systemBlue)
```

## Theme Package

The ZIP must contain exactly one `manifest.json` directly at its root. All
other files must be PNG images.

```text
ThemeOcean.zip
├── manifest.json
└── images
    ├── hero.png
    ├── hero@2x.png
    ├── hero@3x.png
    ├── mark.png
    ├── mark@2x.png
    └── mark@3x.png
```

Example `manifest.json`:

```json
{
  "schemaVersion": 1,
  "id": "ocean",
  "name": "Ocean",
  "version": "1.0.0",
  "colors": {
    "background": "#F4FAF8",
    "surface": "#FFFFFF",
    "primary": "#006C67",
    "primaryText": "#FFFFFF",
    "textPrimary": "#102A28",
    "textSecondary": "#52706D",
    "border": "#C7DDD9"
  },
  "images": {
    "hero": "images/hero.png",
    "mark": "images/mark.png"
  }
}
```

Rules:

- `schemaVersion` must be `1`.
- `id` and `version` use letters, numbers, `.`, `_`, and `-`.
- Colors use `#RRGGBB` or `#RRGGBBAA`. Color keys are app-defined tokens.
- An image value is always the logical 1x path, such as `images/hero.png`.
  The archive may provide any combination of 1x, `@2x`, and `@3x` files.
- Each logical image must have at least one physical file.
- A logical image may contain only `@3x`; lower-scale devices fall back to it.
- Symbolic links, absolute paths, `..`, duplicate entries, and non-PNG/JSON
  files are rejected.
- Default limits are 80 MB compressed, 200 MB expanded, 2,000 entries, and 64
  logical images. Configure stricter values with `ThemeLimits`.

## Image Scale Handling

Images outside an asset catalog have no scale metadata. ThemeKit resolves a
logical image by screen scale and explicitly constructs `UIImage` with the
physical file's scale:

```swift
let image = try manager.image(named: "hero", screenScale: 3)
// image.resourcePath == "images/hero@3x.png"
// image.scale == 3
```

Do not use `UIImage(contentsOfFile:)` directly. A 1200 px `@3x` file would be
treated as 1200 pt instead of 400 pt.

## Storage and Failure Behavior

The default layout under the configured storage directory is:

```text
ThemeResources/
├── active-theme.json
├── staging/
└── themes/<theme-id>/<uuid>/
```

Installation is transactional:

1. Download to a temporary file.
2. Extract into a unique staging directory.
3. Validate paths, ZIP checksums, the manifest, file types, and PNG headers.
4. Move the validated theme into its final directory.
5. Atomically write active state.
6. Remove older theme versions.

If any step fails, staging is removed and the currently active theme remains
unchanged. The storage directory is excluded from iCloud backup.

## Security Notes

ThemeKit validates ZIP CRC32, path traversal, symbolic links, duplicate paths,
size limits, file types, manifest references, and PNG headers. It does not
provide publisher authentication.

For production, have the server return a SHA-256 digest or signature together
with the package and verify it before installation. HTTPS protects transport,
but it does not prevent a compromised theme server from publishing malicious
images.

## Custom Configuration

```swift
let configuration = ThemeKitConfiguration(
    storageDirectory: customDirectory,
    fallbackColorHex: "#FFFFFF",
    limits: ThemeLimits(
        maxArchiveBytes: 40 * 1_024 * 1_024,
        maxUncompressedBytes: 100 * 1_024 * 1_024,
        maxArchiveEntryCount: 500,
        maxImageCount: 32
    ),
    requestTimeout: 30,
    resourceTimeout: 180
)

let manager = ThemeManager(configuration: configuration)
```

## Example

The example app contains Ember and Tide ZIP packages and demonstrates:

- restoring a persisted theme
- installing a bundled ZIP
- downloading a remote ZIP with progress and cancellation
- applying color tokens
- loading the correct `@2x` or `@3x` image

See `Example/ThemeKitDemo`. The example uses CocoaPods for the local package and
XcodeGen for its project file:

```bash
cd Example/ThemeKitDemo
xcodegen generate
pod install
open ThemeKitDemo.xcworkspace
```

## Testing

With CocoaPods:

```bash
cd Example/ThemeKitDemo
xcodegen generate
pod install
xcodebuild \
  -workspace ThemeKitDemo.xcworkspace \
  -scheme ThemeKitDemo \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  test
```

## License

ThemeKit is available under the MIT license. See `LICENSE`.
