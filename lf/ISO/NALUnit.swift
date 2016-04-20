import Foundation
import AVFoundation
import VideoToolbox

// MARK: - NALUnitType
enum NALUnitType: UInt8 {
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
    
    var isVCL:Bool {
        switch self {
        case SLICE:
            return true
        case DPA:
            return true
        case DPB:
            return true
        case DPC:
            return true
        case IDR:
            return true
        default:
            return false
        }
    }
    
    init?(bytes:[UInt8], naluLength:Int32) {
        if (bytes.isEmpty) {
            return nil
        }
        guard let type:NALUnitType = NALUnitType(rawValue: bytes[Int(naluLength)] & 0b00011111) else {
            return nil
        }
        self = type
    }
    
    func setCMSampleAttachmentValues(dictionary:CFMutableDictionaryRef) {
        if (self.isVCL) {
            CFDictionarySetValue(dictionary, unsafeAddressOf(kCMSampleAttachmentKey_DisplayImmediately), unsafeAddressOf(kCFBooleanTrue))
        } else {
            CFDictionarySetValue(dictionary, unsafeAddressOf(kCMSampleAttachmentKey_DoNotDisplay), unsafeAddressOf(kCFBooleanTrue))
        }
        switch self {
        case .IDR:
            CFDictionarySetValue(dictionary, unsafeAddressOf(kCMSampleAttachmentKey_PartialSync), unsafeAddressOf(kCFBooleanTrue))
        case .SLICE:
            CFDictionarySetValue(dictionary, unsafeAddressOf(kCMSampleAttachmentKey_IsDependedOnByOthers), unsafeAddressOf(kCFBooleanTrue))
        default:
            break
        }
    }
}

// MARK: - NALUnit
struct NALUnit {
    var refIdc:UInt8 = 0
    var type:NALUnitType = NALUnitType.UNSPEC
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
                type = NALUnitType(rawValue: byte & 0x31) ?? NALUnitType.UNSPEC
                payload = try buffer.readBytes(buffer.bytesAvailable)
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}
