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
    return noErr
}

class AACEncoder:NSObject, Encoder, AVCaptureAudioDataOutputSampleBufferDelegate {
    private var _inSourceFormat:AudioStreamBasicDescription?
    var inSourceFormat:AudioStreamBasicDescription {
        get {
            return _inSourceFormat!
        }
        set {
            _inSourceFormat = newValue
        }
    }

    private var _inDestinationFormat:AudioStreamBasicDescription?
    var inDestinationFormat:AudioStreamBasicDescription {
        get {
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

    func fillComplexBuffer() -> OSStatus {
        return noErr
    }

    func dispose() {
        converter = nil
    }
}
