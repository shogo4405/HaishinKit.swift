import AVFoundation
import Foundation

public protocol KeyPathRepresentable: Hashable, CaseIterable {
    var keyPath: AnyKeyPath { get }
}

public class Setting<T: AnyObject, Key: KeyPathRepresentable>: ExpressibleByDictionaryLiteral {
    public typealias Key = Key
    public typealias Value = Any

    weak var observer: T? {
        didSet {
            for (key, value) in elements {
                self[key] = value
            }
            elements.removeAll()
        }
    }

    private var elements: [(Key, Any)] = []

    public required init(dictionaryLiteral elements: (Key, Any)...) {
        self.elements = elements
    }

    public subscript(key: Key) -> Any? {
        get {
            observer?[keyPath: key.keyPath]
        }
        set {
            switch key.keyPath {
            case let path as ReferenceWritableKeyPath<T, Bool>:
                if let newValue = newValue as? Bool {
                    observer?[keyPath: path] = newValue
                }
            case let path as ReferenceWritableKeyPath<T, UInt32>:
                if let newValue = toUInt32(value: newValue) {
                    observer?[keyPath: path] = newValue
                }
            case let path as ReferenceWritableKeyPath<T, Int32>:
                if let newValue = toInt32(value: newValue) {
                    observer?[keyPath: path] = newValue
                }
            case let path as ReferenceWritableKeyPath<T, Double>:
                if let newValue = toDouble(value: newValue) {
                    observer?[keyPath: path] = newValue
                }
            case let path as ReferenceWritableKeyPath<T, String>:
                if let newValue = newValue as? String {
                    observer?[keyPath: path] = newValue
                }
            case let path as ReferenceWritableKeyPath<T, ScalingMode>:
                if let newValue = newValue as? ScalingMode {
                    observer?[keyPath: path] = newValue
                }
            #if os(iOS)
            case let path as ReferenceWritableKeyPath<T, AVCaptureVideoStabilizationMode>:
                if let newValue = newValue as? AVCaptureVideoStabilizationMode {
                    observer?[keyPath: path] = newValue
                }
            #endif
            #if !os(tvOS)
            case let path as ReferenceWritableKeyPath<T, AVCaptureSession.Preset>:
                if let newValue = newValue as? AVCaptureSession.Preset {
                    observer?[keyPath: path] = newValue
                }
            #endif
            default:
                return
            }
        }
    }

    private func toDouble(value: Any?) -> Double? {
        switch value {
        case let value as Float:
            return Double(value)
        case let value as Double:
            return value
        case let value as Int:
            return Double(value)
        case let value as CGFloat:
            return Double(value)
        default:
            return nil
        }
    }

    private func toUInt32(value: Any?) -> UInt32? {
        switch value {
        case let value as Int:
            return numericCast(value)
        case let value as Int8:
            return numericCast(value)
        case let value as Int16:
            return numericCast(value)
        case let value as Int32:
            return numericCast(value)
        case let value as Int64:
            return numericCast(value)
        case let value as UInt:
            return numericCast(value)
        case let value as UInt8:
            return numericCast(value)
        case let value as UInt16:
            return numericCast(value)
        case let value as UInt32:
            return value
        case let value as UInt64:
            return numericCast(value)
        case let value as Double:
            return UInt32(value)
        case let value as Float:
            return UInt32(value)
        case let value as CGFloat:
            return UInt32(value)
        default:
            return nil
        }
    }

    private func toInt32(value: Any?) -> Int32? {
        switch value {
        case let value as Int:
            return numericCast(value)
        case let value as Int8:
            return numericCast(value)
        case let value as Int16:
            return numericCast(value)
        case let value as Int32:
            return value
        case let value as Int64:
            return numericCast(value)
        case let value as UInt:
            return numericCast(value)
        case let value as UInt8:
            return numericCast(value)
        case let value as UInt16:
            return numericCast(value)
        case let value as UInt32:
            return numericCast(value)
        case let value as UInt64:
            return numericCast(value)
        case let value as Double:
            return Int32(value)
        case let value as Float:
            return Int32(value)
        case let value as CGFloat:
            return Int32(value)
        default:
            return nil
        }
    }
}

extension Setting: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    public var debugDescription: String {
        var data: [Key: Any] = [:]
        for key in Key.allCases {
            data[key] = observer?[keyPath: key.keyPath]
        }
        return data.description
    }
}
