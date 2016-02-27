import Foundation

public let kASUndefined:ASUndefined = ASUndefined()

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

public class ASUndefined: CustomStringConvertible {

    public var description:String {
        return "undefined"
    }

    private init() {
    }
}

public struct ASArray: ArrayLiteralConvertible, CustomStringConvertible {
    private var data:[Any?]
    private var dict:[String: Any?] = [:]

    public subscript(i: Any) -> Any? {
        get {
            if let i:Int = i as? Int {
                return i < data.count ? data[i] : kASUndefined
            }
            if let i:String = i as? String {
                if let i:Int = Int(i) {
                    return i < data.count ? data[i] : kASUndefined
                }
                return dict[i]
            }
            return nil
        }
        set {
            if let i:Int = i as? Int {
                if (data.count <= i) {
                    data += [Any?](count: i - data.count + 1, repeatedValue: kASUndefined)
                }
                data[i] = newValue
            }
            if let i:String = i as? String {
                if let i:Int = Int(i) {
                    if (data.count <= i) {
                        data += [Any?](count: i - data.count + 1, repeatedValue: kASUndefined)
                    }
                    data[i] = newValue
                    return
                }
                dict[i] = newValue
            }
        }
    }

    public var description:String {
        return data.description
    }

    public var length:Int {
        return data.count
    }

    public init(count:Int) {
        self.data = [Any?](count: count, repeatedValue: kASUndefined)
    }

    public init(data:[Any?]) {
        self.data = data
    }

    public init (arrayLiteral elements: Any?...) {
        self = ASArray(data: elements)
    }
}

public typealias ASObject = [String: Any?]
public typealias ECMAObject = ASObject

/**
 * ActionScript 1.0 and 2.0 and flash.xml.XMLDocument in ActionScript 3.0
 * @see 2.17 XML Document Type (amf0-file-format-specification.pdf)
 * @see 3.9 XMLDocument type (amf-file-format-spec.pdf)
 */
public struct ASXMLDocument: CustomStringConvertible {
    private var data:String
    
    public var description:String {
        return data
    }
    
    public init (data:String) {
        self.data = data
    }
}

/**
 * ActionScript 3.0 introduces a new XML type.
 * @see 3.13 XML type (amf-file-format-spec.pdf)
 */
public struct ASXML: CustomStringConvertible {
    private var data:String
    
    public var description:String {
        return data
    }
    
    public init (data:String) {
        self.data = data
    }
}

protocol AMFSerializer {
    func serialize(value:Bool) -> [UInt8]
    func deserialize(inout bytes:[UInt8], inout _ position:Int) -> Bool

    func serialize(value:String) -> [UInt8]
    func deserialize(inout bytes:[UInt8], inout _ position:Int) -> String

    func serialize(value:Int) -> [UInt8]
    func deserialize(inout bytes:[UInt8], inout _ position:Int) -> Int

    func serialize(value:Double) -> [UInt8]
    func deserialize(inout bytes:[UInt8], inout _ position:Int) -> Double

    func serialize(value:NSDate) -> [UInt8]
    func deserialize(inout bytes:[UInt8], inout _ position:Int) -> NSDate

    func serialize(value:[Any?]) -> [UInt8]
    func deserialize(inout bytes:[UInt8], inout _ position:Int) -> [Any?]

    func serialize(value: ASArray) -> [UInt8]
    func deserialize(inout bytes:[UInt8], inout _ position:Int) -> ASArray

    func serialize(value: ASObject) -> [UInt8]
    func deserialize(inout bytes:[UInt8], inout _ position:Int) -> ASObject

    func serialize(value: ASXMLDocument) -> [UInt8]
    func deserialize(inout bytes:[UInt8], inout _ position:Int) -> ASXMLDocument

    func serialize(value:Any?) -> [UInt8]
    func deserialize(inout bytes:[UInt8], inout _ position:Int) -> Any?
}

/**
 * AMF0Serializer
 * @reference http://wwwimages.adobe.com/content/dam/Adobe/en/devnet/amf/pdf/amf0-file-format-specification.pdf
 */
class AMF0Serializer:AMFSerializer {
    
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

    func serialize(value:Any?) -> [UInt8] {
        if value == nil {
            return [Type.Null.rawValue]
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
            return [Type.Undefined.rawValue]
        }
    }

