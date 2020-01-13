import AVFoundation
import VideoToolbox

enum NALType: UInt8 {
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
struct NALUnit {
    var refIdc: UInt8 = 0
    var type: NALType = .unspec
    var payload = Data()
}

extension NALUnit: DataConvertible {
    // MARK: DataConvertible
    var data: Data {
        get {
            ByteArray()
                .writeUInt8(refIdc << 5 | type.rawValue)
                .writeBytes(payload)
                .data
        }
        set {
            let buffer = ByteArray(data: newValue)
            do {
                let byte: UInt8 = try buffer.readUInt8()
                refIdc = byte & 0x60 >> 5
                type = NALType(rawValue: byte & 0x31) ?? .unspec
                payload = try buffer.readBytes(buffer.bytesAvailable)
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}
