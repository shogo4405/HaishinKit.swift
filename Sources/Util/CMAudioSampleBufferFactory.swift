import CoreMedia
import Foundation

enum CMAudioSampleBufferFactory {
    static func makeSampleBuffer(_ buffer: CMSampleBuffer, numSamples: Int, presentationTimeStamp: CMTime) -> CMSampleBuffer? {
        guard 0 < numSamples, let formatDescription = buffer.formatDescription, let streamBasicDescription = formatDescription.streamBasicDescription else {
            return nil
        }
        var status: OSStatus = noErr
        var blockBuffer: CMBlockBuffer?
        let blockSize = numSamples * Int(streamBasicDescription.pointee.mBytesPerPacket)
        status = CMBlockBufferCreateWithMemoryBlock(
            allocator: nil,
            memoryBlock: nil,
            blockLength: blockSize,
            blockAllocator: nil,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: blockSize,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard let blockBuffer, status == noErr else {
            return nil
        }
        status = CMBlockBufferFillDataBytes(
            with: 0,
            blockBuffer: blockBuffer,
            offsetIntoDestination: 0,
            dataLength: blockSize
        )
        guard status == noErr else {
            return nil
        }
        var sampleBuffer: CMSampleBuffer?
        status = CMAudioSampleBufferCreateWithPacketDescriptions(
            allocator: nil,
            dataBuffer: blockBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleCount: numSamples,
            presentationTimeStamp: presentationTimeStamp,
            packetDescriptions: nil,
            sampleBufferOut: &sampleBuffer
        )
        guard let sampleBuffer, status == noErr else {
            return nil
        }
        return sampleBuffer
    }
}
