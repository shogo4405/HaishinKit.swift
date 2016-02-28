import Foundation
import AudioToolbox
import AVFoundation

public class AudioQueuePlayback: NSObject {
    public private(set) var running:Bool = false
    public private(set) var fileStreamID:AudioFileStreamID?
    public var formatDescription:AudioStreamBasicDescription? = nil {
        didSet {
            dispatch_async(lockQueue) {
                guard let _:AudioStreamBasicDescription = self.formatDescription else {
                    return
                }
                var fileStreamID = COpaquePointer()
                self.newOutput(&self.formatDescription!)
                AudioFileStreamOpen(
                    unsafeBitCast(self, UnsafeMutablePointer<Void>.self),
                    self.propertyListenerProc,
                    self.packetsProc,
                    kAudioFileAAC_ADTSType,
                    &fileStreamID
                )
                self.fileStreamID = fileStreamID
            }
        }
    }

    private var queue:AudioQueueRef? = nil
    private let lockQueue:dispatch_queue_t = dispatch_queue_create("com.github.shogo4405.lf.AudioQueuePlayback.lock", DISPATCH_QUEUE_SERIAL)

    private var outputCallback:AudioQueueOutputCallback = {(
        inUserData: UnsafeMutablePointer<Void>,
        inAQ: AudioQueueRef,
        inBuffer:AudioQueueBufferRef) -> Void in
    }

    private var packetsProc:AudioFileStream_PacketsProc = {(
        inClientData:UnsafeMutablePointer<Void>,
        inNumberBytes:UInt32,
        inNumberPackets:UInt32,
        inInputData:UnsafePointer<Void>,
        inPacketDescriptions:UnsafeMutablePointer<AudioStreamPacketDescription>) -> Void in
        let playback:AudioQueuePlayback = unsafeBitCast(inClientData, AudioQueuePlayback.self)
        for (var i:Int = 0; i < Int(inNumberPackets); ++i) {
            let offset:Int64 = inPacketDescriptions[i].mStartOffset
            let packetSize:UInt32 = inPacketDescriptions[i].mDataByteSize
        }
    }

    private var propertyListenerProc:AudioFileStream_PropertyListenerProc = {(
        inClientData:UnsafeMutablePointer<Void>,
        inAudioFileStream:AudioFileStreamID,
        inPropertyID:AudioFileStreamPropertyID,
        ioFlags:UnsafeMutablePointer<AudioFileStreamPropertyFlags>) -> Void in
        switch inPropertyID {
        case kAudioFileStreamProperty_ReadyToProducePackets:
            var asbd:AudioStreamBasicDescription = AudioStreamBasicDescription()
            var asbdSize:UInt32 = UInt32(sizeof(AudioStreamBasicDescription.self))
            AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataFormat, &asbdSize, &asbd)
            break
        default:
            break
        }
    }

    public func parseBytes(bytes:[UInt8]) -> OSStatus {
        guard let fileStreamID:AudioFileStreamID = fileStreamID where running else {
            return kAudio_ParamError
        }
        return AudioFileStreamParseBytes(fileStreamID, UInt32(bytes.count), bytes, AudioFileStreamParseFlags(rawValue: 0))
    }

    private func newOutput(inFormat: UnsafePointer<AudioStreamBasicDescription>) -> OSStatus {
        return AudioQueueNewOutput(inFormat, outputCallback, unsafeBitCast(self, UnsafeMutablePointer<Void>.self), CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &self.queue!)
    }
}

// MARK: - Runnable
extension AudioQueuePlayback: Runnable {
    public func startRunning() {
        dispatch_async(lockQueue) {
            guard !self.running else {
                return
            }
            self.queue = AudioQueueRef()
            self.running = true
        }
    }

    public func stopRunning() {
        dispatch_async(lockQueue) {
            guard self.running else {
                return
            }
            if let queue:AudioQueueRef = self.queue {
                AudioQueueStop(queue, false)
                AudioQueueDispose(queue, true)
            }
            self.queue = nil
            self.running = false
        }
    }
}