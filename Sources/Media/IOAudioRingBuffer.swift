import Accelerate
import AVFoundation
import CoreMedia
import Foundation

final class IOAudioRingBuffer {
    private static let bufferCounts: UInt32 = 16
    private static let numSamples: UInt32 = 1024

    var counts: Int {
        if tail <= head {
            return head - tail + skip
        }
        return Int(buffer.frameLength) - tail + head + skip
    }

    private(set) var presentationTimeStamp: CMTime = .zero
    private var head = 0
    private var tail = 0
    private var skip = 0
    private var format: AVAudioFormat
    private var buffer: AVAudioPCMBuffer
    private var workingBuffer: AVAudioPCMBuffer

    init?(_ inSourceFormat: inout AudioStreamBasicDescription, bufferCounts: UInt32 = IOAudioRingBuffer.bufferCounts) {
        guard
            inSourceFormat.mFormatID == kAudioFormatLinearPCM,
            let format = AVAudioFormatFactory.makeAudioFormat(&inSourceFormat),
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

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else {
            return
        }
        if presentationTimeStamp == .zero {
            presentationTimeStamp = sampleBuffer.presentationTimeStamp
        }
        if workingBuffer.frameLength < sampleBuffer.numSamples {
            if let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleBuffer.numSamples)) {
                self.workingBuffer = buffer
            }
        }
        workingBuffer.frameLength = AVAudioFrameCount(sampleBuffer.numSamples)
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(sampleBuffer.numSamples),
            into: workingBuffer.mutableAudioBufferList
        )
        if status == noErr && kLinearPCMFormatFlagIsBigEndian == ((sampleBuffer.formatDescription?.audioStreamBasicDescription?.mFormatFlags ?? 0) & kLinearPCMFormatFlagIsBigEndian) {
            if format.isInterleaved {
                switch format.commonFormat {
                case .pcmFormatInt16:
                    let length = sampleBuffer.dataBuffer?.dataLength ?? 0
                    var image = vImage_Buffer(data: workingBuffer.mutableAudioBufferList[0].mBuffers.mData, height: 1, width: vImagePixelCount(length / 2), rowBytes: length)
                    vImageByteSwap_Planar16U(&image, &image, vImage_Flags(kvImageNoFlags))
                default:
                    break
                }
            }
        }
        skip = numSamples(sampleBuffer)
        appendAudioPCMBuffer(workingBuffer)
    }

    func appendAudioPCMBuffer(_ audioPCMBuffer: AVAudioPCMBuffer, offset: Int = 0) {
        let numSamples = min(Int(audioPCMBuffer.frameLength) - offset, Int(buffer.frameLength) - head)
        if format.isInterleaved {
            let channelCount = Int(format.channelCount)
            switch format.commonFormat {
            case .pcmFormatInt16:
                memcpy(buffer.int16ChannelData?[0].advanced(by: head * channelCount), audioPCMBuffer.int16ChannelData?[0].advanced(by: offset * channelCount), numSamples * channelCount * 2)
            case .pcmFormatInt32:
                memcpy(buffer.int32ChannelData?[0].advanced(by: head * channelCount), audioPCMBuffer.int32ChannelData?[0].advanced(by: offset * channelCount), numSamples * channelCount * 4)
            case .pcmFormatFloat32:
                memcpy(buffer.floatChannelData?[0].advanced(by: head * channelCount), audioPCMBuffer.floatChannelData?[0].advanced(by: offset * channelCount), numSamples * channelCount * 4)
            default:
                break
            }
        } else {
            for i in 0..<Int(format.channelCount) {
                switch format.commonFormat {
                case .pcmFormatInt16:
                    memcpy(buffer.int16ChannelData?[i].advanced(by: head), audioPCMBuffer.int16ChannelData?[i].advanced(by: offset), numSamples * 2)
                case .pcmFormatInt32:
                    memcpy(buffer.int32ChannelData?[i].advanced(by: head), audioPCMBuffer.int32ChannelData?[i].advanced(by: offset), numSamples * 4)
                case .pcmFormatFloat32:
                    memcpy(buffer.floatChannelData?[i].advanced(by: head), audioPCMBuffer.floatChannelData?[i].advanced(by: offset), numSamples * 4)
                default:
                    break
                }
            }
        }
        head += numSamples
        if head == buffer.frameLength {
            head = 0
            if 0 < Int(audioPCMBuffer.frameLength) - numSamples {
                appendAudioPCMBuffer(audioPCMBuffer, offset: numSamples)
            }
        }
    }

    func render(_ inNumberFrames: UInt32, ioData: UnsafeMutablePointer<AudioBufferList>?, offset: Int = 0) -> OSStatus {
        if 0 < skip {
            let numSamples = min(Int(inNumberFrames), skip)
            guard let bufferList = UnsafeMutableAudioBufferListPointer(ioData) else {
                return noErr
            }
            if format.isInterleaved {
                let channelCount = Int(format.channelCount)
                switch format.commonFormat {
                case .pcmFormatInt16:
                    bufferList[0].mData?.assumingMemoryBound(to: Int16.self).advanced(by: offset * channelCount).update(repeating: 0, count: numSamples)
                case .pcmFormatInt32:
                    bufferList[0].mData?.assumingMemoryBound(to: Int32.self).advanced(by: offset * channelCount).update(repeating: 0, count: numSamples)
                case .pcmFormatFloat32:
                    bufferList[0].mData?.assumingMemoryBound(to: Float32.self).advanced(by: offset * channelCount).update(repeating: 0, count: numSamples)
                default:
                    break
                }
            } else {
                for i in 0..<Int(format.channelCount) {
                    switch format.commonFormat {
                    case .pcmFormatInt16:
                        bufferList[i].mData?.assumingMemoryBound(to: Int16.self).advanced(by: offset).update(repeating: 0, count: numSamples)
                    case .pcmFormatInt32:
                        bufferList[i].mData?.assumingMemoryBound(to: Int32.self).advanced(by: offset).update(repeating: 0, count: numSamples)
                    case .pcmFormatFloat32:
                        bufferList[i].mData?.assumingMemoryBound(to: Float32.self).advanced(by: offset).update(repeating: 0, count: numSamples)
                    default:
                        break
                    }
                }
            }
            skip -= numSamples
            presentationTimeStamp = CMTimeAdd(presentationTimeStamp, CMTime(value: CMTimeValue(numSamples), timescale: presentationTimeStamp.timescale))
            if 0 < inNumberFrames - UInt32(numSamples) {
                return render(inNumberFrames - UInt32(numSamples), ioData: ioData, offset: numSamples)
            }
            return noErr
        }
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
                    memcpy(bufferList[i].mData?.advanced(by: offset * 2), buffer.int16ChannelData?[i].advanced(by: tail), numSamples * 2)
                case .pcmFormatInt32:
                    memcpy(bufferList[i].mData?.advanced(by: offset * 4), buffer.int32ChannelData?[i].advanced(by: tail), numSamples * 4)
                case .pcmFormatFloat32:
                    memcpy(bufferList[i].mData?.advanced(by: offset * 4), buffer.floatChannelData?[i].advanced(by: tail), numSamples * 4)
                default:
                    break
                }
            }
        }
        tail += numSamples
        presentationTimeStamp = CMTimeAdd(presentationTimeStamp, CMTime(value: CMTimeValue(numSamples), timescale: presentationTimeStamp.timescale))
        if tail == buffer.frameLength {
            tail = 0
            if 0 < inNumberFrames - UInt32(numSamples) {
                return render(inNumberFrames - UInt32(numSamples), ioData: ioData, offset: numSamples)
            }
        }
        return noErr
    }

    private func numSamples(_ sampleBuffer: CMSampleBuffer) -> Int {
        // Device audioMic or ReplayKit audioMic.
        let sampleRate = Int32(format.sampleRate)
        if presentationTimeStamp.timescale == sampleRate {
            let presentationTimeStamp = CMTimeAdd(presentationTimeStamp, CMTime(value: CMTimeValue(counts), timescale: presentationTimeStamp.timescale))
            return max(Int(sampleBuffer.presentationTimeStamp.value - presentationTimeStamp.value), 0)
        }
        return 0
    }
}