    func deserialize(inout bytes: [UInt8], inout _ position: Int) -> Any? {
        switch bytes[position] {
        case Type.Number.rawValue:
            return deserialize(&bytes, &position) as Double
        case Type.Bool.rawValue:
            return deserialize(&bytes, &position) as Bool
        case Type.String.rawValue:
            return deserialize(&bytes, &position) as String
        case Type.Object.rawValue:
            return deserialize(&bytes, &position) as ASObject
        case Type.Null.rawValue:
            ++position
            return nil
        case Type.Undefined.rawValue:
            ++position
            return Type.Undefined
        case Type.Reference.rawValue:
            assertionFailure("TODO")
            return nil
        case Type.ECMAArray.rawValue:
            return deserialize(&bytes, &position) as ASArray
        case Type.ObjectEnd.rawValue:
            assertionFailure()
            return nil
        case Type.StrictArray.rawValue:
            return deserialize(&bytes, &position) as [Any?]
        case Type.Date.rawValue:
            return deserialize(&bytes, &position) as NSDate
        case Type.LongString.rawValue:
            return deserialize(&bytes, &position) as String
        case Type.Unsupported.rawValue:
            assertionFailure("Unsupported")
            return nil
        case Type.XmlDocument.rawValue:
            return deserialize(&bytes, &position) as ASXMLDocument
        case Type.TypedObject.rawValue:
            assertionFailure("TODO")
            return nil
        case Type.Avmplush.rawValue:
            assertionFailure("TODO")
            return nil
        default:
            assertionFailure("Unknown")
            return nil
        }
    }

    /**
     * @see 2.2 Number Type
     */
    func serialize(value:Double) -> [UInt8] {
        return [Type.Number.rawValue] + Array(value.bytes.reverse())
    }
    
    func deserialize(inout bytes:[UInt8], inout _ position:Int) -> Double {
        if (bytes.count < position || bytes[position] != Type.Number.rawValue) {
            assertionFailure()
            return 0
        }
        let start:Int = ++position
        position += sizeof(Double.self)
        return Double(bytes: Array(Array(bytes[start..<position].reverse())))
    }
    
    func serialize(value:Int) -> [UInt8] {
        return serialize(Double(value))
    }

    func deserialize(inout bytes:[UInt8], inout _ position:Int) -> Int {
        return Int(deserialize(&bytes, &position) as Double)
    }

    /**
     * @see 2.3 Boolean Type
     */
    func serialize(value:Bool) -> [UInt8] {
        return [Type.Bool.rawValue, value ? 0x01 : 0x00]
    }
    
    func deserialize(inout bytes: [UInt8], inout _ position: Int) -> Bool {
        if (bytes.count < position || bytes[position] != Type.Bool.rawValue) {
            assertionFailure()
            return false
        }
        ++position
        return bytes[position++] == 0x01 ? true : false
    }

    /**
     * @see 2.4 String Type
     */
    func serialize(value:String) -> [UInt8] {
        let isLong:Bool = UInt32(UInt16.max) < UInt32(value.characters.count)
        return [isLong ? Type.LongString.rawValue : Type.String.rawValue] + serializeUTF8(value, isLong)
    }
    
    func deserialize(inout bytes:[UInt8], inout _ position:Int) -> String {
        if (bytes.count < position) {
            assertionFailure()
            return ""
        }
        switch bytes[position] {
        case Type.String.rawValue:
            ++position
            return deserializeUTF8(&bytes, &position, false)
        case Type.LongString.rawValue:
            ++position
            return deserializeUTF8(&bytes, &position, true)
        default:
            assertionFailure()
            return ""
        }
    }

    /**
     * 2.5 Object Type
     * typealias ECMAObject = Dictionary<String, Any?>
     */
    func serialize(value: ASObject) -> [UInt8] {
        var bytes:[UInt8] = [Type.Object.rawValue]
        for (key, data) in value {
            bytes += serializeUTF8(key, false)
            bytes += serialize(data)
        }
        bytes += serializeUTF8("", false)
        bytes.append(Type.ObjectEnd.rawValue)
        return bytes
    }

    func deserialize(inout bytes: [UInt8], inout _ position: Int) -> ASObject {
        var result:ASObject = ASObject()
        if (bytes.count < position) {
            assertionFailure()
            return result
        }
        if (bytes[position] == Type.Null.rawValue) {
            ++position
            return result
        }
        if (bytes[position] != Type.Object.rawValue) {
            assertionFailure()
            return result
        }
        ++position
        while (true) {
            let key:String = deserializeUTF8(&bytes, &position, false)
            if (key == "") {
                ++position
                break
            }
            result[key] = deserialize(&bytes, &position)
        }
        return result
    }

