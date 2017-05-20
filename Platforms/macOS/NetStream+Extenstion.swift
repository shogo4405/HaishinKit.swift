import Foundation
import AVFoundation

extension NetStream {
    open func attachScreen(_ screen:AVCaptureScreenInput?) {
        lockQueue.async {
            self.mixer.videoIO.attachScreen(screen)
        }
    }
}
