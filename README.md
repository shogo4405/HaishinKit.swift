# HaishinKit (formerly lf)
[![Platform](https://img.shields.io/cocoapods/p/HaishinKit.svg?style=flat)](http://cocoapods.org/pods/HaishinKit)
![Language](https://img.shields.io/badge/language-Swift%204.0-orange.svg)
[![CocoaPods](https://img.shields.io/cocoapods/v/HaishinKit.svg?style=flat)](http://cocoapods.org/pods/HaishinKit)
[![GitHub license](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](https://raw.githubusercontent.com/shogo4405/HaishinKit.swift/master/LICENSE.md)

* Camera and Microphone streaming library via RTMP, HLS for iOS, macOS, tvOS.
* Issuesの言語は、英語か、日本語でお願いします！

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
|-|HKView|GLHKView|MTHKView|
|-|:---:|:---:|:---:|
|Engine|AVCaptureVideoPreviewLayer|OpenGL ES|Metal|
|Publish|○|○|◯|
|Playback|×|○|◯|
|VIsualEffect|×|○|◯|
|Condition|Stable|Stable|Beta|

### Others
- [x] _Support tvOS 10.2+  (Technical Preview)_
  - tvOS can't publish Camera and Microphone. Available playback feature.
- [x] Hardware acceleration for H264 video encoding, AAC audio encoding
- [x] Support "Allow app extension API only" option
- [x] Support GPUImage framework (~> 0.5.12)
  - https://github.com/shogo4405/GPUHaishinKit.swift/blob/master/README.md
- [ ] ~~Objectiv-C Bridging~~

## Requirements
|-|iOS|OSX|tvOS|XCode|Swift|CocoaPods|Carthage|
|:----:|:----:|:----:|:----:|:----:|:----:|:----:|:----:|
0.11.0+|8.0+|10.11+|10.2+|10.0+|5.0|1.5.0+|0.29.0+|
|0.10.0+|8.0+|10.11+|10.2+|10.0+|4.2|1.5.0+|0.29.0+|

## Cocoa Keys
Please contains Info.plist.

iOS 10.0+
* NSMicrophoneUsageDescription
* NSCameraUsageDescription

macOS 10.14+
* NSMicrophoneUsageDescription
* NSCameraUsageDescription

## Installation
*Please set up your project Swift 5.0. *

### CocoaPods
```rb
source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

def import_pods
    pod 'HaishinKit', '~> 0.11.3'
end

target 'Your Target'  do
    platform :ios, '8.0'
    import_pods
end
```
### Carthage
```
github "shogo4405/HaishinKit.swift" ~> 0.11.3
```

## License
BSD-3-Clause

## Donation
Paypal
 - https://www.paypal.me/shogo4405

Bitcoin
```txt
1LP7Jo4VwAFdEisJSykBAtUyAusZjozSpw
```

## Prerequisites
Make sure you setup and activate your AVAudioSession.
```swift
import AVFoundation
let session = AVAudioSession.sharedInstance()
do {
    try session.setPreferredSampleRate(44_100)
    // https://stackoverflow.com/questions/51010390/avaudiosession-setcategory-swift-4-2-ios-12-play-sound-on-silent
    if #available(iOS 10.0, *) {
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
    } else {
        session.perform(NSSelectorFromString("setCategory:withOptions:error:"), with: AVAudioSession.Category.playAndRecord, with:  [AVAudioSession.CategoryOptions.allowBluetooth])
    }
    try session.setMode(AVAudioSessionModeDefault)
    try session.setActive(true)
} catch {
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

### Settings
```swift
let sampleRate:Double = 44_100

// see: #58
#if(iOS)
let session = AVAudioSession.sharedInstance()
do {
    try session.setPreferredSampleRate(44_100)
    // https://stackoverflow.com/questions/51010390/avaudiosession-setcategory-swift-4-2-ios-12-play-sound-on-silent
    if #available(iOS 10.0, *) {
        try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth])
    } else {
        session.perform(NSSelectorFromString("setCategory:withOptions:error:"), with: AVAudioSession.Category.playAndRecord, with:  [AVAudioSession.CategoryOptions.allowBluetooth])
    }
    try session.setActive(true)
} catch {
}
#endif

var rtmpStream = RTMPStream(connection: rtmpConnection)

rtmpStream.captureSettings = [
    "fps": 30, // FPS
    "sessionPreset": AVCaptureSession.Preset.medium.rawValue, // input video width/height
    "continuousAutofocus": false, // use camera autofocus mode
    "continuousExposure": false, //  use camera exposure mode
    // "preferredVideoStabilizationMode": AVCaptureVideoStabilizationMode.auto.rawValue
]
rtmpStream.audioSettings = [
    "muted": false, // mute audio
    "bitrate": 32 * 1024,
    "sampleRate": sampleRate, 
]
rtmpStream.videoSettings = [
    "width": 640, // video output width
    "height": 360, // video output height
    "bitrate": 160 * 1024, // video output bitrate
    // "dataRateLimits": [160 * 1024 / 8, 1], optional kVTCompressionPropertyKey_DataRateLimits property
    "profileLevel": kVTProfileLevel_H264_Baseline_3_1, // H264 Profile require "import VideoToolbox"
    "maxKeyFrameIntervalDuration": 2, // key frame / sec
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
Please hit `carthage update` command. HaishinKit needs Logboard module via Carthage.
```sh
carthage update
```

### Do you support me via Email?
Yes. Consulting fee is [$50](https://www.paypal.me/shogo4405/50USD)/1 incident. I don't recommend. 
Please consider to use Issues.


## Reference
* Adobe’s Real Time Messaging Protocol
  * http://www.adobe.com/content/dam/Adobe/en/devnet/rtmp/pdf/rtmp_specification_1.0.pdf
* Action Message Format -- AMF 0
  * http://wwwimages.adobe.com/content/dam/Adobe/en/devnet/amf/pdf/amf0-file-format-specification.pdf
* Action Message Format -- AMF 3 
  * http://wwwimages.adobe.com/www.adobe.com/content/dam/Adobe/en/devnet/amf/pdf/amf-file-format-spec.pdf
* Video File Format Specification Version 10
  * https://www.adobe.com/content/dam/Adobe/en/devnet/flv/pdfs/video_file_format_spec_v10.pdf
* Adobe Flash Video File Format Specification Version 10.1
  * http://download.macromedia.com/f4v/video_file_format_spec_v10_1.pdf

