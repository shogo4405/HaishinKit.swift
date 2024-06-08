import Foundation

struct ISOTypeBufferUtil {
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

    static func toNALFileFormat(_ data: inout Data) {
        var lastIndexOf = data.count - 1
        for i in (2..<data.count).reversed() {
            guard data[i] == 1 && data[i - 1] == 0 && data[i - 2] == 0 else {
                continue
            }
            let startCodeLength = 0 <= i - 3 && data[i - 3] == 0 ? 4 : 3
            let start = 4 - startCodeLength
            let length = lastIndexOf - i
            if 0 < length {
                data.replaceSubrange(i - startCodeLength + 1...i, with: Int32(length).bigEndian.data[start...])
                lastIndexOf = i - startCodeLength
            }
        }
    }
}
