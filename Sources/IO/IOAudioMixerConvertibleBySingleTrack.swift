import AVFoundation
import Foundation

final class IOAudioMixerConvertibleBySingleTrack: IOAudioMixerConvertible {
    var delegate: (any IOAudioMixerDelegate)?
    var inputFormat: AVAudioFormat?
    var settings: IOAudioMixerSettings = .init()

    private lazy var resampler: IOAudioResampler<IOAudioMixerConvertibleBySingleTrack> = {
        var resampler = IOAudioResampler<IOAudioMixerConvertibleBySingleTrack>()
        resampler.delegate = self
        return resampler
    }()

    func append(_ buffer: CMSampleBuffer, track: UInt8) {
        guard settings.mainTrack == track else {
            return
        }
        resampler.append(buffer)
    }

    func append(_ buffer: AVAudioPCMBuffer, when: AVAudioTime, track: UInt8) {
        guard settings.mainTrack == track else {
            return
        }
        resampler.append(buffer, when: when)
    }
}

extension IOAudioMixerConvertibleBySingleTrack: IOAudioResamplerDelegate {
    // MARK: IOAudioResamplerDelegate
    func resampler(_ resampler: IOAudioResampler<IOAudioMixerConvertibleBySingleTrack>, didOutput audioFormat: AVAudioFormat) {
        delegate?.audioMixer(self, didOutput: audioFormat)
    }

    func resampler(_ resampler: IOAudioResampler<IOAudioMixerConvertibleBySingleTrack>, didOutput audioPCMBuffer: AVAudioPCMBuffer, when: AVAudioTime) {
        delegate?.audioMixer(self, didOutput: audioPCMBuffer, when: when)
    }

    func resampler(_ resampler: IOAudioResampler<IOAudioMixerConvertibleBySingleTrack>, errorOccurred error: IOAudioUnitError) {
        delegate?.audioMixer(self, errorOccurred: error)
    }
}
