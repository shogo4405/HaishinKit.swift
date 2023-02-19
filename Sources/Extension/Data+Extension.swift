import CoreMedia
import Foundation

extension Data {
    var bytes: [UInt8] {
        withUnsafeBytes {
            guard let pointer = $0.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return []
            }
            return [UInt8](UnsafeBufferPointer(start: pointer, count: count))
        }
    }

    func makeBlockBuffer(advancedBy: Int = 0) -> CMBlockBuffer? {
        var blockBuffer: CMBlockBuffer?
        let length = count - advancedBy
        return withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> CMBlockBuffer? in
            guard let baseAddress = buffer.baseAddress else {
                return nil
            }
            guard CMBlockBufferCreateWithMemoryBlock(
                    allocator: kCFAllocatorDefault,
                    memoryBlock: nil,
                    blockLength: length,
                    blockAllocator: nil,
                    customBlockSource: nil,
                    offsetToData: 0,
                    dataLength: length,
                    flags: 0,
                    blockBufferOut: &blockBuffer) == noErr else {
                return nil
            }
            guard let blockBuffer else {
                return nil
            }
            guard CMBlockBufferReplaceDataBytes(
                    with: baseAddress.advanced(by: advancedBy),
                    blockBuffer: blockBuffer,
                    offsetIntoDestination: 0,
                    dataLength: length) == noErr else {
                return nil
            }
            return blockBuffer
        }
    }
}
