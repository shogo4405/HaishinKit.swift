import CoreMedia

extension CMSampleBuffer {
    var dependsOnOthers: Bool {
        get {
            guard
                let attachments = CMSampleBufferGetSampleAttachmentsArray(self, createIfNecessary: false) else {
                return false
            }
            let attachment: [NSObject: AnyObject] = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFDictionary.self) as [NSObject: AnyObject]
            return attachment["DependsOnOthers" as NSObject] as! Bool
        }
        set {
            let attachments: CFArray? = CMSampleBufferGetSampleAttachmentsArray(self, createIfNecessary: true)
            if let attachmentArray = attachments {
                let dic = unsafeBitCast(
                    CFArrayGetValueAtIndex(attachmentArray, 0),
                    to: CFMutableDictionary.self
                )
                CFDictionarySetValue(
                    dic,
                    Unmanaged.passUnretained(kCMSampleAttachmentKey_DependsOnOthers).toOpaque(),
                    Unmanaged.passUnretained(dependsOnOthers ? kCFBooleanTrue : kCFBooleanFalse).toOpaque()
                )
            }
        }
    }
    
    var dataBuffer: CMBlockBuffer? {
        get {
            return CMSampleBufferGetDataBuffer(self)
        }
        set {
            _ = newValue.map {
                CMSampleBufferSetDataBuffer(self, newValue: $0)
            }
        }
    }
    var imageBuffer: CVImageBuffer? {
        return CMSampleBufferGetImageBuffer(self)
    }
    var numSamples: CMItemCount {
        return CMSampleBufferGetNumSamples(self)
    }
    var duration: CMTime {
        return CMSampleBufferGetDuration(self)
    }
    var formatDescription: CMFormatDescription? {
        return CMSampleBufferGetFormatDescription(self)
    }
    var decodeTimeStamp: CMTime {
        return CMSampleBufferGetDecodeTimeStamp(self)
    }
    var presentationTimeStamp: CMTime {
        return CMSampleBufferGetPresentationTimeStamp(self)
    }
}
