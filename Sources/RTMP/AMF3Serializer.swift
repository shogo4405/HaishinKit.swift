import Foundation

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

    func indexOf(value: [Int32]) -> Int? {
        return nil
    }

    func indexOf(value: [UInt32]) -> Int? {
        return nil
    }

    func indexOf(value: [Double]) -> Int? {
        return nil
    }

    func indexOf(value: [Any?]) -> Int? {
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

// MARK: -
/**
 AMF3 Serializer

 - seealso: http://wwwimages.adobe.com/www.adobe.com/content/dam/Adobe/en/devnet/amf/pdf/amf-file-format-spec.pdf
 */
class AMF3Serializer: ByteArray {
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

    var reference:AMFReference = AMFReference()
}

// MARK: AMFSerializer
extension AMF3Serializer: AMFSerializer {

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
            throw AMFSerializerError.Deserialize
        }
        position -= 1
        switch type {
        case .Undefined:
            position += 1
            return kASUndefined
        case .Null:
            position += 1
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
     - seealso: 3.4 false Type
     - seealso: 3.5 true type
     */
    func serialize(value:Bool) -> Self {
        return writeUInt8(value ? Type.BoolTrue.rawValue: Type.BoolFalse.rawValue)
    }

    func deserialize() throws -> Bool {
        switch try readUInt8() {
        case Type.BoolTrue.rawValue:
            return true
        case Type.BoolFalse.rawValue:
            return false
        default:
            throw AMFSerializerError.Deserialize
        }
    }

    /**
     - seealso: 3.6 integer type
     */
    func serialize(value:Int) -> Self {
        return writeUInt8(Type.Integer.rawValue).serializeU29(value)
    }
    
    func deserialize() throws -> Int {
        guard try readUInt8() == Type.Integer.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        return try deserializeU29()
    }
    
    /**
     - seealso: 3.7 double type
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

    /**
     - seealso: 3.8 String type
     */
    func serialize(value:String) -> Self {
        return writeUInt8(Type.String.rawValue).serializeUTF8(value)
    }

    func deserialize() throws -> String {
        guard try readUInt8() == Type.String.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        return try deserializeUTF8()
    }

    /**
     - seealso: 3.9 XML type
     */
    func serialize(value: ASXMLDocument) -> Self {
        writeUInt8(Type.Xml.rawValue)
        if let index:Int = reference.indexOf(value) {
            return serializeU29(index << 1)
        }
        reference.objects.append(value)
        let utf8:[UInt8] = [UInt8](value.description.utf8)
        return serialize(utf8.count << 1 | 0x01).writeBytes(utf8)
    }

    func deserialize() throws -> ASXMLDocument {
        guard try readUInt8() == Type.Xml.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        let refs:Int = try deserializeU29()
        if (refs & 0x01) == 0 {
            guard let document:ASXMLDocument = try reference.getObject(refs >> 1) as? ASXMLDocument else {
                throw AMFSerializerError.Deserialize
            }
            return document
        }
        let document:ASXMLDocument = ASXMLDocument(data: try readUTF8Bytes(refs >> 1))
        reference.objects.append(document)
        return document
    }
    
    /**
     - seealso: 3.10 Date type
     */
    func serialize(value:NSDate) -> Self {
        writeUInt8(Type.Date.rawValue)
        if let index:Int = reference.indexOf(value) {
            return serializeU29(index << 1)
        }
        reference.objects.append(value)
        return serializeU29(0x01).writeDouble(value.timeIntervalSince1970 * 1000)
    }

    func deserialize() throws -> NSDate {
        guard try readUInt8() == Type.Date.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        let refs:Int = try deserializeU29()
        if (refs & 0x01) == 0 {
            guard let date:NSDate = try reference.getObject(refs >> 1) as? NSDate else {
                throw AMFSerializerError.Deserialize
            }
            return date
        }
        let date:NSDate = NSDate(timeIntervalSince1970: try readDouble() / 1000)
        reference.objects.append(date)
        return date
    }

    /**
     - seealso: 3.11 Array type
     */
    func serialize(value: ASArray) -> Self {
        writeUInt8(Type.Array.rawValue)
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
        guard try readUInt8() == Type.Array.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        return ASArray()
    }
    
    /**
     - seealso: 3.12 Object type
     - note: ASObject = Dictionary<String, Any?>
     */
    func serialize(value: ASObject) -> Self {
        writeUInt8(Type.Object.rawValue)
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
        guard try readUInt8() == Type.Object.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        return ASObject()
    }

    /**
     - seealso: 3.13 XML type
     */
    func serialize(value: ASXML) -> Self {
        writeUInt8(Type.XmlString.rawValue)
        if let index:Int = reference.indexOf(value) {
            return serializeU29(index << 1)
        }
        reference.objects.append(value)
        let utf8:[UInt8] = [UInt8](value.description.utf8)
        return serialize(utf8.count << 1 | 0x01).writeBytes(utf8)
    }

    func deserialize() throws -> ASXML {
        guard try readUInt8() == Type.Xml.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        let refs:Int = try deserializeU29()
        if (refs & 0x01) == 0 {
            guard let xml:ASXML = try reference.getObject(refs >> 1) as? ASXML else {
                throw AMFSerializerError.Deserialize
            }
            return xml
        }
        let xml:ASXML = ASXML(data: try readUTF8Bytes(refs >> 1))
        reference.objects.append(xml)
        return xml
    }

    /**
     - seealso: 3.14 ByteArray type
     - note: flash.utils.ByteArray = lf.ByteArray
     */
    func serialize(value: ByteArray) -> Self {
        return self
    }

    func deserialize() throws -> ByteArray {
        return ByteArray()
    }

    /**
     - seealso: 3.15 Vector Type, vector-int-type
     */
    func serialize(value:[Int32]) -> Self {
        writeUInt8(Type.VectorInt.rawValue)
        if let index:Int = reference.indexOf(value) {
            return serializeU29(index << 1)
        }
        reference.objects.append(value)
        serializeU29(value.count << 1 | 0x01).writeUInt8(0x00)
        for v in value {
            writeInt32(v)
        }
        return self
    }

    func deserialize() throws -> [Int32] {
        guard try readUInt8() == Type.VectorInt.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        return []
    }

    /**
     - seealso: 3.15 Vector Type, vector-uint-type
     */
    func serialize(value:[UInt32]) -> Self {
        writeUInt8(Type.VectorUInt.rawValue)
        if let index:Int = reference.indexOf(value) {
            return serializeU29(index << 1)
        }
        reference.objects.append(value)
        serializeU29(value.count << 1 | 0x01).writeUInt8(0x00)
        for v in value {
            writeUInt32(v)
        }
        return self
    }

    func deserialize() throws -> [UInt32] {
        guard try readUInt8() == Type.VectorUInt.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        return []
    }

    /**
     - seealso: 3.15 Vector Type, vector-number-type
     */
    func serialize(value:[Double]) -> Self {
        writeUInt8(Type.VectorNumber.rawValue)
        if let index:Int = reference.indexOf(value) {
            return serializeU29(index << 1)
        }
        reference.objects.append(value)
        serializeU29(value.count << 1 | 0x01).writeUInt8(0x00)
        for v in value {
            writeDouble(v)
        }
        return self
    }

    func deserialize() throws -> [Double] {
        guard try readUInt8() == Type.VectorNumber.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        return []
    }

    /**
     - seealso: 3.15 Vector Type, vector-object-type
     */
    func serialize(value:[Any?]) -> Self {
        writeUInt8(Type.VectorObject.rawValue)
        if let index:Int = reference.indexOf(value) {
            return serializeU29(index << 1)
        }
        reference.objects.append(value)
        serializeU29(value.count << 1 | 0x01).serializeUTF8("*")
        for v in value {
            serialize(v)
        }
        return self
    }

    func deserialize() throws -> [Any?] {
        guard try readUInt8() == Type.Array.rawValue else {
            throw AMFSerializerError.Deserialize
        }
        return []
    }
    
    /**
     - seealso: 1.3.1 Variable Length Unsigned 29-bit Integer Encoding
     */
    private func serializeU29(value:Int) -> Self {
        if (value < Int(Int32.min) || Int(Int32.max) < value) {
            return serialize(Double(value))
        }
        let value:UInt32 = UInt32(value)
        switch UInt32(0) {
        case value & 0xFFFFFF80:
            return writeUInt8(UInt8(value & 0x7f))
        case value & 0xFFFFC000:
            return writeUInt8(UInt8(value >> 7 | 0x80))
                .writeUInt8(UInt8(value & 0x7F))
        case value & 0xFFE00000:
            return writeUInt8(UInt8(value >> 14 | 0x80))
                .writeUInt8(UInt8(value >> 7 | 0x80))
                .writeUInt8(UInt8(value & 0x7F))
        default:
            return writeUInt8(UInt8(value >> 22 | 0x80))
                .writeUInt8(UInt8(value >> 15 | 0x80))
                .writeUInt8(UInt8(value >> 8 | 0x80))
                .writeUInt8(UInt8(value & 0xFF))
        }
    }

    private func deserializeU29() throws -> Int {
        
        var count:Int = 1
        var result:Int = 0
        var byte:UInt8 = try readUInt8()
        
        while (byte & 0x80 != 0 && count < 4) {
            result <<= 7
            result |= Int(byte & 0x7F)
            byte = try readUInt8()
            count += 1
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
     - seealso: 1.3.2 Strings and UTF-8
     */
    private func serializeUTF8(value:String) -> Self {
        if (value.isEmpty) {
            return serializeU29(0x01)
        }
        if let index:Int = reference.indexOf(value) {
            return serializeU29(index << 1)
        }
        let utf8:[UInt8] = [UInt8](value.utf8)
        reference.strings.append(value)
        return serializeU29(utf8.count << 1 | 0x01).writeBytes(utf8)
    }

    private func deserializeUTF8() throws -> String {
        let ref:Int = try deserializeU29()
        if (ref & 0x01) == 0 {
            return try reference.getString(ref >> 1)
        }
        guard let length:Int = ref >> 1 where length != 0 else {
            return ""
        }
        let string:String = try readUTF8Bytes(length)
        reference.strings.append(string)
        return string
    }
}
