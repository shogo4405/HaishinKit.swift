import AVFoundation
import Foundation

extension AudioCodec {
    final class AudioBuffer {
        // swiftlint:disable nesting
        enum Error: Swift.Error {
            case isReady
            case noBlockBuffer
        }

        static let numSamples = 1024

        let input: UnsafeMutableAudioBufferListPointer

        var isReady: Bool {
            numSamples == index
        }

        var maxLength: Int {
            numSamples * bytesPerFrame * numberChannels * maximumBuffers
        }

        let listSize: Int

        private var index = 0
        private var buffers: [Data]
        private var numSamples: Int
        private let bytesPerFrame: Int
        private let maximumBuffers: Int
        private let numberChannels: Int
        private let bufferList: UnsafeMutableAudioBufferListPointer
        private(set) var presentationTimeStamp: CMTime = .invalid

        deinit {
            input.unsafeMutablePointer.deallocate()
            bufferList.unsafeMutablePointer.deallocate()
        }

        init(_ inSourceFormat: AudioStreamBasicDescription, numSamples: Int = AudioBuffer.numSamples) {
            self.numSamples = numSamples
            let nonInterleaved = inSourceFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0
            bytesPerFrame = Int(inSourceFormat.mBytesPerFrame)
            maximumBuffers = nonInterleaved ? Int(inSourceFormat.mChannelsPerFrame) : 1
            listSize = AudioBufferList.sizeInBytes(maximumBuffers: maximumBuffers)
            input = AudioBufferList.allocate(maximumBuffers: maximumBuffers)
            bufferList = AudioBufferList.allocate(maximumBuffers: maximumBuffers)
            numberChannels = nonInterleaved ? 1 : Int(inSourceFormat.mChannelsPerFrame)
            let dataByteSize = numSamples * bytesPerFrame
            buffers = .init(repeating: .init(repeating: 0, count: numSamples * bytesPerFrame), count: maximumBuffers)
            input.unsafeMutablePointer.pointee.mNumberBuffers = UInt32(maximumBuffers)
            for i in 0..<maximumBuffers {
                input[i].mNumberChannels = UInt32(numberChannels)
                buffers[i].withUnsafeMutableBytes { pointer in
                    input[i].mData = pointer.baseAddress
                }
                input[i].mDataByteSize = UInt32(dataByteSize)
            }
        }

        func write(_ bytes: UnsafeMutableRawPointer?, count: Int, presentationTimeStamp: CMTime) {
            numSamples = count
            index = count
            input.unsafeMutablePointer.pointee.mBuffers.mNumberChannels = 1
            input.unsafeMutablePointer.pointee.mBuffers.mData = bytes
            input.unsafeMutablePointer.pointee.mBuffers.mDataByteSize = UInt32(count)
        }

        func write(_ sampleBuffer: CMSampleBuffer, offset: Int) throws -> Int {
            guard !isReady else {
                throw Error.isReady
            }

            if presentationTimeStamp == .invalid {
                let offsetTimeStamp: CMTime = offset == 0 ? .zero : CMTime(value: CMTimeValue(offset), timescale: sampleBuffer.presentationTimeStamp.timescale)
                presentationTimeStamp = CMTimeAdd(sampleBuffer.presentationTimeStamp, offsetTimeStamp)
            }

            var blockBuffer: CMBlockBuffer?
            CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
                sampleBuffer,
                bufferListSizeNeededOut: nil,
                bufferListOut: bufferList.unsafeMutablePointer,
                bufferListSize: listSize,
                blockBufferAllocator: kCFAllocatorDefault,
                blockBufferMemoryAllocator: kCFAllocatorDefault,
                flags: 0,
                blockBufferOut: &blockBuffer
            )

            guard blockBuffer != nil else {
                throw Error.noBlockBuffer
            }

            let numSamples = min(self.numSamples - index, sampleBuffer.numSamples - offset)
            for i in 0..<maximumBuffers {
                guard let data = bufferList[i].mData else {
                    continue
                }
                buffers[i].replaceSubrange(
                    index * bytesPerFrame..<index * bytesPerFrame + numSamples * bytesPerFrame,
                    with: data.advanced(by: offset * bytesPerFrame),
                    count: numSamples * bytesPerFrame
                )
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
}

extension AudioCodec.AudioBuffer: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}
