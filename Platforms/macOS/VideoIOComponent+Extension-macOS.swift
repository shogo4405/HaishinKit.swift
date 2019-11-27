#if os(macOS)

import AVFoundation

extension VideoIOComponent {
    func attachScreen(_ screen: AVCaptureScreenInput?) {
        mixer?.session.beginConfiguration()
        output = nil
        guard screen != nil else {
            input = nil
            return
        }
        input = screen
        mixer?.session.addOutput(output)
        output.setSampleBufferDelegate(self, queue: lockQueue)
        mixer?.session.commitConfiguration()
        if mixer?.session.isRunning ?? false {
            mixer?.session.startRunning()
        }
    }
}

#endif
