import AVFoundation
import CoreMedia

@objc
public protocol RTMPStreamDelegate: class {
    func didPublishInsufficientBW(_ stream: RTMPStream, withConnection: RTMPConnection)
    func didPublishSufficientBW(_ stream: RTMPStream, withConnection: RTMPConnection)

    @objc
    optional func outputAudio(_ buffer: AVAudioPCMBuffer, presentationTimeStamp: CMTime)

    @objc
    optional func outputVideo(_ buffer: CMSampleBuffer)

    func clear()
}
