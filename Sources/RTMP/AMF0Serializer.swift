import Foundation

final class AMFSerializerUtil {
    private static var classes: [String: AnyClass] = [:]

    static func getClassByAlias(_ name: String) -> AnyClass? {
        objc_sync_enter(classes)
        let clazz: AnyClass? = classes[name]
        objc_sync_exit(classes)
        return clazz
    }

    static func registerClassAlias(_ name: String, clazz: AnyClass) {
        objc_sync_enter(classes)
        classes[name] = clazz
        objc_sync_exit(classes)
    }
}

enum AMFSerializerError: Error {
    case deserialize
    case outOfIndex
}

// MARK: -
protocol AMFSerializer: ByteArrayConvertible {
    var reference: AMFReference { get set }

    @discardableResult
    func serialize(_ value: Bool) -> Self
    func deserialize() throws -> Bool

    @discardableResult
    func serialize(_ value: String) -> Self
    func deserialize() throws -> String

    @discardableResult
    func serialize(_ value: Int) -> Self
    func deserialize() throws -> Int

    @discardableResult
    func serialize(_ value: Double) -> Self
    func deserialize() throws -> Double

    @discardableResult
    func serialize(_ value: Date) -> Self
    func deserialize() throws -> Date

    @discardableResult
    func serialize(_ value: [Any?]) -> Self
    func deserialize() throws -> [Any?]

    @discardableResult
    func serialize(_ value: ASArray) -> Self
    func deserialize() throws -> ASArray

    @discardableResult
    func serialize(_ value: ASObject) -> Self
    func deserialize() throws -> ASObject

    @discardableResult
    func serialize(_ value: ASXMLDocument) -> Self
    func deserialize() throws -> ASXMLDocument

    @discardableResult
    func serialize(_ value: Any?) -> Self
    func deserialize() throws -> Any?
}

// MARK: -
/**
 AMF0Serializer

 -seealso: http://wwwimages.adobe.com/content/dam/Adobe/en/devnet/amf/pdf/amf0-file-format-specification.pdf
 */
final class AMF0Serializer: ByteArray {
    enum `Type`: UInt8 {
        case number = 0x00
        case bool = 0x01
        case string = 0x02
        case object = 0x03
        // case MovieClip   = 0x04
        case null = 0x05
        case undefined = 0x06
        case reference = 0x07
        case ecmaArray = 0x08
        case objectEnd = 0x09
        case strictArray = 0x0a
        case date = 0x0b
        case longString = 0x0c
        case unsupported = 0x0d
        // case RecordSet   = 0x0e
        case xmlDocument = 0x0f
        case typedObject = 0x10
        case avmplush = 0x11
    }

    var reference = AMFReference()
}

extension AMF0Serializer: AMFSerializer {
    // MARK: AMFSerializer
    @discardableResult
    func serialize(_ value: Any?) -> Self {
        if value == nil {
            return writeUInt8(Type.null.rawValue)
        }
        switch value {
        case let value as Int:
            return serialize(Double(value))
        case let value as UInt:
            return serialize(Double(value))
        case let value as Int8:
            return serialize(Double(value))
        case let value as UInt8:
            return serialize(Double(value))
        case let value as Int16:
            return serialize(Double(value))
        case let value as UInt16:
            return serialize(Double(value))
        case let value as Int32:
            return serialize(Double(value))
        case let value as UInt32:
            return serialize(Double(value))
        case let value as Float:
            return serialize(Double(value))
        case let value as Double:
            return serialize(Double(value))
        case let value as Date:
            return serialize(value)
        case let value as String:
            return serialize(value)
        case let value as Bool:
            return serialize(value)
        case let value as ASArray:
            return serialize(value)
        case let value as ASObject:
            return serialize(value)
        default:
            return writeUInt8(Type.undefined.rawValue)
        }
    }

    func deserialize() throws -> Any? {
        guard let type = Type(rawValue: try readUInt8()) else {
            return nil
        }
        position -= 1
        switch type {
        case .number:
            return try deserialize() as Double
        case .bool:
            return try deserialize() as Bool
        case .string:
            return try deserialize() as String
        case .object:
            return try deserialize() as ASObject
        case .null:
            position += 1
            return nil
        case .undefined:
            position += 1
            return kASUndefined
        case .reference:
            assertionFailure("TODO")
            return nil
        case .ecmaArray:
            return try deserialize() as ASArray
        case .objectEnd:
            assertionFailure()
            return nil
        case .strictArray:
            return try deserialize() as [Any?]
        case .date:
            return try deserialize() as Date
        case .longString:
            return try deserialize() as String
        case .unsupported:
            assertionFailure("Unsupported")
            return nil
        case .xmlDocument:
            return try deserialize() as ASXMLDocument
        case .typedObject:
            return try deserialize() as Any
        case .avmplush:
            assertionFailure("TODO")
            return nil
        }
    }

    /**
     * @see 2.2 Number Type
     */
    func serialize(_ value: Double) -> Self {
        writeUInt8(Type.number.rawValue).writeDouble(value)
    }

    func deserialize() throws -> Double {
        guard try readUInt8() == Type.number.rawValue else {
            throw AMFSerializerError.deserialize
        }
        return try readDouble()
    }

    func serialize(_ value: Int) -> Self {
        serialize(Double(value))
    }

