import Foundation


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
    
    var buffer:ByteArray = ByteArray()
    
    func serialize(value:Any?) -> AMFSerializer {
        
        if value == nil {
            buffer.writeUInt8(Type.Null.rawValue)
            return self
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
            buffer.writeUInt8(Type.Undefined.rawValue)
            return self
        }
    }
    
    func deserialize() throws -> Any? {
        switch try buffer.readUInt8() {
        case Type.Undefined.rawValue, Type.Null.rawValue:
            return nil
        case Type.BoolFalse.rawValue:
            return try deserialize() as Bool
        case Type.BoolTrue.rawValue:
            return try deserialize() as Bool
        case Type.Integer.rawValue:
            return try deserialize() as Int
        case Type.Number.rawValue:
            return try deserialize() as Double
        case Type.String.rawValue:
            return try deserialize() as String
        case Type.Xml.rawValue:
            assertionFailure("Unsupported")
            return nil
        case Type.Date.rawValue:
            return try deserialize() as NSDate
        case Type.Array.rawValue:
            return try deserialize() as ASArray
        case Type.Object.rawValue:
            return try deserialize() as ASObject
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
    
    func serialize(value: ASXMLDocument) -> AMFSerializer {
        return self
    }
    
    func deserialize() -> ASXMLDocument {
        return ASXMLDocument(data: "string")
    }
    
    /**
     * @see 3.4 false Type
     * @see 3.5 true type
     */
    func serialize(value:Bool) -> AMFSerializer {
        buffer.writeUInt8(value ? Type.BoolTrue.rawValue: Type.BoolFalse.rawValue)
        return self
    }
    
    func deserialize() throws -> Bool {
        return try buffer.readUInt8() == 1
    }
    
    /**
     * @see 3.6 integer type
     */
    func serialize(value:Int) -> AMFSerializer {
        buffer.writeUInt8(Type.Integer.rawValue)
        return serializeU29(value)
    }
    
    func deserialize() throws -> Int {
        guard try buffer.readUInt8() == Type.Integer.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        return try deserializeU29()
    }
    
    /**
     * @see 3.7 double type
     */
    func serialize(value:Double) -> AMFSerializer {
        return self
    }
    
    func deserialize() throws -> Double {
        guard try buffer.readUInt8() == Type.Number.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        return 0
    }
    
    /**
     * @see 3.8 String type
     */
    func serialize(value:String) -> AMFSerializer {
        buffer.writeUInt8(Type.String.rawValue)
        return serializeUTF8(value)
    }
    
    func deserialize() throws -> String {
        guard try buffer.readUInt8() == Type.String.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        return try deserializeUTF8()
    }
    
    /**
     * @see 3.10 Date type
     */
    func serialize(value:NSDate) -> AMFSerializer {
        return self
    }
    
    func deserialize() throws -> NSDate {
        guard try buffer.readUInt8() == Type.Date.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        return NSDate()
    }
    
    /**
     * @see 3.11 Array type
     */
    func serialize(value:[Any?]) -> AMFSerializer {
        return self
    }
    
    func deserialize() throws -> [Any?] {
        guard try buffer.readUInt8() == Type.Array.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        return []
    }
    
    func serialize(value: ASArray) -> AMFSerializer {
        return self
    }
    
    func deserialize() throws -> ASArray {
        guard try buffer.readUInt8() == Type.Array.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        return ASArray()
    }
    
    /**
     * @see 3.12 Object type
     * typealias ECMAObject = Dictionary<String, Any?>
     */
    func serialize(value: ASObject) -> AMFSerializer {
        return self
    }
    
    func deserialize() throws -> ASObject {
        guard try buffer.readUInt8() == Type.Object.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        return ASObject()
    }
    
    /**
     * @see 1.3.1 Variable Length Unsigned 29-bit Integer Encoding
     */
    private func serializeU29(value:Int) -> AMFSerializer {
        if (value < Int(Int32.min) || Int(Int32.max) < value) {
            // is error better?
            return serialize(Double(value))
        }
        
        let value:UInt32 = UInt32(value)
        
        if (value & 0xFFFFFF80 == 0) {
            buffer.writeUInt8(UInt8(value & 0x7f))
            return self
        }
        
        if (value & 0xFFFFC000 == 0) {
            buffer.writeBytes([
                UInt8(value >> 7 | 0x80),
                UInt8(value & 0x7F)
                ])
            return self
        }
        
        if (value & 0xFFE00000 == 0) {
            buffer
                .writeUInt8(UInt8(value >> 14 | 0x80))
                .writeUInt8(UInt8(value >> 7 | 0x80))
                .writeUInt8(UInt8(value & 0x7F))
            return self
        }
        
        buffer
            .writeUInt8(UInt8(value >> 22 | 0x80))
            .writeUInt8(UInt8(value >> 15 | 0x80))
            .writeUInt8(UInt8(value >> 8 | 0x80))
            .writeUInt8(UInt8(value & 0xFF))
        
        return self
    }
    
    private func deserializeU29() throws -> Int {
        
        var count:Int = 1
        var result:Int = 0
        var byte:UInt8 = try buffer.readUInt8()
        
        while (byte & 0x80 != 0 && count < 4) {
            result <<= 7
            result |= Int(byte & 0x7F)
            byte = try buffer.readUInt8()
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
    private func serializeUTF8(value:String) -> AMFSerializer {
        guard !value.isEmpty else {
            return serializeU29(0x01)
        }
        let utf8:[UInt8] = [UInt8](value.utf8)
        serializeU29(utf8.count << 1 | 0x01)
        buffer.writeBytes(utf8)
        return self
    }
    
    private func deserializeUTF8() throws -> String {
        let strref:Int = try deserializeU29()
        let length:Int = strref >> 1
        return try buffer.readUTF8Bytes(length)
    }
}
