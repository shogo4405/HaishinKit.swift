Pod::Spec.new do |s|

  s.name         = "lf"
  s.version      = "0.3"
  s.summary      = "Camera/Microphone streaming library via RTMP/HLS for iOS/OSX"

  s.description  = <<-DESC
  lf is a lIVE fRAMEWORK. Camera/Microphone streaming library via RTMP/HLS for iOS/OSX
  DESC

  s.homepage     = "https://github.com/shogo4405/lf.swift"
  s.license      = "New BSD"
  s.author       = { "shogo4405" => "shogo4405@gmail.com" }
  s.authors      = { "shogo4405" => "shogo4405@gmail.com" }
  s.source       = { :git => "https://github.com/shogo4405/lf.swift.git", :tag => "#{s.version}" }
  s.social_media_url = "http://twitter.com/shogo4405"

  s.ios.deployment_target = "8.0"
  s.ios.source_files = "Platforms/iOS"
  s.osx.deployment_target = "10.10"
  s.osx.source_files = "Platforms/MacOS"

  s.source_files = "Sources/*.swift"
  s.dependency 'XCGLogger', '~> 3.3'
  s.dependency 'CryptoSwift', '~> 0.4'

end

