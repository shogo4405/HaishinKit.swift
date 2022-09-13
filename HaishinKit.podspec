Pod::Spec.new do |s|

  s.name          = "HaishinKit"
  s.version       = "1.2.7"
  s.summary       = "Camera and Microphone streaming library via RTMP, HLS for iOS, macOS and tvOS."
  s.swift_version = "5.5"

  s.description  = <<-DESC
  HaishinKit. Camera and Microphone streaming library via RTMP, HLS for iOS, macOS and tvOS.
  DESC

  s.homepage     = "https://github.com/shogo4405/HaishinKit.swift"
  s.license      = "New BSD"
  s.author       = { "shogo4405" => "shogo4405@gmail.com" }
  s.authors      = { "shogo4405" => "shogo4405@gmail.com" }
  s.source       = { :git => "https://github.com/shogo4405/HaishinKit.swift.git", :tag => "#{s.version}" }
  s.social_media_url = "https://twitter.com/shogo4405"

  s.ios.deployment_target = "9.0"
  s.ios.source_files = "Platforms/iOS/*.{h,swift}"

  s.osx.deployment_target = "10.11"
  s.osx.source_files = "Platforms/macOS/*.{h,swift}"

  s.tvos.deployment_target = "10.2"
  s.tvos.source_files = "Platforms/tvOS/*.{h,swift}"

  s.source_files = "Sources/**/*.swift"
  s.dependency 'Logboard', '~> 2.3.0'

end
