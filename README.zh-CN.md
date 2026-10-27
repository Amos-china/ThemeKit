# ThemeKit

[English](README.md) | 简体中文

ThemeKit 是一个 UIKit 动态主题资源库，使用 Alamofire 下载 ZIP 主题包，通过
ZIPFoundation 安全解压到 App 沙盒，并支持按屏幕倍率加载 PNG 资源。

它适用于不重新发版也能更换颜色和图片的 App。ThemeKit 不内置具体主题、品牌色
或全局单例，接入 App 可以自行配置存储目录、资源限制和颜色 token。

## 环境要求

- iOS 15.0+
- Swift 5.0+
- UIKit
- CocoaPods 1.16+

ThemeKit 目前只提供 CocoaPods 集成方式。

## 安装

在 `Podfile` 中添加：

```ruby
platform :ios, '15.0'
use_frameworks!

target 'YourApp' do
  pod 'ThemeKit',
      :git => 'https://github.com/Amos-china/ThemeKit.git',
      :tag => '0.1.0'
end
```

本地开发时可以直接引用源码目录：

```ruby
pod 'ThemeKit', :path => '../ThemeKit'
```

然后执行：

```bash
pod install
open YourApp.xcworkspace
```

请打开 `.xcworkspace`，不要直接打开 `.xcodeproj`。

## 快速开始

通常在整个 App 的依赖组装阶段创建一个 `ThemeManager`：

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

### 恢复上次主题

App 启动时恢复上次启用的主题：

```swift
do {
    if try await manager.restore() == nil {
        // 没有历史主题，使用 App 默认样式。
    }
} catch {
    // 已保存的主题无效，ThemeKit 已清理异常状态。
}
```

### 安装内置主题

```swift
let archiveURL = Bundle.main.url(
    forResource: "ThemeOcean",
    withExtension: "zip"
)!

try await manager.install(
    archiveURL: archiveURL,
    source: .bundled
)
```

### 下载并安装远程主题

```swift
try await manager.downloadAndInstall(from: zipURL) { progress in
    Task { @MainActor in
        progressView.setProgress(
            Float(progress.fraction ?? 0),
            animated: true
        )
    }
}
```

下载可以通过下面的方法取消：

```swift
manager.cancelDownload()
```

取消或安装失败时，当前已经生效的主题不会被替换。

### 读取主题图片

```swift
let themeImage = try manager.image(named: "hero")
imageView.image = themeImage.image
```

在测试或 Preview 中需要指定倍率时：

```swift
let image = try manager.image(
    named: "hero",
    screenScale: 2
)
```

### 读取颜色 token

```swift
let palette = manager.palette!

view.backgroundColor = palette.color(
    "background",
    fallback: .systemBackground
)
label.textColor = palette.color(
    "textPrimary",
    fallback: .label
)
button.tintColor = palette.color(
    "primary",
    fallback: .systemBlue
)
```

## 主题资源包

ZIP 根目录必须直接包含唯一的 `manifest.json`，其他文件只能是 PNG 图片。

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

`manifest.json` 示例：

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

资源包规则：

- `schemaVersion` 必须为 `1`。
- `id`、`version` 只能使用字母、数字、`.`、`_`、`-`。
- 颜色使用 `#RRGGBB` 或 `#RRGGBBAA`，颜色 key 由接入 App 自行定义。
- `images` 的 value 始终填写不带倍率后缀的逻辑 1x 路径，例如
  `images/hero.png`。
- 实际 ZIP 中可以提供 1x、`@2x`、`@3x` 的任意组合。
- 每个逻辑图片至少要存在一个实际 PNG 文件。
- 可以只提供 `@3x`，低倍率设备会自动回退使用已有版本。
- 不允许符号链接、绝对路径、`..`、重复路径和非 PNG/JSON 文件。
- 默认限制为：压缩包 80 MB、解压后 200 MB、最多 2,000 个条目、
  最多 64 个逻辑图片。可以通过 `ThemeLimits` 设置更严格的值。

## 图片倍率处理

沙盒中的 PNG 不在 Asset Catalog 内，本身没有倍率元数据。ThemeKit 会根据屏幕
倍率选择文件，并使用实际文件倍率重新构造 `UIImage`：

```swift
let image = try manager.image(
    named: "hero",
    screenScale: 3
)

// image.resourcePath == "images/hero@3x.png"
// image.scale == 3
```

不要直接使用 `UIImage(contentsOfFile:)`。否则一张宽 1200 px 的 `@3x` 图片会
被当成 1200 pt，而不是正确的 400 pt。

## 存储与失败处理

默认资源目录结构：

```text
ThemeResources/
├── active-theme.json
├── staging/
└── themes/<theme-id>/<uuid>/
```

安装过程是事务式的：

1. 下载到临时文件。
2. 解压到唯一的 staging 目录。
3. 校验路径、ZIP 校验和、manifest、文件类型和 PNG 文件头。
4. 将校验通过的主题移动到最终目录。
5. 原子写入当前主题状态。
6. 清理旧主题版本。

任何一步失败都会删除 staging，当前已经启用的主题保持不变。资源目录会排除
iCloud 备份。

## 安全说明

ThemeKit 已校验 ZIP CRC32、路径穿越、符号链接、重复路径、大小限制、文件
类型、manifest 引用和 PNG 文件头，但不提供发布者身份认证。

生产环境建议服务端在返回资源包时同时返回 SHA-256 或签名，并在安装前校验。
HTTPS 只能保护传输过程，不能防止主题服务端被攻破后发布恶意图片。

## 自定义配置

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

## 示例工程

示例 App 包含 Ember 和 Tide 两个 ZIP 主题包，演示以下功能：

- 恢复上次启用的主题。
- 安装 App Bundle 中的主题包。
- 下载远程主题包，并显示进度、支持取消。
- 应用主题颜色 token。
- 加载正确的 `@2x` 或 `@3x` 图片。

示例代码位于 `Example/ThemeKitDemo`，使用 CocoaPods 管理依赖，使用 XcodeGen
生成工程文件：

```bash
cd Example/ThemeKitDemo
xcodegen generate
pod install
open ThemeKitDemo.xcworkspace
```

## 测试

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

也可以使用本机已有的模拟器 ID：

```bash
xcodebuild \
  -workspace ThemeKitDemo.xcworkspace \
  -scheme ThemeKitDemo \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>' \
  test
```

## License

ThemeKit 使用 MIT License，详见 `LICENSE`。
