Pod::Spec.new do |s|

  s.name         = "lf"
  s.version      = "0.5.12"
  s.summary      = "Camera and Microphone streaming library via RTMP, HLS for iOS, macOS."

  s.description  = <<-DESC
  lf is a lIVE fRAMEWORK. Camera and Microphone streaming library via RTMP, HLS for iOS, macOS.
  DESC

  s.homepage     = "https://github.com/shogo4405/lf.swift"
  s.license      = "New BSD"
  s.author       = { "shogo4405" => "shogo4405@gmail.com" }
  s.authors      = { "shogo4405" => "shogo4405@gmail.com" }
  s.source       = { :git => "https://github.com/shogo4405/lf.swift.git", :tag => "#{s.version}" }
  s.social_media_url = "http://twitter.com/shogo4405"

  s.ios.deployment_target = "8.0"
  s.ios.source_files = "Platforms/iOS/*.{h,swift}"
  s.osx.deployment_target = "10.11"
  s.osx.source_files = "Platforms/macOS/*.{h,swift}"

  s.source_files = "Sources/**/*.swift"
  s.dependency 'XCGLogger', '~> 4.0.0'

end

