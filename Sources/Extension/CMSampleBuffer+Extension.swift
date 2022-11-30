import Accelerate
import CoreMedia

extension CMSampleBuffer {
    static var format = vImage_CGImageFormat(
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        colorSpace: nil,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue),
        version: 0,
        decode: nil,
        renderingIntent: .defaultIntent)

    var isNotSync: Bool {
        get {
            getAttachmentValue(for: kCMSampleAttachmentKey_NotSync) ?? false
        }
        set {
            setAttachmentValue(for: kCMSampleAttachmentKey_NotSync, value: newValue)
        }
    }

    @available(iOS, obsoleted: 13.0)
    @available(tvOS, obsoleted: 13.0)
    @available(macOS, obsoleted: 10.15)
    var isValid: Bool {
        CMSampleBufferIsValid(self)
    }

    @available(iOS, obsoleted: 13.0)
    @available(tvOS, obsoleted: 13.0)
    @available(macOS, obsoleted: 10.15)
    var dataBuffer: CMBlockBuffer? {
        get {
            CMSampleBufferGetDataBuffer(self)
        }
        set {
            _ = newValue.map {
                CMSampleBufferSetDataBuffer(self, newValue: $0)
            }
        }
    }

    @available(iOS, obsoleted: 13.0)
    @available(tvOS, obsoleted: 13.0)
    @available(macOS, obsoleted: 10.15)
    var imageBuffer: CVImageBuffer? {
        CMSampleBufferGetImageBuffer(self)
    }

    @available(iOS, obsoleted: 13.0)
    @available(tvOS, obsoleted: 13.0)
    @available(macOS, obsoleted: 10.15)
    var numSamples: CMItemCount {
        CMSampleBufferGetNumSamples(self)
    }

    @available(iOS, obsoleted: 13.0)
    @available(tvOS, obsoleted: 13.0)
    @available(macOS, obsoleted: 10.15)
    var duration: CMTime {
        CMSampleBufferGetDuration(self)
    }

    @available(iOS, obsoleted: 13.0)
    @available(tvOS, obsoleted: 13.0)
    @available(macOS, obsoleted: 10.15)
    var formatDescription: CMFormatDescription? {
        CMSampleBufferGetFormatDescription(self)
    }

    @available(iOS, obsoleted: 13.0)
    @available(tvOS, obsoleted: 13.0)
    @available(macOS, obsoleted: 10.15)
    var decodeTimeStamp: CMTime {
        CMSampleBufferGetDecodeTimeStamp(self)
    }

    @available(iOS, obsoleted: 13.0)
    @available(tvOS, obsoleted: 13.0)
    @available(macOS, obsoleted: 10.15)
    var presentationTimeStamp: CMTime {
        CMSampleBufferGetPresentationTimeStamp(self)
    }

    func muted(_ muted: Bool) -> CMSampleBuffer? {
        guard muted else {
            return self
        }
        guard let dataBuffer = dataBuffer else {
            return nil
        }
        let status = CMBlockBufferFillDataBytes(
            with: 0,
            blockBuffer: dataBuffer,
            offsetIntoDestination: 0,
            dataLength: dataBuffer.dataLength
        )
        guard status == noErr else {
            return nil
        }
        return self
    }

    func over(_ sampleBuffer: CMSampleBuffer?, regionOfInterest roi: CGRect = .zero) -> CMSampleBuffer {
        guard var inputImageBuffer = vImage_Buffer(cvPixelBuffer: sampleBuffer?.imageBuffer, format: &CMSampleBuffer.format) else {
            return self
        }
        defer {
            inputImageBuffer.free()
        }
        guard let imageBuffer, var srcImageBuffer = vImage_Buffer(cvPixelBuffer: imageBuffer, format: &CMSampleBuffer.format) else {
            return self
        }
        defer {
            srcImageBuffer.free()
        }
        let xScale = Float(roi.width) / Float(inputImageBuffer.width)
        let yScale = Float(roi.height) / Float(inputImageBuffer.height)
        let scaleFactor = (xScale < yScale) ? xScale : yScale
        var scaledInputImageBuffer = inputImageBuffer.scale(scaleFactor )
        defer {
            scaledInputImageBuffer.free()
        }
        _ = srcImageBuffer.over(&scaledInputImageBuffer, origin: roi.origin)
        _ = srcImageBuffer.copy(to: imageBuffer, format: &CMSampleBuffer.format)
        return self
    }

    // swiftlint:disable discouraged_optional_boolean
    @inline(__always)
    private func getAttachmentValue(for key: CFString) -> Bool? {
        guard
            let attachments = CMSampleBufferGetSampleAttachmentsArray(self, createIfNecessary: false) as? [[CFString: Any]],
            let value = attachments.first?[key] as? Bool else {
            return nil
        }
        return value
    }

    @inline(__always)
    private func setAttachmentValue(for key: CFString, value: Bool) {
        guard
            let attachments: CFArray = CMSampleBufferGetSampleAttachmentsArray(self, createIfNecessary: true), 0 < CFArrayGetCount(attachments) else {
            return
        }
        let attachment = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
        CFDictionarySetValue(
            attachment,
            Unmanaged.passUnretained(key).toOpaque(),
            Unmanaged.passUnretained(value ? kCFBooleanTrue : kCFBooleanFalse).toOpaque()
        )
    }

    #if os(macOS)
    /* Used code from the example https://developer.apple.com/documentation/accelerate/vimage/reading_from_and_writing_to_core_video_pixel_buffers */
    func reflectHorizontal() {
        guard let imageBuffer, var sourceBuffer = vImage_Buffer(cvPixelBuffer: imageBuffer, format: &CMSampleBuffer.format) else {
            return
        }
        defer {
            sourceBuffer.free()
        }
        guard
            var destinationBuffer = vImage_Buffer(
                height: sourceBuffer.height,
                width: sourceBuffer.width,
                pixelBits: CMSampleBuffer.format.bitsPerPixel,
                flags: vImage_Flags(kvImageNoFlags)) else {
            return
        }
        defer {
            destinationBuffer.free()
        }
        guard
            vImageHorizontalReflect_ARGB8888(
                &sourceBuffer,
                &destinationBuffer,
                vImage_Flags(kvImageLeaveAlphaUnchanged)) == kvImageNoError else {
            return
        }
        _ = destinationBuffer.copy(to: imageBuffer, format: &CMSampleBuffer.format)
    }
    #endif
}
