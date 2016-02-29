import Foundation
import AudioToolbox
import AVFoundation

public class AudioStreamPlayback: NSObject {
    static let bufferSize:UInt32 = 128 * 1024
    static let numberOfBuffers:Int = 3
    static let maxPacketDescriptions:Int = 3

    public private(set) var running:Bool = false
    public private(set) var fileStreamID:AudioFileStreamID?
    public var formatDescription:AudioStreamBasicDescription? = nil {
        didSet {
            dispatch_async(lockQueue) {
                guard let _:AudioStreamBasicDescription = self.formatDescription else {
                    return
                }
                var fileStreamID = COpaquePointer()
                AudioFileStreamOpen(
                    unsafeBitCast(self, UnsafeMutablePointer<Void>.self),
                    self.propertyListenerProc,
                    self.packetsProc,
                    kAudioFileAAC_ADTSType,
                    &fileStreamID
                )
                self.fileStreamID = fileStreamID
                self.newOutput(&self.formatDescription!)
            }
        }
    }

    private(set) var inuse:[Bool] = []
    private(set) var bytes:[[UInt8]] = []
    private(set) var buffers:[AudioQueueBufferRef] = []
    private(set) var current:Int = 0
    private(set) var filledBytes:UInt32 = 0
    private(set) var filledPackets:Int = 0
    private(set) var packetDescriptions:[AudioStreamPacketDescription] = []

    private var queue:AudioQueueRef? = nil
    private let lockQueue:dispatch_queue_t = dispatch_queue_create("com.github.shogo4405.lf.AudioQueuePlayback.lock", DISPATCH_QUEUE_SERIAL)

    private var outputCallback:AudioQueueOutputCallback = {(
        inUserData: UnsafeMutablePointer<Void>,
        inAQ: AudioQueueRef,
        inBuffer:AudioQueueBufferRef) -> Void in
        let playback:AudioStreamPlayback = unsafeBitCast(inUserData, AudioStreamPlayback.self)
        if let i:Int = playback.buffers.indexOf(inBuffer) {
            objc_sync_enter(playback.inuse)
            playback.inuse[i] = false
            objc_sync_exit(playback.inuse)
        }
    }

    private var packetsProc:AudioFileStream_PacketsProc = {(
        inClientData:UnsafeMutablePointer<Void>,
        inNumberBytes:UInt32,
        inNumberPackets:UInt32,
        inInputData:UnsafePointer<Void>,
        inPacketDescriptions:UnsafeMutablePointer<AudioStreamPacketDescription>) -> Void in

        let playback:AudioStreamPlayback = unsafeBitCast(inClientData, AudioStreamPlayback.self)
        for (var i:Int = 0; i < Int(inNumberPackets); ++i) {
            let offset:Int64 = inPacketDescriptions[i].mStartOffset
            let packetSize:UInt32 = inPacketDescriptions[i].mDataByteSize
            let spaceRemaining:UInt32 = AudioStreamPlayback.bufferSize - playback.filledBytes

            if (spaceRemaining < packetSize) {
                playback.enqueueBuffer()
            }

            var bytes:[UInt8] = [UInt8](count: Int(packetSize) - Int(offset), repeatedValue: 0x00)
            var data:NSData = NSData(bytes: inInputData, length: Int(packetSize))
            data.getBytes(&bytes, range: NSMakeRange(Int(offset), bytes.count))

            playback.bytes[playback.current] += bytes
            playback.packetDescriptions[playback.filledPackets] = inPacketDescriptions[i]
            playback.packetDescriptions[playback.filledPackets].mStartOffset = Int64(playback.filledBytes)
            playback.filledBytes += packetSize
            ++playback.filledPackets

            let packetsRemaining = AudioStreamPlayback.maxPacketDescriptions - playback.filledPackets
            if (packetsRemaining == 0) {
                playback.enqueueBuffer()
            }
        }
    }

    private var propertyListenerProc:AudioFileStream_PropertyListenerProc = {(
        inClientData:UnsafeMutablePointer<Void>,
        inAudioFileStream:AudioFileStreamID,
        inPropertyID:AudioFileStreamPropertyID,
        ioFlags:UnsafeMutablePointer<AudioFileStreamPropertyFlags>) -> Void in
    }

    public func parseBytes(bytes:[UInt8]) -> OSStatus {
        guard let fileStreamID:AudioFileStreamID = fileStreamID where running else {
            return kAudio_ParamError
        }
        return AudioFileStreamParseBytes(fileStreamID, UInt32(bytes.count), bytes, AudioFileStreamParseFlags(rawValue: 0))
    }


    public func enqueueBuffer() {
        dispatch_async(lockQueue) {
            guard self.running else {
                return
            }
            var status:OSStatus = noErr
            let buffer:AudioQueueBufferRef = self.buffers[self.current]
            buffer.memory.mAudioData = UnsafeMutablePointer<Void>(self.bytes[self.current])
            buffer.memory.mAudioDataByteSize = self.filledBytes
            status = AudioQueueEnqueueBuffer(self.queue!, buffer, UInt32(self.current), &self.packetDescriptions)
            if (status != noErr) { print(status) }
            if (AudioStreamPlayback.numberOfBuffers < ++self.current) {
                self.current = 0
            }
            self.filledBytes = 0
            self.filledPackets = 0
            var inuse:Bool = true
            repeat {
                objc_sync_enter(self.inuse)
                inuse = self.inuse[self.current]
                objc_sync_exit(self.inuse)
            } while(inuse)
        }
    }

    private func newOutput(inFormat: UnsafePointer<AudioStreamBasicDescription>) -> OSStatus {
        return AudioQueueNewOutput(inFormat,
            outputCallback,
            unsafeBitCast(self, UnsafeMutablePointer<Void>.self),
            CFRunLoopGetCurrent(),
            kCFRunLoopCommonModes,
            0,
            &self.queue!
        )
    }
}

// MARK: - Runnable
extension AudioStreamPlayback: Runnable {
    public func startRunning() {
        dispatch_async(lockQueue) {
            guard !self.running else {
                return
            }
            self.queue = AudioQueueRef()
            self.bytes = [[UInt8]](count: AudioStreamPlayback.numberOfBuffers, repeatedValue: [])
            self.inuse = [Bool](count: AudioStreamPlayback.numberOfBuffers, repeatedValue: false)
            self.packetDescriptions = [AudioStreamPacketDescription](
                count: AudioStreamPlayback.maxPacketDescriptions, repeatedValue: AudioStreamPacketDescription()
            )
            for _ in 0..<AudioStreamPlayback.numberOfBuffers {
                var buffer:AudioQueueBuffer = AudioQueueBuffer(
                    mAudioDataBytesCapacity: 0,
                    mAudioData: nil,
                    mAudioDataByteSize: 0,
                    mUserData: nil,
                    mPacketDescriptionCapacity: 0,
                    mPacketDescriptions: nil,
                    mPacketDescriptionCount: 0
                )
                self.buffers.append(withUnsafeMutablePointer(&buffer){$0})
            }
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
            self.bytes.removeAll(keepCapacity: false)
            self.inuse.removeAll(keepCapacity: false)
            self.buffers.removeAll(keepCapacity: false)
            self.current = 0
            self.filledBytes = 0
            self.filledPackets = 0
            self.packetDescriptions.removeAll(keepCapacity: false)
            self.running = false
        }
    }
}
