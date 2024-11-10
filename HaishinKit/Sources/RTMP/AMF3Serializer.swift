import Foundation

final class AMFReference {
    var strings: [String] = []
    var objects: [Any] = []

    func getString(_ index: Int) throws -> String {
        if strings.count <= index {
            throw AMFSerializerError.outOfIndex
        }
        return strings[index]
    }

    func getObject(_ index: Int) throws -> Any {
        if objects.count <= index {
            throw AMFSerializerError.outOfIndex
        }
        return objects[index]
    }

    func indexOf<T: Equatable>(_ value: T) -> Int? {
        for (index, data) in objects.enumerated() {
            if let data: T = data as? T, data == value {
                return index
            }
        }
        return nil
    }

    func indexOf(_ value: [Int32]) -> Int? {
        nil
    }

    func indexOf(_ value: [UInt32]) -> Int? {
        nil
    }

    func indexOf(_ value: [Double]) -> Int? {
        nil
    }

    func indexOf(_ value: [Any?]) -> Int? {
        nil
    }

    func indexOf(_ value: AMFObject) -> Int? {
        for (index, data) in objects.enumerated() {
            if let data: AMFObject = data as? AMFObject, data.description == value.description {
                return index
            }
        }
        return nil
    }

    func indexOf(_ value: String) -> Int? {
        strings.firstIndex(of: value)
    }
}

enum AMF3Type: UInt8 {
    case undefined = 0x00
    case null = 0x01
    case boolFalse = 0x02
    case boolTrue = 0x03
    case integer = 0x04
    case number = 0x05
    case string = 0x06
    case xml = 0x07
    case date = 0x08
    case array = 0x09
    case object = 0x0A
    case xmlString = 0x0B
    case byteArray = 0x0C
    case vectorInt = 0x0D
    case vectorUInt = 0x0E
    case vectorNumber = 0x0F
    case vectorObject = 0x10
    case dictionary = 0x11
}

// MARK: -
/**
 AMF3 Serializer

 - seealso: http://wwwimages.adobe.com/www.adobe.com/content/dam/Adobe/en/devnet/amf/pdf/amf-file-format-spec.pdf
 */
final class AMF3Serializer: ByteArray {
    var reference = AMFReference()
}

extension AMF3Serializer: AMFSerializer {
    // MARK: AMFSerializer
    @discardableResult
    func serialize(_ value: (any Sendable)?) -> Self {
        if value == nil {
            return writeUInt8(AMF3Type.null.rawValue)
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
        case let value as CGFloat:
            return serialize(Double(value))
        case let value as Double:
            return serialize(Double(value))
        case let value as Date:
            return serialize(value)
        case let value as String:
            return serialize(value)
        case let value as Bool:
            return serialize(value)
        case let value as AMFArray:
            return serialize(value)
        case let value as AMFObject:
            return serialize(value)
        default:
            return writeUInt8(AMF3Type.undefined.rawValue)
        }
    }

    func deserialize() throws -> (any Sendable)? {
        guard let type = AMF3Type(rawValue: try readUInt8()) else {
            throw AMFSerializerError.deserialize
        }
        position -= 1
        switch type {
        case .undefined:
            position += 1
            return kAMFUndefined
        case .null:
            position += 1
            return nil
        case .boolFalse:
            return try deserialize() as Bool
        case .boolTrue:
            return try deserialize() as Bool
        case .integer:
            return try deserialize() as Int
        case .number:
            return try deserialize() as Double
        case .string:
            return try deserialize() as String
        case .xml:
            return try deserialize() as AMFXMLDocument
        case .date:
            return try deserialize() as Date
        case .array:
            return try deserialize() as AMFArray
        case .object:
            return try deserialize() as AMFObject
        case .xmlString:
            return try deserialize() as AMFXML
        case .byteArray:
            return try deserialize() as Data
        case .vectorInt:
            return try deserialize() as [Int32]
        case .vectorUInt:
            return try deserialize() as [UInt32]
        case .vectorNumber:
            return try deserialize() as [Double]
        case .vectorObject:
            return try deserialize() as [(any Sendable)?]
        case .dictionary:
            assertionFailure("Unsupported")
            return nil
        }
    }

    /**
     - seealso: 3.4 false Type
     - seealso: 3.5 true type
     */
    @discardableResult
    func serialize(_ value: Bool) -> Self {
        writeUInt8(value ? AMF3Type.boolTrue.rawValue : AMF3Type.boolFalse.rawValue)
    }

