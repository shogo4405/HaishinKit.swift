import Foundation
import AudioToolbox
import AVFoundation

public class AudioStreamPlayback: NSObject {
    static let bufferSize:UInt32 = 128 * 1024
    static let numberOfBuffers:Int = 3
    static let maxPacketDescriptions:Int = 12 * 12

    public var soundTransform:SoundTransform = SoundTransform() {
        didSet {
            guard let queue:AudioQueueRef = queue where running else {
                return
            }
            soundTransform.setParameter(queue)
        }
    }

    public private(set) var running:Bool = false
    public private(set) var fileStreamID:AudioFileStreamID?
    public var formatDescription:AudioStreamBasicDescription? = nil {
        didSet {
            guard let _:AudioStreamBasicDescription = formatDescription else {
                return
            }
            guard newOutput(&formatDescription!) == noErr else {
                logger.warning("AudioQueueNewOutput")
                return
            }
        }
    }

    var inuse:[Bool] = []
    var bytes:[[UInt8]] = []
    var buffers:[AudioQueueBufferRef] = []
    var current:Int = 0
    var filledBytes:UInt32 = 0
    var filledPackets:Int = 0
    var packetDescriptions:[AudioStreamPacketDescription] = []

    private var started:Bool = false
    private var queue:AudioQueueRef? = nil
    private let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.AudioStreamPlayback.lock", DISPATCH_QUEUE_SERIAL
    )

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

            var bytes:[UInt8] = [UInt8](count: Int(packetSize + UInt32(offset)), repeatedValue: 0x00)
            var data:NSData = NSData(bytes: inInputData, length: Int(packetSize + UInt32(offset)))
            data.getBytes(&bytes, length: bytes.count)

            playback.bytes[playback.current] += Array(bytes[Int(offset)..<bytes.count])
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
        let playback:AudioStreamPlayback = unsafeBitCast(inClientData, AudioStreamPlayback.self)
        switch inPropertyID {
        case kAudioFileStreamProperty_ReadyToProducePackets:
            logger.info("ReadyToProducePackets")
            guard let
                queue:AudioQueueRef = playback.queue,
                fileFormatID:AudioFileStreamID = playback.fileStreamID,
                formatDescription:AudioStreamBasicDescription = AudioFileStreamUtil.getFormatDescription(fileFormatID),
                cookie:[UInt8] = AudioFileStreamUtil.getMagicCookie(fileFormatID) else {
                logger.warning("ReadyToProducePackets")
                return
            }
            playback.formatDescription = formatDescription
            playback.allocateBuffers()
            AudioQueueUtil.setMagicCookie(queue, inData: cookie)
        default:
            break
        }
    }

    public func allocateBuffers() {
        guard let queue:AudioQueueRef = queue else {
            return
        }
        for i in 0..<buffers.count {
            guard AudioQueueAllocateBuffer(
                queue,
                AudioStreamPlayback.bufferSize,
                &buffers[i]) == noErr else {
                logger.warning("AudioQueueAllocateBuffer[\(i)]")
                return
            }
        }
    }

    public func parseBytes(bytes:[UInt8]) -> OSStatus {
        guard let fileStreamID:AudioFileStreamID = fileStreamID where running else {
            return kAudio_ParamError
        }
        return AudioFileStreamParseBytes(
            fileStreamID,
            UInt32(bytes.count),
            bytes,
            AudioFileStreamParseFlags(rawValue: 0)
        )
    }

    public func enqueueBuffer() {
        dispatch_sync(lockQueue) {
            self.enqueueBufferProcess()
        }
    }

    private func enqueueBufferProcess() {
        guard let queue:AudioQueueRef = queue where running else {
            return
        }

        inuse[current] = true
        memcpy(buffers[current].memory.mAudioData, bytes[current], Int(filledBytes))
        buffers[current].memory.mAudioDataByteSize = filledBytes
        bytes[current].removeAll(keepCapacity: false)

        guard AudioQueueEnqueueBuffer(
            queue,
            buffers[current],
            UInt32(packetDescriptions.count),
            &packetDescriptions) == noErr else {
            logger.warning("AudioQueueEnqueueBuffer")
            return
        }

        if (started) {
            AudioQueueStart(queue, nil)
            started = true
        }

        if (AudioStreamPlayback.numberOfBuffers <= ++current) {
            current = 0
        }
        filledBytes = 0
        filledPackets = 0

        var loop:Bool = true
        repeat {
            objc_sync_enter(inuse)
            loop = inuse[current]
            objc_sync_exit(inuse)
            sleep(1)
        }
        while(loop)
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
            var fileStreamID = COpaquePointer()
            AudioFileStreamOpen(
                unsafeBitCast(self, UnsafeMutablePointer<Void>.self),
                self.propertyListenerProc,
                self.packetsProc,
                kAudioFileAAC_ADTSType,
                &fileStreamID
            )
            self.queue = AudioQueueRef()
            self.bytes = [[UInt8]](count: AudioStreamPlayback.numberOfBuffers, repeatedValue: [])
            self.inuse = [Bool](count: AudioStreamPlayback.numberOfBuffers, repeatedValue: false)
            self.fileStreamID = fileStreamID
            self.packetDescriptions = [AudioStreamPacketDescription](
                count: AudioStreamPlayback.maxPacketDescriptions, repeatedValue: AudioStreamPacketDescription()
            )
            for _ in 0..<AudioStreamPlayback.numberOfBuffers {
                var buffer:AudioQueueBuffer = AudioQueueBuffer(
                    mAudioDataBytesCapacity: AudioStreamPlayback.bufferSize,
                    mAudioData: UnsafeMutablePointer<Void>.alloc(Int(AudioStreamPlayback.bufferSize)),
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
            if let fileStreamID:AudioFileStreamID = self.fileStreamID {
                AudioFileStreamClose(fileStreamID)
            }
            if let queue:AudioQueueRef = self.queue {
                AudioQueueStop(queue, false)
                AudioQueueDispose(queue, true)
            }
            self.queue = nil
            self.bytes.removeAll(keepCapacity: false)
            self.inuse.removeAll(keepCapacity: false)
            self.buffers.removeAll(keepCapacity: false)
            self.started = false
            self.current = 0
            self.filledBytes = 0
            self.fileStreamID = nil
            self.filledPackets = 0
            self.packetDescriptions.removeAll(keepCapacity: false)
            self.running = false
        }
    }
}
