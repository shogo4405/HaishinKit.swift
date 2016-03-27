import Foundation

class AMFSerializerUtil {
    private static var classes:[String: AnyClass] = [:]

    static func getClassByAlias(name:String) -> AnyClass? {
        objc_sync_enter(classes)
        let clazz:AnyClass? = classes[name]
        objc_sync_exit(classes)
        return clazz
    }

    static func registerClassAlias(name:String, clazz: AnyClass) {
        objc_sync_enter(classes)
        classes[name] = clazz
        objc_sync_exit(classes)
    }
}

enum AMFSerializerError: ErrorType {
    case Deserialize
    case OutOfIndex
}

class AMFReference {
    var strings:[String] = []
    var objects:[Any] = []

    func getString(index:Int) throws -> String {
        if (strings.count <= index) {
            throw AMFSerializerError.OutOfIndex
        }
        return strings[index]
    }

    func getObject(index:Int) throws -> Any {
        if (objects.count <= index) {
            throw AMFSerializerError.OutOfIndex
        }
        return objects[index]
    }

    func indexOf<T:Equatable>(value: T) -> Int? {
        for (index, data) in objects.enumerate() {
            if let data:T = data as? T where data == value {
                return index
            }
        }
        return nil
    }

    func indexOf(value:ASObject) -> Int? {
        for (index, data) in objects.enumerate() {
            if let data:ASObject = data as? ASObject where data.description == value.description {
                return index
            }
        }
        return nil
    }

    func indexOf(value:String) -> Int? {
        return strings.indexOf(value)
    }
}

protocol AMFSerializer: ByteArrayConvertible {
    var reference:AMFReference { get set }

    func serialize(value:Bool) -> Self
    func deserialize() throws -> Bool

    func serialize(value:String) -> Self
    func deserialize() throws -> String

    func serialize(value:Int) -> Self
    func deserialize() throws -> Int

    func serialize(value:Double) -> Self
    func deserialize() throws -> Double

    func serialize(value:NSDate) -> Self
    func deserialize() throws -> NSDate

    func serialize(value:[Any?]) -> Self
    func deserialize() throws -> [Any?]

    func serialize(value: ASArray) -> Self
    func deserialize() throws -> ASArray

    func serialize(value: ASObject) -> Self
    func deserialize() throws -> ASObject

    func serialize(value: ASXMLDocument) -> Self
    func deserialize() throws -> ASXMLDocument

    func serialize(value:Any?) -> Self
    func deserialize() throws -> Any?
}

/**
 * AMF0Serializer
 * -seealso: http://wwwimages.adobe.com/content/dam/Adobe/en/devnet/amf/pdf/amf0-file-format-specification.pdf
 */
class AMF0Serializer: ByteArray {
    enum Type:UInt8 {
        case Number      = 0x00
        case Bool        = 0x01
        case String      = 0x02
        case Object      = 0x03
        // case MovieClip   = 0x04
        case Null        = 0x05
        case Undefined   = 0x06
        case Reference   = 0x07
        case ECMAArray   = 0x08
        case ObjectEnd   = 0x09
        case StrictArray = 0x0a
        case Date        = 0x0b
        case LongString  = 0x0c
        case Unsupported = 0x0d
        // case RecordSet   = 0x0e
        case XmlDocument = 0x0f
        case TypedObject = 0x10
        case Avmplush    = 0x11
    }

    var reference:AMFReference = AMFReference()
}

extension AMF0Serializer: AMFSerializer {

    func serialize(value:Any?) -> Self {
        if value == nil {
            return writeUInt8(Type.Null.rawValue)
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
        case let value as NSDate:
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
            return writeUInt8(Type.Undefined.rawValue)
        }
    }

    func deserialize() throws -> Any? {
        guard let type:Type = Type(rawValue: try readUInt8()) else {
            return nil
        }
        position -= 1
        switch type {
        case .Number:
            return try deserialize() as Double
        case .Bool:
            return try deserialize() as Bool
        case .String:
            return try deserialize() as String
        case .Object:
            return try deserialize() as ASObject
        case .Null:
            position += 1
            return nil
        case .Undefined:
            position += 1
            return Type.Undefined
        case .Reference:
            assertionFailure("TODO")
            return nil
        case .ECMAArray:
            return try deserialize() as ASArray
        case .ObjectEnd:
            assertionFailure()
            return nil
        case .StrictArray:
            return try deserialize() as [Any?]
        case .Date:
            return try deserialize() as NSDate
        case .LongString:
            return try deserialize() as String
        case .Unsupported:
            assertionFailure("Unsupported")
            return nil
        case .XmlDocument:
            return try deserialize() as ASXMLDocument
        case .TypedObject:
            assertionFailure("TODO")
            return nil
        case .Avmplush:
            assertionFailure("TODO")
            return nil
        }
    }

