import CoreMedia
import Foundation

protocol SoundMixerDelegate: class {
    func outputSampleBuffer(_ sampleBuffer:CMSampleBuffer)
}

// MARK: -
class SoundMixer {
    static let defaultSampleSize:Int = 1024
    weak var delegate:SoundMixerDelegate?

    let lockQueue:DispatchQueue = DispatchQueue(label: "com.github.shogo4405.lf.SoundMixer.lock")
    private var duration:CMTime = kCMTimeZero
    private var remainSampleBuffers:[Int:Data] = [:]
    private var presentationTimeStamp:CMTime = kCMTimeZero

    func appendSampleBuffer(_ sampleBuffer:CMSampleBuffer, withChannel:Int) {
        lockQueue.async {
            self._appendSampleBuffer(sampleBuffer, withChannel: withChannel)
        }
    }

    private func _appendSampleBuffer(_ sampleBuffer:CMSampleBuffer, withChannel:Int) {
        if (presentationTimeStamp == kCMTimeZero) {
            duration = CMTime(value: CMTimeValue(SoundMixer.defaultSampleSize), timescale: 44100)
            presentationTimeStamp = sampleBuffer.presentationTimeStamp
        }

        var blockBuffer:CMBlockBuffer? = nil
        let currentBufferList:UnsafeMutableAudioBufferListPointer = AudioBufferList.allocate(maximumBuffers: 1)
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            nil,
            currentBufferList.unsafeMutablePointer,
            AudioBufferList.sizeInBytes(maximumBuffers: 1),
            nil,
            nil,
            0,
            &blockBuffer
        )

        let frameSize:Int = SoundMixer.defaultSampleSize * 2

        var step:Int = 0
        if let data:Data = remainSampleBuffers[withChannel] {
            let buffer:UnsafeMutableAudioBufferListPointer = AudioBufferList.allocate(maximumBuffers: 1)
            buffer.unsafeMutablePointer.pointee.mNumberBuffers = 1
            buffer.unsafeMutablePointer.pointee.mBuffers.mData = malloc(frameSize)
            buffer.unsafeMutablePointer.pointee.mBuffers.mDataByteSize = UInt32(frameSize)
            let pointer:UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>(OpaquePointer(buffer.unsafeMutablePointer.pointee.mBuffers.mData!))
            data.copyBytes(to: pointer, count: data.count)
            step = 2048 - data.count
            print(step)
            memcpy(buffer.unsafeMutablePointer.pointee.mBuffers.mData!.advanced(by: data.count), currentBufferList.unsafePointer.pointee.mBuffers.mData!.advanced(by: step), step)
            var result:CMSampleBuffer?
            var timing:CMSampleTimingInfo = CMSampleTimingInfo(
                duration: duration,
                presentationTimeStamp: presentationTimeStamp,
                decodeTimeStamp: kCMTimeInvalid
            )
            CMSampleBufferCreate(kCFAllocatorDefault, nil, false, nil, nil, sampleBuffer.formatDescription, SoundMixer.defaultSampleSize, 1, &timing, 0, nil, &result)
            CMSampleBufferSetDataBufferFromAudioBufferList(result!, kCFAllocatorDefault, kCFAllocatorDefault, 0, buffer.unsafePointer)
            delegate?.outputSampleBuffer(sampleBuffer)
            presentationTimeStamp = CMTimeAdd(presentationTimeStamp, duration)
        }

        let length:Int = Int(currentBufferList.unsafePointer.pointee.mBuffers.mDataByteSize) - step
        for i in 0..<Int(floor(Double(length) / Double(frameSize))) {
            let buffer:UnsafeMutableAudioBufferListPointer = AudioBufferList.allocate(maximumBuffers: 1)
            buffer.unsafeMutablePointer.pointee.mNumberBuffers = 1
            buffer.unsafeMutablePointer.pointee.mBuffers.mData = malloc(frameSize)
            memcpy(buffer.unsafeMutablePointer.pointee.mBuffers.mData, currentBufferList.unsafePointer.pointee.mBuffers.mData!.advanced(by: step + frameSize * i), frameSize)
            buffer.unsafeMutablePointer.pointee.mBuffers.mDataByteSize = UInt32(frameSize)
            var result:CMSampleBuffer?
            var timing:CMSampleTimingInfo = CMSampleTimingInfo(
                duration: duration,
                presentationTimeStamp: presentationTimeStamp,
                decodeTimeStamp: kCMTimeInvalid
            )
            CMSampleBufferCreate(kCFAllocatorDefault, nil, false, nil, nil, sampleBuffer.formatDescription, SoundMixer.defaultSampleSize, 1, &timing, 0, nil, &result)
            CMSampleBufferSetDataBufferFromAudioBufferList(result!, kCFAllocatorDefault, kCFAllocatorDefault, 0, buffer.unsafePointer)
            delegate?.outputSampleBuffer(sampleBuffer)
            free(buffer.unsafeMutablePointer.pointee.mBuffers.mData)
            presentationTimeStamp = CMTimeAdd(presentationTimeStamp, duration)
        }

        let remain:Int = length % frameSize
        remainSampleBuffers[withChannel] = Data(bytes: currentBufferList.unsafePointer.pointee.mBuffers.mData!.advanced(by: length - remain), count: remain)
    }
}
