import Foundation
import AVFoundation
import VideoToolbox

public enum AVCProfileIndication:UInt8 {
    case Baseline = 66
    case Main = 77
    case Extended = 88
    case High = 100
    case High10 = 110
    case High422 = 122
    case High444 = 144
    case High424Predictive = 244

    var autoLevel:String {
        switch self {
        case .Baseline:
            return kVTProfileLevel_H264_Baseline_AutoLevel as String
        case .Main:
            return kVTProfileLevel_H264_Main_AutoLevel as String
        case .Extended:
            return kVTProfileLevel_H264_Extended_AutoLevel as String
        case .High:
            return kVTProfileLevel_H264_High_AutoLevel as String
        case .High10:
            return kVTProfileLevel_H264_High_AutoLevel as String
        case .High422:
            return kVTProfileLevel_H264_High_AutoLevel as String
        case .High444:
            return kVTProfileLevel_H264_High_AutoLevel as String
        case .High424Predictive:
            return kVTProfileLevel_H264_High_AutoLevel as String
        }
    }

    var allowFrameReordering:Bool {
        return AVCProfileIndication.Baseline.rawValue < rawValue
    }
}

// @see ISO/IEC 14496-15 2010
public struct AVCConfigurationRecord: CustomStringConvertible {

    static func getData(formatDescription:CMFormatDescriptionRef?) -> NSData? {
        if (formatDescription == nil) {
            return nil
        }
        if let atoms:NSDictionary = CMFormatDescriptionGetExtension(formatDescription!, "SampleDescriptionExtensionAtoms") as? NSDictionary {
            return atoms["avcC"] as? NSData
        }
        return nil
    }

    static let reserveLengthSizeMinusOne:UInt8 = 0x3F
    static let reserveNumOfSequenceParameterSets:UInt8 = 0xE0
    static let reserveChromaFormat:UInt8 = 0xFC
    static let reserveBitDepthLumaMinus8:UInt8 = 0xF8
    static let reserveBitDepthChromaMinus8 = 0xF8
    
    public var configurationVersion:UInt8 = 1
    public var AVCProfileIndication:UInt8 = 0
    public var profileCompatibility:UInt8 = 0
    public var AVCLevelIndication:UInt8 = 0
    public var lengthSizeMinusOneWithReserved:UInt8 = 0
    public var numOfSequenceParameterSetsWithReserved:UInt8 = 0
    public var sequenceParameterSets:[[UInt8]] = []
    public var pictureParameterSets:[[UInt8]] = []
    
    public var chromaFormatWithReserve:UInt8 = 0
    public var bitDepthLumaMinus8WithReserve:UInt8 = 0
    public var bitDepthChromaMinus8WithReserve:UInt8 = 0
    public var sequenceParameterSetExt:[[UInt8]] = []

    var naluLength:Int32 {
        return Int32((lengthSizeMinusOneWithReserved >> 6) + 1)
    }
    
    public var description:String {
        var description:String = "AVCConfigurationRecord{"
        description += "configurationVersion:\(configurationVersion),"
        description += "AVCProfileIndication:\(AVCProfileIndication),"
        description += "lengthSizeMinusOneWithReserved:\(lengthSizeMinusOneWithReserved),"
        description += "numOfSequenceParameterSetsWithReserved:\(numOfSequenceParameterSetsWithReserved),"
        description += "sequenceParameterSets:\(sequenceParameterSets),"
        description += "pictureParameterSets:\(pictureParameterSets)"
        description += "}"
        return description
    }

    init() {
    }

    init(data: NSData) {
        var bytes:[UInt8] = [UInt8](count: data.length, repeatedValue: 0x00)
        data.getBytes(&bytes, length: bytes.count)
        self.bytes = bytes
    }
    
    private var _bytes:[UInt8] = []
    var bytes:[UInt8] {
        get {
            return _bytes
        }
        set {
            let buffer:ByteArray = ByteArray(bytes: newValue)
            configurationVersion = buffer.readUInt8()
            AVCProfileIndication = buffer.readUInt8()
            profileCompatibility = buffer.readUInt8()
            AVCLevelIndication = buffer.readUInt8()
            lengthSizeMinusOneWithReserved = buffer.readUInt8()
            numOfSequenceParameterSetsWithReserved = buffer.readUInt8()
            
            let numOfSequenceParameterSets:UInt8 = numOfSequenceParameterSetsWithReserved & ~AVCConfigurationRecord.reserveNumOfSequenceParameterSets
            for _ in 0..<numOfSequenceParameterSets {
                let length:Int = Int(buffer.readUInt16())
                sequenceParameterSets.append(buffer.readUInt8(length))
            }
            
            let numPictureParameterSets:UInt8 = buffer.readUInt8()
            for _ in 0..<numPictureParameterSets {
                let length:Int = Int(buffer.readUInt16())
                pictureParameterSets.append(buffer.readUInt8(length))
            }
            
            _bytes = newValue
        }
    }
    
