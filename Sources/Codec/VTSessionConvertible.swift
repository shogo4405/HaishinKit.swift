import AVFoundation
import Foundation
import VideoToolbox

protocol VTSessionConvertible {
    func setOption(_ option: VTSessionOption) -> OSStatus
    func setOptions(_ options: Set<VTSessionOption>) -> OSStatus
    func copySupportedPropertyDictionary() -> [AnyHashable: Any]
    func encodeFrame(_ imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime, duration: CMTime, outputHandler: @escaping VTCompressionOutputHandler) -> OSStatus
    func decodeFrame(_ sampleBuffer: CMSampleBuffer, outputHandler: @escaping VTDecompressionOutputHandler) -> OSStatus
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
