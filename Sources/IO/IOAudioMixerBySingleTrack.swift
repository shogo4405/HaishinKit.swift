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
    private var inSourceFormat: AudioStreamBasicDescription? {
        didSet {
            guard var inSourceFormat, inSourceFormat != oldValue else {
                return
            }
            outputFormat = settings.makeAudioFormat(Self.makeAudioFormat(&inSourceFormat))
        }
    }
    private var track: IOAudioMixerTrack<IOAudioMixerBySingleTrack>?

    func append(_ track: UInt8, buffer: CMSampleBuffer) {
        guard settings.mainTrack == track else {
            return
        }
        inSourceFormat = buffer.formatDescription?.audioStreamBasicDescription
        self.track?.append(buffer)
    }

    func append(_ track: UInt8, buffer: AVAudioPCMBuffer, when: AVAudioTime) {
        guard settings.mainTrack == track else {
            return
        }
        inSourceFormat = buffer.format.streamDescription.pointee
        self.track?.append(buffer, when: when)
    }
}

extension IOAudioMixerBySingleTrack: IOAudioMixerTrackDelegate {
    // MARK: IOAudioMixerTrackDelegate
    func track(_ resampler: IOAudioMixerTrack<IOAudioMixerBySingleTrack>, didOutput audioPCMBuffer: AVAudioPCMBuffer, when: AVAudioTime) {
        delegate?.audioMixer(self, didOutput: audioPCMBuffer, when: when)
    }

    func track(_ resampler: IOAudioMixerTrack<IOAudioMixerBySingleTrack>, errorOccurred error: IOAudioUnitError) {
        delegate?.audioMixer(self, errorOccurred: error)
    }
}
