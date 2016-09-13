import Foundation

class IOComponent: NSObject {
    fileprivate(set) var mixer:AVMixer

    init(mixer: AVMixer) {
        self.mixer = mixer
    }
}
