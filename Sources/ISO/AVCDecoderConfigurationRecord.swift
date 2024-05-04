import AVFoundation
import VideoToolbox

protocol DecoderConfigurationRecord {
    func makeFormatDescription() -> CMFormatDescription?
}

// MARK: -
/*
 - seealso: ISO/IEC 14496-15 2010
 */
struct AVCDecoderConfigurationRecord: DecoderConfigurationRecord {
    static let reserveLengthSizeMinusOne: UInt8 = 0x3F
    static let reserveNumOfSequenceParameterSets: UInt8 = 0xE0
    static let reserveChromaFormat: UInt8 = 0xFC
    static let reserveBitDepthLumaMinus8: UInt8 = 0xF8
    static let reserveBitDepthChromaMinus8 = 0xF8

    var configurationVersion: UInt8 = 1
    var avcProfileIndication: UInt8 = 0
    var profileCompatibility: UInt8 = 0
    var avcLevelIndication: UInt8 = 0
    var lengthSizeMinusOneWithReserved: UInt8 = 0
    var numOfSequenceParameterSetsWithReserved: UInt8 = 0
    var sequenceParameterSets: [[UInt8]] = []
    var pictureParameterSets: [[UInt8]] = []

    var chromaFormatWithReserve: UInt8 = 0
    var bitDepthLumaMinus8WithReserve: UInt8 = 0
    var bitDepthChromaMinus8WithReserve: UInt8 = 0
    var sequenceParameterSetExt: [[UInt8]] = []

    var naluLength: Int32 {
        Int32((lengthSizeMinusOneWithReserved >> 6) + 1)
    }

    init() {
    }

    init(data: Data) {
        self.data = data
    }

    func makeFormatDescription() -> CMFormatDescription? {
        return pictureParameterSets[0].withUnsafeBytes { (ppsBuffer: UnsafeRawBufferPointer) -> CMFormatDescription? in
            guard let ppsBaseAddress = ppsBuffer.baseAddress else {
                return nil
            }
            return sequenceParameterSets[0].withUnsafeBytes { (spsBuffer: UnsafeRawBufferPointer) -> CMFormatDescription? in
                guard let spsBaseAddress = spsBuffer.baseAddress else {
                    return nil
                }
                let pointers: [UnsafePointer<UInt8>] = [
                    spsBaseAddress.assumingMemoryBound(to: UInt8.self),
                    ppsBaseAddress.assumingMemoryBound(to: UInt8.self)
                ]
                let sizes: [Int] = [spsBuffer.count, ppsBuffer.count]
                let nalUnitHeaderLength: Int32 = 4
                var formatDescriptionOut: CMFormatDescription?
                CMVideoFormatDescriptionCreateFromH264ParameterSets(
                    allocator: kCFAllocatorDefault,
                    parameterSetCount: pointers.count,
                    parameterSetPointers: pointers,
                    parameterSetSizes: sizes,
                    nalUnitHeaderLength: nalUnitHeaderLength,
                    formatDescriptionOut: &formatDescriptionOut
                )
                return formatDescriptionOut
            }
        }
    }
}

extension AVCDecoderConfigurationRecord: DataConvertible {
    // MARK: DataConvertible
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt8(configurationVersion)
                .writeUInt8(avcProfileIndication)
                .writeUInt8(profileCompatibility)
                .writeUInt8(avcLevelIndication)
                .writeUInt8(lengthSizeMinusOneWithReserved)
                .writeUInt8(numOfSequenceParameterSetsWithReserved)
            for i in 0..<sequenceParameterSets.count {
                buffer
                    .writeUInt16(UInt16(sequenceParameterSets[i].count))
                    .writeBytes(Data(sequenceParameterSets[i]))
            }
            buffer.writeUInt8(UInt8(pictureParameterSets.count))
            for i in 0..<pictureParameterSets.count {
                buffer
                    .writeUInt16(UInt16(pictureParameterSets[i].count))
                    .writeBytes(Data(pictureParameterSets[i]))
            }
            return buffer.data
        }
        set {
            let buffer = ByteArray(data: newValue)
            do {
                configurationVersion = try buffer.readUInt8()
                avcProfileIndication = try buffer.readUInt8()
                profileCompatibility = try buffer.readUInt8()
                avcLevelIndication = try buffer.readUInt8()
                lengthSizeMinusOneWithReserved = try buffer.readUInt8()
                numOfSequenceParameterSetsWithReserved = try buffer.readUInt8()
                let numOfSequenceParameterSets: UInt8 = numOfSequenceParameterSetsWithReserved & ~AVCDecoderConfigurationRecord.reserveNumOfSequenceParameterSets
                for _ in 0..<numOfSequenceParameterSets {
                    let length = Int(try buffer.readUInt16())
                    sequenceParameterSets.append(try buffer.readBytes(length).bytes)
                }
                let numPictureParameterSets: UInt8 = try buffer.readUInt8()
                for _ in 0..<numPictureParameterSets {
                    let length = Int(try buffer.readUInt16())
                    pictureParameterSets.append(try buffer.readBytes(length).bytes)
                }
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}

extension AVCDecoderConfigurationRecord: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}
