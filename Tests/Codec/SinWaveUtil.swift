import Foundation
import AVFoundation

final class SinWaveUtil {
    static func createCMSampleBuffer(_ sampleRate:Double = 44100, numSamples:Int = 1024) -> CMSampleBuffer? {
        var status: OSStatus = noErr
        var sampleBuffer: CMSampleBuffer?
        var formatDescription: CMAudioFormatDescription? = nil
        var timing: CMSampleTimingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: Int32(sampleRate)),
            presentationTimeStamp: kCMTimeZero,
            decodeTimeStamp: kCMTimeInvalid
        )
        var asbd: AudioStreamBasicDescription = AudioStreamBasicDescription()
        asbd.mSampleRate = sampleRate
        asbd.mFormatID = kAudioFormatLinearPCM
        asbd.mFormatFlags = 0xc
        asbd.mBytesPerPacket = 2
        asbd.mFramesPerPacket = 1
        asbd.mBytesPerFrame = 2
        asbd.mChannelsPerFrame = 1
        asbd.mBitsPerChannel = 16

        status = CMAudioFormatDescriptionCreate(
            kCFAllocatorDefault, &asbd, 0, nil, 0, nil, nil, &formatDescription
        )

        guard status == noErr else {
            return nil
        }

        status = CMSampleBufferCreate(
            kCFAllocatorDefault,
            nil,
            false,
            nil,
            nil,
            formatDescription,
            numSamples,
            1,
            &timing,
            0,
            nil,
            &sampleBuffer
        )

        guard status == noErr else {
            return nil
        }

        let format: AVAudioFormat = AVAudioFormat(cmAudioFormatDescription: formatDescription!)
        let buffer: AVAudioPCMBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numSamples))!
        buffer.frameLength = buffer.frameCapacity
        let channels = Int(format.channelCount)
        for ch in (0..<channels) {
            let samples = buffer.int16ChannelData![ch]
            for n in 0..<Int(buffer.frameLength) {
                samples[n] = Int16(sinf(Float(2.0 * Double.pi) * 440.0 * Float(n) / Float(sampleRate)) * 16383.0)
            }
        }

        status = CMSampleBufferSetDataBufferFromAudioBufferList(
            sampleBuffer!,
            kCFAllocatorDefault,
            kCFAllocatorDefault,
            0,
            buffer.audioBufferList
        )

        guard status == noErr else {
            return nil
        }

        return sampleBuffer
    }
}
