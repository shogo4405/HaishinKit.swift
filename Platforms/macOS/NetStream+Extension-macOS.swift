#if os(macOS)

import AVFoundation
import Foundation

extension NetStream {
    open func attachScreen(_ screen: AVCaptureScreenInput?) {
        lockQueue.async {
            self.mixer.videoIO.attachScreen(screen)
        }
    }
}

#endif
