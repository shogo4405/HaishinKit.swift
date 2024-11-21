import Foundation
import VideoToolbox

struct VTSessionOptionKey: RawRepresentable {
    typealias RawValue = String

    static let depth = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_Depth as String)
    static let profileLevel = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_ProfileLevel as String)
    static let H264EntropyMode = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_H264EntropyMode as String)
    static let numberOfPendingFrames = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_NumberOfPendingFrames as String)
    static let pixelBufferPoolIsShared = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_PixelBufferPoolIsShared as String)
    static let videoEncoderPixelBufferAttributes = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_VideoEncoderPixelBufferAttributes as String)
    static let aspectRatio16x9 = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_AspectRatio16x9 as String)
    static let cleanAperture = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_CleanAperture as String)
    static let fieldCount = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_FieldCount as String)
    static let fieldDetail = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_FieldDetail as String)
    static let pixelAspectRatio = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_PixelAspectRatio as String)
    static let progressiveScan = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_ProgressiveScan as String)
    static let colorPrimaries = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_ColorPrimaries as String)
    static let transferFunction = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_TransferFunction as String)
    static let YCbCrMatrix = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_YCbCrMatrix as String)
    static let ICCProfile = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_ICCProfile as String)
    static let expectedDuration = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_ExpectedDuration as String)
    static let expectedFrameRate = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_ExpectedFrameRate as String)
    static let sourceFrameCount = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_SourceFrameCount as String)
    static let allowFrameReordering = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_AllowFrameReordering as String)
    static let allowTemporalCompression = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_AllowTemporalCompression as String)
    static let maxKeyFrameInterval = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_MaxKeyFrameInterval as String)
    static let maxKeyFrameIntervalDuration = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration as String)

    #if os(macOS)
    static let usingHardwareAcceleratedVideoEncoder = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_UsingHardwareAcceleratedVideoEncoder as String)
    static let requireHardwareAcceleratedVideoEncoder = VTSessionOptionKey(rawValue: kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder as String)
    static let enableHardwareAcceleratedVideoEncoder = VTSessionOptionKey(rawValue: kVTVideoEncoderSpecification_EnableHardwareAcceleratedVideoEncoder as String)
    #endif

    static let multiPassStorage = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_MultiPassStorage as String)
    static let forceKeyFrame = VTSessionOptionKey(rawValue: kVTEncodeFrameOptionKey_ForceKeyFrame as String)
    static let pixelTransferProperties = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_PixelTransferProperties as String)
    static let averageBitRate = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_AverageBitRate as String)
    static let dataRateLimits = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_DataRateLimits as String)
    static let moreFramesAfterEnd = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_MoreFramesAfterEnd as String)
    static let moreFramesBeforeStart = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_MoreFramesBeforeStart as String)
    static let quality = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_Quality as String)
    static let realTime = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_RealTime as String)
    static let maxH264SliceBytes = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_MaxH264SliceBytes as String)
    static let maxFrameDelayCount = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_MaxFrameDelayCount as String)
    static let encoderID = VTSessionOptionKey(rawValue: kVTVideoEncoderSpecification_EncoderID as String)

    @available(iOS 16.0, tvOS 16.0, macOS 13.0, *)
    static let constantBitRate = VTSessionOptionKey(rawValue: kVTCompressionPropertyKey_ConstantBitRate as String)

    let rawValue: String

    var CFString: CFString {
        return rawValue as CFString
    }

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}
