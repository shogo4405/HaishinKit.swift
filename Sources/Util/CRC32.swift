import Foundation

final class CRC32 {
    static let MPEG2:CRC32 = CRC32(polynomial: 0x04c11db7)

    let table:[UInt32]

    init(polynomial:UInt32) {
        var table:[UInt32] = [UInt32](repeating: 0x00000000, count: 256)
        for i in 0..<table.count {
            var crc:UInt32 = UInt32(i) << 24
            for _ in 0..<8 {
                crc = (crc << 1) ^ ((crc & 0x80000000) == 0x80000000 ? polynomial : 0)
            }
            table[i] = crc
        }
        self.table = table
    }

    func calculate(_ bytes:[UInt8]) -> UInt32 {
        return calculate(bytes, seed: nil)
    }

    func calculate(_ bytes:[UInt8], seed:UInt32?) -> UInt32 {
        var crc:UInt32 = seed ?? 0xffffffff
        for i in 0..<bytes.count {
            crc = (crc << 8) ^ table[Int((crc >> 24) ^ (UInt32(bytes[i]) & 0xff) & 0xff)]
        }
        return crc
    }
}

extension CRC32: CustomStringConvertible {
    // MARK: CustomStringConvertible
    var description:String {
        return Mirror(reflecting: self).description
    }
}
