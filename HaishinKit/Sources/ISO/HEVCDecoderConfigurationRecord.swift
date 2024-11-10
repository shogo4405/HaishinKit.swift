import AVFoundation
import Foundation

/// ISO/IEC 14496-15 8.3.3.1.2
struct HEVCDecoderConfigurationRecord: DecoderConfigurationRecord {
    var configurationVersion: UInt8 = 1
    var generalProfileSpace: UInt8 = 0
    var generalTierFlag = false
    var generalProfileIdc: UInt8 = 0
    var generalProfileCompatibilityFlags: UInt32 = 0
    var generalConstraintIndicatorFlags: UInt64 = 0
    var generalLevelIdc: UInt8 = 0
    var minSpatialSegmentationIdc: UInt16 = 0
    var parallelismType: UInt8 = 0
    var chromaFormat: UInt8 = 0
    var bitDepthLumaMinus8: UInt8 = 0
    var bitDepthChromaMinus8: UInt8 = 0
    var avgFrameRate: UInt16 = 0
    var constantFrameRate: UInt8 = 0
    var numTemporalLayers: UInt8 = 0
    var temporalIdNested: UInt8 = 0
    var lengthSizeMinusOne: UInt8 = 0
    var numberOfArrays: UInt8 = 0
    var array: [HEVCNALUnitType: [Data]] = [:]

    init() {
    }

    init(data: Data) {
        self.data = data
    }

    func makeFormatDescription() -> CMFormatDescription? {
        guard let vps = array[.vps], let sps = array[.sps], let pps = array[.pps] else {
            return nil
        }
        return vps[0].withUnsafeBytes { (vpsBuffer: UnsafeRawBufferPointer) -> CMFormatDescription? in
            guard let vpsBaseAddress = vpsBuffer.baseAddress else {
                return nil
            }
            return sps[0].withUnsafeBytes { (spsBuffer: UnsafeRawBufferPointer) -> CMFormatDescription? in
                guard let spsBaseAddress = spsBuffer.baseAddress else {
                    return nil
                }
                return pps[0].withUnsafeBytes { (ppsBuffer: UnsafeRawBufferPointer) -> CMFormatDescription? in
                    guard let ppsBaseAddress = ppsBuffer.baseAddress else {
                        return nil
                    }
                    var formatDescriptionOut: CMFormatDescription?
                    let pointers: [UnsafePointer<UInt8>] = [
                        vpsBaseAddress.assumingMemoryBound(to: UInt8.self),
                        spsBaseAddress.assumingMemoryBound(to: UInt8.self),
                        ppsBaseAddress.assumingMemoryBound(to: UInt8.self)
                    ]
                    let sizes: [Int] = [vpsBuffer.count, spsBuffer.count, ppsBuffer.count]
                    let nalUnitHeaderLength: Int32 = 4
                    CMVideoFormatDescriptionCreateFromHEVCParameterSets(
                        allocator: kCFAllocatorDefault,
                        parameterSetCount: pointers.count,
                        parameterSetPointers: pointers,
                        parameterSetSizes: sizes,
                        nalUnitHeaderLength: nalUnitHeaderLength,
                        extensions: nil,
                        formatDescriptionOut: &formatDescriptionOut
                    )
                    return formatDescriptionOut
                }
            }
        }
    }
}

extension HEVCDecoderConfigurationRecord: DataConvertible {
    // MARK: DataConvertible
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt8(configurationVersion)
            return buffer.data
        }
        set {
            let buffer = ByteArray(data: newValue)
            do {
                configurationVersion = try buffer.readUInt8()
                let a = try buffer.readUInt8()
                generalProfileSpace = a >> 6
                generalTierFlag = a & 0x20 > 0
                generalProfileIdc = a & 0x1F
                generalProfileCompatibilityFlags = try buffer.readUInt32()
                generalConstraintIndicatorFlags = UInt64(try buffer.readUInt32()) << 16 | UInt64(try buffer.readUInt16())
                generalLevelIdc = try buffer.readUInt8()
                minSpatialSegmentationIdc = try buffer.readUInt16() & 0xFFF
                parallelismType = try buffer.readUInt8() & 0x3
                chromaFormat = try buffer.readUInt8() & 0x3
                bitDepthLumaMinus8 = try buffer.readUInt8() & 0x7
                bitDepthChromaMinus8 = try buffer.readUInt8() & 0x7
                avgFrameRate = try buffer.readUInt16()
                let b = try buffer.readUInt8()
                constantFrameRate = b >> 6
                numTemporalLayers = b & 0x38 >> 3
                temporalIdNested = b & 0x6 >> 1
                lengthSizeMinusOne = b & 0x3
                numberOfArrays = try buffer.readUInt8()
                for _ in 0..<numberOfArrays {
                    let a = try buffer.readUInt8()
                    let nalUnitType = HEVCNALUnitType(rawValue: a & 0b00111111) ?? .unspec
                    array[nalUnitType] = []
                    let numNalus = try buffer.readUInt16()
                    for _ in 0..<numNalus {
                        let length = try buffer.readUInt16()
                        array[nalUnitType]?.append(try buffer.readBytes(Int(length)))
                    }
                }
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}

extension HEVCDecoderConfigurationRecord: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}
