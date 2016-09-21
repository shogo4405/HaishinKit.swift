import Foundation

public let kASUndefined:ASUndefined = ASUndefined()
public typealias ASObject = [String: Any?]

public final class ASUndefined: NSObject {
    public override var description:String {
        return "undefined"
    }
    fileprivate override init() {
        super.init()
    }
}

// MARK: -
public struct ASArray {
    fileprivate(set) var data:[Any?]
    fileprivate(set) var dict:[String: Any?] = [:]

    public var length:Int {
        return data.count
    }

    public init(count:Int) {
        self.data = [Any?](repeating: kASUndefined, count: count)
    }

    public init(data:[Any?]) {
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
                    data += [Any?](repeating: kASUndefined, count: i - data.count + 1)
                }
                data[i] = newValue
            }
            if let i:String = i as? String {
                if let i:Int = Int(i) {
                    if (data.count <= i) {
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

extension ASArray: CustomStringConvertible {
    // MARK: CustomStringConvertible
    public var description:String {
        return data.description
    }
}

extension ASArray: Equatable {
    // MARK: Equatable
}

public func ==(lhs: ASArray, rhs: ASArray) -> Bool {
    return (lhs.data.description == rhs.data.description) && (lhs.dict.description == rhs.dict.description)
}

// MARK: -
/**
 ActionScript 1.0 and 2.0 and flash.xml.XMLDocument in ActionScript 3.0

 - seealso:
   - 2.17 XML Document Type (amf0-file-format-specification.pdf)
   - 3.9 XMLDocument type (amf-file-format-spec.pdf)
 */
public final class ASXMLDocument: NSObject {
    public override var description:String {
        return data
    }

    fileprivate var data:String

    public init(data:String) {
        self.data = data
    }
}

// MARK: -
/**
 ActionScript 3.0 introduces a new XML type.
 
 - seealso: 3.13 XML type (amf-file-format-spec.pdf)
 */
public final class ASXML: NSObject {
    public override var description:String {
        return data
    }

    fileprivate var data:String

    public init(data:String) {
        self.data = data
    }
}
