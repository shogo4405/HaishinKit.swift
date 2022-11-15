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
        capture = AVCaptureIOUnit(screen) {
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = videoSettings as? [String: Any]
            return output
        }
        capture?.output.setSampleBufferDelegate(self, queue: lockQueue)
    }
}

#endif