    func deserialize() throws -> Bool {
        switch try readUInt8() {
        case AMF3Type.boolTrue.rawValue:
            return true
        case AMF3Type.boolFalse.rawValue:
            return false
        default:
            throw AMFSerializerError.deserialize
        }
    }

    /**
     - seealso: 3.6 integer type
     */
    @discardableResult
    func serialize(_ value: Int) -> Self {
        writeUInt8(AMF3Type.integer.rawValue).serializeU29(value)
    }

    func deserialize() throws -> Int {
        guard try readUInt8() == AMF3Type.integer.rawValue else {
            throw AMFSerializerError.deserialize
        }
        return try deserializeU29()
    }

    /**
     - seealso: 3.7 double type
     */
    @discardableResult
    func serialize(_ value: Double) -> Self {
        writeUInt8(AMF3Type.number.rawValue).writeDouble(value)
    }

    func deserialize() throws -> Double {
        guard try readUInt8() == AMF3Type.number.rawValue else {
            throw AMFSerializerError.deserialize
        }
        return try readDouble()
    }

    /**
     - seealso: 3.8 String type
     */
    @discardableResult
    func serialize(_ value: String) -> Self {
        writeUInt8(AMF3Type.string.rawValue).serializeUTF8(value)
    }

    func deserialize() throws -> String {
        guard try readUInt8() == AMF3Type.string.rawValue else {
            throw AMFSerializerError.deserialize
        }
        return try deserializeUTF8()
    }

    /**
     - seealso: 3.9 XML type
     */
    @discardableResult
    func serialize(_ value: AMFXMLDocument) -> Self {
        writeUInt8(AMF3Type.xml.rawValue)
        if let index: Int = reference.indexOf(value) {
            return serializeU29(index << 1)
        }
        reference.objects.append(value)
        let utf8 = Data(value.description.utf8)
        return serialize(utf8.count << 1 | 0x01).writeBytes(utf8)
    }

    func deserialize() throws -> AMFXMLDocument {
        guard try readUInt8() == AMF3Type.xml.rawValue else {
            throw AMFSerializerError.deserialize
        }
        let refs: Int = try deserializeU29()
        if (refs & 0x01) == 0 {
            guard let document: AMFXMLDocument = try reference.getObject(refs >> 1) as? AMFXMLDocument else {
                throw AMFSerializerError.deserialize
            }
            return document
        }
        let document = AMFXMLDocument(data: try readUTF8Bytes(refs >> 1))
        reference.objects.append(document)
        return document
    }

    /**
     - seealso: 3.10 Date type
     */
    @discardableResult
    func serialize(_ value: Date) -> Self {
        writeUInt8(AMF3Type.date.rawValue)
        if let index: Int = reference.indexOf(value) {
            return serializeU29(index << 1)
        }
        reference.objects.append(value)
        return serializeU29(0x01).writeDouble(value.timeIntervalSince1970 * 1000)
    }

    func deserialize() throws -> Date {
        guard try readUInt8() == AMF3Type.date.rawValue else {
            throw AMFSerializerError.deserialize
        }
        let refs: Int = try deserializeU29()
        if (refs & 0x01) == 0 {
            guard let date: Date = try reference.getObject(refs >> 1) as? Date else {
                throw AMFSerializerError.deserialize
            }
            return date
        }
        let date = Date(timeIntervalSince1970: try readDouble() / 1000)
        reference.objects.append(date)
        return date
    }