    /**
     * @see 2.10 ECMA Array Type
     */
    func serialize(value: ASArray) -> [UInt8] {
        return []
    }
    
    func deserialize(inout bytes: [UInt8], inout _ position: Int) -> ASArray {
    
        if (bytes.count < position) {
            assertionFailure()
            return ASArray()
        }
        
        if (bytes[position] == Type.Null.rawValue) {
            ++position
            return ASArray()
        }
        if (bytes[position] != Type.ECMAArray.rawValue) {
            assertionFailure()
            return ASArray()
        }

        ++position
        var result:ASArray = ASArray(count: Int(UInt32(bytes: Array(bytes[position..<position + 4])).bigEndian))
        position += 4
        while (true) {
            let key:String = deserializeUTF8(&bytes, &position, false)
            if (key == "") {
                ++position
                break
            }
            result[key] = deserialize(&bytes, &position)
        }

        return result
    }

    /**
     * @see 2.12 Strict Array Type
     */
    func serialize(value:[Any?]) -> [UInt8] {
        if (value.isEmpty) {
            return [Type.StrictArray.rawValue, 0x00, 0x00, 0x00, 0x00]
        }
        var bytes:[UInt8] = [Type.StrictArray.rawValue]
        let length:UInt32 = UInt32(value.count) + 1
        bytes += [UInt8(length >> 24), UInt8(length >> 16), UInt8(length >> 8), UInt8(length)]
        for v in value {
            bytes += serialize(v)
        }
        return bytes
    }
    
    func deserialize(inout bytes: [UInt8], inout _ position: Int) -> [Any?] {
        if (bytes[position] != Type.StrictArray.rawValue) {
            assertionFailure()
            return []
        }
        ++position
        var result:[Any?] = []
        let start:Int = position
        position += sizeof(UInt32.self)
        let count:Int = Int(UInt32(bytes: Array(Array(bytes[start..<position]).reverse())))
        for _ in 0..<count {
            result.append(deserialize(&bytes, &position))
        }
        return result
    }

    /**
     * @see 2.13 Date Type
     */
    func serialize(value:NSDate) -> [UInt8] {
        let bytes:[UInt8] = value.timeIntervalSince1970.bytes.reverse()
        return [Type.Date.rawValue] + bytes + [0x00, 0x00]
    }

    func deserialize(inout bytes: [UInt8], inout _ position: Int) -> NSDate {
        guard position <= bytes.count && Type.Date.rawValue == bytes[position] else {
            assertionFailure()
            return NSDate()
        }

        let start:Int = ++position
        position += sizeof(Double.self)
        let date:NSDate = NSDate(timeIntervalSince1970: Double(bytes: Array(bytes[start..<position]).reverse()) / 1000)
        position += 2 // timezone offset

        return date
    }

    /**
     * @see 2.17 XML Document Type
     */
    func serialize(value: ASXMLDocument) -> [UInt8] {
        return [Type.XmlDocument.rawValue] + serializeUTF8(value.description, true)
    }

    func deserialize(inout bytes: [UInt8], inout _ position:Int) -> ASXMLDocument {
        guard position <= bytes.count && Type.XmlDocument.rawValue == bytes[position] else {
            assertionFailure()
            return ASXMLDocument(data: "")
        }
        ++position
        return ASXMLDocument(data: deserializeUTF8(&bytes, &position, true))
    }

    private func serializeUTF8(value:String, _ isLong: Bool) -> [UInt8] {
        let buffer:[UInt8] = [UInt8](value.utf8)
        if (isLong) {
            let length:UInt32 = UInt32(buffer.count).bigEndian
            return length.bytes + buffer
        }
        let length:UInt16 = UInt16(buffer.count).bigEndian
        return length.bytes + buffer
    }

    private func deserializeUTF8(inout bytes:[UInt8], inout _ position:Int, _ isLong:Bool) -> String {
        var start:Int = position
        position += isLong ? sizeof(UInt32.self) : sizeof(UInt16.self)
        let length:Int = isLong ?
            Int(UInt32(bytes: Array(bytes[start..<position])).bigEndian) :
            Int(UInt16(bytes: Array(bytes[start..<position])).bigEndian)
        start = position
        position += length
        return String(bytes: Array(bytes[start..<position]), encoding: NSUTF8StringEncoding)!
    }
}

