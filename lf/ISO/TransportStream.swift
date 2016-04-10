import Foundation

/**
 - seealso: https://en.wikipedia.org/wiki/MPEG_transport_stream#Packet
 */
struct TSPacket {
    static let defaultSyncByte:UInt8 = 0x47
    static let defaultPID:UInt16 = 0
    static let defaultScramblingControl:UInt8 = 0
    static let defaultContinuityCounter:UInt8 = 0

    var syncByte:UInt8 = TSPacket.defaultSyncByte
    var transportErrorIndicator:Bool = false
    var payloadUnitStartIndicator:Bool = false
    var transportPriority:Bool = false
    var PID:UInt16 = TSPacket.defaultPID
    var scramblingControl:UInt8 = TSPacket.defaultScramblingControl
    var adaptationFieldFlag:Bool = false
    var payloadFlag:Bool = false
    var continuityCounter:UInt8 = TSPacket.defaultContinuityCounter
    var adaptationField:TSAdaptationField?
    var payload:[UInt8] = []
}

// MARK: CustomStringConvertible
extension TSPacket: CustomStringConvertible {
    var description:String {
        return Mirror(reflecting: self).description
    }
}

// MARK: - TSAdaptationField
struct TSAdaptationField {
    var length:UInt8 = 0
    var discontinuityIndicator:Bool = false
    var randomAccessIndicator:Bool = false
    var elementaryStreamPriorityIndicator = false
    var PCRFlag:Bool = false
    var OPCRFlag:Bool = false
    var splicingPointFlag:Bool = false
    var transportPrivateDataFlag:Bool = false
    var adaptationFieldExtensionFlag:Bool = false
    var PCR:[UInt8] = []
    var OPCR:[UInt8] = []
    var spliceCountdown:UInt8 = 0
    var transportPrivateDataLength:UInt8 = 0
    var transportPrivateData:[UInt8] = []
    var adaptationExtension:TSAdaptationExtensionField?
    var stuffingBytes:[UInt8] = []
}

// MARK: CustomStringConvertible
extension TSAdaptationField: CustomStringConvertible {
    var description:String {
        return Mirror(reflecting: self).description
    }
}

// MARK: - TSAdaptationExtensionField
struct TSAdaptationExtensionField {
    var length:UInt8 = 0
    var legalTimeWindowFlag:Bool = false
    var piecewiseRateFlag:Bool = false
    var seamlessSpiceFlag:Bool = false
    var legalTimeWindowValidFlag:Bool = false
    var legalTimeWindowOffset:UInt16 = 0
    var piecewiseRate:UInt32 = 0
    var spliceType:UInt8 = 0
    var DTSNetxtAccessUnit:[UInt8] = []
}

extension TSAdaptationExtensionField: CustomStringConvertible {
    var description:String {
        return Mirror(reflecting: self).description
    }
}