    func deserialize() throws -> Int {
        Int(try deserialize() as Double)
    }

    /**
     * @see 2.3 Boolean Type
     */
    func serialize(_ value: Bool) -> Self {
        writeBytes(Data([Type.bool.rawValue, value ? 0x01 : 0x00]))
    }

    func deserialize() throws -> Bool {
        guard try readUInt8() == Type.bool.rawValue else {
            throw AMFSerializerError.deserialize
        }
        return try readUInt8() == 0x01 ? true : false
    }

    /**
     * @see 2.4 String Type
     */
    func serialize(_ value: String) -> Self {
        let isLong: Bool = UInt32(UInt16.max) < UInt32(value.count)
        writeUInt8(isLong ? Type.longString.rawValue : Type.string.rawValue)
        return serializeUTF8(value, isLong)
    }

    func deserialize() throws -> String {
        switch try readUInt8() {
        case Type.string.rawValue:
            return try deserializeUTF8(false)
        case Type.longString.rawValue:
            return try deserializeUTF8(true)
        default:
            assertionFailure()
            return ""
        }
    }

    /**
     * 2.5 Object Type
     * typealias ECMAObject = Dictionary<String, Any?>
     */
    func serialize(_ value: ASObject) -> Self {
        writeUInt8(Type.object.rawValue)
        for (key, data) in value {
            serializeUTF8(key, false).serialize(data)
        }
        return serializeUTF8("", false).writeUInt8(Type.objectEnd.rawValue)
    }

    func deserialize() throws -> ASObject {
        var result = ASObject()

        switch try readUInt8() {
        case Type.null.rawValue:
            return result
        case Type.object.rawValue:
            break
        default:
            throw AMFSerializerError.deserialize
        }

        while true {
            let key: String = try deserializeUTF8(false)
            guard !key.isEmpty else {
                position += 1
                break
            }
            result[key] = try deserialize()
        }

        return result
    }

    /**
     * @see 2.10 ECMA Array Type
     */
    func serialize(_ value: ASArray) -> Self {
        self
    }

    func deserialize() throws -> ASArray {
        switch try readUInt8() {
        case Type.null.rawValue:
            return ASArray()
        case Type.ecmaArray.rawValue:
            break
        default:
            throw AMFSerializerError.deserialize
        }

        var result = ASArray(count: Int(try readUInt32()))
        while true {
            let key: String = try deserializeUTF8(false)
            guard !key.isEmpty else {
                position += 1
                break
            }
            result[key] = try deserialize()
        }

        return result
    }

    /**
     * @see 2.12 Strict Array Type
     */
    func serialize(_ value: [Any?]) -> Self {
        writeUInt8(Type.strictArray.rawValue)
        if value.isEmpty {
            writeBytes(Data([0x00, 0x00, 0x00, 0x00]))
            return self
        }
        writeUInt32(UInt32(value.count))
        for v in value {
            serialize(v)
        }
        return self
    }

    func deserialize() throws -> [Any?] {
        guard try readUInt8() == Type.strictArray.rawValue else {
            throw AMFSerializerError.deserialize
        }
        var result: [Any?] = []
        let count = Int(try readUInt32())
        for _ in 0..<count {
            result.append(try deserialize())
        }
        return result
    }

    /**
     * @see 2.13 Date Type
     */
    func serialize(_ value: Date) -> Self {
        writeUInt8(Type.date.rawValue).writeDouble(value.timeIntervalSince1970 * 1000).writeBytes(Data([0x00, 0x00]))
    }

    func deserialize() throws -> Date {
        guard try readUInt8() == Type.date.rawValue else {
            throw AMFSerializerError.deserialize
        }
        let date = Date(timeIntervalSince1970: try readDouble() / 1000)
        position += 2 // timezone offset
        return date
    }

    /**
     * @see 2.17 XML Document Type
     */
    func serialize(_ value: ASXMLDocument) -> Self {
        writeUInt8(Type.xmlDocument.rawValue).serializeUTF8(value.description, true)
    }

    func deserialize() throws -> ASXMLDocument {
        guard try readUInt8() == Type.xmlDocument.rawValue else {
            throw AMFSerializerError.deserialize
        }
        return ASXMLDocument(data: try deserializeUTF8(true))
    }

    func deserialize() throws -> Any {
        guard try readUInt8() == Type.typedObject.rawValue else {
            throw AMFSerializerError.deserialize
        }

        let typeName = try deserializeUTF8(false)
        var result = ASObject()
        while true {
            let key: String = try deserializeUTF8(false)
            guard !key.isEmpty else {
                position += 1
                break
            }
            result[key] = try deserialize()
        }

        return try ASTypedObject.decode(typeName: typeName, data: result)
    }

    @discardableResult
    private func serializeUTF8(_ value: String, _ isLong: Bool) -> Self {
        let utf8 = Data(value.utf8)
        if isLong {
            writeUInt32(UInt32(utf8.count))
        } else {
            writeUInt16(UInt16(utf8.count))
        }
        return writeBytes(utf8)
    }

    private func deserializeUTF8(_ isLong: Bool) throws -> String {
        let length: Int = isLong ? Int(try readUInt32()) : Int(try readUInt16())
        return try readUTF8Bytes(length)
    }
}
