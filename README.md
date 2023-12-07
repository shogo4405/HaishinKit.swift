# HaishinKit for iOS, macOS, tvOS, visionOS and [Android](https://github.com/shogo4405/HaishinKit.kt).
[![GitHub Stars](https://img.shields.io/github/stars/shogo4405/HaishinKit.swift?style=social)](https://github.com/shogo4405/HaishinKit.swift/stargazers)
[![Release](https://img.shields.io/github/v/release/shogo4405/HaishinKit.swift)](https://github.com/shogo4405/HaishinKit.swift/releases/latest)
[![Platform Compatibility](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fshogo4405%2FHaishinKit.swift%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/shogo4405/HaishinKit.swift)
[![Swift Compatibility](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fshogo4405%2FHaishinKit.swift%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/shogo4405/HaishinKit.swift)
[![GitHub license](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](https://raw.githubusercontent.com/shogo4405/HaishinKit.swift/master/LICENSE.md)

* Camera and Microphone streaming library via RTMP and SRT for iOS, macOS, tvOS and visionOS.
* README.md contains unreleased content, which can be tested on the main branch.
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
* If you **want to contribute**, submit a pull request with a pr template.
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
[HaishinKit for Android.](https://github.com/shogo4405/HaishinKit.kt)|Camera and Microphone streaming library via RTMP for Android.|[BSD 3-Clause "New" or "Revised" License](https://github.com/shogo4405/HaishinKit.kt/blob/master/LICENSE.md)
[HaishinKit for Flutter.](https://github.com/shogo4405/HaishinKit.dart)|Camera and Microphone streaming library via RTMP for Flutter.|[BSD 3-Clause "New" or "Revised" License](https://github.com/shogo4405/HaishinKit.dart/blob/master/LICENSE.md)

## 🎨 Features
### RTMP
- [x] Authentication
- [x] Publish and Recording
- [x] _Playback (Beta)_
- [x] [Adaptive bitrate streaming](../../issues/1308)
- [ ] Action Message Format
  - [x] AMF0
  - [ ] AMF3
- [x] SharedObject
- [x] RTMPS
  - [x] Native (RTMP over SSL/TLS)
  - [x] _Tunneled (RTMPT over SSL/TLS) (Technical Preview)_
- [x] _RTMPT (Technical Preview)_
- [x] ReplayKit Live as a Broadcast Upload Extension
- [x] [Enhanced RTMP](https://github.com/veovera/enhanced-rtmp)

### SRT(beta)
- [x] Publish and Recording (H264/AAC)
- [x] Playback(beta)
- [ ] mode
  - [x] caller
  - [x] listener
  - [ ] rendezvous

### Multi Camera
Supports two camera video sources. A picture-in-picture display that shows the image of the secondary camera of the primary camera. Supports camera split display that displays horizontally and vertically.

|Picture-In-Picture|Split|
|:-:|:-:|
|<img width="1382" alt="" src="https://user-images.githubusercontent.com/810189/210043421-ceb18cb7-9b50-43fa-a0a2-8b92b78d9df1.png">|<img width="1382" alt="" src="https://user-images.githubusercontent.com/810189/210043687-a99f21b6-28b2-4170-96de-6c814debd84d.png">|

```swift
// If you want to use the multi-camera feature, please make sure stream.isMultiCamSessionEnabled = true. Before attachCamera or attachAudio.
stream.isMultiCamSessionEnabled = true

let back = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
stream.attachCamera(back)
if #available(iOS 13.0, *) {
  let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
  stream.attachMultiCamera(front)
}
rtmpStream.attachAudio(AVCaptureDevice.default(for: .audio))
```

### Rendering
|Features|[PiPHKView](https://shogo4405.github.io/HaishinKit.swift/Classes/PiPHKView.html)|[MTHKView](https://shogo4405.github.io/HaishinKit.swift/Classes/MTHKView.html)|
|-|:---:|:---:|
|Engine|AVSampleBufferDisplayLayer|Metal|
|Publish|✔|✔|
|Playback|✔|✔|
|VisualEffect|✔|✔|
|MultiCamera|✔|✔|
|PictureInPicture|✔|<br />|

### Others
- [x] tvOS 17.0 for AVCaptureSession.
- [x] [Support multitasking camera access.](https://developer.apple.com/documentation/avfoundation/capture_setup/accessing_the_camera_while_multitasking)
- [x] Support "Allow app extension API only" option

## 🐾 Examples
Examples project are available for iOS with UIKit, iOS with SwiftUI, macOS and tvOS. Example macOS requires Apple Silicon mac.
- [x] Camera and microphone publish.
- [x] Playback
```sh
git clone https://github.com/shogo4405/HaishinKit.swift.git
cd HaishinKit.swift
carthage bootstrap --platform iOS,macOS,tvOS --use-xcframeworks
open HaishinKit.xcodeproj
```

## 🌏 Requirements

### Development
|Version|Xcode|Swift|
|:----:|:----:|:----:|
|1.7.0+|15.0+|5.9+|
|1.6.0+|15.0+|5.8+|
|1.5.0+|14.0+|5.7+|

### OS
|-|iOS|tvOS|macOS|visionOS|watchOS|
|:----|:----:|:----:|:----:|:----:|:----:|
|HaishinKit|12.0+|12.0+|10.13+|1.0+|-|
|SRTHaishinKit|12.0+|-|13.0+|-|-|

### Cocoa Keys
Please contains Info.plist.

**iOS 10.0+**
* NSMicrophoneUsageDescription
* NSCameraUsageDescription

**macOS 10.14+**
* NSMicrophoneUsageDescription
* NSCameraUsageDescription

**tvOS 17.0+**
* NSMicrophoneUsageDescription
* NSCameraUsageDescription

## 🔧 Installation
HaishinKit has a multi-module configuration. If you want to use the SRT protocol, please use SRTHaishinKit. SRTHaishinKit supports SPM only.
|  | HaishinKit | SRTHaishinKit |
| - | :- | :- |
| SPM | https://github.com/shogo4405/HaishinKit.swift | https://github.com/shogo4405/HaishinKit.swift |
| CocoaPods | source 'https://github.com/CocoaPods/Specs.git'<br>use_frameworks!<br><br>def import_pods<br>    pod 'HaishinKit', '~> 1.6.0<br>end<br><br>target 'Your Target'  do<br>    platform :ios, '12.0'<br>    import_pods<br>end<br> | Not supported. |
| Carthage | github "shogo4405/HaishinKit.swift" ~> 1.6.0 | Not supported. |

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
### Ingest
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

### Playback
```swift
let connection = RTMPConnection()
let stream = RTMPStream(connection: rtmpConnection)

let hkView = MTHKView(frame: view.bounds)
hkView.videoGravity = AVLayerVideoGravity.resizeAspectFill
hkView.attachStream(stream)

// add ViewController#view
view.addSubview(hkView)

connection.connect("rtmp://localhost/appName/instanceName")
stream.play("streamName")
```

### Authentication
```swift
var connection = RTMPConnection()
connection.connect("rtmp://username:password@localhost/appName/instanceName")
```

## 📓 SRT Usage
### Ingest
```swift
let connection = SRTConnection()
let stream = SRTStream(connection: connection)
stream.attachAudio(AVCaptureDevice.default(for: .audio)) { error in
    // print(error)
}
stream.attachCamera(AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)) { error in
    // print(error)
}

let hkView = HKView(frame: view.bounds)
hkView.videoGravity = AVLayerVideoGravity.resizeAspectFill
hkView.attachStream(rtmpStream)

// add ViewController#view
view.addSubview(hkView)

connection.connect("srt://host:port?option=foo")
stream.publish()
```

### Playback
```swift
let connection = SRTConnection()
let stream = SRTStream(connection: connection)

let hkView = MTHKView(frame: view.bounds)
hkView.videoGravity = AVLayerVideoGravity.resizeAspectFill
hkView.attachStream(rtmpStream)

// add ViewController#view
view.addSubview(hkView)

connection.connect("srt://host:port?option=foo")
stream.play()
```

## 📓 Settings
### 📹 Capture
```swift
stream.frameRate = 30
stream.sessionPreset = AVCaptureSession.Preset.medium

/// Specifies the video capture settings.
stream.videoCapture(for: 0).map {
    // $0.isVideoMirrored = true
    $0.preferredVideoStabilizationMode = .standard
    // $0.colorFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
}
```

### 🔊 [AudioCodecSettings](https://shogo4405.github.io/HaishinKit.swift/Structs/AudioCodecSettings.html)
When you specify the sampling rate, it will perform resampling. Additionally, in the case of multiple channels, downsampling can be applied.
```
stream.audioSettings = AudioCodecSettings(
  bitRate: Int = 64 * 1000,
  sampleRate: Float64 = 0,
  channels: UInt32 = 0,
  downmix: Bool = false,
  channelMap: [Int]? = nil
)
```

### 🎥 [VideoCodecSettings](https://shogo4405.github.io/HaishinKit.swift/Structs/VideoCodecSettings.html)
```
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
```

### ⏺️ Recording
```
// Specifies the recording settings. 0" means the same of input.
stream.startRecording(self, settings: [
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