    /**
     * @see 2.2 Number Type
     */
    func serialize(value:Double) -> Self {
        return writeUInt8(Type.Number.rawValue).writeDouble(value)
    }

    func deserialize() throws -> Double {
        guard try readUInt8() == Type.Number.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        return try readDouble()
    }
    
    func serialize(value:Int) -> Self {
        return serialize(Double(value))
    }

    func deserialize() throws -> Int {
        return Int(try deserialize() as Double)
    }

    /**
     * @see 2.3 Boolean Type
     */
    func serialize(value:Bool) -> Self {
        return writeBytes([Type.Bool.rawValue, value ? 0x01 : 0x00])
    }

    func deserialize() throws -> Bool {
        guard try readUInt8() == Type.Bool.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        return try readUInt8() == 0x01 ? true : false
    }

    /**
     * @see 2.4 String Type
     */
    func serialize(value:String) -> Self {
        let isLong:Bool = UInt32(UInt16.max) < UInt32(value.characters.count)
        writeUInt8(isLong ? Type.LongString.rawValue : Type.String.rawValue)
        return serializeUTF8(value, isLong)
    }
    
    func deserialize() throws -> String {
        switch try readUInt8() {
        case Type.String.rawValue:
            return try deserializeUTF8(false)
        case Type.LongString.rawValue:
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
    func serialize(value: ASObject) -> Self {
        writeUInt8(Type.Object.rawValue)
        for (key, data) in value {
            serializeUTF8(key, false).serialize(data)
        }
        return serializeUTF8("", false).writeUInt8(Type.ObjectEnd.rawValue)
    }

    func deserialize() throws -> ASObject {
        var result:ASObject = ASObject()

        switch try readUInt8() {
        case Type.Null.rawValue:
            return result
        case Type.Object.rawValue:
            break
        default:
            throw AMFSerializerError.Deserialize
        }

        while (true) {
            let key:String = try deserializeUTF8(false)
            guard key != "" else {
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
    func serialize(value:ASArray) -> Self {
        return self
    }

    func deserialize() throws -> ASArray {

        switch try readUInt8() {
        case Type.Null.rawValue:
            return ASArray()
        case Type.ECMAArray.rawValue:
            break
        default:
            throw AMFSerializerError.Deserialize
        }

        var result:ASArray = ASArray(count: Int(try readUInt32()))
        while (true) {
            let key:String = try deserializeUTF8(false)
            guard key != "" else {
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
    func serialize(value:[Any?]) -> Self {
        writeUInt8(Type.StrictArray.rawValue)
        if value.isEmpty {
            writeBytes([0x00, 0x00, 0x00, 0x00])
            return self
        }
        writeUInt32(UInt32(value.count))
        for v in value {
            serialize(v)
        }
        return self
    }
    
    func deserialize() throws -> [Any?] {
        guard try readUInt8() == Type.StrictArray.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        var result:[Any?] = []
        let count:Int = Int(try readUInt32())
        for _ in 0..<count {
            result.append(try deserialize())
        }
        return result
    }

    /**
     * @see 2.13 Date Type
     */
    func serialize(value:NSDate) -> Self {
        return writeUInt8(Type.Date.rawValue).writeDouble(value.timeIntervalSince1970 * 1000).writeBytes([0x00, 0x00])
    }

    func deserialize() throws -> NSDate {
        guard try readUInt8() == Type.Date.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        let date:NSDate = NSDate(timeIntervalSince1970: try readDouble() / 1000)
        position += 2 // timezone offset
        return date
    }

    /**
     * @see 2.17 XML Document Type
     */
    func serialize(value: ASXMLDocument) -> Self {
        return writeUInt8(Type.XmlDocument.rawValue).serializeUTF8(value.description, true)
    }

    func deserialize() throws -> ASXMLDocument {
        guard try readUInt8() == Type.XmlDocument.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        return ASXMLDocument(data: try deserializeUTF8(true))
    }

    private func serializeUTF8(value:String, _ isLong: Bool) -> Self {
        let utf8:[UInt8] = [UInt8](value.utf8)
        if (isLong) {
            writeUInt32(UInt32(utf8.count))
        } else {
            writeUInt16(UInt16(utf8.count))
        }
        return writeBytes(utf8)
    }

    private func deserializeUTF8(isLong:Bool) throws -> String {
        let length:Int = isLong ? Int(try readUInt32()) : Int(try readUInt16())
        return try readUTF8Bytes(length)
    }
}
