import Foundation

struct AVCFormatStream {
    let data: Data

    init(data: Data) {
        self.data = data
    }

    init?(bytes: UnsafePointer<UInt8>, count: UInt32) {
        self.init(data: Data(bytes: bytes, count: Int(count)))
    }

    init?(data: Data?) {
        guard let data = data else {
            return nil
        }
        self.init(data: data)
    }

    func toByteStream() -> Data {
        let buffer = ByteArray(data: data)
        var result = Data()
        while 0 < buffer.bytesAvailable {
            do {
                let length: Int = try Int(buffer.readUInt32())
                result.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
                result.append(try buffer.readBytes(length))
            } catch {
                logger.error("\(buffer)")
            }
        }
        return result
    }

    static func toNALFileFormat(_ data: inout Data) -> Data {
        var startCodeLength: Int = 4
        var startCodeOffset: Int = 0
        for i in 0..<data.count {
            if data[i] == 0 && data[i + 1] == 0 && data[i + 2] == 0 && data[i + 3] == 1 {
                startCodeLength = 4
            } else if data[i] == 0 && data[i + 1] == 0 && data[i + 2] == 1 {
                if 1 < i && data[i - 1] != 0 {
                    startCodeLength = 3
                } else {
                    continue
                }
            } else {
                continue
            }
            let length = i - startCodeOffset - startCodeLength
            if 0 < length {
                let start = 4 - startCodeLength
                data.replaceSubrange(startCodeOffset..<startCodeOffset + startCodeLength, with: Int32(length).bigEndian.data[start...])
            }
            startCodeOffset = i
        }
        let length = data.count - startCodeOffset - startCodeLength
        let start = 4 - startCodeLength
        data.replaceSubrange(startCodeOffset..<startCodeOffset + startCodeLength, with: Int32(length).bigEndian.data[start...])
        return data
    }
}
