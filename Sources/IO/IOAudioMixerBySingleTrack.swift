import AVFoundation
import Foundation

final class IOAudioMixerBySingleTrack: IOAudioMixerConvertible {
    var delegate: (any IOAudioMixerDelegate)?
    var settings = IOAudioMixerSettings.default {
        didSet {
            if let trackSettings = settings.tracks[settings.mainTrack] {
                track?.settings = trackSettings
            }
        }
    }
    var inputFormats: [UInt8: AVAudioFormat] {
        var formats: [UInt8: AVAudioFormat] = .init()
        if let track = track, let inputFormat = track.inputFormat {
            formats[track.id] = inputFormat
        }
        return formats
    }
    private(set) var outputFormat: AVAudioFormat? {
        didSet {
            guard let outputFormat, outputFormat != oldValue else {
                return
            }
            let track = IOAudioMixerTrack<IOAudioMixerBySingleTrack>(id: settings.mainTrack, outputFormat: outputFormat)
            track.delegate = self
            self.track = track
        }
    }
    private var inSourceFormat: CMFormatDescription? {
        didSet {
            guard inSourceFormat != oldValue else {
                return
            }
            outputFormat = settings.makeOutputFormat(inSourceFormat)
        }
    }
    private var track: IOAudioMixerTrack<IOAudioMixerBySingleTrack>?

    func append(_ track: UInt8, buffer: CMSampleBuffer) {
        guard settings.mainTrack == track else {
            return
        }
        inSourceFormat = buffer.formatDescription
        self.track?.append(buffer)
    }

    func append(_ track: UInt8, buffer: AVAudioPCMBuffer, when: AVAudioTime) {
        guard settings.mainTrack == track else {
            return
        }
        inSourceFormat = buffer.format.formatDescription
        self.track?.append(buffer, when: when)
    }
}

extension IOAudioMixerBySingleTrack: IOAudioMixerTrackDelegate {
    // MARK: IOAudioMixerTrackDelegate
    func track(_ resampler: IOAudioMixerTrack<IOAudioMixerBySingleTrack>, didOutput buffer: AVAudioPCMBuffer, when: AVAudioTime) {
        delegate?.audioMixer(self, didOutput: buffer.muted(settings.isMuted), when: when)
    }

    func track(_ resampler: IOAudioMixerTrack<IOAudioMixerBySingleTrack>, errorOccurred error: IOAudioUnitError) {
        delegate?.audioMixer(self, errorOccurred: error)
    }
}
