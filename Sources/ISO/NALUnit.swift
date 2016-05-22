import Foundation
import AVFoundation
import VideoToolbox

// MARK: NALType
enum NALType: UInt8 {
    case UNSPEC   = 0
    case SLICE    = 1 // P frame
    case DPA      = 2
    case DPB      = 3
    case DPC      = 4
    case IDR      = 5 // I frame
    case SEI      = 6
    case SPS      = 7
    case PPS      = 8
    case AUD      = 9
    case EOSEQ    = 10
    case EOSTREAM = 11
    case FILL     = 12
}

// MARK: -
struct NALUnit {
    var refIdc:UInt8 = 0
    var type:NALType = .UNSPEC
    var payload:[UInt8] = []
}

// MARK: BytesConvertible
extension NALUnit: BytesConvertible {
    var bytes:[UInt8] {
        get {
            return ByteArray()
                .writeUInt8(refIdc << 5 | type.rawValue)
                .writeBytes(payload)
                .bytes
        }
        set {
            let buffer:ByteArray = ByteArray(bytes: newValue)
            do {
                let byte:UInt8 = try buffer.readUInt8()
                refIdc = byte & 0x60 >> 5
                type = NALType(rawValue: byte & 0x31) ?? .UNSPEC
                payload = try buffer.readBytes(buffer.bytesAvailable)
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}
