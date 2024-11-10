import CoreMedia
import Foundation

enum HEVCNALUnitType: UInt8 {
    case codedSliceTrailN = 0
    case codedSliceTrailR = 1
    case codedSliceTsaN = 2
    case codedSliceTsaR = 3
    case codedSliceStsaN = 4
    case codedSliceStsaR = 5
    case codedSliceRadlN = 6
    case codedSliceRadlR = 7
    case codedSliceRaslN = 8
    case codedSliceRsslR = 9
    /// 10...15 Reserved
    case vps = 32
    case sps = 33
    case pps = 34
    case accessUnitDelimiter = 35
    case unspec = 0xFF
}

struct HEVCNALUnit: NALUnit, Equatable {
    let type: HEVCNALUnitType
    let temporalIdPlusOne: UInt8
    let payload: Data

    init(_ data: Data) {
        self.init(data, length: data.count)
    }

    init(_ data: Data, length: Int) {
        self.type = HEVCNALUnitType(rawValue: (data[0] & 0x7e) >> 1) ?? .unspec
        self.temporalIdPlusOne = data[1] & 0b00011111
        self.payload = data.subdata(in: 2..<length)
    }

    var data: Data {
        var result = Data()
        result.append(type.rawValue << 1)
        result.append(temporalIdPlusOne)
        result.append(payload)
        return result
    }
}

extension [HEVCNALUnit] {
    func makeFormatDescription(_ nalUnitHeaderLength: Int32 = 4) -> CMFormatDescription? {
        guard
            let vps = first(where: { $0.type == .vps }),
            let sps = first(where: { $0.type == .sps }),
            let pps = first(where: { $0.type == .pps }) else {
            return nil
        }
        return vps.data.withUnsafeBytes { (vpsBuffer: UnsafeRawBufferPointer) -> CMFormatDescription? in
            guard let vpsBaseAddress = vpsBuffer.baseAddress else {
                return nil
            }
            return sps.data.withUnsafeBytes { (spsBuffer: UnsafeRawBufferPointer) -> CMFormatDescription? in
                guard let spsBaseAddress = spsBuffer.baseAddress else {
                    return nil
                }
                return pps.data.withUnsafeBytes { (ppsBuffer: UnsafeRawBufferPointer) -> CMFormatDescription? in
                    guard let ppsBaseAddress = ppsBuffer.baseAddress else {
                        return nil
                    }
                    var formatDescriptionOut: CMFormatDescription?
                    let pointers: [UnsafePointer<UInt8>] = [
                        vpsBaseAddress.assumingMemoryBound(to: UInt8.self),
                        spsBaseAddress.assumingMemoryBound(to: UInt8.self),
                        ppsBaseAddress.assumingMemoryBound(to: UInt8.self)
                    ]
                    let sizes: [Int] = [vpsBuffer.count, spsBuffer.count, ppsBuffer.count]
                    CMVideoFormatDescriptionCreateFromHEVCParameterSets(
                        allocator: kCFAllocatorDefault,
                        parameterSetCount: pointers.count,
                        parameterSetPointers: pointers,
                        parameterSetSizes: sizes,
                        nalUnitHeaderLength: nalUnitHeaderLength,
                        extensions: nil,
                        formatDescriptionOut: &formatDescriptionOut
                    )
                    return formatDescriptionOut
                }
            }
        }
    }
}
