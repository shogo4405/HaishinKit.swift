import AVFoundation
import Foundation

protocol IOTellyUnitDelegate: AnyObject {
    func tellyUnit(_ tellyUnit: IOTellyUnit, didSetAudioFormat audioFormat: AVAudioFormat?)
    func tellyUnit(_ tellyUnit: IOTellyUnit, dequeue sampleBuffer: CMSampleBuffer)
    func tellyUnit(_ tellyUnit: IOTellyUnit, didBufferingChanged: Bool)
}

final class IOTellyUnit {
    var isRunning: Atomic<Bool> = .init(false)

    var audioFormat: AVAudioFormat? {
        didSet {
            delegate?.tellyUnit(self, didSetAudioFormat: audioFormat)
        }
    }

    var videoFormat: CMFormatDescription? {
        didSet {
            mediaLink.hasVideo = videoFormat != nil
        }
    }

    var soundTransform: SoundTransform = .init() {
        didSet {
            soundTransform.apply(mediaLink.playerNode)
        }
    }

    var playerNode: AVAudioPlayerNode {
        return mediaLink.playerNode
    }

    var delegate: (any IOTellyUnitDelegate)?

    private lazy var mediaLink: MediaLink = {
        var mediaLink = MediaLink<IOTellyUnit>()
        mediaLink.delegate = self
        return mediaLink
    }()
}

extension IOTellyUnit: Running {
    func startRunning() {
        guard !isRunning.value else {
            return
        }
        isRunning.mutate { $0 = true }
    }

    func stopRunning() {
        guard isRunning.value else {
            return
        }
        isRunning.mutate { $0 = false }
        audioFormat = nil
        videoFormat = nil
    }
}

extension IOTellyUnit: IOMuxer {
    // MARK: IOMuxer
    func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime) {
        guard let audioBuffer = audioBuffer as? AVAudioPCMBuffer else {
            return
        }
        mediaLink.enqueueAudio(audioBuffer)
    }

    func append(_ sampleBuffer: CMSampleBuffer) {
        mediaLink.enqueueVideo(sampleBuffer)
    }
}

extension IOTellyUnit: MediaLinkDelegate {
    // MARK: MediaLinkDelegate
    func mediaLink(_ mediaLink: MediaLink<IOTellyUnit>, dequeue sampleBuffer: CMSampleBuffer) {
        delegate?.tellyUnit(self, dequeue: sampleBuffer)
    }

    func mediaLink(_ mediaLink: MediaLink<IOTellyUnit>, didBufferingChanged: Bool) {
        delegate?.tellyUnit(self, didBufferingChanged: didBufferingChanged)
    }
}
