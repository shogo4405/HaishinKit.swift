# lf.swift
lf is a lIVE fRAMEWORK. iOS Camera/Microphone streaming library via RTMP/HTTP

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
HTTP Live Streaming (HLS). Your iPhone become a IP Camera. Basic snipet.
```swift
httpStream = HTTPStream()
httpStream.syncOrientation = true
httpStream.attachCamera(AVMixer.deviceWithPosition(.Back))

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

## Reference
* Adobe’s Real Time Messaging Protocol
 * http://www.adobe.com/content/dam/Adobe/en/devnet/rtmp/pdf/rtmp_specification_1.0.pdf
* Action Message Format -- AMF 0
 * http://wwwimages.adobe.com/content/dam/Adobe/en/devnet/amf/pdf/amf0-file-format-specification.pdf
* Action Message Format -- AMF 3 
 * http://wwwimages.adobe.com/www.adobe.com/content/dam/Adobe/en/devnet/amf/pdf/amf-file-format-spec.pdf
