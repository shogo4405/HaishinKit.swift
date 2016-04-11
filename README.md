# lf.swift
iOS向けライブ配信用のライブラリーです。現在、RTMPでの配信をサポートしています。

## Install
### Cocoapod
    pod 'lf'
    use_frameworks!

## Usage
* Basic
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
* Setting
```swift
var rtmpStream = RTMPStream(rtmpConnection: rtmpConnection)
rtmpStream.captureSetting = [
    "width": 640,
    "height": 360,
]
```
* RTMP Auth
```swift
var rtmpConnection:RTMPConnection = RTMPConnection()
rtmpConnection.connect("rtmp://username:password@localhost/appName/instanceName")
```
* Screen Capture
```swift
var rtmpStream = RTMPStream(rtmpConnection: rtmpConnection)
rtmpStream.attachScreen(ScreenCaptureSession())
```

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
