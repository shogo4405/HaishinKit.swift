import Foundation
import AVFoundation
import AudioToolbox

protocol Encoder {
    func dispose()
}

protocol VideoEncoderDelegate: class {
    func sampleOuput(video sampleBuffer: CMSampleBuffer)
}

protocol AudioEncoderDelegate: class {
    func sampleOuput(audio sampleBuffer: CMSampleBuffer)
}

func AACEncoderComplexInputDataProc(
    convert:AudioConverterRef,
    ioNumberDataPackets: UnsafeMutablePointer<UInt32>,
    ioData: UnsafeMutablePointer<AudioBufferList>,
    outDataPacketDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>>,
    inUserData:UnsafeMutablePointer<Void>) -> OSStatus {
    let encoder:AACEncoder = unsafeBitCast(inUserData, AACEncoder.self)
    print(encoder)
    return noErr
}

class AACEncoder:NSObject, Encoder, AVCaptureAudioDataOutputSampleBufferDelegate {
    var channels:UInt32 = 2
    var sampleRate:Double = 44100

    let lockQueue:dispatch_queue_t = dispatch_queue_create("com.github.shogo4405.lf.AACEncoder.lock", DISPATCH_QUEUE_SERIAL)

    private var _inSourceFormat:AudioStreamBasicDescription?
    var inSourceFormat:AudioStreamBasicDescription {
        get {
            if (_inSourceFormat == nil) {
                _inSourceFormat = AudioStreamBasicDescription()
                _inSourceFormat!.mFormatID = kAudioFormatLinearPCM
                _inSourceFormat!.mSampleRate = sampleRate
                _inSourceFormat!.mBitsPerChannel = 16
                _inSourceFormat!.mFramesPerPacket = 1
                _inSourceFormat!.mChannelsPerFrame = channels
            }
            return _inSourceFormat!
        }
        set {
            _inSourceFormat = newValue
        }
    }

    private var _inDestinationFormat:AudioStreamBasicDescription?
    var inDestinationFormat:AudioStreamBasicDescription {
        get {
            if (_inDestinationFormat == nil) {
                _inDestinationFormat = AudioStreamBasicDescription()
                _inDestinationFormat!.mFormatID = kAudioFormatMPEG4AAC
                _inDestinationFormat!.mSampleRate = sampleRate
                _inDestinationFormat!.mFormatFlags = 0
                _inDestinationFormat!.mChannelsPerFrame = channels
            }
            return _inDestinationFormat!
        }
        set {
            _inDestinationFormat = newValue
        }
    }

    lazy var inClassDescriptions:[AudioClassDescription] = {
        var inClassDescriptions:[AudioClassDescription] = []
        inClassDescriptions.append(AudioClassDescription(mType: kAudioEncoderComponentType, mSubType: kAudioFormatMPEG4AAC, mManufacturer: kAppleHardwareAudioCodecManufacturer))
        inClassDescriptions.append(AudioClassDescription(mType: kAudioEncoderComponentType,mSubType: kAudioFormatMPEG4AAC, mManufacturer: kAppleSoftwareAudioCodecManufacturer))
        return inClassDescriptions
    }()

    private var _converter:AudioConverterRef?
    private var converter:AudioConverterRef {
        get {
            var status:OSStatus = noErr
            if (_converter == nil) {
                status = AudioConverterNewSpecific(
                    &inSourceFormat,
                    &inDestinationFormat,
                    UInt32(inClassDescriptions.count),
                    &inClassDescriptions,
                    &_converter!
                )
            }
            if (status != noErr) {
                print(status)
            }
            return _converter!
        }
        set {
            if (_converter != nil) {
                AudioConverterDispose(_converter!)
            }
            _converter = newValue
        }
    }

    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
    }

    func fillComplexBuffer(inOutputDataPacketSize: UnsafeMutablePointer<UInt32>, outOutputData: UnsafeMutablePointer<AudioBufferList>, outPacketDescription: UnsafeMutablePointer<AudioStreamPacketDescription>) -> OSStatus {
        return AudioConverterFillComplexBuffer(
            converter,
            AACEncoderComplexInputDataProc,
            unsafeBitCast(self, UnsafeMutablePointer<Void>.self),
            inOutputDataPacketSize,
            outOutputData,
            outPacketDescription
        )
    }

    func dispose() {
        converter = nil
    }
}
