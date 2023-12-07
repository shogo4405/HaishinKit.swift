Pod::Spec.new do |s|

  s.name          = "HaishinKit"
  s.version       = "1.7.2"
  s.summary       = "Camera and Microphone streaming library via RTMP and SRT for iOS, macOS, tvOS and visionOS."
  s.swift_version = "5.9"

  s.description  = <<-DESC
  HaishinKit. Camera and Microphone streaming library via RTMP and SRT for iOS, macOS, tvOS and visionOS.
  DESC

  s.homepage     = "https://github.com/shogo4405/HaishinKit.swift"
  s.license      = "New BSD"
  s.author       = { "shogo4405" => "shogo4405@gmail.com" }
  s.authors      = { "shogo4405" => "shogo4405@gmail.com" }
  s.source       = { :git => "https://github.com/shogo4405/HaishinKit.swift.git", :tag => "#{s.version}" }

  s.ios.deployment_target = "12.0"
  s.ios.source_files = "Platforms/iOS/*.{h,swift}"

  s.osx.deployment_target = "10.13"
  s.osx.source_files = "Platforms/iOS/*.{h,swift}"

  s.tvos.deployment_target = "12.0"
  s.tvos.source_files = "Platforms/iOS/*.{h,swift}"

  # s.visionos.deployment_target = "1.0"
  # s.visionos.source_files = "Platforms/iOS/*.{h,swift}"

  s.source_files = "Sources/**/*.swift"
  s.dependency 'Logboard', '~> 2.4.1'

end
