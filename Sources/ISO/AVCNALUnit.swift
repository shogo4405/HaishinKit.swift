import CoreMedia
import Foundation

enum AVCNALUnitType: UInt8, Equatable {
    case unspec = 0
    case slice = 1 // P frame
    case dpa = 2
    case dpb = 3
    case dpc = 4
    case idr = 5 // I frame
    case sei = 6
    case sps = 7
    case pps = 8
    case aud = 9
    case eoseq = 10
    case eostream = 11
    case fill = 12
}

// MARK: -
struct AVCNALUnit: NALUnit, Equatable {
    let refIdc: UInt8
    let type: AVCNALUnitType
    let payload: Data

    init(_ data: Data) {
        self.init(data, length: data.count)
    }

    init(_ data: Data, length: Int) {
        self.refIdc = data[0] >> 5
        self.type = AVCNALUnitType(rawValue: data[0] & 0x1f) ?? .unspec
        self.payload = data.subdata(in: 1..<length)
    }

    var data: Data {
        var result = Data()
        result.append(refIdc << 5 | self.type.rawValue)
        result.append(payload)
        return result
    }
}

extension [AVCNALUnit] {
    func makeFormatDescription(_ nalUnitHeaderLength: Int32 = 4) -> CMFormatDescription? {
        guard
            let pps = first(where: { $0.type == .pps }),
            let sps = first(where: { $0.type == .sps }) else {
            return nil
        }
        var formatDescription: CMFormatDescription?
        let status = pps.data.withUnsafeBytes { (ppsBuffer: UnsafeRawBufferPointer) -> OSStatus in
            guard let ppsBaseAddress = ppsBuffer.baseAddress else {
                return kCMFormatDescriptionBridgeError_InvalidParameter
            }
            return sps.data.withUnsafeBytes { (spsBuffer: UnsafeRawBufferPointer) -> OSStatus in
                guard let spsBaseAddress = spsBuffer.baseAddress else {
                    return kCMFormatDescriptionBridgeError_InvalidParameter
                }
                let pointers: [UnsafePointer<UInt8>] = [
                    spsBaseAddress.assumingMemoryBound(to: UInt8.self),
                    ppsBaseAddress.assumingMemoryBound(to: UInt8.self)
                ]
                let sizes: [Int] = [spsBuffer.count, ppsBuffer.count]
                return CMVideoFormatDescriptionCreateFromH264ParameterSets(
                    allocator: kCFAllocatorDefault,
                    parameterSetCount: pointers.count,
                    parameterSetPointers: pointers,
                    parameterSetSizes: sizes,
                    nalUnitHeaderLength: nalUnitHeaderLength,
                    formatDescriptionOut: &formatDescription
                )
            }
        }
        if status != noErr {
            logger.error(status)
        }
        return formatDescription
    }
}
