import AVFoundation
import Foundation
import VideoToolbox

enum VTSessionError: Swift.Error {
    case failedToCreate(status: OSStatus)
    case failedToPrepare(status: OSStatus)
    case failedToConvert(status: OSStatus)
}

protocol VTSessionConvertible {
    func setOption(_ option: VTSessionOption) -> OSStatus
    func setOptions(_ options: Set<VTSessionOption>) -> OSStatus
    func copySupportedPropertyDictionary() -> [AnyHashable: Any]
    func convert(_ sampleBuffer: CMSampleBuffer, continuation: AsyncStream<CMSampleBuffer>.Continuation?) throws
    func invalidate()
}

extension VTSessionConvertible where Self: VTSession {
    func setOption(_ option: VTSessionOption) -> OSStatus {
        return VTSessionSetProperty(self, key: option.key.CFString, value: option.value)
    }

    func setOptions(_ options: Set<VTSessionOption>) -> OSStatus {
        var properties: [AnyHashable: AnyObject] = [:]
        for option in options {
            properties[option.key.CFString] = option.value
        }
        return VTSessionSetProperties(self, propertyDictionary: properties as CFDictionary)
    }

    func copySupportedPropertyDictionary() -> [AnyHashable: Any] {
        var support: CFDictionary?
        guard VTSessionCopySupportedPropertyDictionary(self, supportedPropertyDictionaryOut: &support) == noErr else {
            return [:]
        }
        guard let result = support as? [AnyHashable: Any] else {
            return [:]
        }
        return result
    }
}
