import Foundation

public let kASUndefined = ASUndefined()

public typealias ASObject = [String: Any?]

public final class ASUndefined: NSObject {
    override public var description: String {
        "undefined"
    }

    override fileprivate init() {
        super.init()
    }
}

public struct ASTypedObject {
    public typealias TypedObjectDecoder = (_ type: String, _ data: ASObject) throws -> Any

    static var decoders: [String: TypedObjectDecoder] = [:]

    static func decode(typeName: String, data: ASObject) throws -> Any {
        let decoder = decoders[typeName] ?? { ASTypedObject(typeName: $0, data: $1) }
        return try decoder(typeName, data)
    }

    var typeName: String
    var data: ASObject

    public static func register(typeNamed name: String, decoder: @escaping TypedObjectDecoder) {
        decoders[name] = decoder
    }

    public static func register<T: Decodable>(type: T.Type, named name: String) {
        decoders[name] = {
            let jsonData = try JSONSerialization.data(withJSONObject: $1, options: [])
            return try JSONDecoder().decode(type, from: jsonData)
        }
    }

    public static func unregister(typeNamed name: String) {
        decoders.removeValue(forKey: name)
    }
}

// MARK: -
public struct ASArray {
    private(set) var data: [Any?]
    private(set) var dict: [String: Any?] = [:]

    public var length: Int {
        data.count
    }

    public init(count: Int) {
        self.data = [Any?](repeating: kASUndefined, count: count)
    }

    public init(data: [Any?]) {
        self.data = data
    }
}

extension ASArray: ExpressibleByArrayLiteral {
    // MARK: ExpressibleByArrayLiteral
    public init (arrayLiteral elements: Any?...) {
        self = ASArray(data: elements)
    }

    public subscript(i: Any) -> Any? {
        get {
            if let i: Int = i as? Int {
                return i < data.count ? data[i] : kASUndefined
            }
            if let i: String = i as? String {
                if let i = Int(i) {
                    return i < data.count ? data[i] : kASUndefined
                }
                return dict[i] as Any
            }
            return nil
        }
        set {
            if let i: Int = i as? Int {
                if data.count <= i {
                    data += [Any?](repeating: kASUndefined, count: i - data.count + 1)
                }
                data[i] = newValue
            }
            if let i: String = i as? String {
                if let i = Int(i) {
                    if data.count <= i {
                        data += [Any?](repeating: kASUndefined, count: i - data.count + 1)
                    }
                    data[i] = newValue
                    return
                }
                dict[i] = newValue
            }
        }
    }
}

extension ASArray: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    public var debugDescription: String {
        data.description
    }
}

extension ASArray: Equatable {
    // MARK: Equatable
    public static func == (lhs: ASArray, rhs: ASArray) -> Bool {
        (lhs.data.description == rhs.data.description) && (lhs.dict.description == rhs.dict.description)
    }
}

// MARK: -
/**
 ActionScript 1.0 and 2.0 and flash.xml.XMLDocument in ActionScript 3.0

 - seealso:
   - 2.17 XML Document Type (amf0-file-format-specification.pdf)
   - 3.9 XMLDocument type (amf-file-format-spec.pdf)
 */
public final class ASXMLDocument: NSObject {
    override public var description: String {
        data
    }

    private var data: String

    public init(data: String) {
        self.data = data
    }
}

// MARK: -
/**
 ActionScript 3.0 introduces a new XML type.
 
 - seealso: 3.13 XML type (amf-file-format-spec.pdf)
 */
public final class ASXML: NSObject {
    override public var description: String {
        data
    }

    private var data: String

    public init(data: String) {
        self.data = data
    }
}
