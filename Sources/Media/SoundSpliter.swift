import CoreMedia
import Foundation

public protocol SoundSpliterDelegate: class {
    func outputSampleBuffer(_ sampleBuffer:CMSampleBuffer)
}

// MARK: -
public class SoundSpliter: NSObject {
    static let defaultSampleSize:Int = 1024
    public weak var delegate:SoundSpliterDelegate?

    private let lockQueue:DispatchQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.SoundMixer.lock")
    private(set) var status:OSStatus = noErr {
        didSet {
            if (status != 0) {
                logger.warn("\(self.status)")
            }
        }
    }
    private var frameSize:Int = 2048
    private var duration:CMTime = kCMTimeZero
    private var sampleData:Data = Data()
    private var formatDescription:CMFormatDescription?
    private var presentationTimeStamp:CMTime = kCMTimeZero

    private var minimumByteSize:Int {
        return min(Int.max, sampleData.count)
    }

    public func appendSampleBuffer(_ sampleBuffer:CMSampleBuffer) {
        if (presentationTimeStamp == kCMTimeZero) {
            duration = CMTime(value: 1, timescale: 44100)
            formatDescription = sampleBuffer.formatDescription
            presentationTimeStamp = sampleBuffer.presentationTimeStamp
        }

        var blockBuffer:CMBlockBuffer? = nil
        let audioBufferList:UnsafeMutableAudioBufferListPointer = AudioBufferList.allocate(maximumBuffers: 1)
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            nil,
            audioBufferList.unsafeMutablePointer,
            AudioBufferList.sizeInBytes(maximumBuffers: 1),
            nil,
            nil,
            0,
            &blockBuffer
        )

        if let mData:UnsafeMutableRawPointer = audioBufferList.unsafePointer.pointee.mBuffers.mData {
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

        let minimumByteSize:Int = self.minimumByteSize
        let remain:Int = minimumByteSize % frameSize
        let length:Int = minimumByteSize - remain
        let sampleData:Data = self.sampleData

        self.sampleData.removeAll()
        self.sampleData.append(sampleData.subdata(in: length..<sampleData.count))

        let data:Data = sampleData.subdata(in: 0..<length)
        for i in 0..<data.count / frameSize {
            let wave:Data = data.subdata(in: i * frameSize..<(i * frameSize) + frameSize)
            var result:CMSampleBuffer?
            let buffer:UnsafeMutableAudioBufferListPointer = AudioBufferList.allocate(maximumBuffers: 1)
            var timing:CMSampleTimingInfo = CMSampleTimingInfo(
                duration: duration,
                presentationTimeStamp: presentationTimeStamp,
                decodeTimeStamp: kCMTimeInvalid
            )
            buffer.unsafeMutablePointer.pointee.mNumberBuffers = 1
            buffer.unsafeMutablePointer.pointee.mBuffers.mNumberChannels = 1
            buffer.unsafeMutablePointer.pointee.mBuffers.mDataByteSize = UInt32(frameSize)
            buffer.unsafeMutablePointer.pointee.mBuffers.mData = UnsafeMutableRawPointer.allocate(bytes: frameSize, alignedTo: 0)
            wave.copyBytes(
                to: buffer.unsafeMutablePointer.pointee.mBuffers.mData!.assumingMemoryBound(to: UInt8.self),
                count: Int(buffer.unsafeMutablePointer.pointee.mBuffers.mDataByteSize)
            )
            status = CMSampleBufferCreate(kCFAllocatorDefault, nil, false, nil, nil, formatDescription!, SoundSpliter.defaultSampleSize, 1, &timing, 0, nil, &result)
            if let result:CMSampleBuffer = result {
                status = CMSampleBufferSetDataBufferFromAudioBufferList(
                    result,
                    kCFAllocatorDefault,
                    kCFAllocatorDefault,
                    kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                    buffer.unsafePointer
                )
                if (status == 0) {
                    delegate?.outputSampleBuffer(result)
                }
                presentationTimeStamp = CMTimeAdd(presentationTimeStamp, result.duration)
            }
            buffer.unsafeMutablePointer.pointee.mBuffers.mData?.deallocate(bytes: frameSize, alignedTo: 0)
        }
    }

    public func clear() {
        sampleData.removeAll()
    }
}
