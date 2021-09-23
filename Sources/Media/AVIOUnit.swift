import CoreMedia
import Foundation

class AVIOUnit: NSObject {
    private(set) weak var mixer: AVMixer?

    init(mixer: AVMixer) {
        self.mixer = mixer
    }
}
