# HaishinKit
- This is the main module. It provides common functionality for live streaming and supports the RTMP protocol.

## 📓 RTMP Usage
### Ingest
```swift
let mixer = MediaMixer()
let connection = RTMPConnection()
let stream = RTMPStream(connection: connection)
let hkView = MTHKView(frame: view.bounds)

Task {
  do {
    try await mixer.attachAudio(AVCaptureDevice.default(for: .audio))
  } catch {
    print(error)
  }

  do {
    try await mixer.attachVideo(AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back))
  } catch {
    print(error)
  }

  await mixer.addOutput(stream)
}

Task { MainActor in
  await stream.addOutput(hkView)
  // add ViewController#view
  view.addSubview(hkView)
}

Task {
  do {
    try await connection.connect("rtmp://localhost/appName/instanceName")
    try await stream.publish(streamName)
  } catch RTMPConnection.Error.requestFailed(let response) {
    print(response)
  } catch RTMPStream.Error.requestFailed(let response) {
    print(response)
  } catch {
    print(error)
  }
}
```

### Playback
```swift
let connection = RTMPConnection()
let stream = RTMPStream(connection: connection)
let audioPlayer = AudioPlayer(AVAudioEngine())

let hkView = MTHKView(frame: view.bounds)

Task { MainActor in
  await stream.addOutput(hkView)
}

Task {
  // requires attachAudioPlayer
  await stream.attachAudioPlayer(audioPlayer)

  do {
    try await connection.connect("rtmp://localhost/appName/instanceName")
    try await stream.play(streamName)
  } catch RTMPConnection.Error.requestFailed(let response) {
    print(response)
  } catch RTMPStream.Error.requestFailed(let response) {
    print(response)
  } catch {
    print(error)
  }
}
```

### Authentication
```swift
var connection = RTMPConnection()
connection.connect("rtmp://username:password@localhost/appName/instanceName")
```
