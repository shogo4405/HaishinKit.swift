import AVFoundation
import CoreMedia

public protocol RTMPStreamDelegate: class {
    func rtmpStream(_ stream: RTMPStream, didPublishInsufficientBW connection: RTMPConnection)
    func rtmpStream(_ stream: RTMPStream, didPublishSufficientBW connection: RTMPConnection)
    func rtmpStream(_ stream: RTMPStream, didOutput audio: AVAudioBuffer, presentationTimeStamp: CMTime)
    func rtmpStream(_ stream: RTMPStream, didOutput video: CMSampleBuffer)
    func rtmpStream(_ stream: RTMPStream, didStatics connection: RTMPConnection)
    func rtmpStreamDidClear(_ stream: RTMPStream)
}

public extension RTMPStreamDelegate {
    func rtmpStream(_ stream: RTMPStream, didStatics connection: RTMPConnection) {
    }

    func rtmpStream(_ stream: RTMPStream, didOutput audio: AVAudioBuffer, presentationTimeStamp: CMTime) {
    }

    func rtmpStream(_ stream: RTMPStream, didOutput video: CMSampleBuffer) {
    }
}
