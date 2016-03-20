import Foundation

public let kASUndefined:ASUndefined = ASUndefined()
public typealias ASObject = [String: Any?]

public class ASUndefined {
    private init() {
    }
}

extension ASUndefined: CustomStringConvertible {
    public var description:String {
        return "undefined"
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

/**
 * ActionScript 1.0 and 2.0 and flash.xml.XMLDocument in ActionScript 3.0
 * - seealso: 2.17 XML Document Type (amf0-file-format-specification.pdf)
 * - seealso: 3.9 XMLDocument type (amf-file-format-spec.pdf)
 */
public struct ASXMLDocument {
    private var data:String

    public init (data:String) {
        self.data = data
    }
}

extension ASXMLDocument: CustomStringConvertible {
    public var description:String {
        return data
    }
}

/**
 * ActionScript 3.0 introduces a new XML type.
 * -seealso: 3.13 XML type (amf-file-format-spec.pdf)
 */
public struct ASXML {
    private var data:String
    
    public init (data:String) {
        self.data = data
    }
}

extension ASXML: CustomStringConvertible {
    public var description:String {
        return data
    }
}