/**
 * AMF3 Serializer
 * @reference http://wwwimages.adobe.com/www.adobe.com/content/dam/Adobe/en/devnet/amf/pdf/amf-file-format-spec.pdf
 */
class AMF3Serializer: AMFSerializer {
    enum Type:UInt8 {
        case Undefined    = 0x00
        case Null         = 0x01
        case BoolFalse    = 0x02
        case BoolTrue     = 0x03
        case Integer      = 0x04
        case Number       = 0x05
        case String       = 0x06
        case Xml          = 0x07
        case Date         = 0x08
        case Array        = 0x09
        case Object       = 0x0A
        case XmlString    = 0x0B
        case ByteArray    = 0x0C
        case VectorInt    = 0x0D
        case VectorUInt   = 0x0E
        case VectorNumber = 0x0F
        case VectorObject = 0x10
        case Dictionary   = 0x11
    }

    func serialize(value:Any?) -> [UInt8] {
        
        if value == nil {
            return [Type.Null.rawValue]
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
            return [Type.Undefined.rawValue]
        }
    }
    
    func deserialize(inout bytes:[UInt8], inout _ position:Int) -> Any? {
        switch bytes[position] {
        case Type.Undefined.rawValue, Type.Null.rawValue:
            ++position
            return nil
        case Type.BoolFalse.rawValue:
            ++position
            return false
        case Type.BoolTrue.rawValue:
            ++position
            return true
        case Type.Integer.rawValue:
            return deserialize(&bytes, &position) as Int
        case Type.Number.rawValue:
            return deserialize(&bytes, &position) as Double
        case Type.String.rawValue:
            return deserialize(&bytes, &position) as String
        case Type.Xml.rawValue:
            assertionFailure("Unsupported")
            return nil
        case Type.Date.rawValue:
            return deserialize(&bytes, &position) as NSDate
        case Type.Array.rawValue:
            return deserialize(&bytes, &position) as ASArray
        case Type.Object.rawValue:
            return deserialize(&bytes, &position) as ASObject
        case Type.XmlString.rawValue:
            assertionFailure("Unsupported")
            return nil
        case Type.ByteArray.rawValue:
            assertionFailure("Unsupported")
            return nil
        case Type.VectorInt.rawValue:
            assertionFailure("Unsupported")
            return nil
        case Type.VectorNumber.rawValue:
            assertionFailure("Unsupported")
            return nil
        case Type.VectorObject.rawValue:
            assertionFailure("Unsupported")
            return nil
        case Type.Dictionary.rawValue:
            assertionFailure("Unsupported")
            return nil
        default:
            return nil
        }
    }

    func serialize(value: ASXMLDocument) -> [UInt8] {
        return []
    }
    
    func deserialize(inout bytes:[UInt8], inout _ position:Int) -> ASXMLDocument {
        return ASXMLDocument(data: "string")
    }

    /**
     * @see 3.4 false Type
     * @see 3.5 true type
     */
    func serialize(value:Bool) -> [UInt8] {
        return [value ? Type.BoolTrue.rawValue: Type.BoolFalse.rawValue]
    }
    
    func deserialize(inout bytes:[UInt8], inout _ position:Int) -> Bool {
        if (bytes.count < position) {
            return false
        }
        let byte:UInt8 = bytes[position]
        if (byte == Type.BoolTrue.rawValue) {
            ++position
            return true
        }
        if (byte == Type.BoolFalse.rawValue) {
            ++position
            return false
        }
        assertionFailure()
        return false
    }

    /**
     * @see 3.6 integer type
     */
    func serialize(value:Int) -> [UInt8] {
        return [Type.Integer.rawValue] + serializeU29(value)
    }

    func deserialize(inout bytes:[UInt8], inout _ position:Int) -> Int {
        if (bytes[position] != Type.Integer.rawValue) {
            assertionFailure()
            return 0
        }
        ++position
        return deserializeU29(&bytes, position: &position)
    }

    /**
     * @see 3.7 double type
     */
    func serialize(value:Double) -> [UInt8] {
        return [Type.Number.rawValue] + Array(value.bytes.reverse())
    }
    
