# lf.swift
lf is a lIVE fRAMEWORK. Camera and Microphone streaming library via RTMP, HLS for iOS, macOS.

## Install
### CocoaPods
```rb
source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

def import_pods
    pod 'lf', '~> 0.3.0'
end

target 'Your Target'  do
    platform :ios, '8.0'
    import_pods
end
```

## RTMP Usage
Real Time Messaging Protocol (RTMP).
```swift
var rtmpConnection:RTMPConnection = RTMPConnection()
var rtmpStream = RTMPStream(rtmpConnection: rtmpConnection)
rtmpStream.view.videoGravity = AVLayerVideoGravityResizeAspectFill
rtmpStream.attachAudio(AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio))
rtmpStream.attachCamera(AVMixer.deviceWithPosition(.Back))

view.addSubview(rtmpStream.view)
rtmpConnection.connect("rtmp://localhost/appName/instanceName")
rtmpStream.publish("streamName")
```
### Settings
```swift
var rtmpStream = RTMPStream(rtmpConnection: rtmpConnection)
rtmpStream.captureSettings = [
    "fps": 30, // FPS
    "sessionPreset": AVCaptureSessionPresetMedium, // input video width/height
    "continuousAutofocus": false, // use camera autofocus mode
    "continuousExposure": false, //  use camera exposure mode
]
rtmpStream.audioSettings = [
    "muted": false, // mute audio
    "bitrate": 32 * 1024,
]
rtmpStream.videoSettings = [
    "width": 640, // video output width
    "height": 360, // video output height
    "bitrate": 160 * 1024, // video output bitrate
    "profileLevel": kVTProfileLevel_H264_Baseline_3_1, // H264 Profile require "import VideoToolbox"
    "maxKeyFrameIntervalDuration": 2, // key frame / sec
]
```
### RTMP Auth 
```swift
var rtmpConnection:RTMPConnection = RTMPConnection()
rtmpConnection.connect("rtmp://username:password@localhost/appName/instanceName")
```

## HTTP Usage
HTTP Live Streaming (HLS). Your iPhone/Mac become a IP Camera. Basic snipet. You can see http://ip.address:8080/hello/playlist.m3u8 
```swift
httpStream = HTTPStream()

httpStream.attachCamera(AVMixer.deviceWithPosition(.Back))
rtmpStream.attachAudio(AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio))

httpStream.publish("hello")

httpService = HTTPService(domain: "", type: "_http._tcp", name: "lf", port: 8080)
httpService.startRunning()
httpService.addHTTPStream(httpStream)

view.addSubview(httpStream.view)
```

## License
New BSD

## Enviroment
|lf|iOS|OSX|Swift|CocoaPods|
|----|----|----|----|----|
|0.3|8.0|10.11|2.3|1.0.0|
|0.2|8.0|-|2.3|0.39.0|

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

