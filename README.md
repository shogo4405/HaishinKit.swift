# lf.swift
lf is a lIVE fRAMEWORK. iOS/OSX Camera/Microphone streaming library via RTMP/HTTP

## Install
### Cocoapod
    pod 'lf'
    use_frameworks!

## Usage/RTMP
Real Time Messaging Protocol (RTMP). Basic snipet.
```swift
var rtmpConnection:RTMPConnection = RTMPConnection()
var rtmpStream = RTMPStream(rtmpConnection: rtmpConnection)
rtmpStream.videoGravity = AVLayerVideoGravityResizeAspectFill
rtmpStream.attachAudio(AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio))
rtmpStream.attachCamera(AVMixer.deviceWithPosition(.Back))

view.addSubview(rtmpStream.view)
rtmpConnection.connect("rtmp://localhost/appName/instanceName")
rtmpStream.publish("streamName")
```
Settings
```swift
var rtmpStream = RTMPStream(rtmpConnection: rtmpConnection)
rtmpStream.videoSettings = [
    "width": 640, // video output width
    "height": 360, // video output height
]
```
RTMP Auth 
```swift
var rtmpConnection:RTMPConnection = RTMPConnection()
rtmpConnection.connect("rtmp://username:password@localhost/appName/instanceName")
```

## Usage/HTTP
HTTP Live Streaming (HLS). Your iPhone/Mac become a IP Camera. Basic snipet.
```swift
httpStream = HTTPStream()
httpStream.syncOrientation = true
httpStream.attachCamera(AVMixer.deviceWithPosition(.Back))
rtmpStream.attachAudio(AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio))

httpStream.publish("hello")

httpService = HTTPService(domain: "", type: "_http._tcp", name: "lf", port: 8080)
httpService.startRunning()
httpService.addHTTPStream(httpStream)

view.addSubview(httpStream.view)
```

You can see http://ip.address:8080/hello/playlist.m3u8 

## Class Overview
|AS3|lf|
|----|----|
|flash.net.SharedObject|RTMPSharedObject|
|flash.net.Responder|Responder|
|flash.net.NetConnection|RTMPConnection|
|flash.net.NetStream|RTMPStream|

## License
New BSD

## Enviroment
|lf|iOS|OSX|Swift|CocoaPod|
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

