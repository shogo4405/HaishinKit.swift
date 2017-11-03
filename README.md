# HaishinKit (formerly lf)
[![Platform](https://img.shields.io/cocoapods/p/HaishinKit.svg?style=flat)](http://cocoapods.org/pods/HaishinKit)
![Language](https://img.shields.io/badge/language-Swift%204.0-orange.svg)
[![CocoaPods](https://img.shields.io/cocoapods/v/HaishinKit.svg?style=flat)](http://cocoapods.org/pods/HaishinKit)
[![GitHub license](https://img.shields.io/badge/license-New%20BSD-blue.svg)](https://raw.githubusercontent.com/shogo4405/HaishinKit.swift/master/LICENSE.md)

* Camera and Microphone streaming library via RTMP, HLS for iOS, macOS, tvOS.
* Issuesの言語は、英語か、日本語でお願いします！

## Features
### RTMP
- [x] Authentication
- [x] Publish and Recording (H264/AAC)
- [x] _Playback (Technical Preview)_
- [x] Adaptive bitrate streaming
  - [x] Handling (see also [#126](/../../issues/126))
  - [x] Automatic drop frames
- [ ] Action Message Format
  - [x] AMF0
  - [ ] AMF3
- [x] SharedObject
- [x] RTMPS
  - [x] Native (RTMP over SSL/TSL)
  - [x] _Tunneled (RTMPT over SSL/TSL) (Technical Preview)_
- [x] _RTMPT (Technical Preview)_
- [x] _ReplayKit Live as a Broadcast Upload Extension (Technical Preview)_

### HLS
- [x] HTTPService
- [x] HLS Publish

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
|0.8.0|8.0+|10.11+|10.2+|9.0+|4.0|1.2.0|0.20.0+|
|0.7.0|8.0+|10.11+|10.2+|8.3+|3.1|1.2.0|0.20.0+|

## Cocoa Keys
iOS10.0+
* NSMicrophoneUsageDescription
* NSCameraUsageDescription

## Installation
*Please set up your project Swift 4.0.*

### CocoaPods
```rb
source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

def import_pods
    pod 'HaishinKit', '~> 0.8.0'
end

target 'Your Target'  do
    platform :ios, '8.0'
    import_pods
end
```
### Carthage
```
github "shogo4405/HaishinKit.swift" ~> 0.8.0
```

## License
New BSD

## Donation
Bitcoin
```txt
1CWA9muX36QKBdJiRQJGpu2HvchfEpJbWr
```

## Prerequisites
Make sure you setup and activate your AVAudioSession.
```swift
import AVFoundation

do {
   try AVAudioSession.sharedInstance().setPreferredSampleRate(44_100)
   try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
   try AVAudioSession.sharedInstance().setMode(AVAudioSessionModeDefault)
   try AVAudioSession.sharedInstance().setActive(true)
   } catch {
}
```
## RTMP Usage
Real Time Messaging Protocol (RTMP).
```swift
let rtmpConnection:RTMPConnection = RTMPConnection()
let rtmpStream: RTMPStream = RTMPStream(connection: rtmpConnection)
rtmpStream.attachAudio(AVCaptureDevice.default(for: AVMediaType.audio)) { error in
    // print(error)
}
rtmpStream.attachCamera(DeviceUtil.device(withPosition: .back)) { error in
    // print(error)
}

let lfView: LFView = LFView(frame: view.bounds)
lfView.videoGravity = AVLayerVideoGravity.resizeAspectFill
lfView.attachStream(rtmpStream)

// add ViewController#view
view.addSubview(lfView)

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
do {
    try AVAudioSession.sharedInstance().setPreferredSampleRate(sampleRate)
    try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
    try AVAudioSession.sharedInstance().setMode(AVAudioSessionModeDefault)
    try AVAudioSession.sharedInstance().setActive(true)
} catch {
}
#endif

var rtmpStream:RTMPStream = RTMPStream(connection: rtmpConnection)

rtmpStream.captureSettings = [
    "fps": 30, // FPS
    "sessionPreset": AVCaptureSessionPresetMedium, // input video width/height
    "continuousAutofocus": false, // use camera autofocus mode
    "continuousExposure": false, //  use camera exposure mode
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
    AVMediaTypeAudio: [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 0,
        AVNumberOfChannelsKey: 0,
        // AVEncoderBitRateKey: 128000,
    ],
    AVMediaTypeVideo: [
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
rtmpStream.attachAudio(AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio), automaticallyConfiguresApplicationAudioSession: false)

```
### Authentication
```swift
var rtmpConnection:RTMPConnection = RTMPConnection()
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
var httpStream:HTTPStream = HTTPStream()
httpStream.attachCamera(DeviceUtil.device(withPosition: .back))
httpStream.attachAudio(AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio))
httpStream.publish("hello")

var lfView:LFView = LFView(frame: view.bounds)
lfView.attachStream(httpStream)

var httpService:HLSService = HLSService(domain: "", type: "_http._tcp", name: "lf", port: 8080)
httpService.startRunning()
httpService.addHTTPStream(httpStream)

// add ViewController#view
view.addSubview(lfView)
```

## FAQ
### How can I run example project?
Please hit `carthage update` command. HaishinKit needs Logboard module via Carthage.
```sh
carthage update
```

### Do you support me via Email?
Yes. Consulting fee is $50/1 incident. I don't recommend.
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

