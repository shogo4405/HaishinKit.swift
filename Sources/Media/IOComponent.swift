import CoreMedia
import Foundation

class IOComponent: NSObject {
    fileprivate(set) weak var mixer:AVMixer?

    init(mixer: AVMixer) {
        self.mixer = mixer
    }
}

