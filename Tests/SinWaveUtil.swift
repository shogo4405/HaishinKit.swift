import AVFoundation

final class SinWaveUtil {
    static func makeCMSampleBuffer(_ sampleRate: Double = 44100, numSamples: Int = 1024) -> CMSampleBuffer? {
        var status: OSStatus = noErr
        var sampleBuffer: CMSampleBuffer?
        var formatDescription: CMAudioFormatDescription? = nil
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: Int32(sampleRate)),
            presentationTimeStamp: CMTime.zero,
            decodeTimeStamp: CMTime.invalid
        )

        var asbd = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: 0xc,
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 16,
            mReserved: 0
        )

        status = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &formatDescription
        )

        guard status == noErr else {
            return nil
        }

        status = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: nil,
            dataReady: false,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleCount: numSamples,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )

        guard status == noErr else {
            return nil
        }

        let format = AVAudioFormat(cmAudioFormatDescription: formatDescription!)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numSamples))!
        buffer.frameLength = buffer.frameCapacity
        let channels = Int(format.channelCount)
        for ch in (0..<channels) {
            let samples = buffer.int16ChannelData![ch]
            for n in 0..<Int(buffer.frameLength) {
                samples[n] = Int16(sinf(Float(2.0 * .pi) * 440.0 * Float(n) / Float(sampleRate)) * 16383.0)
            }
        }

        status = CMSampleBufferSetDataBufferFromAudioBufferList(
            sampleBuffer!,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            bufferList: buffer.audioBufferList
        )

        guard status == noErr else {
            return nil
        }

        return sampleBuffer
    }
}
