# ``SRTHaishinKit``
This module supports the SRT protocol.

## Overview
This is a module that supports SRT protocol. It internally uses a library that is built from [libsrt](https://github.com/Haivision/srt) and converted into an xcframework.

## 🎨 Features
- Ingest
  - H264, HEVC and AAC support.
- Playback
  - H264, HEVC and AAC support.
- SRT Mode
  - [x] caller
  - [x] listener
  - [ ] rendezvous

## 📓 Usage
### SRT Logging
- Defining a Swift wrapper method for `srt_setloglevel`.
```swift
await SRTLogger.shared.setLevel(.debug)
```

### Ingest
```swift
let mixer = MediaMixer()
let connection = SRTConnection()
let stream = SRTStream(connection: connection)
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
  stream.attachAudioPlayer(audioPlayer)
  do {
    try await connection.connect("srt://host:port")
    try await stream.publish()
  } catch {
    print(error)
  }
}
```

### Playback
```swift
let connection = SRTConnection()
let stream = SRTStream(connection: connection)
let hkView = MTHKView(frame: view.bounds)
let audioPlayer = AudioPlayer(AVAudioEngine())

Task { MainActor in
  await stream.addOutput(hkView)
  // add ViewController#view
  view.addSubview(hkView)
}

Task {
  // requires attachAudioPlayer
  await stream.attachAudioPlayer(audioPlayer)

  do {
    try await connection.connect("srt://host:port")
    try await stream.play()
  } catch {
    print(error)
  }
}
```

### Specify socket options.
- On the HaishinKit side, the default settings of libsrt are used.
  - Please check [the following code](https://github.com/shogo4405/HaishinKit.swift/blob/main/SRTHaishinKit/Sources/SRT/SRTSocketOption.swift) for the support status.
- Many SRT options can be defined as query parameters in the connection URL as follows.
```swift
try await connection.connect("srt://host:port?key=value")
```

## 🔧 Test
### ffplay as a SRT service for ingest HaishinKit.
```sh
$ ffplay -i 'srt://${YOUR_IP_ADDRESS}?mode=listener'
```
### ffmpeg as a SRT service for playback HaishinKit.
```sh
$ ffmpeg -stream_loop -1 -re -i input.mp4 -c copy -f mpegts 'srt://0.0.0.0:9998?mode=listener'
```

## 📜 License
### SRTHaishinKit
- SRTHaishinKit is licensed under the BSD-3-Clause.

### libsrt.xcframework
- libsrt.xcframework is licensed under MPLv2.0.
- This is a build of https://github.com/Haivision/srt as an xcframework.
