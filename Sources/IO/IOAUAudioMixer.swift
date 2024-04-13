import AVFoundation
import Foundation

final class IOAUAudioMixer: IOAudioMixerConvertible {
    private static let defaultSampleTime: AVAudioFramePosition = 0

    private class Track {
        let resampler: IOAudioResampler<IOAUAudioMixer>
        var ringBuffer: IOAudioRingBuffer?

        init(resampler: IOAudioResampler<IOAUAudioMixer>, format: AVAudioFormat? = nil) {
            self.resampler = resampler
            if let format {
                self.ringBuffer = .init(format)
            }
        }
    }

    var delegate: (any IOAudioMixerDelegate)?
    var settings: IOAudioMixerSettings = .init() {
        didSet {
            defaultTrack?.resampler.settings = settings.defaultResamplerSettings
            if !settings.defaultResamplerSettings.invalidate(oldValue.defaultResamplerSettings) {
                enforceResamplersSettings()
            }
        }
    }
    var inputFormat: AVAudioFormat? {
        return defaultTrack?.resampler.inputFormat
    }
    var outputFormat: AVAudioFormat? {
        return defaultTrack?.resampler.outputFormat
    }
    private(set) var numberOfTracks = 0
    private var tracks: [Int: Track] = [:] {
        didSet {
            numberOfTracks = tracks.keys.count
            tryToSetupAudioNodes()
        }
    }
    private var shouldMix: Bool {
        numberOfTracks > 1
    }
    private var anchor: AVAudioTime?
    private var sampleTime: AVAudioFramePosition = IOAUAudioMixer.defaultSampleTime
    private var mixerNode: MixerNode?
    private var outputNode: OutputNode?
    private var defaultTrack: Track? {
        tracks[settings.mainTrack]
    }

    private let inputRenderCallback: AURenderCallback = { (inRefCon: UnsafeMutableRawPointer, _: UnsafeMutablePointer<AudioUnitRenderActionFlags>, _: UnsafePointer<AudioTimeStamp>, inBusNumber: UInt32, inNumberFrames: UInt32, ioData: UnsafeMutablePointer<AudioBufferList>?) in
        let audioMixer = Unmanaged<IOAUAudioMixer>.fromOpaque(inRefCon).takeUnretainedValue()
        let status = audioMixer.provideInput(inNumberFrames, channel: Int(inBusNumber), ioData: ioData)
        guard status == noErr else {
            audioMixer.delegate?.audioMixer(audioMixer, errorOccurred: .failedToMix(error: IOAudioMixerError.unableToProvideInputData))
            return noErr
        }
        return status
    }

    func append(_ sampleBuffer: CMSampleBuffer, track: UInt8 = 0) {
        if sampleTime == Self.defaultSampleTime, track == settings.mainTrack {
            sampleTime = sampleBuffer.presentationTimeStamp.value
            if let outputFormat {
                anchor = .init(hostTime: AVAudioTime.hostTime(forSeconds: sampleBuffer.presentationTimeStamp.seconds), sampleTime: sampleTime, atRate: outputFormat.sampleRate)
            }
        }
        self.track(channel: Int(track)).resampler.append(sampleBuffer)
    }

    func append(_ audioBuffer: AVAudioPCMBuffer, when: AVAudioTime, track: UInt8) {
        if sampleTime == Self.defaultSampleTime, track == settings.mainTrack {
            sampleTime = when.sampleTime
            anchor = when
        }
        self.track(channel: Int(track)).resampler.append(audioBuffer, when: when)
    }

    private func track(channel: Int) -> Track {
        let channel = Int(channel)
        if let track = tracks[channel] {
            return track
        }
        let track = makeTrack(channel: channel)
        if channel == settings.mainTrack {
            enforceResamplersSettings()
        }
        return track
    }

    private func makeTrack(channel: Int) -> Track {
        let resampler = IOAudioResampler<IOAUAudioMixer>()
        resampler.channel = channel
        if channel == settings.mainTrack {
            resampler.settings = settings.defaultResamplerSettings
        } else {
            applySettings(resampler: resampler, defaultFormat: outputFormat, preferredSettings: settings.resamplersSettings[channel])
        }
        resampler.delegate = self
        let track = Track(resampler: resampler, format: resampler.outputFormat)
        tracks[channel] = track
        return track
    }

    private func tryToSetupAudioNodes() {
        guard shouldMix else {
            return
        }
        do {
            try setupAudioNodes()
        } catch {
            delegate?.audioMixer(self, errorOccurred: .failedToMix(error: error))
        }
    }

