Pod::Spec.new do |s|

  s.name          = "TFSRT"
  s.version       = "1.0.0"
  s.summary       = "Camera and Microphone streaming library via SRT for iOS, macOS, tvOS and visionOS."
  s.swift_version = "5.10"

  s.description  = <<-DESC
  SRTHaishinKit. Camera and Microphone streaming library via SRT for iOS, macOS, tvOS and visionOS.
  DESC

  s.homepage     = "https://github.com/talk-fun/HaishinKit.swift.git"
  s.license      = "New BSD"
  s.author       = { "欢拓" => "20427740@qq.com" }
  s.authors      = { "欢拓" => "20427740@qq.com" }
  s.source       = { :git => "https://github.com/talk-fun/HaishinKit.swift.git", :tag => "#{s.version}" }

  s.ios.deployment_target = "13.0"
  s.ios.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
  s.ios.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }

  s.tvos.deployment_target = "13.0"
  s.tvos.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=appletvsimulator*]' => 'x86_64' }
  s.tvos.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=appletvsimulator*]' => 'x86_64' }

  s.source_files = "SRTHaishinKit/SRTHaishinKit.h" ,"SRTHaishinKit/Sources/SRT/*.swift" ,"TFSDK/*.{h,m,swift}" , "Examples/iOS/AudioCapture.swift"

  s.vendored_frameworks = "SRTHaishinKit/Vendor/SRT/libsrt.xcframework"
  s.dependency 'HaishinKit', '2.0.1'
  s.dependency 'TFGPUImage'
end
