import CoreMedia
import Foundation

enum NALUnitType: UInt8, Equatable {
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
struct NALUnit: Equatable {
    let refIdc: UInt8
    let type: NALUnitType
    let payload: Data

    init(_ data: Data) {
        self.init(data, length: data.count)
    }

    init(_ data: Data, length: Int) {
        self.refIdc = data[0] & 0x60 >> 5
        self.type = NALUnitType(rawValue: data[0] & 0x1f) ?? .unspec
        self.payload = data.subdata(in: 1..<length)
    }

    var data: Data {
        var result = Data()
        result.append(refIdc << 5 | self.type.rawValue | 0b1100000)
        result.append(payload)
        return result
    }
}

class NALUnitReader {
    static let defaultStartCodeLength: Int = 4
    static let defaultNALUnitHeaderLength: Int32 = 4

    var nalUnitHeaderLength: Int32 = NALUnitReader.defaultNALUnitHeaderLength

    func read(_ data: Data) -> [NALUnit] {
        var units: [NALUnit] = []
        var lastIndexOf = data.count - 1
        for i in (2..<data.count).reversed() {
            guard data[i] == 1 && data[i - 1] == 0 && data[i - 2] == 0 else {
                continue
            }
            let startCodeLength = 0 <= i - 3 && data[i - 3] == 0 ? 4 : 3
            units.append(.init(data.subdata(in: (i + 1)..<lastIndexOf + 1)))
            lastIndexOf = i - startCodeLength
        }
        return units
    }

    func makeFormatDescription(_ data: Data) -> CMFormatDescription? {
        let units = read(data).filter { $0.type == .pps || $0.type == .sps }
        guard
            let pps = units.first(where: { $0.type == .pps }),
            let sps = units.first(where: { $0.type == .sps }) else {
            return nil
        }
        var formatDescription: CMFormatDescription?
        _ = pps.data.withUnsafeBytes { (ppsBuffer: UnsafeRawBufferPointer) -> OSStatus? in
            guard let ppsBaseAddress = ppsBuffer.baseAddress else {
                return nil
            }
            return sps.data.withUnsafeBytes { (spsBuffer: UnsafeRawBufferPointer) -> OSStatus? in
                guard let spsBaseAddress = spsBuffer.baseAddress else {
                    return nil
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
        return formatDescription
    }
}
