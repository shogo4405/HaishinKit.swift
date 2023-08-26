# HaishinKit for iOS, macOS, tvOS, and [Android](https://github.com/shogo4405/HaishinKit.kt).
[![GitHub Stars](https://img.shields.io/github/stars/shogo4405/HaishinKit.swift?style=social)](https://github.com/shogo4405/HaishinKit.swift/stargazers)
[![Release](https://img.shields.io/github/v/release/shogo4405/HaishinKit.swift)](https://github.com/shogo4405/HaishinKit.swift/releases/latest)
[![Platform Compatibility](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fshogo4405%2FHaishinKit.swift%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/shogo4405/HaishinKit.swift)
[![Swift Compatibility](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fshogo4405%2FHaishinKit.swift%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/shogo4405/HaishinKit.swift)
[![GitHub license](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](https://raw.githubusercontent.com/shogo4405/HaishinKit.swift/master/LICENSE.md)

* Camera and Microphone streaming library via RTMP, HLS for iOS, macOS, tvOS.
* README.md contains unreleased content, which can be tested on the main branch.
* [API Documentation](https://shogo4405.github.io/HaishinKit.swift/documentation/haishinkit)

<p align="center">
<strong>Sponsored with 💖 by</strong><br />
<a href="https://getstream.io/chat/sdk/ios/?utm_source=https://github.com/shogo4405/HaishinKit.swift&utm_medium=github&utm_content=developer&utm_term=swift" target="_blank">
<img src="https://stream-blog-v2.imgix.net/blog/wp-content/uploads/f7401112f41742c4e173c30d4f318cb8/stream_logo_white.png?w=350" alt="Stream Chat" style="margin: 8px" />
</a>
<br />
Enterprise Grade APIs for Feeds & Chat. <a href="https://getstream.io/tutorials/ios-chat/?utm_source=github.com/shogo4405/HaishinKit.swift&utm_medium=github&utm_campaign=oss_sponsorship" target="_blank">Try the iOS Chat tutorial</a> 💬
</p>

## 💬 Communication
* If you need help with making LiveStreaming requests using HaishinKit, use a [GitHub Discussions](https://github.com/shogo4405/HaishinKit.swift/discussions) with **Q&A**.
* If you'd like to discuss a feature request, use a [GitHub Discussions](https://github.com/shogo4405/HaishinKit.swift/discussions) with **Idea**
* If you met a HaishinKit's bug🐛, use a [GitHub Issue](https://github.com/shogo4405/HaishinKit.swift/issues) with **Bug report template**
  - The trace level log is very useful. Please set `LBLogger.with(HaishinKitIdentifier).level = .trace`. 
  - If you don't use an issue template. I will immediately close the your issue without a comment.
* If you **want to contribute**, submit a pull request!
* If you want to support e-mail based communication without GitHub.
  - Consulting fee is [$50](https://www.paypal.me/shogo4405/50USD)/1 incident. I'm able to response a few days.
* [Discord chatroom](https://discord.com/invite/8nkshPnanr).
* 日本語が分かる方は、日本語でのコミニケーションをお願いします！

## 💖 Sponsors
<p align="center">
<a href="https://streamlabs.com/" target="_blank"><img src="https://user-images.githubusercontent.com/810189/206836172-9c360977-ab6b-4eff-860b-82d0e7b06318.png" width="350px" alt="Streamlabs" /></a>
</p>

## 🌏 Related projects
Project name    |Notes       |License
----------------|------------|--------------
[SRTHaishinKit for iOS.](https://github.com/shogo4405/SRTHaishinKit.swift)|Camera and Microphone streaming library via SRT.|[BSD 3-Clause "New" or "Revised" License](https://github.com/shogo4405/SRTHaishinKit.swift/blob/master/LICENSE.md)
[HaishinKit for Android.](https://github.com/shogo4405/HaishinKit.kt)|Camera and Microphone streaming library via RTMP for Android.|[BSD 3-Clause "New" or "Revised" License](https://github.com/shogo4405/HaishinKit.kt/blob/master/LICENSE.md)
[HaishinKit for Flutter.](https://github.com/shogo4405/HaishinKit.dart)|Camera and Microphone streaming library via RTMP for Flutter.|[BSD 3-Clause "New" or "Revised" License](https://github.com/shogo4405/HaishinKit.dart/blob/master/LICENSE.md)

## 🎨 Features
### RTMP
- [x] Authentication
- [x] Publish and Recording
- [x] _Playback (Beta)_
- [x] Adaptive bitrate streaming
  - [x] Handling (see also [#1153](/../../issues/1153))
- [ ] Action Message Format
  - [x] AMF0
  - [ ] AMF3
- [x] SharedObject
- [x] RTMPS
  - [x] Native (RTMP over SSL/TLS)
  - [x] _Tunneled (RTMPT over SSL/TLS) (Technical Preview)_
- [x] _RTMPT (Technical Preview)_
- [x] ReplayKit Live as a Broadcast Upload Extension
- [x] Supported codec
  - Audio
    - [x] AAC
  - Video
    - [x] H264/AVC
      - ex: `stream.videoSettings.profileLevel = kVTProfileLevel_H264_Baseline_3_1 as String`
    - [x] H265/HEVC ([Server-side support is required.](https://github.com/veovera/enhanced-rtmp/blob/main/enhanced-rtmp-v1.pdf))
      - ex: `stream.videoSettings.profileLevel = kVTProfileLevel_HEVC_Main_AutoLevel as String`

### HLS
- [x] HTTPService
- [x] HLS Publish

### Multi Camera
Supports two camera video sources. A picture-in-picture display that shows the image of the secondary camera of the primary camera. Supports camera split display that displays horizontally and vertically.

|Picture-In-Picture|Split|
|:-:|:-:|
|<img width="1382" alt="" src="https://user-images.githubusercontent.com/810189/210043421-ceb18cb7-9b50-43fa-a0a2-8b92b78d9df1.png">|<img width="1382" alt="" src="https://user-images.githubusercontent.com/810189/210043687-a99f21b6-28b2-4170-96de-6c814debd84d.png">|

```swift
// If you're using multi-camera functionality, please make sure to call the attachMultiCamera method first. This is required for iOS 14 and 15, among others.
if #available(iOS 13.0, *) {
  let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
  stream.attachMultiCamera(front)
}
let back = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
stream.attachCamera(back)
rtmpStream.attachAudio(AVCaptureDevice.default(for: .audio))
```

### Rendering
|Features|[HKView](https://shogo4405.github.io/HaishinKit.swift/Classes/HKView.html)|[PiPHKView](https://shogo4405.github.io/HaishinKit.swift/Classes/PiPHKView.html)|[MTHKView](https://shogo4405.github.io/HaishinKit.swift/Classes/MTHKView.html)|
|-|:---:|:---:|:---:|
|Engine|AVCaptureVideoPreviewLayer|AVSampleBufferDisplayLayer|Metal|
|Publish|✔|✔|✔|
|Playback|<br />|✔|✔|
|VisualEffect|<br />|✔|✔|
|PictureInPicture|<br />|✔|<br />|
|MultiCamera|<br />|✔|✔|

### Others
- [x] [Support multitasking camera access.](https://developer.apple.com/documentation/avfoundation/capture_setup/accessing_the_camera_while_multitasking)
- [x] _Support tvOS 11.0+  (Technical Preview)_
  - tvOS can't use camera and microphone devices.
- [x] Hardware acceleration for H264 video encoding, AAC audio encoding
- [x] Support "Allow app extension API only" option
- [ ] ~~Support GPUImage framework (~> 0.5.12)~~
  - ~~https://github.com/shogo4405/GPUHaishinKit.swift/blob/master/README.md~~
- [ ] ~~Objective-C Bridging~~

## 🌏 Requirements
|-|iOS|OSX|tvOS|Xcode|Swift|
|:----:|:----:|:----:|:----:|:----:|:----:|
|1.5.0+|11.0+|10.13+|10.2+|14.3+|5.7+|
|1.4.0+|11.0+|10.13+|10.2+|14.0+|5.7+|

## 🐾 Examples
Examples project are available for iOS with UIKit, iOS with SwiftUI, macOS and tvOS.
- [x] Camera and microphone publish.
- [x] RTMP Playback  
```sh
git clone https://github.com/shogo4405/HaishinKit.swift.git
cd HaishinKit.swift
carthage bootstrap --use-xcframeworks
open HaishinKit.xcodeproj
```

## ☕ Cocoa Keys
Please contains Info.plist.

iOS 10.0+
* NSMicrophoneUsageDescription
* NSCameraUsageDescription

macOS 10.14+
* NSMicrophoneUsageDescription
* NSCameraUsageDescription

## 🔧 Installation
### CocoaPods
```rb
source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

def import_pods
    pod 'HaishinKit', '~> 1.5.6
end

target 'Your Target'  do
    platform :ios, '11.0'
    import_pods
end
```
### Carthage
```
github "shogo4405/HaishinKit.swift" ~> 1.5.7
```
### Swift Package Manager
```
https://github.com/shogo4405/HaishinKit.swift
```

## 🔧 Prerequisites
Make sure you setup and activate your AVAudioSession iOS.
```swift
import AVFoundation
let session = AVAudioSession.sharedInstance()
do {
    try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
    try session.setActive(true)
} catch {
    print(error)
}
```

## 📓 RTMP Usage
Real Time Messaging Protocol (RTMP).
```swift
let connection = RTMPConnection()
let stream = RTMPStream(connection: rtmpConnection)
stream.attachAudio(AVCaptureDevice.default(for: .audio)) { error in
    // print(error)
}
stream.attachCamera(AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)) { error in
    // print(error)
}

let hkView = MTHKView(frame: view.bounds)
hkView.videoGravity = AVLayerVideoGravity.resizeAspectFill
hkView.attachStream(stream)

// add ViewController#view
view.addSubview(hkView)

connection.connect("rtmp://localhost/appName/instanceName")
stream.publish("streamName")
```

### RTMP URL Format
* rtmp://server-ip-address[:port]/application/[appInstance]/[prefix:[path1[/path2/]]]streamName
  - [] mark is an Optional.
  ```
  rtmpConneciton.connect("rtmp://server-ip-address[:port]/application/[appInstance]")
  rtmpStream.publish("[prefix:[path1[/path2/]]]streamName")
  ```
* rtmp://localhost/live/streamName
  ```
  rtmpConneciton.connect("rtmp://localhost/live")
  rtmpStream.publish("streamName")
  ```

### Settings
```swift
var stream = RTMPStream(connection: rtmpConnection)

stream.frameRate = 30
stream.sessionPreset = AVCaptureSession.Preset.medium

/// Specifies the video capture settings.
stream.videoCapture(for: 0).isVideoMirrored = false
stream.videoCapture(for: 0).preferredVideoStabilizationMode = .auto
// rtmpStream.videoCapture(for: 1).isVideoMirrored = false

// Specifies the audio codec settings.
stream.audioSettings = AudioCodecSettings(
  bitRate: 64 * 1000
)

// Specifies the video codec settings.
stream.videoSettings = VideoCodecSettings(
  videoSize: .init(width: 854, height: 480),
  profileLevel: kVTProfileLevel_H264_Baseline_3_1 as String,
  bitRate: 640 * 1000,
  maxKeyFrameIntervalDuration: 2,
  scalingMode: .trim,
  bitRateMode: .average,
  allowFrameReordering: nil,
  isHardwareEncoderEnabled: true
)

// Specifies the recording settings. 0" means the same of input.
stream.startRecording([
  AVMediaType.audio: [
    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
    AVSampleRateKey: 0,
    AVNumberOfChannelsKey: 0,
    // AVEncoderBitRateKey: 128000,
  ],
  AVMediaType.video: [
    AVVideoCodecKey: AVVideoCodecH264,
    AVVideoHeightKey: 0,
    AVVideoWidthKey: 0,
    /*
    AVVideoCompressionPropertiesKey: [
      AVVideoMaxKeyFrameIntervalDurationKey: 2,
      AVVideoProfileLevelKey: AVVideoProfileLevelH264Baseline30,
      AVVideoAverageBitRateKey: 512000
    ]
    */
  ]
])

// 2nd arguemnt set false
stream.attachAudio(AVCaptureDevice.default(for: .audio), automaticallyConfiguresApplicationAudioSession: false)
```

```swift
// picrure in picrure settings.
stream.multiCamCaptureSettings = MultiCamCaptureSetting(
  mode: .pip,
  cornerRadius: 16.0,
  regionOfInterest: .init(
    origin: CGPoint(x: 16, y: 16),
    size: .init(width: 160, height: 160)
  )
)
```

```swift
// split settings.
stream.multiCamCaptureSettings = MultiCamCaptureSetting(
  mode: .split(direction: .east),
  cornerRadius: 0.0,
  regionOfInterest: .init(
    origin: .zero,
    size: .zero
  )
)
```
### Authentication
```swift
var connection = RTMPConnection()
connection.connect("rtmp://username:password@localhost/appName/instanceName")
```

### Screen Capture
```swift
// iOS
let screen = IOUIScreenCaptureUnit(shared: UIApplication.shared)
screen.delegate = stream
screen.startRunning()

// macOS
stream.attachScreen(AVCaptureScreenInput(displayID: CGMainDisplayID()))
```

## 📓 HTTP Usage
HTTP Live Streaming (HLS). Your iPhone/Mac become a IP Camera. Basic snipet. You can see http://ip.address:8080/hello/playlist.m3u8 
```swift
var stream = HTTPStream()
stream.attachCamera(AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back))
stream.attachAudio(AVCaptureDevice.default(for: .audio))
stream.publish("hello")

var hkView = MTHKView(frame: view.bounds)
hkView.attachStream(httpStream)

var httpService = HLSService(domain: "", type: "_http._tcp", name: "HaishinKit", port: 8080)
httpService.addHTTPStream(stream)
httpService.startRunning()

// add ViewController#view
view.addSubview(hkView)
```

## 💠 Sponsorship
Looking for sponsors. Sponsoring I will enable us to:
- Purchase smartphones or peripheral devices for testing purposes.
- Pay for testing on a specific streaming service or for testing on mobile lines.
- Potentially private use to continue the OSS development

 If you use any of our libraries for work, see if your employers would be interested in sponsorship. I have some special offers.　I would greatly appreciate. Thank you.
 - If you request I will note your name product our README.
 - If you mention on a discussion, an issue or pull request that you are sponsoring us I will prioritise helping you even higher.

スポンサーを募集しています。利用用途としては、
- テスト目的で、スマートフォンの購入や周辺機器の購入を行います。
- 特定のストリーミングサービスへのテストの支払いや、モバイル回線でのテストの支払いに利用します。
- 著書のOSS開発を継続的に行う為に私的に利用する可能性もあります。

このライブラリーを仕事で継続的に利用している場合は、ぜひ。雇用主に、スポンサーに興味がないか確認いただけると幸いです。いくつか特典を用意しています。
- README.mdへの企業ロゴの掲載
- IssueやPull Requestの優先的な対応

[Sponsorship](https://github.com/sponsors/shogo4405)

## 📖 Reference
* Adobe’s Real Time Messaging Protocol
  * http://www.adobe.com/content/dam/Adobe/en/devnet/rtmp/pdf/rtmp_specification_1.0.pdf
* Action Message Format -- AMF 0
  * https://www.adobe.com/content/dam/acom/en/devnet/pdf/amf0-file-format-specification.pdf
* Action Message Format -- AMF 3 
  * https://www.adobe.com/content/dam/acom/en/devnet/pdf/amf-file-format-spec.pdf
* Video File Format Specification Version 10
  * https://www.adobe.com/content/dam/acom/en/devnet/flv/video_file_format_spec_v10.pdf
* Adobe Flash Video File Format Specification Version 10.1
  * http://download.macromedia.com/f4v/video_file_format_spec_v10_1.pdf

## 📜 License
BSD-3-Clause
