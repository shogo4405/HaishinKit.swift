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
    var reference:AMFReference = AMFReference()

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
        guard let type:Type = Type(rawValue: try buffer.readUInt8()) else {
            throw AMFSerializerError.Deserialize
        }
        preDecrement(&buffer.position)
        switch type {
        case .Undefined, .Null:
            preIncrement(&buffer.position)
            return nil
        case .BoolFalse:
            return try deserialize() as Bool
        case .BoolTrue:
            return try deserialize() as Bool
        case .Integer:
            return try deserialize() as Int
        case .Number:
            return try deserialize() as Double
        case .String:
            return try deserialize() as String
        case .Xml:
            return try deserialize() as ASXMLDocument
        case .Date:
            return try deserialize() as NSDate
        case .Array:
            return try deserialize() as ASArray
        case .Object:
            return try deserialize() as ASObject
        case .XmlString:
            return try deserialize() as ASXML
        case .ByteArray:
            return try deserialize() as ByteArray
        case .VectorInt:
            return try deserialize() as [Int32]
        case .VectorUInt:
            return try deserialize() as [UInt32]
        case .VectorNumber:
            return try deserialize() as [Double]
        case .VectorObject:
            return try deserialize() as [Any?]
        case .Dictionary:
            assertionFailure("Unsupported")
            return nil
        }
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
        buffer.writeUInt8(Type.Number.rawValue).writeDouble(value)
        return self
    }

    func deserialize() throws -> Double {
        guard try buffer.readUInt8() == Type.Number.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        return try buffer.readDouble()
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
     * @see 3.9 XML type
     */
    func serialize(value: ASXMLDocument)  -> AMFSerializer {
        buffer.writeUInt8(Type.Xml.rawValue)
        if let index:Int = reference.indexOf(value) {
            return serializeU29(index << 1)
        }
        reference.objects.append(value)
        let utf8:[UInt8] = [UInt8](value.description.utf8)
        serialize(utf8.count << 1 | 0x01)
        buffer.writeBytes(utf8)
        return self
    }

    func deserialize() throws -> ASXMLDocument {
        guard try buffer.readUInt8() == Type.Xml.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        let refs:Int = try deserializeU29()
        if (refs & 0x01) == 0 {
            guard let document:ASXMLDocument = try reference.getObject(refs >> 1) as? ASXMLDocument else {
                throw AMFSerializerError.Deserialize
            }
            return document
        }
        return ASXMLDocument(data: "string")
    }
    
    /**
     * @see 3.10 Date type
     */
    func serialize(value:NSDate) -> AMFSerializer {
        buffer.writeUInt8(Type.Date.rawValue)
        if let index:Int = reference.indexOf(value) {
            return serializeU29(index << 1)
        }
        reference.objects.append(value)
        serializeU29(0x01)
        buffer.writeDouble(value.timeIntervalSince1970 * 1000)
        return self
    }

    func deserialize() throws -> NSDate {
        guard try buffer.readUInt8() == Type.Date.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        let refs:Int = try deserializeU29()
        if (refs & 0x01) == 0 {
            guard let date:NSDate = try reference.getObject(refs >> 1) as? NSDate else {
                throw AMFSerializerError.Deserialize
            }
            return date
        }
        let date:NSDate = NSDate(timeIntervalSince1970: try buffer.readDouble() / 1000)
        reference.objects.append(date)
        return date
    }

    /**
     * @see 3.11 Array type
     */
    func serialize(value: ASArray) -> AMFSerializer {
        buffer.writeUInt8(Type.Array.rawValue)
        if let index:Int = reference.indexOf(value) {
            return serializeU29(index << 1)
        }
        reference.objects.append(value)
        serialize(value.length << 1 | 0x01)
        for (key, value) in value.dict {
            serialize(key).serialize(value)
        }
        serialize("")
        for value in value.data {
            serialize(value)
        }
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
        buffer.writeUInt8(Type.Object.rawValue)
        if let index:Int = reference.indexOf(value) {
            return serializeU29(index << 1)
        }
        reference.objects.append(value)
        for (key, value) in value {
            serialize(key).serialize(value)
        }
        return serialize("")
    }

    func deserialize() throws -> ASObject {
        guard try buffer.readUInt8() == Type.Object.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        return ASObject()
    }

    func serialize(value: ASXML) -> AMFSerializer {
        buffer.writeUInt8(Type.XmlString.rawValue)
        if let index:Int = reference.indexOf(value) {
            return serializeU29(index << 1)
        }
        reference.objects.append(value)
        serializeU29(0x01)
        return self
    }

    func deserialize() throws -> ASXML {
        guard try buffer.readUInt8() == Type.Xml.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        return ASXML(data: "")
    }

    func serialize(value: ByteArray) -> AMFSerializer {
        return self
    }

    func deserialize() throws -> ByteArray {
        return ByteArray()
    }

    /**
     * Vector<Int>()
     */
    func serialize(value:[Int32]) -> AMFSerializer {
        buffer.writeUInt8(Type.VectorInt.rawValue)
        return self
    }
    
    func deserialize() throws -> [Int32] {
        guard try buffer.readUInt8() == Type.VectorInt.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        return []
    }

    /**
     * Vector<UInt>()
     */
    func serialize(value:[UInt32]) -> AMFSerializer {
        buffer.writeUInt8(Type.VectorUInt.rawValue)
        return self
    }

    func deserialize() throws -> [UInt32] {
        guard try buffer.readUInt8() == Type.VectorUInt.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        return []
    }

    /**
     * Vector<Number>()
     */
    func serialize(value:[Double]) -> AMFSerializer {
        buffer.writeUInt8(Type.VectorNumber.rawValue)
        return self
    }

    func deserialize() throws -> [Double] {
        guard try buffer.readUInt8() == Type.VectorNumber.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        return []
    }

    /**
     * Vector<Object>()
     */
    func serialize(value:[Any?]) -> AMFSerializer {
        buffer.writeUInt8(Type.Array.rawValue)
        return self
    }

    func deserialize() throws -> [Any?] {
        guard try buffer.readUInt8() == Type.Array.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        return []
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
            buffer
                .writeUInt8(UInt8(value >> 7 | 0x80))
                .writeUInt8(UInt8(value & 0x7F))
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
            preIncrement(&count)
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
        if (value.isEmpty) {
            return serializeU29(0x01)
        }
        if let index:Int = reference.indexOf(value) {
            return serializeU29(index << 1)
        }
        let utf8:[UInt8] = [UInt8](value.utf8)
        reference.strings.append(value)
        serializeU29(utf8.count << 1 | 0x01)
        buffer.writeBytes(utf8)
        return self
    }

    private func deserializeUTF8() throws -> String {
        let ref:Int = try deserializeU29()
        if (ref & 0x01) == 0 {
            return try reference.getString(ref >> 1)
        }
        guard let length:Int = ref >> 1 where length != 0 else {
            return ""
        }
        let string:String = try buffer.readUTF8Bytes(length)
        reference.strings.append(string)
        return string
    }
}
