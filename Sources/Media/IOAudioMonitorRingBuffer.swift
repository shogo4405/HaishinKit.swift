import AVFoundation
import CoreMedia
import Foundation

class IOAudioMonitorRingBuffer {
    private static let bufferCounts: UInt32 = 16
    private static let numSamples: UInt32 = 1024

    private var head = 0
    private var tail = 0
    private var format: AVAudioFormat
    private var buffer: AVAudioPCMBuffer
    private var workingBuffer: AVAudioPCMBuffer

    init?(_ inSourceFormat: inout AudioStreamBasicDescription, bufferCounts: UInt32 = IOAudioMonitorRingBuffer.bufferCounts) {
        guard
            inSourceFormat.mFormatID == kAudioFormatLinearPCM,
            let format = AudioCodec.makeAudioFormat(&inSourceFormat),
            let workingBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: Self.numSamples) else {
            return nil
        }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: Self.numSamples * bufferCounts) else {
            return nil
        }
        self.format = format
        self.buffer = buffer
        self.buffer.frameLength = self.buffer.frameCapacity
        self.workingBuffer = workingBuffer
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, offset: Int = 0) {
        let numSamples = min(sampleBuffer.numSamples, Int(buffer.frameLength) - head)
        if offset == 0 {
            if workingBuffer.frameLength < sampleBuffer.numSamples {
                if let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleBuffer.numSamples)) {
                    self.workingBuffer = buffer
                }
            }
            workingBuffer.frameLength = AVAudioFrameCount(sampleBuffer.numSamples)
            CMSampleBufferCopyPCMDataIntoAudioBufferList(
                sampleBuffer,
                at: 0,
                frameCount: Int32(sampleBuffer.numSamples),
                into: workingBuffer.mutableAudioBufferList
            )
        }
        if format.isInterleaved {
            let channelCount = Int(format.channelCount)
            switch format.commonFormat {
            case .pcmFormatInt16:
                memcpy(buffer.int16ChannelData?[0].advanced(by: head * channelCount), workingBuffer.int16ChannelData?[0].advanced(by: offset * channelCount), numSamples * channelCount * 2)
            case .pcmFormatInt32:
                memcpy(buffer.int32ChannelData?[0].advanced(by: head * channelCount), workingBuffer.int32ChannelData?[0].advanced(by: offset * channelCount), numSamples * channelCount * 4)
            case .pcmFormatFloat32:
                memcpy(buffer.floatChannelData?[0].advanced(by: head * channelCount), workingBuffer.floatChannelData?[0].advanced(by: offset * channelCount), numSamples * channelCount * 4)
            default:
                break
            }
        } else {
            for i in 0..<Int(format.channelCount) {
                switch format.commonFormat {
                case .pcmFormatInt16:
                    memcpy(buffer.int16ChannelData?[i].advanced(by: head), workingBuffer.int16ChannelData?[i].advanced(by: offset), numSamples * 2)
                case .pcmFormatInt32:
                    memcpy(buffer.int32ChannelData?[i].advanced(by: head), workingBuffer.int32ChannelData?[i].advanced(by: offset), numSamples * 4)
                case .pcmFormatFloat32:
                    memcpy(buffer.floatChannelData?[i].advanced(by: head), workingBuffer.floatChannelData?[i].advanced(by: offset), numSamples * 4)
                default:
                    break
                }
            }
        }
        head += numSamples
        if head == buffer.frameLength {
            head = 0
            if 0 < sampleBuffer.numSamples - numSamples {
                appendSampleBuffer(sampleBuffer, offset: numSamples)
            }
        }
    }

    func render(_ inNumberFrames: UInt32, ioData: UnsafeMutablePointer<AudioBufferList>?, offset: Int = 0) -> OSStatus {
        let numSamples = min(Int(inNumberFrames), Int(buffer.frameLength) - tail)
        guard let bufferList = UnsafeMutableAudioBufferListPointer(ioData), head != tail else {
            return noErr
        }
        if format.isInterleaved {
            let channelCount = Int(format.channelCount)
            switch format.commonFormat {
            case .pcmFormatInt16:
                memcpy(bufferList[0].mData?.advanced(by: offset * channelCount * 2), buffer.int16ChannelData?[0].advanced(by: tail * channelCount), numSamples * channelCount * 2)
            case .pcmFormatInt32:
                memcpy(bufferList[0].mData?.advanced(by: offset * channelCount * 4), buffer.int32ChannelData?[0].advanced(by: tail * channelCount), numSamples * channelCount * 4)
            case .pcmFormatFloat32:
                memcpy(bufferList[0].mData?.advanced(by: offset * channelCount * 4), buffer.floatChannelData?[0].advanced(by: tail * channelCount), numSamples * channelCount * 4)
            default:
                break
            }
        } else {
            for i in 0..<Int(format.channelCount) {
                switch format.commonFormat {
                case .pcmFormatInt16:
                    memcpy(bufferList[i].mData?.advanced(by: offset * 2), buffer.int16ChannelData?[i], numSamples * 2)
                case .pcmFormatInt32:
                    memcpy(bufferList[i].mData?.advanced(by: offset * 4), buffer.int32ChannelData?[i], numSamples * 4)
                case .pcmFormatFloat32:
                    memcpy(bufferList[i].mData?.advanced(by: offset * 4), buffer.floatChannelData?[i], numSamples * 4)
                default:
                    break
                }
            }
        }
        tail += numSamples + offset
        if offset == 0 && numSamples != inNumberFrames {
            tail = 0
            return render(inNumberFrames - UInt32(numSamples), ioData: ioData, offset: numSamples)
        }
        return noErr
    }

    func clear() {
        let numSamples = Int(buffer.frameLength)
        if format.isInterleaved {
            let channelCount = Int(format.channelCount)
            switch format.commonFormat {
            case .pcmFormatInt16:
                buffer.int16ChannelData?[0].assign(repeating: 0, count: numSamples * channelCount)
            case .pcmFormatInt32:
                buffer.int32ChannelData?[0].assign(repeating: 0, count: numSamples * channelCount)
            case .pcmFormatFloat32:
                buffer.floatChannelData?[0].assign(repeating: 0, count: numSamples * channelCount)
            default:
                break
            }
        } else {
            for i in 0..<Int(format.channelCount) {
                switch format.commonFormat {
                case .pcmFormatInt16:
                    buffer.int16ChannelData?[i].assign(repeating: 0, count: numSamples)
                case .pcmFormatInt32:
                    buffer.int32ChannelData?[i].assign(repeating: 0, count: numSamples)
                case .pcmFormatFloat32:
                    buffer.floatChannelData?[i].assign(repeating: 0, count: numSamples)
                default:
                    break
                }
            }
        }
        head = 0
        tail = 0
    }
}
