import Foundation
import AVFoundation

protocol BytesConvertible {
    
    var bytes: [UInt8] { get }
    
    init(bytes: [UInt8])
    
}

extension BytesConvertible where Self: Strideable {
    
    var bytes: [UInt8] {
        
        var value: Self = self
        
        return withUnsafePointer(&value) {
            Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>($0), count: sizeof(Self.self)))
        }
        
    }
    
    init(bytes: [UInt8]) {
        
        self = bytes.withUnsafeBufferPointer {
            return UnsafePointer($0.baseAddress).memory
        }
        
    }
    
}

extension Int16: BytesConvertible {}
extension UInt16: BytesConvertible {}
extension Int32: BytesConvertible {}
extension UInt32: BytesConvertible {}
extension UInt64: BytesConvertible {}
extension Double: BytesConvertible {}
extension Float: BytesConvertible {}

