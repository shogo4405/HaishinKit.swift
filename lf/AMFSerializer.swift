import Foundation

public typealias ECMAObject = Dictionary<String, Any?>

public struct ECMAArray: ArrayLiteralConvertible, Printable {
    private var data:[Any?] = []
    private var dict:Dictionary<String, Any?> = [:]

    public subscript(i: Any) -> Any? {
        get {
            if let i:Int = i as? Int {
                return data[i]
            }
            if let i:String = i as? String {
                return dict[i]
            }
            return nil
        }
        set {
            if let i:Int = i as? Int {
                data[i] = newValue
            }
            if let i:String = i as? String {
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
    
    public init(data:[Any?]) {
        self.data = data
    }
    
    public init(arrayLiteral elements: Any?...) {
        self = ECMAArray(data: elements)
    }
}

protocol AMFSerializer {

    func serialize(value:Bool) -> [UInt8]
    func deserialize(bytes:[UInt8], inout position:Int) -> Bool

    func serialize(value:String) -> [UInt8]
    func deserialize(bytes:[UInt8], inout position:Int) -> String

    func serialize(value:Int) -> [UInt8]
    func deserialize(bytes:[UInt8], inout position:Int) -> Int

    func serialize(value:Double) -> [UInt8]
    func deserialize(bytes:[UInt8], inout position:Int) -> Double

    func serialize(value:NSDate) -> [UInt8]
    func deserialize(bytes:[UInt8], inout position:Int) -> NSDate

    func serialize(value:[Any?]) -> [UInt8]
    func deserialize(bytes:[UInt8], inout position:Int) -> [Any?]

    func serialize(value:ECMAArray) -> [UInt8]
    func deserialize(bytes:[UInt8], inout position:Int) -> ECMAArray

    func serialize(value:ECMAObject) -> [UInt8]
    func deserialize(bytes:[UInt8], inout position:Int) -> ECMAObject

    func serialize(value:Any?) -> [UInt8]
    func deserialize(bytes:[UInt8], inout position:Int) -> Any?
}

class SynchronizedArray<T:Comparable>: Printable {
    private var data:[T] = []

    var description:String {
        return data.description
    }

    func append(newElement:T) {
        objc_sync_enter(self)
        data.append(newElement)
        objc_sync_exit(self)
    }

    func appendIfAbsent(newElement:T) {
        var indexOf:Int = -1
        objc_sync_enter(self)
        for i in 0..<data.count {
            if (data[i] == newElement) {
                indexOf = i
                break
            }
        }
        if (indexOf == -1) {
            data.append(newElement)
        }
        objc_sync_exit(self)
    }

    func indexOf(value:T) -> Int {
        var indexOf:Int = -1
        objc_sync_enter(self)
        for i in 0..<data.count {
            if (data[i] == value) {
                indexOf = i
                break
            }
        }
        objc_sync_exit(self)
        return indexOf
    }

    subscript(index: Int) -> T {
        set {
            objc_sync_enter(self)
            data[index] = newValue
            objc_sync_exit(self)
        }
        get {
            var element:T!
            objc_sync_enter(self)
            element = data[index]
            objc_sync_exit(self)
            return element
        }
    }
}

class AMFReference: NSObject {
    var strings:SynchronizedArray<String> = SynchronizedArray<String>()
}

/**
 * AMF0Serializer
 * @reference http://wwwimages.adobe.com/content/dam/Adobe/en/devnet/amf/pdf/amf0-file-format-specification.pdf
 */
class AMF0Serializer:AMFSerializer {
    
    enum TYPE:UInt8 {
        case NUMBER      = 0x00
        case BOOL        = 0x01
        case STRING      = 0x02
        case OBJECT      = 0x03
        //  case MOVIECLIP   = 0x04
        case NULL        = 0x05
        case UNDEFINED   = 0x06
        case REFERENCE   = 0x07
        case ECMAARRAY   = 0x08
        case OBJECTTERM  = 0x09
        case STRICTARRAY = 0x0a
        case DATE        = 0x0b
        case LONGSTRING  = 0x0c
        case UNSUPPORTED = 0x0d
        //  case RECORDSET   = 0x0e
        case XML         = 0x0f
        case TYPEDOBJECT = 0x10
        case AVMPLUSH    = 0x11
    }

    func serialize(value:Any?) -> [UInt8] {
        
        if value == nil {
            return [TYPE.NULL.rawValue]
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
        case let value as Float32:
            return serialize(Double(value))
        case let value as Double:
            return serialize(Double(value))
        case let value as NSDate:
            return serialize(value)
        case let value as String:
            return serialize(value)
        case let value as Bool:
            return serialize(value)
        case let value as ECMAArray:
            return serialize(value)
        case let value as ECMAObject:
            return serialize(value)
        default:
            return [TYPE.UNDEFINED.rawValue]
        }
    }
    
    func deserialize(bytes: [UInt8], inout position: Int) -> Any? {
        switch bytes[position] {
        case TYPE.NUMBER.rawValue:
            return deserialize(bytes, position: &position) as Double
        case TYPE.BOOL.rawValue:
            return deserialize(bytes, position: &position) as Bool
        case TYPE.STRING.rawValue:
            return deserialize(bytes, position: &position) as String
        case TYPE.OBJECT.rawValue:
            return deserialize(bytes, position: &position) as ECMAObject
        case TYPE.NULL.rawValue:
            ++position
            return nil
        case TYPE.UNDEFINED.rawValue:
            ++position
            return TYPE.UNDEFINED
        case 0x07:
            return nil
        case TYPE.ECMAARRAY.rawValue:
            return deserialize(bytes, position: &position) as ECMAArray
        case 0x09:
            return nil
        case TYPE.STRICTARRAY.rawValue:
            return deserialize(bytes, position: &position) as [Any?]
        case 0x0b:
            return nil
        case 0x0c:
            return nil
        case 0x0d:
            return nil
        case 0x0b:
            return deserialize(bytes, position: &position) as NSDate
        case 0x0c:
            return deserialize(bytes, position: &position) as String
        case 0x0d:
            return TYPE.UNSUPPORTED
        default:
            return nil
        }
    }
    
    private func invalidDeserialize(type:TYPE, bytes:[UInt8], inout position: Int) -> Bool {
        if (bytes.count < position || bytes[position] != type.rawValue) {
            return true
        }
        ++position
        return false
    }
    
    private func serialize(value:String, longString: Bool) -> [UInt8] {
        var result:[UInt8] = []
        var buffer:[UInt8] = [UInt8](value.utf8)
        
        if (longString) {
            var len:Int32 = Int32(buffer.count)
            result += [UInt8(len >> 24), UInt8(len >> 16), UInt8(len >> 8), UInt8(len)]
        } else {
            var len:Int16 = Int16(buffer.count)
            result += [UInt8(len >> 8), UInt8(len)]
        }
        result += buffer
        
        return result
    }

    /**
     * @see 2.2 Number Type
     */
    func serialize(value:Double) -> [UInt8] {
        return [TYPE.NUMBER.rawValue] + value.bytes.reverse()
    }
    
    func deserialize(bytes:[UInt8], inout position:Int) -> Double {
        if (invalidDeserialize(TYPE.NUMBER, bytes: bytes, position: &position)) {
            assertionFailure()
            return 0
        }
        let start:Int = position
        position += sizeof(Double.self)
        return Double(bytes: Array(bytes[start..<position].reverse()))
    }
    
    func serialize(value:Int) -> [UInt8] {
        return serialize(Double(value))
    }
    
    func deserialize(bytes:[UInt8], inout position:Int) -> Int {
        let value:Double = deserialize(bytes, position: &position)
        return Int(value)
    }

    /**
     * @see 2.3 Boolean Type
     */
    func serialize(value:Bool) -> [UInt8] {
        return [TYPE.BOOL.rawValue, value ? 0x01 : 0x00]
    }
    
    func deserialize(bytes: [UInt8], inout position: Int) -> Bool {
        if (bytes.count < position || bytes[position] != TYPE.BOOL.rawValue) {
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
        let longString:Bool = Int32.max < Int32(count(value))
        return [longString ? TYPE.STRING.rawValue : TYPE.STRING.rawValue] + serialize(value, longString: longString)
    }
    
    func deserialize(bytes:[UInt8], inout position:Int) -> String {
        
        if (bytes.count < position) {
            return ""
        }
        
        switch bytes[position] {
        case TYPE.STRING.rawValue:
            ++position
            return deserialize(bytes, position: &position, longString: false)
        case TYPE.LONGSTRING.rawValue:
            ++position
            return deserialize(bytes, position: &position, longString: true)
        default:
            return ""
        }
    }

    /**
     * 2.5 Object Type
     * typealias ECMAObject = Dictionary<String, Any?>
     */
    func serialize(value:ECMAObject) -> [UInt8] {
        
        var bytes:[UInt8] = [TYPE.OBJECT.rawValue]
        for (key, data) in value {
            bytes += serialize(key, longString: false)
            bytes += serialize(data)
        }
        
        bytes += serialize("", longString: false)
        bytes.append(TYPE.OBJECTTERM.rawValue)
        
        return bytes
    }
    
    func deserialize(bytes: [UInt8], inout position: Int) -> ECMAObject {
        var result:ECMAObject = ECMAObject()
        
        if (bytes[position] == TYPE.NULL.rawValue) {
            ++position
            return result
        }
        
        if (invalidDeserialize(TYPE.OBJECT, bytes: bytes, position: &position)) {
            return result
        }
        
        while (true) {
            var key:String = deserialize(bytes, position: &position, longString: false)
            if (key == "") {
                ++position
                break
            }
            result[key] = deserialize(bytes, position: &position)
        }
        
        return result
    }

    /**
     * @see 2.10 ECMA Array Type
     */
    func serialize(value:ECMAArray) -> [UInt8] {
        return []
    }
    
    func deserialize(bytes: [UInt8], inout position: Int) -> ECMAArray {
        var result:ECMAArray = ECMAArray()
        
        if (bytes[position] == TYPE.NULL.rawValue) {
            ++position
            return result
        }
        
        if (invalidDeserialize(TYPE.ECMAARRAY, bytes: bytes, position: &position)) {
            return result
        }
        
        while (true) {
            var key:String = deserialize(bytes, position: &position, longString: false)
            if (key == "") {
                ++position
                break
            }
            result[key] = deserialize(bytes, position: &position)
        }
        
        return result
    }

    /**
     * @see 2.12 Strict Array Type
     */
    func serialize(value:[Any?]) -> [UInt8] {
        
        if (value.isEmpty) {
            return [TYPE.STRICTARRAY.rawValue, 0x00, 0x00, 0x00, 0x00]
        }

        var bytes:[UInt8] = [TYPE.STRICTARRAY.rawValue]
        let length:UInt32 = UInt32(value.count) + 1
        bytes += [UInt8(length >> 24), UInt8(length >> 16), UInt8(length >> 8), UInt8(length)]
        for v in value {
            bytes += serialize(v)
        }

        return bytes
    }
    
    func deserialize(bytes: [UInt8], inout position: Int) -> [Any?] {
        if (bytes[position] != TYPE.STRICTARRAY.rawValue) {
            assertionFailure()
            return []
        }
        ++position
        var result:[Any?] = []
        let start:Int = position
        position += sizeof(UInt32.self)
        let count:Int = Int(UInt32(bytes: Array(bytes[start..<position]).reverse()))
        for i in 0..<count {
            result.append(deserialize(bytes, position: &position))
        }
        return result
    }

    /**
     * @see 2.13 Date Type
     */
    func serialize(value:NSDate) -> [UInt8] {
        var bytes:[UInt8] = value.timeIntervalSince1970.bytes
        return [TYPE.DATE.rawValue] + bytes + [0x00, 0x00]
    }
    
    func deserialize(bytes: [UInt8], inout position: Int) -> NSDate {
        if (invalidDeserialize(TYPE.DATE, bytes: bytes, position: &position)) {
            return NSDate()
        }
        
        var data:Double = Double(bytes: Array(bytes[position...position + 7]))
        var date:NSDate = NSDate(timeIntervalSince1970: data)
        position += 7 + 2
        
        return date
    }

    private func deserialize(bytes:[UInt8], inout position:Int, longString:Bool) -> String {
        
        var length:Int = (Int(bytes[position]) << 8) | Int(bytes[++position])
        var start:Int = ++position
        position += length
        
        if (length == 0) {
            return ""
        }
        
        return String(bytes: Array(bytes[start...position - 1]), encoding: NSUTF8StringEncoding)!
    }
}

/**
 * AMF3 Serializer
 * @reference http://wwwimages.adobe.com/www.adobe.com/content/dam/Adobe/en/devnet/amf/pdf/amf-file-format-spec.pdf
 */
class AMF3Serializer:AMFSerializer {
    enum TYPE:UInt8 {
        case UNDEFINED    = 0x00
        case NULL         = 0x01
        case BOOL_FALSE   = 0x02
        case BOOL_TRUE    = 0x03
        case INTEGER      = 0x04
        case NUMBER       = 0x05
        case STRING       = 0x06
        case XML          = 0x07
        case DATE         = 0x08
        case ARRAY        = 0x09
        case OBJECT       = 0x0A
        case XMLSTRING    = 0x0B
        case BYTEARRAY    = 0x0C
        case VECTORINT    = 0x0D
        case VECTORUINT   = 0x0E
        case VECTORNUMBER = 0x0F
        case VECTOROBJECT = 0x10
        case DICTIONARY   = 0x11
    }

    var reference:AMFReference

    init () {
        reference = AMFReference()
    }

    init (reference:AMFReference) {
        self.reference = reference
    }

    func serialize(value:Any?) -> [UInt8] {
        
        if value == nil {
            return [TYPE.NULL.rawValue]
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
        case let value as Float32:
            return serialize(Double(value))
        case let value as Double:
            return serialize(Double(value))
        case let value as NSDate:
            return serialize(value)
        case let value as String:
            return serialize(value)
        case let value as Bool:
            return serialize(value)
        case let value as ECMAArray:
            return serialize(value)
        case let value as ECMAObject:
            return serialize(value)
        default:
            return [TYPE.UNDEFINED.rawValue]
        }
    }
    
    func deserialize(bytes:[UInt8], inout position:Int) -> Any? {
        switch bytes[position] {
        case TYPE.UNDEFINED.rawValue, TYPE.NULL.rawValue:
            ++position
            return nil
        case TYPE.BOOL_FALSE.rawValue:
            ++position
            return false
        case TYPE.BOOL_TRUE.rawValue:
            ++position
            return true
        case TYPE.INTEGER.rawValue:
            return deserialize(bytes, position: &position) as Int
        case TYPE.NUMBER.rawValue:
            return deserialize(bytes, position: &position) as Double
        case TYPE.STRING.rawValue:
            return deserialize(bytes, position: &position) as String
        case TYPE.XML.rawValue:
            assertionFailure("Unsupported")
            return nil
        case TYPE.DATE.rawValue:
            return deserialize(bytes, position: &position) as NSDate
        case TYPE.ARRAY.rawValue:
            return deserialize(bytes, position: &position) as ECMAArray
        case TYPE.OBJECT.rawValue:
            return deserialize(bytes, position: &position) as ECMAObject
        case TYPE.XMLSTRING.rawValue:
            assertionFailure("Unsupported")
            return nil
        case TYPE.BYTEARRAY.rawValue:
            assertionFailure("Unsupported")
            return nil
        case TYPE.VECTORINT.rawValue:
            assertionFailure("Unsupported")
            return nil
        case TYPE.VECTORNUMBER.rawValue:
            assertionFailure("Unsupported")
            return nil
        case TYPE.VECTOROBJECT.rawValue:
            assertionFailure("Unsupported")
            return nil
        case TYPE.DICTIONARY.rawValue:
            assertionFailure("Unsupported")
            return nil
        default:
            return nil
        }
    }

    /**
     * @see 3.4 false Type
     * @see 3.5 true type
     */
    func serialize(value:Bool) -> [UInt8] {
        return [value ? TYPE.BOOL_TRUE.rawValue: TYPE.BOOL_FALSE.rawValue]
    }
    
    func deserialize(bytes:[UInt8], inout position:Int) -> Bool {
        if (bytes.count < position) {
            return false
        }
        let byte:UInt8 = bytes[position]
        if (byte == TYPE.BOOL_TRUE.rawValue) {
            ++position
            return true
        }
        if (byte == TYPE.BOOL_FALSE.rawValue) {
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
        return [TYPE.INTEGER.rawValue] + serializeU29(value)
    }

    func deserialize(bytes:[UInt8], inout position:Int) -> Int {
        if (bytes[position] != TYPE.INTEGER.rawValue) {
            assertionFailure()
            return 0
        }
        ++position
        return deserializeU29(bytes, position: &position)
    }

    /**
     * @see 3.7 double type
     */
    func serialize(value:Double) -> [UInt8] {
        return [TYPE.NUMBER.rawValue] + value.bytes.reverse()
    }
    
    func deserialize(bytes:[UInt8], inout position:Int) -> Double {
        if (bytes.count < position || bytes[position] != TYPE.NUMBER.rawValue) {
            assertionFailure()
            return 0
        }
        let start:Int = ++position
        position += sizeof(Double.self)
        return Double(bytes: Array(bytes[start..<position].reverse()))
    }

    /**
     * @see 3.8 String type
     */
    func serialize(value:String) -> [UInt8] {
        return [TYPE.STRING.rawValue] + serializeUTF8(value)
    }
    
    func deserialize(bytes:[UInt8], inout position:Int) -> String {
        if (bytes[position] != TYPE.STRING.rawValue) {
            assertionFailure()
            return ""
        }
        ++position
        return deserializeUTF8(bytes, position: &position)
    }

    /**
     * @see 3.10 Date type
     */
    func serialize(value:NSDate) -> [UInt8] {
        return [TYPE.DATE.rawValue] + serializeU29(0x01) + value.timeIntervalSince1970.bytes
    }

    func deserialize(bytes:[UInt8], inout position:Int) -> NSDate {
        return NSDate()
    }

    /**
     * @see 3.11 Array type
     */
    func serialize(value:[Any?]) -> [UInt8] {
        var buffer:[UInt8] = [TYPE.ARRAY.rawValue]
        buffer += serializeU29(value.count << 1 | 0x01)
        for data in value {
            buffer += serialize(data)
        }
        return buffer
    }

    func deserialize(bytes:[UInt8], inout position:Int) -> [Any?] {
        return []
    }

    func serialize(value:ECMAArray) -> [UInt8] {
        var buffer:[UInt8] = [TYPE.ARRAY.rawValue]
        buffer += serializeU29((value.data.count + value.dict.count) << 1 | 0x01)

        for (key, data) in value.dict {
            buffer += serialize(key)
            buffer += serialize(data)
        }
        buffer += serialize("")
        
        for data in value.data {
            buffer += serialize(data)
        }

        return buffer
    }

    func deserialize(bytes: [UInt8], inout position: Int) -> ECMAArray {
        return ECMAArray()
    }

    /**
     * @see 3.12 Object type
     * typealias ECMAObject = Dictionary<String, Any?>
     */
    func serialize(value:ECMAObject) -> [UInt8] {
        return []
    }

    func deserialize(bytes:[UInt8], inout position:Int) -> ECMAObject {
        var result:ECMAObject = ECMAObject()
        return result
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

    private func deserializeU29(bytes: [UInt8], inout position: Int) -> Int {

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

        let indexOf:Int = reference.strings.indexOf(value)
        if (indexOf != -1) {
            return serializeU29(indexOf << 1)
        }

        let buffer:[UInt8] = [UInt8](value.utf8)
        let length:[UInt8] = serializeU29(buffer.count << 1 | 0x01)
        reference.strings.append(value)

        return length + buffer
    }

    private func deserializeUTF8(bytes: [UInt8], inout position: Int) -> String {
        var strref:Int = deserializeU29(bytes, position: &position)

        if (strref & 0x01 == 0) {
            strref = strref >> 1
            return reference.strings[strref]
        }

        let length:Int = strref >> 1
        let offset:Int = position

        if (length == 0) {
            return ""
        }

        position += length
        let string:String = String(bytes: Array(bytes[offset..<position]), encoding: NSUTF8StringEncoding)!
        reference.strings.appendIfAbsent(string)

        return string
    }
}
