import Accelerate
import AVFoundation
import Foundation

final class AudioCodecRingBuffer {
    enum Error: Swift.Error {
        case isReady
        case noBlockBuffer
    }

    static let numSamples: UInt32 = 1024
    static let maxBuffers: Int = 6

    var isReady: Bool {
        numSamples == index
    }

    var current: AVAudioPCMBuffer {
        return buffers[cursor]
    }

    private(set) var presentationTimeStamp: CMTime = .invalid
    private var index: Int = 0
    private var numSamples: Int
    private var format: AVAudioFormat
    private var buffers: [AVAudioPCMBuffer] = []
    private var cursor: Int = 0
    private var workingBuffer: AVAudioPCMBuffer
    private var maxBuffers: Int = AudioCodecRingBuffer.maxBuffers

    init?(_ inSourceFormat: inout AudioStreamBasicDescription, numSamples: UInt32 = AudioCodecRingBuffer.numSamples) {
        guard
            inSourceFormat.mFormatID == kAudioFormatLinearPCM,
            let format = AudioCodec.makeAudioFormat(&inSourceFormat),
            let workingBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: numSamples) else {
            return nil
        }
        for _ in 0..<maxBuffers {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: numSamples) else {
                return nil
            }
            buffer.frameLength = numSamples
            self.buffers.append(buffer)
        }
        self.format = format
        self.workingBuffer = workingBuffer
        self.numSamples = Int(numSamples)
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, offset: Int) -> Int {
        if isReady {
            return -1
        }
        if presentationTimeStamp == .invalid {
            let offsetTimeStamp: CMTime = offset == 0 ? .zero : CMTime(value: CMTimeValue(offset), timescale: sampleBuffer.presentationTimeStamp.timescale)
            presentationTimeStamp = CMTimeAdd(sampleBuffer.presentationTimeStamp, offsetTimeStamp)
        }
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
            if kLinearPCMFormatFlagIsBigEndian == ((sampleBuffer.formatDescription?.audioStreamBasicDescription?.mFormatFlags ?? 0) & kLinearPCMFormatFlagIsBigEndian) {
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
        }
        let numSamples = min(self.numSamples - index, Int(sampleBuffer.numSamples) - offset)
        if format.isInterleaved {
            let channelCount = Int(format.channelCount)
            switch format.commonFormat {
            case .pcmFormatInt16:
                memcpy(current.int16ChannelData?[0].advanced(by: index * channelCount), workingBuffer.int16ChannelData?[0].advanced(by: offset * channelCount), numSamples * 2 * channelCount)
            case .pcmFormatInt32:
                memcpy(current.int32ChannelData?[0].advanced(by: index * channelCount), workingBuffer.int32ChannelData?[0].advanced(by: offset * channelCount), numSamples * 4 * channelCount)
            case .pcmFormatFloat32:
                memcpy(current.floatChannelData?[0].advanced(by: index * channelCount), workingBuffer.floatChannelData?[0].advanced(by: offset * channelCount), numSamples * 4 * channelCount)
            default:
                break
            }
        } else {
            for i in 0..<Int(format.channelCount) {
                switch format.commonFormat {
                case .pcmFormatInt16:
                    memcpy(current.int16ChannelData?[i].advanced(by: index), workingBuffer.int16ChannelData?[i].advanced(by: offset), numSamples * 2)
                case .pcmFormatInt32:
                    memcpy(current.int32ChannelData?[i].advanced(by: index), workingBuffer.int32ChannelData?[i].advanced(by: offset), numSamples * 4)
                case .pcmFormatFloat32:
                    memcpy(current.floatChannelData?[i].advanced(by: index), workingBuffer.floatChannelData?[i].advanced(by: offset), numSamples * 4)
                default:
                    break
                }
            }
        }
        index += numSamples

        return numSamples
    }

    func next() {
        presentationTimeStamp = .invalid
        index = 0
        cursor += 1
        if cursor == buffers.count {
            cursor = 0
        }
    }
}

extension AudioCodecRingBuffer: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}
