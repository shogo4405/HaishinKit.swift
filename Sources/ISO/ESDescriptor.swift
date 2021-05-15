import Foundation

struct ESDescriptor: BaseDescriptor {
    static let tag: UInt8 = 0x03
    // MARK: BaseDescriptor
    let tag: UInt8 = Self.tag
    var size: UInt32 = 0
    // MARK: ESDescriptor
    var ES_ID: UInt16 = 0
    var streamDependenceFlag = false
    var URLFlag = false
    var OCRstreamFlag = false
    var streamPriority: UInt8 = 0
    var dependsOn_ES_ID: UInt16 = 0
    var URLLength: UInt8 = 0
    var URLstring: String = ""
    var OCR_ES_Id: UInt16 = 0
    var decConfigDescr = DecoderConfigDescriptor()
    var slConfigDescr = SLConfigDescriptor()
}

extension ESDescriptor: DataConvertible {
    // MARK: DataConvertible
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt8(tag)
                .writeUInt32(0)
                .writeUInt16(ES_ID)
                .writeUInt8((streamDependenceFlag ? 1 : 0) << 7 | (URLFlag ? 1 : 0) << 6 | streamPriority)
            if streamDependenceFlag {
                buffer.writeUInt16(dependsOn_ES_ID)
            }
            if URLFlag {
                buffer
                    .writeUInt8(URLLength)
                    .writeUTF8Bytes(URLstring)
            }
            if OCRstreamFlag {
                buffer.writeUInt16(OCR_ES_Id)
            }
            buffer.writeBytes(decConfigDescr.data)
            buffer.writeBytes(slConfigDescr.data)
            writeSize(buffer)
            return buffer.data
        }
        set {
            do {
                let buffer = ByteArray(data: newValue)
                _ = try buffer.readUInt8()
                size = try readSize(buffer)
                ES_ID = try buffer.readUInt16()
                let first = try buffer.readUInt8()
                streamDependenceFlag = (first & 0x80) != 0
                URLFlag = (first & 0x40) != 0
                streamPriority = (first & 0x1F)
                if streamDependenceFlag {
                    dependsOn_ES_ID = try buffer.readUInt16()
                }
                if URLFlag {
                    URLLength = try buffer.readUInt8()
                    URLstring = try buffer.readUTF8Bytes(Int(URLLength))
                }
                if OCRstreamFlag {
                    OCR_ES_Id = try buffer.readUInt16()
                }
                var position = buffer.position
                decConfigDescr.data = try buffer.readBytes(buffer.bytesAvailable)
                position += 5 + Int(decConfigDescr.size)
                buffer.position = position
                slConfigDescr.data = try buffer.readBytes(buffer.bytesAvailable)
            } catch {
                logger.error(error)
            }
        }
    }
}
