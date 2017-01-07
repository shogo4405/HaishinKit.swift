import CoreMedia
import Foundation

protocol SoundMixerDelegate: class {
    func outputSampleBuffer(_ sampleBuffer:CMSampleBuffer)
}

// MARK: -
class SoundMixer {
    static let defaultSampleSize:Int = 1024
    weak var delegate:SoundMixerDelegate?

    private let lockQueue:DispatchQueue = DispatchQueue(label: "com.github.shogo4405.lf.SoundMixer.lock")
    private(set) var status:OSStatus = noErr {
        didSet {
            if (status != 0) {
                logger.warning("\(self.status)")
            }
        }
    }
    private var frameSize:Int = 2048
    private var duration:CMTime = kCMTimeZero
    private var sampleDatas:[Int:Data] = [:]
    private var expectCounts:Int = 2
    private var formatDescription:CMFormatDescription?
    private var formatDescriptions:[Int:CMFormatDescription] = [:]
    private var presentationTimeStamp:CMTime = kCMTimeZero

    private var minimumByteSize:Int {
        var byteSize:Int = Int.max
        for data:Data in sampleDatas.values {
            if (data.count < byteSize) {
                byteSize = data.count
            }
        }
        return byteSize
    }

    func appendSampleBuffer(_ sampleBuffer:CMSampleBuffer, withChannel:Int) {
        if (withChannel == 0 && presentationTimeStamp == kCMTimeZero) {
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

        formatDescriptions[withChannel] = sampleBuffer.formatDescription
        if let mData:UnsafeMutableRawPointer = audioBufferList.unsafePointer.pointee.mBuffers.mData {
            if (sampleDatas[withChannel] == nil) {
                sampleDatas[withChannel] = Data()
            }
            sampleDatas[withChannel]?.append(
                mData.assumingMemoryBound(to: UInt8.self),
                count: Int(audioBufferList.unsafePointer.pointee.mBuffers.mDataByteSize)
            )
        }

        lockQueue.async {
            self.doMixing()
        }
    }

    func doMixing() {
        guard expectCounts == sampleDatas.count, frameSize < self.minimumByteSize else {
            return
        }

        let minimumByteSize:Int = self.minimumByteSize
        let remain:Int = minimumByteSize % frameSize
        let length:Int = minimumByteSize - remain

        var buffers:[[Int16]] = []
        for (key, value) in sampleDatas {
            buffers.append(value.subdata(in: 0..<length).toArray(type: Int16.self))
            sampleDatas[key]?.removeAll()
            sampleDatas[key]?.append(value.subdata(in: length..<value.count))
        }

        var buffer32:[Int32] = [Int32](repeating: 0, count: length / 2)
        for i in 0..<buffers.count {
            guard let asbd:AudioStreamBasicDescription = formatDescriptions[i]?.streamBasicDescription?.pointee else {
                continue
            }
            for j in 0..<buffer32.count {
                if (asbd.mFormatFlags & kAudioFormatFlagIsBigEndian != 0) {
                    buffer32[j] += Int32(buffers[i][j])
                } else {
                    buffer32[j] += Int32(buffers[i][j].bigEndian)
                }
            }
        }

        var buffer16:[Int16] = [Int16](repeating: 0, count: buffer32.count)
        for i in 0..<buffer16.count {
            if (Int32(Int16.max) < buffer32[i]) {
                buffer32[i] = Int32(Int16.max)
            }
            if (buffer32[i] < Int32(Int16.min)) {
                buffer32[i] = Int32(Int16.min)
            }
            buffer16[i] = Int16(buffer32[i])
        }

        let data:Data = Data(fromArray: buffer16)
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
            status = CMSampleBufferCreate(kCFAllocatorDefault, nil, false, nil, nil, formatDescription!, SoundMixer.defaultSampleSize, 1, &timing, 0, nil, &result)
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
}
