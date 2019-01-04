import AVFoundation

public protocol SoundSpliterDelegate: class {
    func outputSampleBuffer(_ sampleBuffer: CMSampleBuffer)
}

// MARK: -
public class SoundSpliter: NSObject {
    static let defaultSampleSize: Int = 1024
    public weak var delegate: SoundSpliterDelegate?

    private let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.SoundMixer.lock")
    private(set) var status: OSStatus = noErr {
        didSet {
            if status != 0 {
                logger.warn("\(self.status)")
            }
        }
    }
    private var frameSize: Int = 2048
    private var duration = CMTime.zero
    private var sampleData = Data()
    private var formatDescription: CMFormatDescription?
    private var presentationTimeStamp = CMTime.zero

    private var minimumByteSize: Int {
        return min(.max, sampleData.count)
    }

    public func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        if presentationTimeStamp == CMTime.zero {
            duration = CMTime(value: 1, timescale: 44100)
            formatDescription = sampleBuffer.formatDescription
            presentationTimeStamp = sampleBuffer.presentationTimeStamp
        }

        var blockBuffer: CMBlockBuffer?
        let audioBufferList: UnsafeMutableAudioBufferListPointer = AudioBufferList.allocate(maximumBuffers: 1)
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: audioBufferList.unsafeMutablePointer,
            bufferListSize: AudioBufferList.sizeInBytes(maximumBuffers: 1),
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        if let mData: UnsafeMutableRawPointer = audioBufferList.unsafePointer.pointee.mBuffers.mData {
            sampleData.append(
                mData.assumingMemoryBound(to: UInt8.self),
                count: Int(audioBufferList.unsafePointer.pointee.mBuffers.mDataByteSize)
            )
        }

        lockQueue.async {
            self.split()
        }
    }

    func split() {
        guard frameSize < self.minimumByteSize else {
            return
        }

        let minimumByteSize: Int = self.minimumByteSize
        let remain: Int = minimumByteSize % frameSize
        let length: Int = minimumByteSize - remain
        let sampleData: Data = self.sampleData

        self.sampleData.removeAll()
        self.sampleData.append(sampleData.subdata(in: length..<sampleData.count))

        let data: Data = sampleData.subdata(in: 0..<length)
        for i in 0..<data.count / frameSize {
            let wave: Data = data.subdata(in: i * frameSize..<(i * frameSize) + frameSize)
            var result: CMSampleBuffer?
            let buffer: UnsafeMutableAudioBufferListPointer = AudioBufferList.allocate(maximumBuffers: 1)
            var timing = CMSampleTimingInfo(
                duration: duration,
                presentationTimeStamp: presentationTimeStamp,
                decodeTimeStamp: CMTime.invalid
            )
            buffer.unsafeMutablePointer.pointee.mNumberBuffers = 1
            buffer.unsafeMutablePointer.pointee.mBuffers.mNumberChannels = 1
            buffer.unsafeMutablePointer.pointee.mBuffers.mDataByteSize = UInt32(frameSize)
            buffer.unsafeMutablePointer.pointee.mBuffers.mData = UnsafeMutableRawPointer.allocate(byteCount: frameSize, alignment: 0)
            wave.copyBytes(
                to: buffer.unsafeMutablePointer.pointee.mBuffers.mData!.assumingMemoryBound(to: UInt8.self),
                count: Int(buffer.unsafeMutablePointer.pointee.mBuffers.mDataByteSize)
            )
            status = CMSampleBufferCreate(allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: false, makeDataReadyCallback: nil, refcon: nil, formatDescription: formatDescription!, sampleCount: SoundSpliter.defaultSampleSize, sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &result)
            if let result: CMSampleBuffer = result {
                status = CMSampleBufferSetDataBufferFromAudioBufferList(
                    result,
                    blockBufferAllocator: kCFAllocatorDefault,
                    blockBufferMemoryAllocator: kCFAllocatorDefault,
                    flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                    bufferList: buffer.unsafePointer
                )
                if status == 0 {
                    delegate?.outputSampleBuffer(result)
                }
                presentationTimeStamp = CMTimeAdd(presentationTimeStamp, result.duration)
            }
            buffer.unsafeMutablePointer.pointee.mBuffers.mData?.deallocate()
        }
    }

    public func clear() {
        sampleData.removeAll()
    }
}
