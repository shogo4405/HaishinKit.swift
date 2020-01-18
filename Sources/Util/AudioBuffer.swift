import AVFoundation
import Foundation

final class AudioBuffer {
    enum AudioBufferError: Error {
        case notReady
    }

    static let numSamples = 1024

    let input: UnsafeMutableAudioBufferListPointer

    var isReady: Bool {
        numSamples == index
    }

    var maxLength: Int {
        numSamples * bytesPerFrame
    }

    let listSize: Int

    private var index = 0
    private var buffers: [Data]
    private let numSamples: Int
    private let bytesPerFrame: Int
    private let maximumBuffers: Int
    private(set) var presentationTimeStamp: CMTime = .invalid

    deinit {
        input.unsafeMutablePointer.deallocate()
    }

    init(_ inSourceFormat: AudioStreamBasicDescription, numSamples: Int = AudioBuffer.numSamples) {
        let nonInterleaved = inSourceFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0
        self.numSamples = nonInterleaved ? numSamples / 2 : numSamples
        bytesPerFrame = Int(inSourceFormat.mBytesPerFrame)
        maximumBuffers = nonInterleaved ? Int(inSourceFormat.mChannelsPerFrame) : 1
        listSize = AudioBufferList.sizeInBytes(maximumBuffers: maximumBuffers)
        buffers = .init(repeating: .init(repeating: 0, count: self.numSamples * bytesPerFrame), count: maximumBuffers)
        input = AudioBufferList.allocate(maximumBuffers: maximumBuffers)
        input.unsafeMutablePointer.pointee.mNumberBuffers = UInt32(maximumBuffers)
        for i in 0..<maximumBuffers {
            input[i].mNumberChannels = nonInterleaved ? 1 : inSourceFormat.mChannelsPerFrame
            input[i].mDataByteSize = UInt32(buffers[i].count)
            buffers[i].withUnsafeMutableBytes { pointer in
                input[i].mData = pointer.baseAddress
            }
        }
    }

    func write(_ sampleBuffer: CMSampleBuffer, offset: Int) throws -> Int {
        guard let data = sampleBuffer.dataBuffer?.data, !isReady else {
            throw AudioBufferError.notReady
        }
        if presentationTimeStamp == .invalid {
            let offsetTimeStamp: CMTime = offset == 0 ? .zero : CMTime(value: CMTimeValue(offset), timescale: sampleBuffer.presentationTimeStamp.timescale)
            presentationTimeStamp = CMTimeAdd(sampleBuffer.presentationTimeStamp, offsetTimeStamp)
        }
        let numSamples = min(self.numSamples - index, sampleBuffer.numSamples - offset)
        for i in 0..<maximumBuffers {
            buffers[i].replaceSubrange(index * bytesPerFrame..<index * bytesPerFrame + numSamples * bytesPerFrame, with: data.advanced(by: offset * bytesPerFrame + numSamples * bytesPerFrame * i))
        }
        index += numSamples
        return numSamples
    }

    func muted() {
        for i in 0..<maximumBuffers {
            buffers[i].resetBytes(in: 0...)
        }
    }

    func clear() {
        presentationTimeStamp = .invalid
        index = 0
    }
}

extension AudioBuffer: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}
