import Foundation

class IOComponent: NSObject {
    fileprivate(set) var mixer:AVMixer

    internal init(mixer: AVMixer) {
        self.mixer = mixer
    }
}