    /**
     - seealso: 3.11 Array type
     */
    @discardableResult
    func serialize(_ value: AMFArray) -> Self {
        writeUInt8(AMF3Type.array.rawValue)
        if let index: Int = reference.indexOf(value) {
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

    func deserialize() throws -> AMFArray {
        guard try readUInt8() == AMF3Type.array.rawValue else {
            throw AMFSerializerError.deserialize
        }
        return AMFArray()
    }

    /**
     - seealso: 3.12 Object type
     - note: ASObject = Dictionary<String, Any?>
     */
    @discardableResult
    func serialize(_ value: AMFObject) -> Self {
        writeUInt8(AMF3Type.object.rawValue)
        if let index: Int = reference.indexOf(value) {
            return serializeU29(index << 1)
        }
        reference.objects.append(value)
        for (key, value) in value {
            serialize(key).serialize(value)
        }
        return serialize("")
    }

    func deserialize() throws -> AMFObject {
        guard try readUInt8() == AMF3Type.object.rawValue else {
            throw AMFSerializerError.deserialize
        }
        return AMFObject()
    }

    /**
     - seealso: 3.13 XML type
     */
    @discardableResult
    func serialize(_ value: AMFXML) -> Self {
        writeUInt8(AMF3Type.xmlString.rawValue)
        if let index: Int = reference.indexOf(value) {
            return serializeU29(index << 1)
        }
        reference.objects.append(value)
        let utf8 = Data(value.description.utf8)
        return serialize(utf8.count << 1 | 0x01).writeBytes(utf8)
    }

    func deserialize() throws -> AMFXML {
        guard try readUInt8() == AMF3Type.xml.rawValue else {
            throw AMFSerializerError.deserialize
        }
        let refs: Int = try deserializeU29()
        if (refs & 0x01) == 0 {
            guard let xml: AMFXML = try reference.getObject(refs >> 1) as? AMFXML else {
                throw AMFSerializerError.deserialize
            }
            return xml
        }
        let xml = AMFXML(data: try readUTF8Bytes(refs >> 1))
        reference.objects.append(xml)
        return xml
    }

    /**
     - seealso: 3.14 ByteArray type
     - note: flash.utils.ByteArray = lf.ByteArray
     */
    @discardableResult
    func serialize(_ value: Data) -> Self {
        self
    }

    func deserialize() throws -> Data {
        Data()
    }

    /**
     - seealso: 3.15 Vector Type, vector-int-type
     */
    @discardableResult
    func serialize(_ value: [Int32]) -> Self {
        writeUInt8(AMF3Type.vectorInt.rawValue)
        if let index: Int = reference.indexOf(value) {
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
        guard try readUInt8() == AMF3Type.vectorInt.rawValue else {
            throw AMFSerializerError.deserialize
        }
        return []
    }

    /**
     - seealso: 3.15 Vector Type, vector-uint-type
     */
    @discardableResult
    func serialize(_ value: [UInt32]) -> Self {
        writeUInt8(AMF3Type.vectorUInt.rawValue)
        if let index: Int = reference.indexOf(value) {
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
        guard try readUInt8() == AMF3Type.vectorUInt.rawValue else {
            throw AMFSerializerError.deserialize
        }
        return []
    }

    /**
     - seealso: 3.15 Vector Type, vector-number-type
     */
    @discardableResult
    func serialize(_ value: [Double]) -> Self {
        writeUInt8(AMF3Type.vectorNumber.rawValue)
        if let index: Int = reference.indexOf(value) {
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
        guard try readUInt8() == AMF3Type.vectorNumber.rawValue else {
            throw AMFSerializerError.deserialize
        }
        return []
    }

    /**
     - seealso: 3.15 Vector Type, vector-object-type
     */
    @discardableResult
    func serialize(_ value: [(any Sendable)?]) -> Self {
        writeUInt8(AMF3Type.vectorObject.rawValue)
        if let index: Int = reference.indexOf(value) {
            return serializeU29(index << 1)
        }
        reference.objects.append(value)
        serializeU29(value.count << 1 | 0x01).serializeUTF8("*")
        for v in value {
            serialize(v)
        }
        return self
    }

    func deserialize() throws -> [(any Sendable)?] {
        guard try readUInt8() == AMF3Type.array.rawValue else {
            throw AMFSerializerError.deserialize
        }
        return []
    }

    /**
     - seealso: 1.3.1 Variable Length Unsigned 29-bit Integer Encoding
     */
    @discardableResult
    private func serializeU29(_ value: Int) -> Self {
        if value < Int(Int32.min) || Int(Int32.max) < value {
            return serialize(Double(value))
        }
        let value = UInt32(value)
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
        var count = 1
        var result = 0
        var byte: UInt8 = try readUInt8()

        while byte & 0x80 != 0 && count < 4 {
            result <<= 7
            result |= Int(byte & 0x7F)
            byte = try readUInt8()
            count += 1
        }

        if count < 4 {
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
    @discardableResult
    private func serializeUTF8(_ value: String) -> Self {
        if value.isEmpty {
            return serializeU29(0x01)
        }
        if let index: Int = reference.indexOf(value) {
            return serializeU29(index << 1)
        }
        let utf8 = Data(value.utf8)
        reference.strings.append(value)
        return serializeU29(utf8.count << 1 | 0x01).writeBytes(utf8)
    }

    private func deserializeUTF8() throws -> String {
        let ref: Int = try deserializeU29()
        if (ref & 0x01) == 0 {
            return try reference.getString(ref >> 1)
        }
        let string: String = try readUTF8Bytes(length)
        reference.strings.append(string)
        return string
    }
}
