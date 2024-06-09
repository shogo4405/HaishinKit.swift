import Foundation

final class CRC32: Sendable {
    static let mpeg2 = CRC32(polynomial: 0x04c11db7)

    let table: [UInt32]

    init(polynomial: UInt32) {
        var table = [UInt32](repeating: 0x00000000, count: 256)
        for i in 0..<table.count {
            var crc = UInt32(i) << 24
            for _ in 0..<8 {
                crc = (crc << 1) ^ ((crc & 0x80000000) == 0x80000000 ? polynomial : 0)
            }
            table[i] = crc
        }
        self.table = table
    }

    func calculate(_ data: Data) -> UInt32 {
        calculate(data, seed: nil)
    }

    func calculate(_ data: Data, seed: UInt32?) -> UInt32 {
        var crc: UInt32 = seed ?? 0xffffffff
        for i in 0..<data.count {
            crc = (crc << 8) ^ table[Int((crc >> 24) ^ (UInt32(data[i]) & 0xff) & 0xff)]
        }
        return crc
    }
}

extension CRC32: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}