    func deserialize(inout bytes:[UInt8], inout _ position:Int) -> Double {
        if (bytes.count < position || bytes[position] != Type.Number.rawValue) {
            assertionFailure()
            return 0
        }
        let start:Int = ++position
        position += sizeof(Double.self)
        return Double(bytes: Array(Array(bytes[start..<position].reverse())))
    }

    /**
     * @see 3.8 String type
     */
    func serialize(value:String) -> [UInt8] {
        return [Type.String.rawValue] + serializeUTF8(value)
    }
    
    func deserialize(inout bytes:[UInt8], inout _ position:Int) -> String {
        if (bytes[position] != Type.String.rawValue) {
            assertionFailure()
            return ""
        }
        ++position
        return deserializeUTF8(&bytes, position: &position)
    }

    /**
     * @see 3.10 Date type
     */
    func serialize(value:NSDate) -> [UInt8] {
        return [Type.Date.rawValue] + serializeU29(0x01) + value.timeIntervalSince1970.bytes
    }

    func deserialize(inout bytes:[UInt8], inout _ position:Int) -> NSDate {
        return NSDate()
    }

    /**
     * @see 3.11 Array type
     */
    func serialize(value:[Any?]) -> [UInt8] {
        var buffer:[UInt8] = [Type.Array.rawValue]
        buffer += serializeU29(value.count << 1 | 0x01)
        for data in value {
            buffer += serialize(data)
        }
        return buffer
    }

    func deserialize(inout bytes:[UInt8], inout _ position:Int) -> [Any?] {
        return []
    }

    func serialize(value: ASArray) -> [UInt8] {
        let buffer:[UInt8] = [Type.Array.rawValue]
        return buffer
    }

    func deserialize(inout bytes: [UInt8], inout _ position: Int) -> ASArray {
        return ASArray()
    }

    /**
     * @see 3.12 Object type
     * typealias ECMAObject = Dictionary<String, Any?>
     */
    func serialize(value: ASObject) -> [UInt8] {
        return []
    }

    func deserialize(inout bytes:[UInt8], inout _ position:Int) -> ASObject {
        return ASObject()
    }

    /**
     * @see 1.3.1 Variable Length Unsigned 29-bit Integer Encoding
     */
    private func serializeU29(value:Int) -> [UInt8] {
        if (value < Int(Int32.min) || Int(Int32.max) < value) {
            // is error better?
            return serialize(Double(value))
        }
        
        let value:UInt32 = UInt32(value)
        
        if (value & 0xFFFFFF80 == 0) {
            return [
                UInt8(value & 0x7f)
            ]
        }
        
        if (value & 0xFFFFC000 == 0) {
            return [
                UInt8(value >> 7 | 0x80),
                UInt8(value & 0x7F)
            ]
        }
        
        if (value & 0xFFE00000 == 0) {
            return [
                UInt8(value >> 14 | 0x80),
                UInt8(value >> 7 | 0x80),
                UInt8(value & 0x7F)
            ]
        }
        
        return [
            UInt8(value >> 22 | 0x80),
            UInt8(value >> 15 | 0x80),
            UInt8(value >> 8 | 0x80),
            UInt8(value & 0xFF)
        ]
    }

    private func deserializeU29(inout bytes: [UInt8], inout position: Int) -> Int {

        var count:Int = 1
        var result:Int = 0
        var byte:UInt8 = bytes[position++]

        while (byte & 0x80 != 0 && count < 4) {
            result <<= 7
            result |= Int(byte & 0x7F)
            byte = bytes[position++]
            ++count
        }

        if (count < 4) {
            result <<= 7
            result |= Int(byte)
        } else {
            result <<= 8
            result |= Int(byte)
        }

        return result
    }

    /**
     * @see 1.3.2 Strings and UTF-8
     */
    private func serializeUTF8(value:String) -> [UInt8] {
        if (value.isEmpty) {
            return serializeU29(0x01)
        }

        let buffer:[UInt8] = [UInt8](value.utf8)
        let length:[UInt8] = serializeU29(buffer.count << 1 | 0x01)

        return length + buffer
    }

    private func deserializeUTF8(inout bytes: [UInt8], inout position: Int) -> String {
        let strref:Int = deserializeU29(&bytes, position: &position)

        let length:Int = strref >> 1
        let offset:Int = position

        if (length == 0) {
            return ""
        }

        position += length
        let string:String = String(bytes: Array(bytes[offset..<position]), encoding: NSUTF8StringEncoding)!
        
        return string
    }
}
