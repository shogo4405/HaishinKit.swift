import Foundation
import AVFoundation

extension VideoIOComponent {
    func attachScreen(_ screen:AVCaptureScreenInput?) {
        mixer?.session.beginConfiguration()
        output = nil
        guard let _:AVCaptureScreenInput = screen else {
            input = nil
            return
        }
        input = screen
        mixer?.session.addOutput(output)
        output.setSampleBufferDelegate(self, queue: lockQueue)
        mixer?.session.commitConfiguration()
        if (mixer?.session.isRunning ?? false) {
            mixer?.session.startRunning()
        }
    }
}