    private func setupAudioNodes() throws {
        mixerNode = nil
        outputNode = nil
        guard let outputFormat else {
            return
        }
        sampleTime = Self.defaultSampleTime
        let mixerNode = try MixerNode(format: outputFormat)
        try mixerNode.update(busCount: numberOfTracks, scope: .input)
        let busCount = try mixerNode.busCount(scope: .input)
        if busCount > numberOfTracks {
            for index in numberOfTracks..<busCount {
                try mixerNode.enable(bus: index, scope: .input, isEnabled: false)
            }
        }
        for (bus, _) in tracks {
            try mixerNode.update(format: outputFormat, bus: bus, scope: .input)

            var callbackStruct = AURenderCallbackStruct(inputProc: inputRenderCallback,
                                                        inputProcRefCon: Unmanaged.passUnretained(self).toOpaque())
            try mixerNode.update(inputCallback: &callbackStruct, bus: bus)
            try mixerNode.update(volume: 1, bus: bus, scope: .input)
        }
        try mixerNode.update(format: outputFormat, bus: 0, scope: .output)
        try mixerNode.update(volume: 1, bus: 0, scope: .output)
        let outputNode = try OutputNode(format: outputFormat)
        try outputNode.update(format: outputFormat, bus: 0, scope: .input)
        try outputNode.update(format: outputFormat, bus: 0, scope: .output)
        try mixerNode.connect(to: outputNode)
        try mixerNode.initializeAudioUnit()
        try outputNode.initializeAudioUnit()
        self.mixerNode = mixerNode
        self.outputNode = outputNode
        if logger.isEnabledFor(level: .info) {
            logger.info("mixerAudioUnit: \(mixerNode)")
        }
    }

    private func provideInput(_ inNumberFrames: UInt32, channel: Int, ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {
        guard let ringBuffer = track(channel: channel).ringBuffer else {
            return noErr
        }
        if ringBuffer.counts == 0 {
            guard let bufferList = UnsafeMutableAudioBufferListPointer(ioData) else {
                return noErr
            }
            for i in 0..<bufferList.count {
                memset(bufferList[i].mData, 0, Int(bufferList[i].mDataByteSize))
            }
            return noErr
        }
        let status = ringBuffer.render(inNumberFrames, ioData: ioData)
        return status
    }

    private func mix(numberOfFrames: AVAudioFrameCount) {
        guard let outputNode else {
            return
        }
        do {
            let buffer = try outputNode.render(numberOfFrames: numberOfFrames, sampleTime: sampleTime)
            let time = AVAudioTime(sampleTime: sampleTime, atRate: outputNode.format.sampleRate)
            if let anchor, let when = time.extrapolateTime(fromAnchor: anchor) {
                delegate?.audioMixer(self, didOutput: buffer, when: when)
                sampleTime += Int64(numberOfFrames)
            }
        } catch {
            delegate?.audioMixer(self, errorOccurred: .failedToMix(error: error))
        }
    }

    private func enforceResamplersSettings() {
        guard shouldMix else {
            return
        }
        guard let outputFormat else {
            delegate?.audioMixer(self, errorOccurred: .failedToMix(error: IOAudioMixerError.unableToEnforceAudioFormat))
            return
        }
        for (channel, track) in tracks {
            if channel == settings.mainTrack {
                continue
            }
            applySettings(resampler: track.resampler, defaultFormat: outputFormat, preferredSettings: settings.resamplersSettings[channel])
        }
    }

    private func applySettings(resampler: IOAudioResampler<IOAUAudioMixer>,
                               defaultFormat: AVAudioFormat?,
                               preferredSettings: IOAudioResamplerSettings?) {
        let preferredSettings = preferredSettings ?? .init()
        guard let defaultFormat else {
            resampler.settings = preferredSettings
            return
        }
        resampler.settings = IOAudioResamplerSettings(
            sampleRate: defaultFormat.sampleRate,
            channels: defaultFormat.channelCount,
            downmix: preferredSettings.downmix,
            channelMap: preferredSettings.channelMap
        )
    }
}

extension IOAUAudioMixer: IOAudioResamplerDelegate {
    // MARK: IOAudioResamplerDelegate
    func resampler(_ resampler: IOAudioResampler<IOAUAudioMixer>, didOutput audioFormat: AVAudioFormat) {
        guard shouldMix else {
            delegate?.audioMixer(self, didOutput: audioFormat)
            return
        }
        if resampler.channel == settings.mainTrack {
            enforceResamplersSettings()
            tryToSetupAudioNodes()
            delegate?.audioMixer(self, didOutput: audioFormat)
        }
        track(channel: resampler.channel).ringBuffer = .init(audioFormat)
    }

    func resampler(_ resampler: IOAudioResampler<IOAUAudioMixer>, didOutput audioBuffer: AVAudioPCMBuffer, when: AVAudioTime) {
        guard shouldMix else {
            delegate?.audioMixer(self, didOutput: audioBuffer, when: when)
            return
        }
        guard audioBuffer.format.sampleRate == outputFormat?.sampleRate else {
            delegate?.audioMixer(self, errorOccurred: .failedToMix(error: IOAudioMixerError.invalidSampleRate))
            return
        }
        let track = track(channel: resampler.channel)
        if track.ringBuffer == nil, let format = resampler.outputFormat {
            track.ringBuffer = .init(format)
        }
        guard let ringBuffer = track.ringBuffer else {
            return
        }
        ringBuffer.append(audioBuffer, when: when)
        if resampler.channel == settings.mainTrack {
            mix(numberOfFrames: audioBuffer.frameLength)
        }
    }

    func resampler(_ resampler: IOAudioResampler<IOAUAudioMixer>, errorOccurred error: IOAudioUnitError) {
        delegate?.audioMixer(self, errorOccurred: error)
    }
}
