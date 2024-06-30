import Foundation

/// The singleton ASUndefined object.
public let kASUndefined = ASUndefined()

/// The ASObject typealias represents an object for AcrionScript.
public typealias ASObject = [String: (any Sendable)?]

/// The ASUndefined structure represents an undefined for ActionScript.
public struct ASUndefined: Sendable, CustomStringConvertible {
    public var description: String {
        "undefined"
    }
}

/// The ASTypedObject structure represents a typed object for ActionScript.
public struct ASTypedObject: Sendable {
    public let typeName: String
    public let data: ASObject
}

// MARK: -
/// The ASArray structure represents an array value for ActionScript.
public struct ASArray: Sendable {
    private(set) var data: [(any Sendable)?]
    private(set) var dict: [String: (any Sendable)?] = [:]

    /// The length of an array.
    public var length: Int {
        data.count
    }

    /// Creates a new instance containing the specified number of a single.
    public init(count: Int) {
        self.data = [(any Sendable)?](repeating: kASUndefined, count: count)
    }

    /// Creates a new instance of data.
    public init(data: [(any Sendable)?]) {
        self.data = data
    }

    init(_ dict: ASObject) {
        self.dict = dict
        self.data = .init()
    }
}

extension ASArray: ExpressibleByArrayLiteral {
    // MARK: ExpressibleByArrayLiteral
    public init (arrayLiteral elements: (any Sendable)?...) {
        self = ASArray(data: elements)
    }

    /// Accesses the element at the specified position.
    public subscript(i: Any) -> (any Sendable)? {
        get {
            if let i: Int = i as? Int {
                return i < data.count ? data[i] : kASUndefined
            }
            if let i: String = i as? String {
                if let i = Int(i) {
                    return i < data.count ? data[i] : kASUndefined
                }
                return dict[i] as (any Sendable)
            }
            return nil
        }
        set {
            if let i = i as? Int {
                if data.count <= i {
                    data += [(any Sendable)?](repeating: kASUndefined, count: i - data.count + 1)
                }
                data[i] = newValue
            }
            if let i = i as? String {
                if let i = Int(i) {
                    if data.count <= i {
                        data += [(any Sendable)?](repeating: kASUndefined, count: i - data.count + 1)
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
        data.debugDescription + ":" + dict.debugDescription
    }
}

extension ASArray: Equatable {
    // MARK: Equatable
    public static func == (lhs: ASArray, rhs: ASArray) -> Bool {
        (lhs.data.description == rhs.data.description) && (lhs.dict.description == rhs.dict.description)
    }
}

// MARK: -
/// ActionScript 1.0 and 2.0 and flash.xml.XMLDocument in ActionScript 3.0
/// - seealso: 2.17 XML Document Type (amf0-file-format-specification.pdf)
/// - seealso: 3.9 XMLDocument type (amf-file-format-spec.pdf)
public struct ASXMLDocument: Sendable, CustomStringConvertible {
    public var description: String {
        data
    }

    private let data: String

    /// Creates a new instance of string.
    public init(data: String) {
        self.data = data
    }
}

extension ASXMLDocument: Equatable {
    // MARK: Equatable
    public static func == (lhs: ASXMLDocument, rhs: ASXMLDocument) -> Bool {
        (lhs.description == rhs.description)
    }
}

// MARK: -
/// ActionScript 3.0 introduces a new XML type.
/// - seealso: 3.13 XML type (amf-file-format-spec.pdf)
public struct ASXML: Sendable, CustomStringConvertible {
    public var description: String {
        data
    }

    private let data: String

    /// Creates a new instance of string.
    public init(data: String) {
        self.data = data
    }
}

extension ASXML: Equatable {
    // MARK: Equatable
    public static func == (lhs: ASXML, rhs: ASXML) -> Bool {
        (lhs.description == rhs.description)
    }
}
