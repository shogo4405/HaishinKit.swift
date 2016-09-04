import Foundation
import AVFoundation
import VideoToolbox

struct AVCFormatStream {
    internal var bytes:[UInt8] = []

    internal init(bytes:[UInt8]) {
        self.bytes = bytes
    }

    internal func toByteStream() -> [UInt8] {
        let buffer:ByteArray = ByteArray(bytes: bytes)
        var result:[UInt8] = []
        while (0 < buffer.bytesAvailable) {
            do {
                buffer.position += 2
                let size:Int = try Int(buffer.readUInt16())
                result += [0x00, 0x00, 0x00, 0x01]
                result += try buffer.readBytes(size)
            } catch {
                logger.error("\(buffer)")
            }
        }
        return result
    }
}

// MARK: -
/*
 - seealso: ISO/IEC 14496-15 2010
 */
struct AVCConfigurationRecord {

    static internal func getData(_ formatDescription:CMFormatDescription?) -> Data? {
        guard let formatDescription:CMFormatDescription = formatDescription else {
            return nil
        }
        if let atoms:NSDictionary = CMFormatDescriptionGetExtension(formatDescription, "SampleDescriptionExtensionAtoms" as CFString) as? NSDictionary {
            return atoms["avcC"] as? Data
        }
        return nil
    }

    static internal let reserveLengthSizeMinusOne:UInt8 = 0x3F
    static internal let reserveNumOfSequenceParameterSets:UInt8 = 0xE0
    static internal let reserveChromaFormat:UInt8 = 0xFC
    static internal let reserveBitDepthLumaMinus8:UInt8 = 0xF8
    static internal let reserveBitDepthChromaMinus8 = 0xF8

    internal var configurationVersion:UInt8 = 1
    internal var AVCProfileIndication:UInt8 = 0
    internal var profileCompatibility:UInt8 = 0
    internal var AVCLevelIndication:UInt8 = 0
    internal var lengthSizeMinusOneWithReserved:UInt8 = 0
    internal var numOfSequenceParameterSetsWithReserved:UInt8 = 0
    internal var sequenceParameterSets:[[UInt8]] = []
    internal var pictureParameterSets:[[UInt8]] = []

    internal var chromaFormatWithReserve:UInt8 = 0
    internal var bitDepthLumaMinus8WithReserve:UInt8 = 0
    internal var bitDepthChromaMinus8WithReserve:UInt8 = 0
    internal var sequenceParameterSetExt:[[UInt8]] = []

    internal var naluLength:Int32 {
        return Int32((lengthSizeMinusOneWithReserved >> 6) + 1)
    }

    internal init() {
    }

    internal init(data: Data) {
        var bytes:[UInt8] = [UInt8](repeating: 0x00, count: data.count)
        (data as NSData).getBytes(&bytes, length: bytes.count)
        self.bytes = bytes
    }

    internal func createFormatDescription(_ formatDescriptionOut: UnsafeMutablePointer<CMFormatDescription?>) ->  OSStatus {
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

extension AVCConfigurationRecord: BytesConvertible {
    // MARK: BytesConvertible
    internal var bytes:[UInt8] {
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

extension AVCConfigurationRecord: CustomStringConvertible {
    // MARK: CustomStringConvertible
    internal var description:String {
        return Mirror(reflecting: self).description
    }
}
