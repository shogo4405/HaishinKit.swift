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
}

// @see ISO/IEC 14496-15 2010
public struct AVCConfigurationRecord: CustomStringConvertible {
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
    encoder.delegate?.sampleOuput(video: sampleBuffer!)
}

class AVCEncoder:NSObject, Encode, AVCaptureVideoDataOutputSampleBufferDelegate {
    static let defaultAttributes:[NSString: NSObject] = [
        kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
        kCVPixelBufferOpenGLESCompatibilityKey: true,
    ]
    static let defaultEndcoderSpecifications:[NSString: NSObject] = [
        kVTVideoEncoderSpecification_EncoderID: "com.apple.videotoolbox.videoencoder.h264.gva",
    ]

    var width:Int32 = 640
    var height:Int32 = 480
    var status:OSStatus = noErr
    weak var delegate:VideoEncoderDelegate?

    private var attributes:[NSString: NSObject] {
        var attributes:[NSString: NSObject] = AVCEncoder.defaultAttributes
        attributes[kCVPixelBufferWidthKey] = NSNumber(int: width)
        attributes[kCVPixelBufferHeightKey] = NSNumber(int: height)
        return attributes
    }

    private var properties:[NSString: NSObject] = [:]
    private var _session:VTCompressionSession?
    private var session:VTCompressionSession! {
        get {
            if (_session == nil) {
                status = VTCompressionSessionCreate(
                    kCFAllocatorDefault,
                    width,
                    height,
                    kCMVideoCodecType_H264,
                    AVCEncoder.defaultEndcoderSpecifications,
                    attributes,
                    nil,
                    AVCEncoderCallback,
                    unsafeBitCast(self, UnsafeMutablePointer<Void>.self),
                    &_session
                )
                if (_session != nil) {
                    status = VTSessionSetProperties(_session!, properties)
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
    }

    func dispose() {
        session = nil
    }
}
