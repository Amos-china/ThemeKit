Pod::Spec.new do |spec|
  spec.name             = "ThemeKit"
  spec.version          = "0.1.0"
  spec.summary          = "Secure ZIP theme downloads, installation, and image loading for iOS."
  spec.description      = <<-DESC
    ThemeKit downloads signed-by-transport ZIP theme packages with Alamofire,
    extracts and validates them with ZIPFoundation, and resolves scale-aware PNG
    resources from the app sandbox.
  DESC
  spec.homepage         = "https://github.com/Amos-china/ThemeKit"
  spec.license          = { :type => "MIT", :file => "LICENSE" }
  spec.author           = { "Amos-china" => "Amos-china@users.noreply.github.com" }
  spec.source           = {
    :git => "https://github.com/Amos-china/ThemeKit.git",
    :tag => spec.version.to_s
  }

  spec.ios.deployment_target = "15.0"
  spec.swift_versions = ["5.0"]
  spec.frameworks = "UIKit"
  spec.source_files = "Sources/ThemeKit/**/*.swift"

  spec.dependency "Alamofire", "~> 5.12"
  spec.dependency "ZIPFoundation", "~> 0.9"
end
