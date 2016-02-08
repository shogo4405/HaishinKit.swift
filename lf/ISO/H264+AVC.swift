import Foundation
import AVFoundation
import VideoToolbox

public enum NALUType:UInt8 {
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

    public var isVCL:Bool {
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

// @see ISO/IEC 14496-15 2010
public struct AVCConfigurationRecord: CustomStringConvertible {
    
    static func getData(formatDescription:CMFormatDescriptionRef?) -> NSData? {
        if (formatDescription == nil) {
            return nil
        }
        if let atoms:NSDictionary = CMFormatDescriptionGetExtension(formatDescription!, "SampleDescriptionExtensionAtoms") as? NSDictionary {
            return atoms["avcC"] as? NSData
        }
        return nil
    }
    
    static let reserveLengthSizeMinusOne:UInt8 = 0x3F
    static let reserveNumOfSequenceParameterSets:UInt8 = 0xE0
    static let reserveChromaFormat:UInt8 = 0xFC
    static let reserveBitDepthLumaMinus8:UInt8 = 0xF8
    static let reserveBitDepthChromaMinus8 = 0xF8
    
    public var configurationVersion:UInt8 = 1
    public var AVCProfileIndication:UInt8 = 0
    public var profileCompatibility:UInt8 = 0
    public var AVCLevelIndication:UInt8 = 0
    public var lengthSizeMinusOneWithReserved:UInt8 = 0
    public var numOfSequenceParameterSetsWithReserved:UInt8 = 0
    public var sequenceParameterSets:[[UInt8]] = []
    public var pictureParameterSets:[[UInt8]] = []
    
    public var chromaFormatWithReserve:UInt8 = 0
    public var bitDepthLumaMinus8WithReserve:UInt8 = 0
    public var bitDepthChromaMinus8WithReserve:UInt8 = 0
    public var sequenceParameterSetExt:[[UInt8]] = []
    
    var naluLength:Int32 {
        return Int32((lengthSizeMinusOneWithReserved >> 6) + 1)
    }
    
    public var description:String {
        var description:String = "AVCConfigurationRecord{"
        description += "configurationVersion:\(configurationVersion),"
        description += "AVCProfileIndication:\(AVCProfileIndication),"
        description += "lengthSizeMinusOneWithReserved:\(lengthSizeMinusOneWithReserved),"
        description += "numOfSequenceParameterSetsWithReserved:\(numOfSequenceParameterSetsWithReserved),"
        description += "sequenceParameterSets:\(sequenceParameterSets),"
        description += "pictureParameterSets:\(pictureParameterSets)"
        description += "}"
        return description
    }
    
    init() {
    }
    
    init(data: NSData) {
        var bytes:[UInt8] = [UInt8](count: data.length, repeatedValue: 0x00)
        data.getBytes(&bytes, length: bytes.count)
        self.bytes = bytes
    }
    
    private var _bytes:[UInt8] = []
    var bytes:[UInt8] {
        get {
            return _bytes
        }
        set {
            let buffer:ByteArray = ByteArray(bytes: newValue)
            configurationVersion = buffer.readUInt8()
            AVCProfileIndication = buffer.readUInt8()
            profileCompatibility = buffer.readUInt8()
            AVCLevelIndication = buffer.readUInt8()
            lengthSizeMinusOneWithReserved = buffer.readUInt8()
            numOfSequenceParameterSetsWithReserved = buffer.readUInt8()
            
            let numOfSequenceParameterSets:UInt8 = numOfSequenceParameterSetsWithReserved & ~AVCConfigurationRecord.reserveNumOfSequenceParameterSets
            for _ in 0..<numOfSequenceParameterSets {
                let length:Int = Int(buffer.readUInt16())
                sequenceParameterSets.append(buffer.readUInt8(length))
            }
            
            let numPictureParameterSets:UInt8 = buffer.readUInt8()
            for _ in 0..<numPictureParameterSets {
                let length:Int = Int(buffer.readUInt16())
                pictureParameterSets.append(buffer.readUInt8(length))
            }
            
            _bytes = newValue
        }
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
