# HaishinKit for iOS, macOS, tvOS, visionOS and [Android](https://github.com/shogo4405/HaishinKit.kt).
[![GitHub Stars](https://img.shields.io/github/stars/shogo4405/HaishinKit.swift?style=social)](https://github.com/shogo4405/HaishinKit.swift/stargazers)
[![Release](https://img.shields.io/github/v/release/shogo4405/HaishinKit.swift)](https://github.com/shogo4405/HaishinKit.swift/releases/latest)
[![Platform Compatibility](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fshogo4405%2FHaishinKit.swift%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/shogo4405/HaishinKit.swift)
[![Swift Compatibility](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fshogo4405%2FHaishinKit.swift%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/shogo4405/HaishinKit.swift)
[![GitHub license](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](https://raw.githubusercontent.com/shogo4405/HaishinKit.swift/master/LICENSE.md)
[![GitHub Sponsor](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=ff69b4)](https://github.com/sponsors/shogo4405)

* Camera and Microphone streaming library via RTMP and SRT for iOS, macOS, tvOS and visionOS.
* README.md contains unreleased content, which can be tested on the main branch.
* [API Documentation](https://docs.haishinkit.com/swift/latest/)

## 💖 Sponsors
Do you need additional support? Technical support on Issues and Discussions is provided only to contributors and academic researchers of HaishinKit. By becoming a sponsor, we can provide the support you need.

Sponsor: [$50 per month](https://github.com/sponsors/shogo4405): Technical support via GitHub Issues/Discussions with priority response.

## 💬 Communication
* GitHub Issues and Discussions are open spaces for communication among users and are available to everyone as long as [the code of conduct](https://github.com/shogo4405/HaishinKit.swift?tab=coc-ov-file) is followed.
* Whether someone is a contributor to HaishinKit is mainly determined by their GitHub profile icon. If you are using the default icon, there is a chance your input might be overlooked, so please consider setting a custom one. It could be a picture of your pet, for example. Personally, I like cats.
* If you want to support e-mail based communication without GitHub.
  * Consulting fee is [$50](https://www.paypal.me/shogo4405/50USD)/1 incident. I'm able to response a few days.

## 🌏 Related projects
Project name    |Notes       |License
----------------|------------|--------------
[HaishinKit for Android.](https://github.com/shogo4405/HaishinKit.kt)|Camera and Microphone streaming library via RTMP for Android.|[BSD 3-Clause "New" or "Revised" License](https://github.com/shogo4405/HaishinKit.kt/blob/master/LICENSE.md)
[HaishinKit for Flutter.](https://github.com/shogo4405/HaishinKit.dart)|Camera and Microphone streaming library via RTMP for Flutter.|[BSD 3-Clause "New" or "Revised" License](https://github.com/shogo4405/HaishinKit.dart/blob/master/LICENSE.md)

## 🎨 Features
### ✏️ [RTMP](https://github.com/shogo4405/HaishinKit.swift/tree/main/HaishinKit)
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
- [x] ReplayKit Live as a Broadcast Upload Extension
- [x] [Enhanced RTMP](https://github.com/veovera/enhanced-rtmp)

### ✏️ [SRT(beta)](https://github.com/shogo4405/HaishinKit.swift/tree/main/SRTHaishinKit)
- [x] Publish and Recording (H264/HEVC/AAC)
- [x] Playback(beta)
- [ ] mode
  - [x] caller
  - [x] listener
  - [ ] rendezvous

### ✏️ [MOQT(alpha)](https://github.com/shogo4405/HaishinKit.swift/tree/main/MoQTHaishinKit)
> [!NOTE]
> I am working on a preliminary implementation of MOQT for research purposes. If you're interested, please check out the repository.

### 📹 Multi Streaming.
Starting from version 2.0.0, multiple streams are supported, allowing live streaming to separate services. Views also support this, enabling the verification of raw video data
```swift
let mixer = MediaMixer()
let stream0 = RTMPStream() // for Y Service.
let stream1 = RTMPStream() // for F Service.

let view = MTHKView()
view.track = 0 // Video Track Number 0 or 1, UInt8.max.

mixer.addOutput(stream0)
mixer.addOutput(stream1)
mixer.addOutput(view)

let view2 = MTHKView()
stream0.addOutput(view2)
```

### Offscreen Rendering.
Through off-screen rendering capabilities, it is possible to display any text or bitmap on a video during broadcasting or viewing. This allows for various applications such as watermarking and time display.
|Ingest|Playback|
|:---:|:---:|
|<img width="961" alt="" src="https://github.com/user-attachments/assets/aaf6c06f-d2de-43c1-a435-90907f370977">|<img width="849" alt="" src="https://github.com/user-attachments/assets/0a07b418-aa56-41cb-8e6d-e12596b25ae8">|

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
- [x] Strict Concurrency 

## 🐾 Examples
Examples project are available for iOS, macOS(ARM), tvOS and visionOS.
> [!IMPORTANT]
> Please check if the same issue occurs with the latest Examples before posting it on GitHub Issues.

### Usage
You can verify by changing the URL of the following file.
https://github.com/shogo4405/HaishinKit.swift/blob/abf1883d25d0ba29e1d1d67ea9e3a3b5be61a196/Examples/Preference.swift#L1-L7
```sh
git clone https://github.com/shogo4405/HaishinKit.swift.git
cd HaishinKit.swift
open Examples/Examples.xcodeproj
```

## 🌏 Requirements

### Development
|Version|Xcode|Swift|
|:----:|:----:|:----:|
|2.0.0+|16.0+|5.10+|
|1.9.0+|15.4+|5.10+|

### OS
|-|iOS|tvOS|macOS|visionOS|watchOS|
|:----|:----:|:----:|:----:|:----:|:----:|
|HaishinKit|13.0+|13.0+|10.15+|1.0+|-|
|SRTHaishinKit|13.0+|13.0+|10.15+|1.0+|-|

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
* Using Swift Package Manager
  - https://github.com/shogo4405/HaishinKit.swift
* [Discontinued support for CocoaPods.](https://github.com/shogo4405/HaishinKit.swift/discussions/1672)
* [Discontinued support for Carthage.](https://github.com/shogo4405/HaishinKit.swift/pull/1543)

## 📓 Settings
### 🔧 Prerequisites
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

### 📹 AVCaptureSession
```swift
let mixer = MediaMixer()

await mixer.setFrameRate(30)
await mixer.setSessionPreset(AVCaptureSession.Preset.medium)

// Do not call beginConfiguration() and commitConfiguration() internally within the scope of the method, as they are called internally.
await mixer.configuration { session in
  session.automaticallyConfiguresApplicationAudioSession = true
}
```

### 🔊 Audio
#### [Device](https://docs.haishinkit.com/swift/latest/Classes/AudioDeviceUnit.html)
Specifies the audio device settings.
```swift
let front = AVCaptureDevice.default(for: .audio)

try? await mixer.attachAudio(front, track: 0) { audioDeviceUnit in }
```

#### [AudioMixerSettings](https://docs.haishinkit.com/swift/latest/Structs/AudioMixerSettings.html)
If you want to mix multiple audio tracks, please enable the feature flag.
```swift
await mixer.setMultiTrackAudioMixingEnabled(true)
```

When you specify the sampling rate, it will perform resampling. Additionally, in the case of multiple channels, downsampling can be applied.
```swift
// Setting the value to 0 will be the same as the value specified in mainTrack.
var settings = AudioMixerSettings(
  sampleRate: Float64 = 44100,
  channels: UInt32 = 0,
)
settings.tracks = [
  0: .init(
    isMuted: Bool = false,
    downmix: Bool = true,
    channelMap: [Int]? = nil
  )
]

async mixer.setAudioMixerSettings(settings)
```

#### [AudioCodecSettings](https://docs.haishinkit.com/swift/latest/Structs/AudioCodecSettings.html)
```swift
var audioSettings = AudioCodecSettings()
/// Specifies the bitRate of audio output.
audioSettings.bitrate = 64 * 1000
/// Specifies the mixes the channels or not. Currently, it supports input sources with 4, 5, 6, and 8 channels.
audioSettings.downmix = true
/// Specifies the map of the output to input channels.
audioSettings.channelMap: [Int]? = nil

await stream.setAudioSettings(audioSettings)
```

### 🎥 Video
#### [Device](https://docs.haishinkit.com/swift/latest/Classes/VideoDeviceUnit.html)
Specifies the video capture settings.
```swift

let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
do {
  try await mixer.attachCamera(front, track: 0) { videoUnit in
    videoUnit.isVideoMirrored = true
    videoUnit.preferredVideoStabilizationMode = .standard
    videoUnit.colorFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
  }
} catch {
  print(error)
}
```

#### [VideoMixerSettings](https://docs.haishinkit.com/swift/latest/Structs/VideoMixerSettings.html)
```swift
var videoMixerSettings = VideoMixerSettings()
/// Specifies the image rendering mode.
videoMixerSettings.mode = .passthrough or .offscreen
/// Specifies the muted indicies whether freeze video signal or not.
videoMixerSettings.isMuted = false
/// Specifies the main track number.
videoMixerSettings.mainTrack = 0

await mixer.setVideoMixerSettings(videoMixerSettings)
```

#### [VideoCodecSettings](https://docs.haishinkit.com/swift/latest/Structs/VideoCodecSettings.html)
```swift
var videoSettings = VideoCodecSettings(
  videoSize: .init(width: 854, height: 480),
  profileLevel: kVTProfileLevel_H264_Baseline_3_1 as String,
  bitRate: 640 * 1000,
  maxKeyFrameIntervalDuration: 2,
  scalingMode: .trim,
  bitRateMode: .average,
  allowFrameReordering: nil,
  isHardwareEncoderEnabled: true
)

await stream.setVideoSettings(videoSettings)
```

### ⏺️ Recording
```swift
// Specifies the recording settings. 0" means the same of input.
let recorder = HKStreamRecorder()
stream.addOutput(recorder)

try await recorder.startRecording(fileName, settings: [
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

try await recorder.stopRecording()
```

## 📜 License
BSD-3-Clause
