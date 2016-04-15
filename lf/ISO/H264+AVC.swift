import Foundation
import AVFoundation
import VideoToolbox

// MARK: - NALUType
enum NALUType: UInt8 {
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

    init? (bytes:[UInt8], naluLength:Int32) {
        if (bytes.isEmpty) {
            return nil
        }
        guard let type:NALUType = NALUType(rawValue: bytes[Int(naluLength)] & 0b00011111) else {
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

/*
 - seealso: ISO/IEC 14496-15 2010
 */
// MARK: - AVCConfigurationRecord
struct AVCConfigurationRecord {

    static func getData(formatDescription:CMFormatDescriptionRef?) -> NSData? {
        guard let formatDescription:CMFormatDescriptionRef = formatDescription else {
            return nil
        }
        if let atoms:NSDictionary = CMFormatDescriptionGetExtension(formatDescription, "SampleDescriptionExtensionAtoms") as? NSDictionary {
            return atoms["avcC"] as? NSData
        }
        return nil
    }

    static let reserveLengthSizeMinusOne:UInt8 = 0x3F
    static let reserveNumOfSequenceParameterSets:UInt8 = 0xE0
    static let reserveChromaFormat:UInt8 = 0xFC
    static let reserveBitDepthLumaMinus8:UInt8 = 0xF8
    static let reserveBitDepthChromaMinus8 = 0xF8

    var configurationVersion:UInt8 = 1
    var AVCProfileIndication:UInt8 = 0
    var profileCompatibility:UInt8 = 0
    var AVCLevelIndication:UInt8 = 0
    var lengthSizeMinusOneWithReserved:UInt8 = 0
    var numOfSequenceParameterSetsWithReserved:UInt8 = 0
    var sequenceParameterSets:[[UInt8]] = []
    var pictureParameterSets:[[UInt8]] = []

    var chromaFormatWithReserve:UInt8 = 0
    var bitDepthLumaMinus8WithReserve:UInt8 = 0
    var bitDepthChromaMinus8WithReserve:UInt8 = 0
    var sequenceParameterSetExt:[[UInt8]] = []

    var naluLength:Int32 {
        return Int32((lengthSizeMinusOneWithReserved >> 6) + 1)
    }

    init() {
    }

    init(data: NSData) {
        var bytes:[UInt8] = [UInt8](count: data.length, repeatedValue: 0x00)
        data.getBytes(&bytes, length: bytes.count)
        self.bytes = bytes
    }

    func createFormatDescription(formatDescriptionOut: UnsafeMutablePointer<CMFormatDescription?>) ->  OSStatus {
        var parameterSetPointers:[UnsafePointer<UInt8>] = [
            UnsafePointer<UInt8>(sequenceParameterSets[0]),
            UnsafePointer<UInt8>(pictureParameterSets[0])
        ]
        var parameterSetSizes:[Int] = [
            sequenceParameterSets[0].count,
            pictureParameterSets[0].count
        ]
        return CMVideoFormatDescriptionCreateFromH264ParameterSets(
            kCFAllocatorDefault,
            2,
            &parameterSetPointers,
            &parameterSetSizes,
            naluLength,
            formatDescriptionOut
        )
    }
}

// MARK: BytesConvertible
extension AVCConfigurationRecord: BytesConvertible {
    var bytes:[UInt8] {
        get {
            let buffer:ByteArray = ByteArray()
                .writeUInt8(configurationVersion)
                .writeUInt8(AVCProfileIndication)
                .writeUInt8(profileCompatibility)
                .writeUInt8(AVCLevelIndication)
                .writeUInt8(lengthSizeMinusOneWithReserved)
                .writeUInt8(numOfSequenceParameterSetsWithReserved)
            for i in 0..<sequenceParameterSets.count {
                buffer
                    .writeUInt16(UInt16(sequenceParameterSets[i].count))
                    .writeBytes(sequenceParameterSets[i])
            }
            buffer.writeUInt8(UInt8(pictureParameterSets.count))
            for i in 0..<pictureParameterSets.count {
                buffer
                    .writeUInt16(UInt16(pictureParameterSets[i].count))
                    .writeBytes(pictureParameterSets[i])
            }
            return buffer.bytes
        }
        set {
            let buffer:ByteArray = ByteArray(bytes: newValue)
            do {
                configurationVersion = try buffer.readUInt8()
                AVCProfileIndication = try buffer.readUInt8()
                profileCompatibility = try buffer.readUInt8()
                AVCLevelIndication = try buffer.readUInt8()
                lengthSizeMinusOneWithReserved = try buffer.readUInt8()
                numOfSequenceParameterSetsWithReserved = try buffer.readUInt8()
                let numOfSequenceParameterSets:UInt8 = numOfSequenceParameterSetsWithReserved & ~AVCConfigurationRecord.reserveNumOfSequenceParameterSets
                for _ in 0..<numOfSequenceParameterSets {
                    let length:Int = Int(try buffer.readUInt16())
                    sequenceParameterSets.append(try buffer.readBytes(length))
                }
                let numPictureParameterSets:UInt8 = try buffer.readUInt8()
                for _ in 0..<numPictureParameterSets {
                    let length:Int = Int(try buffer.readUInt16())
                    pictureParameterSets.append(try buffer.readBytes(length))
                }
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}

// MARK: CustomStringConvertible
extension AVCConfigurationRecord: CustomStringConvertible {
    var description:String {
        return Mirror(reflecting: self).description
    }
}
