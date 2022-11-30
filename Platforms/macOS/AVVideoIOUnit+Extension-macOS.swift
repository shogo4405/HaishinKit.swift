#if os(macOS)

import AVFoundation

extension AVVideoIOUnit {
    func attachScreen(_ screen: AVCaptureScreenInput?) {
        mixer?.session.beginConfiguration()
        defer {
            mixer?.session.commitConfiguration()
        }
        guard let screen else {
            capture = nil
            return
        }
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = videoSettings as? [String: Any]
        capture = AVCaptureIOUnit(input: screen, output: output, connection: nil)
        capture?.attach(mixer?.session)
        capture?.output.setSampleBufferDelegate(self, queue: lockQueue)
    }
}

#endif
