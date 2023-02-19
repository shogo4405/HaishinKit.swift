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

    static func toVideoStream(_ data: inout Data) -> Data {
        var startCode: Int = 0
        for i in 0..<data.count {
            guard data[i] == 0 && data[i + 1] == 0 && data[i + 2] == 0 && data[i + 3] == 1 else {
                continue
            }
            let length = i - startCode - 4
            if 0 < length {
                data.replaceSubrange(startCode..<startCode + 4, with: Int32(length).bigEndian.data)
            }
            startCode = i
        }
        let length = data.count - startCode - 4
        data.replaceSubrange(startCode..<startCode + 4, with: Int32(length).bigEndian.data)
        return data
    }
}
