# HaishinKit for iOS, macOS, tvOS, visionOS and [Android](https://github.com/shogo4405/HaishinKit.kt).
[![GitHub Stars](https://img.shields.io/github/stars/shogo4405/HaishinKit.swift?style=social)](https://github.com/shogo4405/HaishinKit.swift/stargazers)
[![Release](https://img.shields.io/github/v/release/shogo4405/HaishinKit.swift)](https://github.com/shogo4405/HaishinKit.swift/releases/latest)
[![Platform Compatibility](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fshogo4405%2FHaishinKit.swift%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/shogo4405/HaishinKit.swift)
[![Swift Compatibility](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fshogo4405%2FHaishinKit.swift%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/shogo4405/HaishinKit.swift)
[![GitHub license](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](https://raw.githubusercontent.com/shogo4405/HaishinKit.swift/master/LICENSE.md)
[![GitHub Sponsor](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=ff69b4)](https://github.com/sponsors/shogo4405)

* Camera and Microphone streaming library via RTMP and SRT for iOS, macOS, tvOS and visionOS.
* README.md contains unreleased content, which can be tested on the main branch.
* [API Documentation](https://shogo4405.github.io/HaishinKit.swift/)

## 💖 Sponsors
<p align="center">
  <br />
  <br />
  <a href="https://github.com/sponsors/shogo4405">Sponsorship</a>
  <br />
  <br />
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
- [x] Publish and Recording (H264/HEVC/AAC)
- [x] Playback(beta)
- [ ] mode
  - [x] caller
  - [ ] listener
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
stream.attachCamera(back, track: 0) { _, error in
  if let error {
    logger.warn(error)
  }
}

let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
stream.attachCamera(front, track: 1) { videoUnit, error in
  videoUnit?.isVideoMirrored = true
  if let error {
    logger.error(error)
  }
}
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
|1.8.0+|15.3+|5.9+|
|1.7.0+|15.0+|5.9+|
|1.6.0+|15.0+|5.8+|

### OS
|-|iOS|tvOS|macOS|visionOS|watchOS|
|:----|:----:|:----:|:----:|:----:|:----:|
|HaishinKit|13.0+|13.0+|10.15+|1.0+|-|
|SRTHaishinKit|13.0+|-|13.0+|-|-|

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
let stream = RTMPStream(connection: connection)

stream.attachAudio(AVCaptureDevice.default(for: .audio)) { _, error in
  if let error {
    logger.warn(error)
  }
}

stream.attachCamera(AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back), track: 0) { _, error in
  if let error {
    logger.warn(error)
  }
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
let stream = RTMPStream(connection: connection)

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
stream.attachCamera(AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back), track: 0) { _, error in
  if let error {
    logger.warn(error)
  }
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
### 📹 AVCaptureSession
```swift
stream.frameRate = 30
stream.sessionPreset = AVCaptureSession.Preset.medium

// Do not call beginConfiguration() and commitConfiguration() internally within the scope of the method, as they are called internally.
stream.configuration { session in
  session.automaticallyConfiguresApplicationAudioSession = true
}
```

### 🔊 Audio
#### [Capture](https://shogo4405.github.io/HaishinKit.swift/Classes/IOAudioCaptureUnit.html)
Specifies the capture capture settings.
```swift
let front = AVCaptureDevice.default(for: .audio)
stream.attachAudio(front, track: 0) { audioUnit, error in
}
```

#### [AudioMixerSettings](https://shogo4405.github.io/HaishinKit.swift/Structs/IOAudioMixerSettings.html)
If you want to mix multiple audio tracks, please enable the Feature flag.
```swift
FeatureUtil.setEnabled(for: .multiTrackAudioMixing, isEnabled: true)
```

When you specify the sampling rate, it will perform resampling. Additionally, in the case of multiple channels, downsampling can be applied.
```swift
// Setting the value to 0 will be the same as the value specified in mainTrack.
stream.audioMixerSettings = IOAudioMixerSettings(
  sampleRate: Float64 = 44100,
  channels: UInt32 = 0,
)

stream.audioMixerSettings.isMuted = false
stream.audioMixerSettings.mainTrack = 0
stream.audioMixerSettings.tracks = [
  0: .init(
    isMuted: Bool = false,
    downmix: Bool = true,
    channelMap: [Int]? = nil
  )
]
```

#### [AudioCodecSettings](https://shogo4405.github.io/HaishinKit.swift/Structs/AudioCodecSettings.html)
```swift
/// Specifies the bitRate of audio output.
stream.audioSettings.bitrate = 64 * 1000
/// Specifies the mixes the channels or not. Currently, it supports input sources with 4, 5, 6, and 8 channels.
stream.audioSettings.downmix = true
/// Specifies the map of the output to input channels.
 stream.audioSettings.channelMap: [Int]? = nil
```

### 🎥 Video
#### [Capture](https://shogo4405.github.io/HaishinKit.swift/Classes/IOVideoCaptureUnit.html)
Specifies the video capture settings.
```swift
let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
stream.attachCamera(front, track: 0) { videoUnit, error in
  videoUnit?.isVideoMirrored = true
  videoUnit?.preferredVideoStabilizationMode = .standard
  videoUnit?.colorFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
}
```

#### [VideoMixerSettings](https://shogo4405.github.io/HaishinKit.swift/Structs/IOVideoMixerSettings.html)
```swift
stream.videoMixerSettings = IOVideoMixerSettings(
  mode: .pip,
  cornerRadius: 16.0,
  regionOfInterest: .init(
    origin: CGPoint(x: 16, y: 16),
    size: .init(width: 160, height: 160)
  ),
  direction: .east
)
```

#### [VideoCodecSettings](https://shogo4405.github.io/HaishinKit.swift/Structs/VideoCodecSettings.html)
```swift
stream.videoSettings = .init(
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
Internally, I am now handling data with more than 3 channels. If you encounter audio issues with IOStreamRecorder, it is recommended to set it back to a maximum of 2 channels when saving locally.
```swift
let channels = max(stream.audioInputFormats[0].channels ?? 1, 2)
stream.audioMixerSettings = .init(sampleRate: 0, channels: channels)
```

```swift
// Specifies the recording settings. 0" means the same of input.
var recorder = IOStreamRecorder()
stream.addObserver(recorder)

recorder.settings = [
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
]

recorder.startRunning()
// recorder.stopRunning()
```

## 📜 License
BSD-3-Clause
