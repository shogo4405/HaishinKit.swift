import AVFoundation
import CoreMedia

public protocol RTMPStreamDelegate: class {
    func didPublishInsufficientBW(_ stream: RTMPStream, withConnection: RTMPConnection)
    func didPublishSufficientBW(_ stream: RTMPStream, withConnection: RTMPConnection)
    func didOutputAudio(_ buffer: AVAudioPCMBuffer, presentationTimeStamp: CMTime)
    func didOutputVideo(_ buffer: CMSampleBuffer)
    func didStatics(_ stream: RTMPStream, withConneciton: RTMPConnection)
    func clear()
}

public extension RTMPStreamDelegate {
    func didStatics(_ stream: RTMPStream, withConneciton: RTMPConnection) {
    }
    func didOutputAudio(_ buffer: AVAudioPCMBuffer, presentationTimeStamp: CMTime) {
    }
    func didOutputVideo(_ buffer: CMSampleBuffer) {
    }
}