    func createFormatDescription(formatDescriptionOut: UnsafeMutablePointer<CMFormatDescription?>) ->  OSStatus {
        var parameterSetPointers:[UnsafePointer<UInt8>] = [
            UnsafePointer<UInt8>(sequenceParameterSets[0]),
            UnsafePointer<UInt8>(pictureParameterSets[0])
        ]
        var parameterSetSizes:[Int] = [
            sequenceParameterSets[0].count,
            pictureParameterSets[0].count
        ]
        return CMVideoFormatDescriptionCreateFromH264ParameterSets(
            kCFAllocatorDefault,
            2,
            &parameterSetPointers,
            &parameterSetSizes,
            naluLength,
            formatDescriptionOut
        )
    }
}

func AVCEncoderCallback(
    outputCallbackRefCon:UnsafeMutablePointer<Void>,
    sourceFrameRefCon:UnsafeMutablePointer<Void>,
    status:OSStatus,
    infoFlags:VTEncodeInfoFlags,
    sampleBuffer:CMSampleBuffer?) {
    let encoder:AVCEncoder = unsafeBitCast(outputCallbackRefCon, AVCEncoder.self)
    encoder.formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer!)
    encoder.delegate?.sampleOuput(video: sampleBuffer!)
}

class AVCEncoder:NSObject, Encoder, AVCaptureVideoDataOutputSampleBufferDelegate {

    static func getData(bytes: UnsafeMutablePointer<Int8>, length:Int) -> NSData {
        let mutableData:NSMutableData = NSMutableData()
        mutableData.appendBytes(bytes, length: length)
        return mutableData
    }

    static let defaultFPS:Int = 30
    static let defaultWidth:Int32 = 640
    static let defaultHeight:Int32 = 360

    static let defaultAttributes:[NSString: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA),
        kCVPixelBufferIOSurfacePropertiesKey: [:],
        kCVPixelBufferOpenGLESCompatibilityKey: true,
    ]

    var fps:Int = AVCEncoder.defaultFPS
    var width:Int32 = AVCEncoder.defaultWidth
    var height:Int32 = AVCEncoder.defaultHeight
    var bitrate:Int32 = 160 * 1000
    var keyframeInterval:Int = AVCEncoder.defaultFPS * 2
    var status:OSStatus = noErr
    var profile:AVCProfileIndication = .Baseline
    let lockQueue:dispatch_queue_t = dispatch_queue_create("com.github.shogo4405.lf.AVCEncoder.lock", DISPATCH_QUEUE_SERIAL)
    weak var delegate:VideoEncoderDelegate?

    var formatDescription:CMFormatDescriptionRef? = nil {
        didSet {
            if (!CMFormatDescriptionEqual(formatDescription, oldValue)) {
                delegate?.didSetFormatDescription(video: formatDescription)
            }
        }
    }

    private var attributes:[NSString: AnyObject] {
        var attributes:[NSString: AnyObject] = AVCEncoder.defaultAttributes
        attributes[kCVPixelBufferWidthKey] = NSNumber(int: width)
        attributes[kCVPixelBufferHeightKey] = NSNumber(int: height)
        return attributes
    }

    private var properties:[NSString: NSObject] {
        var properties:[NSString: NSObject] = [
            kVTCompressionPropertyKey_RealTime: kCFBooleanTrue,
            kVTCompressionPropertyKey_ProfileLevel: profile.autoLevel,
            kVTCompressionPropertyKey_AverageBitRate: Int(bitrate),
            kVTCompressionPropertyKey_ExpectedFrameRate: fps,
            kVTCompressionPropertyKey_MaxKeyFrameInterval: keyframeInterval,
            kVTCompressionPropertyKey_AllowFrameReordering: profile.allowFrameReordering,
        ]
        if (profile != .Baseline) {
            properties[kVTCompressionPropertyKey_H264EntropyMode] = kVTH264EntropyMode_CABAC
        }
        return properties
    }

    private var _session:VTCompressionSessionRef? = nil
    private var session:VTCompressionSessionRef! {
        get {
            if (_session == nil) {
                status = VTCompressionSessionCreate(
                    kCFAllocatorDefault,
                    width,
                    height,
                    kCMVideoCodecType_H264,
                    nil,
                    attributes,
                    nil,
                    AVCEncoderCallback,
                    unsafeBitCast(self, UnsafeMutablePointer<Void>.self),
                    &_session
                )
                if (status == noErr) {
                    status = VTSessionSetProperties(_session!, properties)
                }
                if (status == noErr) {
                    VTCompressionSessionPrepareToEncodeFrames(_session!)
                }
            }
            return _session!
        }
        set {
            if (_session != nil) {
                VTCompressionSessionInvalidate(_session!)
            }
            _session = newValue
        }
    }

    func encodeImageBuffer(imageBuffer:CVImageBuffer, presentationTimeStamp:CMTime, duration:CMTime) {
        var flags:VTEncodeInfoFlags = VTEncodeInfoFlags()
        VTCompressionSessionEncodeFrame(session, imageBuffer, presentationTimeStamp, duration, nil, nil, &flags)
    }

    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        let image:CVImageBufferRef = CMSampleBufferGetImageBuffer(sampleBuffer)!
        encodeImageBuffer(image, presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer), duration: CMSampleBufferGetDuration(sampleBuffer))
    }

    func dispose() {
        dispatch_async(lockQueue) {
            self.session = nil
            self.formatDescription = nil
        }
    }
}
