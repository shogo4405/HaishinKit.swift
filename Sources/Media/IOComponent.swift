import CoreMedia
import Foundation

class IOComponent: NSObject {
    var sampleBuffer:CMSampleBuffer?
    fileprivate(set) var mixer:AVMixer

    init(mixer: AVMixer) {
        self.mixer = mixer
    }
}
