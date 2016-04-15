import Foundation

struct PacketizedElementaryStream {
    static let startCode:UInt32 = 1

    var startCode:UInt32 = PacketizedElementaryStream.startCode
    var streamID:UInt8 = 0
    var length:UInt16 = 0
    var payload:[UInt8] = []
}
