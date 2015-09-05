# lf.swift
iOS用のライブ配信ライブラリーです。現在、RTMPをサポートしています。視聴のほうはサポートしていません。ライセンスは、修正BSDライセンスです。

## ライセンス
修正BSDで公開しています。

## 簡単な説明
### RTMP
api自体はAS3のNetConnectionとNetStreamに似せています。
* flash.net.SharedObject → RTMPSharedObject
* flash.net.Responder → Responder
* flash.net.NetConnection → RTMPConnection
* flash.net.NetStream → RTMPStream
* AMF0をサポート
```swift
var rtmpConnection:RTMPConnection = RTMPConnection()
var rtmpStream:RTMPStream = RTMPStream()
rtmpStream = RTMPStream(rtmpConnection: rtmpConnection)
rtmpStream!.attachAudio(AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio))
rtmpStream!.attachCamera(AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo))
rtmpConnection.connect("rtmp://localhost/appName/instanceName")
rtmpStream!.publish("streamName")

var previewLayer:AVCaptureVideoPreviewLayer? = rtmpStream!.toPreviewLayer()
previewLayer!.frame = view.bounds
previewLayer!.videoGravity = AVLayerVideoGravityResizeAspectFill
view.layer.addSublayer(previewLayer!)
```

## 参考文献
