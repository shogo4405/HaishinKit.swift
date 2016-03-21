import Foundation

public let kASUndefined:ASUndefined = ASUndefined()
public typealias ASObject = [String: Any?]

// MARK: ASUndefined
public class ASUndefined {
    private init() {
    }
}

// MARK: CustomStringConvertible
extension ASUndefined: CustomStringConvertible {
    public var description:String {
        return "undefined"
    }
}

// MARK: - ASArray
public struct ASArray: ArrayLiteralConvertible {
    private(set) var data:[Any?]
    private(set) var dict:[String: Any?] = [:]

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

// MARK: CustomStringConvertible
extension ASArray: CustomStringConvertible {
    public var description:String {
        return data.description
    }
}

// MARK: Equatable
extension ASArray: Equatable {
}

public func ==(lhs: ASArray, rhs: ASArray) -> Bool {
    return (lhs.data.description == rhs.data.description) && (lhs.dict.description == rhs.dict.description)
}

/**
 * ActionScript 1.0 and 2.0 and flash.xml.XMLDocument in ActionScript 3.0
 * - seealso: 2.17 XML Document Type (amf0-file-format-specification.pdf)
 * - seealso: 3.9 XMLDocument type (amf-file-format-spec.pdf)
 */
// MARK: - ASXMLDocument
public struct ASXMLDocument {
    private var data:String

    public init (data:String) {
        self.data = data
    }
}

// MARK: CustomStringConvertible
extension ASXMLDocument: CustomStringConvertible {
    public var description:String {
        return data
    }
}

// MARK: Equatable
extension ASXMLDocument: Equatable {
}

public func ==(lhs: ASXMLDocument, rhs: ASXMLDocument) -> Bool {
    return lhs.description == rhs.description
}

/**
 * ActionScript 3.0 introduces a new XML type.
 * -seealso: 3.13 XML type (amf-file-format-spec.pdf)
 */
// MARK: - ASXML
public struct ASXML {
    private var data:String
    
    public init (data:String) {
        self.data = data
    }
}

// MARK: CustomStringConvertible
extension ASXML: CustomStringConvertible {
    public var description:String {
        return data
    }
}

// MARK: Equatable
extension ASXML: Equatable {
}

public func ==(lhs: ASXML, rhs: ASXML) -> Bool {
    return lhs.description == rhs.description
}
