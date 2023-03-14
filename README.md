# HaishinKit for iOS, macOS, tvOS, and [Android](https://github.com/shogo4405/HaishinKit.kt).
[![Platform](https://img.shields.io/cocoapods/p/HaishinKit.svg?style=flat)](http://cocoapods.org/pods/HaishinKit)
![Language](https://img.shields.io/badge/language-Swift%205.3-orange.svg)
[![CocoaPods](https://img.shields.io/cocoapods/v/HaishinKit.svg?style=flat)](http://cocoapods.org/pods/HaishinKit)
[![GitHub license](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](https://raw.githubusercontent.com/shogo4405/HaishinKit.swift/master/LICENSE.md)

* Camera and Microphone streaming library via RTMP, HLS for iOS, macOS, tvOS.
* [API Documentation](https://shogo4405.github.io/HaishinKit.swift/)

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

## 🎨 Features
### RTMP
- [x] Authentication
- [x] Publish and Recording (H264/AAC)
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

### HLS
- [x] HTTPService
- [x] HLS Publish

### Multi Camera
Supports two camera video sources. A picture-in-picture display that shows the image of the secondary camera of the primary camera. Supports camera split display that displays horizontally and vertically.

|Picture-In-Picture|Split|
|:-:|:-:|
|<img width="1382" alt="スクリーンショット 2022-12-30 15 57 38" src="https://user-images.githubusercontent.com/810189/210043421-ceb18cb7-9b50-43fa-a0a2-8b92b78d9df1.png">|<img width="1382" alt="スクリーンショット 2022-12-30 15 55 13" src="https://user-images.githubusercontent.com/810189/210043687-a99f21b6-28b2-4170-96de-6c814debd84d.png">|

```swift
let back = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
stream.attachCamera(back)

if #available(iOS 13.0, *) {
  let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
  stream.attachMultiCamera(front)
}
```

### Rendering
|-|[HKView](https://shogo4405.github.io/HaishinKit.swift/Classes/HKView.html)|[PiPHKView](https://shogo4405.github.io/HaishinKit.swift/Classes/PiPHKView.html)|[MTHKView](https://shogo4405.github.io/HaishinKit.swift/Classes/MTHKView.html)|
|-|:---:|:---:|:---:|
|Engine|AVCaptureVideoPreviewLayer|AVSampleBufferDisplayLayer|Metal|
|Publish|○|◯|○|
|Playback|×|◯|○|
|VisualEffect|×|◯|○|

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
|1.4.0+|11.0+|10.13+|10.2+|14.0+|5.7+|
|1.3.0+|11.0+|10.13+|10.2+|14.0+|5.7+|
|1.2.0+|9.0+|10.11+|10.2+|13.0+|5.5+|

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
    pod 'HaishinKit', '~> 1.4.4
end

target 'Your Target'  do
    platform :ios, '11.0'
    import_pods
end
```
### Carthage
```
github "shogo4405/HaishinKit.swift" ~> 1.4.4
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
let rtmpConnection = RTMPConnection()
let rtmpStream = RTMPStream(connection: rtmpConnection)
rtmpStream.attachAudio(AVCaptureDevice.default(for: .audio)) { error in
    // print(error)
}
rtmpStream.attachCamera(AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)) { error in
    // print(error)
}

let hkView = HKView(frame: view.bounds)
hkView.videoGravity = AVLayerVideoGravity.resizeAspectFill
hkView.attachStream(rtmpStream)

// add ViewController#view
view.addSubview(hkView)

rtmpConnection.connect("rtmp://localhost/appName/instanceName")
rtmpStream.publish("streamName")
// if you want to record a stream.
// rtmpStream.publish("streamName", type: .localRecord)
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
stream.audioSettings = [
  .bitrate: 32 * 1000,
]

// Specifies the video codec settings.
stream.videoSettings = [
  .width: 640, // video output width
  .height: 360, // video output height
  .bitrate: 160 * 1000, // video output bitrate
  .profileLevel: kVTProfileLevel_H264_Baseline_3_1, // H264 Profile require "import VideoToolbox"
  .maxKeyFrameIntervalDuration: 2, // key frame / sec
]

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
var rtmpConnection = RTMPConnection()
rtmpConnection.connect("rtmp://username:password@localhost/appName/instanceName")
```

### Screen Capture
```swift
// iOS
let screen = IOUIScreenCaptureUnit(shared: UIApplication.shared)
screen.delegate = rtmpStream
screen.startRunning()

// macOS
rtmpStream.attachScreen(AVCaptureScreenInput(displayID: CGMainDisplayID()))
```

## 📓 HTTP Usage
HTTP Live Streaming (HLS). Your iPhone/Mac become a IP Camera. Basic snipet. You can see http://ip.address:8080/hello/playlist.m3u8 
```swift
var httpStream = HTTPStream()
httpStream.attachCamera(AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back))
httpStream.attachAudio(AVCaptureDevice.default(for: .audio))
httpStream.publish("hello")

var hkView = HKView(frame: view.bounds)
hkView.attachStream(httpStream)

var httpService = HLSService(domain: "", type: "_http._tcp", name: "HaishinKit", port: 8080)
httpService.addHTTPStream(httpStream)
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
