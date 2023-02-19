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

    init(_ data: Data, length: Int) {
        self.refIdc = data[0] & 0x60 >> 5
        self.type = NALUnitType(rawValue: data[0] & 0x1f) ?? .unspec
        self.payload = data.subdata(in: 1..<length)
    }
}

class NALUnitReader {
    func read(_ data: Data) -> [NALUnit] {
        var units: [NALUnit] = []
        var startCode: Int = 0
        for i in 0..<data.count {
            guard data[i] == 0 && data[i + 1] == 0 && data[i + 2] == 0 && data[i + 3] == 1 else {
                continue
            }
            let length = i - startCode - 4
            if 0 < length {
                units.append(.init(data.advanced(by: startCode + 4), length: length))
            }
            startCode = i
        }
        let length = data.count - startCode - 4
        units.append(.init(data.advanced(by: startCode + 4), length: length))
        return units
    }
}
