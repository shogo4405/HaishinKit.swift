import Foundation
import AVFoundation

public struct NALUnit {
}

// @see ISO/IEC 14496-15 2010
public struct AVCConfigurationRecord: CustomStringConvertible {
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
    
    func createFormatDescription(formatDescriptionOut: UnsafeMutablePointer<CMFormatDescription?>) {
        var parameterSetPointers:[UnsafePointer<UInt8>] = [
            UnsafePointer<UInt8>(sequenceParameterSets[0]),
            UnsafePointer<UInt8>(pictureParameterSets[0])
        ]
        var parameterSetSizes:[Int] = [
            sequenceParameterSets[0].count,
            pictureParameterSets[0].count
        ]
        CMVideoFormatDescriptionCreateFromH264ParameterSets(
            kCFAllocatorDefault,
            2,
            &parameterSetPointers,
            &parameterSetSizes,
            4,
            formatDescriptionOut
        )
    }
}
