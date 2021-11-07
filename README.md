# HaishinKit
[![Platform](https://img.shields.io/cocoapods/p/HaishinKit.svg?style=flat)](http://cocoapods.org/pods/HaishinKit)
![Language](https://img.shields.io/badge/language-Swift%205.3-orange.svg)
[![CocoaPods](https://img.shields.io/cocoapods/v/HaishinKit.svg?style=flat)](http://cocoapods.org/pods/HaishinKit)
[![GitHub license](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](https://raw.githubusercontent.com/shogo4405/HaishinKit.swift/master/LICENSE.md)

* Camera and Microphone streaming library via RTMP, HLS for iOS, macOS, tvOS.
* Issuesの言語は、日本語が分かる方は日本語でお願いします！

<p align="center">
<strong>Sponsored with 💖 by</strong><br />
<a href="https://getstream.io/chat/sdk/ios/?utm_source=https://github.com/shogo4405/HaishinKit.swift&utm_medium=github&utm_content=developer&utm_term=swift" target="_blank">
<img src="https://stream-blog-v2.imgix.net/blog/wp-content/uploads/f7401112f41742c4e173c30d4f318cb8/stream_logo_white.png?w=350" alt="Stream Chat" style="margin: 8px" />
</a>
<br />
Enterprise Grade APIs for Feeds & Chat. <a href="https://getstream.io/tutorials/ios-chat/?utm_source=github.com/shogo4405/HaishinKit.swift&utm_medium=github&utm_campaign=oss_sponsorship" target="_blank">Try the iOS Chat tutorial</a> 💬
</p>

## Communication
* If you need help with making LiveStreaming requests using HaishinKit, use a GitHub issue with **Bug report template**
  - The trace level log is very useful. Please set `Logboard.with(HaishinKitIdentifier).level = .trace`. 
  - If you don't use an issue template. I will immediately close the your issue without a comment.
* If you'd like to discuss a feature request, use a GitHub issue with **Feature request template**.
* If you want to support e-mail based communication without GitHub issue.
  - Consulting fee is [$50](https://www.paypal.me/shogo4405/50USD)/1 incident. I'm able to response a few days.
* If you **want to contribute**, submit a pull request!

## Features
### RTMP
- [x] Authentication
- [x] Publish and Recording (H264/AAC)
- [x] _Playback (Beta)_
- [x] Adaptive bitrate streaming
  - [x] Handling (see also [#126](/../../issues/126))
  - [x] Automatic drop frames
- [ ] Action Message Format
  - [x] AMF0
  - [ ] AMF3
- [x] SharedObject
- [x] RTMPS
  - [x] Native (RTMP over SSL/TLS)
  - [x] _Tunneled (RTMPT over SSL/TLS) (Technical Preview)_
- [x] _RTMPT (Technical Preview)_
- [x] _ReplayKit Live as a Broadcast Upload Extension (Technical Preview)_

### HLS
- [x] HTTPService
- [x] HLS Publish

### Rendering
|-|HKView|MTHKView|
|-|:---:|:---:|
|Engine|AVCaptureVideoPreviewLayer|Metal|
|Publish|○|◯|
|Playback|×|◯|
|VisualEffect|×|◯|
|Condition|Stable|Stable|

### Others
- [x] _Support tvOS 10.2+  (Technical Preview)_
  - tvOS can't publish Camera and Microphone. Available playback feature.
- [x] Hardware acceleration for H264 video encoding, AAC audio encoding
- [x] Support "Allow app extension API only" option
- [ ] ~~Support GPUImage framework (~> 0.5.12)~~
  - ~~https://github.com/shogo4405/GPUHaishinKit.swift/blob/master/README.md~~
- [ ] ~~Objective-C Bridging~~

## Requirements
|-|iOS|OSX|tvOS|XCode|Swift|
|:----:|:----:|:----:|:----:|:----:|:----:|
|1.2.0+|9.0+|10.11+|10.2+|13.0+|5.5+|
|1.1.0+|9.0+|10.11+|10.2+|12.0+|5.0+|
|1.0.0+|8.0+|10.11+|10.2+|11.0+|5.0+|

## Cocoa Keys
Please contains Info.plist.

iOS 10.0+
* NSMicrophoneUsageDescription
* NSCameraUsageDescription

macOS 10.14+
* NSMicrophoneUsageDescription
* NSCameraUsageDescription

## Installation
*Please set up your project Swift 5.5. *

### CocoaPods
```rb
source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

def import_pods
    pod 'HaishinKit', '~> 1.2.2'
end

target 'Your Target'  do
    platform :ios, '9.0'
    import_pods
end
```
### Carthage
```
github "shogo4405/HaishinKit.swift" ~> 1.2.2
```
### Swift Package Manager
```
https://github.com/shogo4405/HaishinKit.swift
```

## License
BSD-3-Clause

## Donation
Paypal
 - https://www.paypal.me/shogo4405

Bitcoin
```txt
3FnjC3CmwFLTzNY5WPNz4LjTo1uxGNozUR
```

## Prerequisites
Make sure you setup and activate your AVAudioSession.
```swift
import AVFoundation
let session = AVAudioSession.sharedInstance()
do {
    // https://stackoverflow.com/questions/51010390/avaudiosession-setcategory-swift-4-2-ios-12-play-sound-on-silent
    if #available(iOS 10.0, *) {
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
    } else {
        session.perform(NSSelectorFromString("setCategory:withOptions:error:"), with: AVAudioSession.Category.playAndRecord, with: [
            AVAudioSession.CategoryOptions.allowBluetooth,
            AVAudioSession.CategoryOptions.defaultToSpeaker]
        )
        try session.setMode(.default)
    }
    try session.setActive(true)
} catch {
    print(error)
}
```
## RTMP Usage
Real Time Messaging Protocol (RTMP).
```swift
let rtmpConnection = RTMPConnection()
let rtmpStream = RTMPStream(connection: rtmpConnection)
rtmpStream.attachAudio(AVCaptureDevice.default(for: AVMediaType.audio)) { error in
    // print(error)
}
rtmpStream.attachCamera(DeviceUtil.device(withPosition: .back)) { error in
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

### RTML URL Format
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
var rtmpStream = RTMPStream(connection: rtmpConnection)

rtmpStream.captureSettings = [
    .fps: 30, // FPS
    .sessionPreset: AVCaptureSession.Preset.medium, // input video width/height
    // .isVideoMirrored: false,
    // .continuousAutofocus: false, // use camera autofocus mode
    // .continuousExposure: false, //  use camera exposure mode
    // .preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode.auto
]
rtmpStream.audioSettings = [
    .muted: false, // mute audio
    .bitrate: 32 * 1000,
]
rtmpStream.videoSettings = [
    .width: 640, // video output width
    .height: 360, // video output height
    .bitrate: 160 * 1000, // video output bitrate
    .profileLevel: kVTProfileLevel_H264_Baseline_3_1, // H264 Profile require "import VideoToolbox"
    .maxKeyFrameIntervalDuration: 2, // key frame / sec
]
// "0" means the same of input
rtmpStream.recorderSettings = [
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
    ],
]

// 2nd arguemnt set false
rtmpStream.attachAudio(AVCaptureDevice.default(for: AVMediaType.audio), automaticallyConfiguresApplicationAudioSession: false)

```
### Authentication
```swift
var rtmpConnection = RTMPConnection()
rtmpConnection.connect("rtmp://username:password@localhost/appName/instanceName")
```

### Screen Capture
```swift
// iOS
rtmpStream.attachScreen(ScreenCaptureSession(shared: UIApplication.shared))
// macOS
rtmpStream.attachScreen(AVCaptureScreenInput(displayID: CGMainDisplayID()))
```

## HTTP Usage
HTTP Live Streaming (HLS). Your iPhone/Mac become a IP Camera. Basic snipet. You can see http://ip.address:8080/hello/playlist.m3u8 
```swift
var httpStream = HTTPStream()
httpStream.attachCamera(DeviceUtil.device(withPosition: .back))
httpStream.attachAudio(AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio))
httpStream.publish("hello")

var hkView = HKView(frame: view.bounds)
hkView.attachStream(httpStream)

var httpService = HLSService(domain: "", type: "_http._tcp", name: "HaishinKit", port: 8080)
httpService.startRunning()
httpService.addHTTPStream(httpStream)

// add ViewController#view
view.addSubview(hkView)
```

## FAQ
### How can I run example project?
```sh
git clone https://github.com/shogo4405/HaishinKit.swift.git
cd HaishinKit.swift

carthage bootstrap --use-xcframeworks

open HaishinKit.xcodeproj
```

## Reference
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

