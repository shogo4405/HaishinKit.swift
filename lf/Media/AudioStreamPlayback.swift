import Foundation
import AudioToolbox
import AVFoundation

public class AudioStreamPlayback: NSObject {
    static let bufferSize:UInt32 = 128 * 1024
    static let numberOfBuffers:Int = 3
    static let maxPacketDescriptions:Int = 128

    public var soundTransform:SoundTransform = SoundTransform() {
        didSet {
            guard let queue:AudioQueueRef = queue where running else {
                return
            }
            soundTransform.setParameter(queue)
        }
    }

    public private(set) var running:Bool = false
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

    private var queue:AudioQueueRef? = nil
    private var inuse:[Bool] = []
    private var buffers:[AudioQueueBufferRef] = []
    private var current:Int = 0
    private var started:Bool = false
    private var filledBytes:UInt32 = 0
    private var packetDescriptions:[AudioStreamPacketDescription] = []
    private var fileStreamID:AudioFileStreamID?
    private var isPacketDescriptionsFull:Bool {
        return packetDescriptions.count == AudioStreamPlayback.maxPacketDescriptions
    }

    private let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.AudioStreamPlayback.lock", DISPATCH_QUEUE_SERIAL
    )

    private var isRunningProc:AudioQueuePropertyListenerProc = {(
        inUserData:UnsafeMutablePointer<Void>,
        inAQ:AudioQueueRef,
        inID:AudioQueuePropertyID) -> Void in
        let isRunning:Bool = AudioQueueUtil.isRunnning(inAQ)
    }

    private var outputCallback:AudioQueueOutputCallback = {(
        inUserData: UnsafeMutablePointer<Void>,
        inAQ: AudioQueueRef,
        inBuffer:AudioQueueBufferRef) -> Void in
        let playback:AudioStreamPlayback = unsafeBitCast(inUserData, AudioStreamPlayback.self)
        playback.onOutputForQueue(inAQ, inBuffer)
    }

    private var packetsProc:AudioFileStream_PacketsProc = {(
        inClientData:UnsafeMutablePointer<Void>,
        inNumberBytes:UInt32,
        inNumberPackets:UInt32,
        inInputData:UnsafePointer<Void>,
        inPacketDescriptions:UnsafeMutablePointer<AudioStreamPacketDescription>) -> Void in
        let playback:AudioStreamPlayback = unsafeBitCast(inClientData, AudioStreamPlayback.self)
        playback.onAudioPacketsForFileStream(inNumberBytes, inNumberPackets, inInputData, inPacketDescriptions)
    }

    private var propertyListenerProc:AudioFileStream_PropertyListenerProc = {(
        inClientData:UnsafeMutablePointer<Void>,
        inAudioFileStream:AudioFileStreamID,
        inPropertyID:AudioFileStreamPropertyID,
        ioFlags:UnsafeMutablePointer<AudioFileStreamPropertyFlags>) -> Void in
        let playback:AudioStreamPlayback = unsafeBitCast(inClientData, AudioStreamPlayback.self)
        playback.onPropertyChangeForFileStream(inAudioFileStream, inPropertyID, ioFlags)
    }

    public func parseBytes(bytes:[UInt8]) {
        guard let fileStreamID:AudioFileStreamID = self.fileStreamID where self.running else {
            return
        }
        guard AudioFileStreamParseBytes(
            fileStreamID,
            UInt32(bytes.count),
            bytes,
            AudioFileStreamParseFlags(rawValue: 0)
            ) == noErr else {
            logger.warning("parseBytes")
            return
        }
    }

    func allocateBuffers() {
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

    func isBufferFull(packetSize:UInt32) -> Bool {
        return (AudioStreamPlayback.bufferSize - filledBytes) < packetSize
    }

    func appendBuffer(inInputData:UnsafePointer<Void>, var inPacketDescription:AudioStreamPacketDescription) {
        let offset:Int = Int(inPacketDescription.mStartOffset)
        let packetSize:UInt32 = inPacketDescription.mDataByteSize
        if (isBufferFull(packetSize) || isPacketDescriptionsFull) {
            enqueueBuffer()
        }
        let buffer:AudioQueueBufferRef = buffers[current]
        memcpy(buffer.memory.mAudioData.advancedBy(Int(filledBytes)), inInputData.advancedBy(offset), Int(packetSize))
        inPacketDescription.mStartOffset = Int64(filledBytes)
        packetDescriptions.append(inPacketDescription)
        filledBytes += packetSize
    }

    func enqueueBuffer() {
        guard let queue:AudioQueueRef = queue where running else {
            return
        }

        inuse[current] = true
        let buffer:AudioQueueBufferRef = buffers[current]
        buffer.memory.mAudioDataByteSize = filledBytes

        guard IsNoErr(AudioQueueEnqueueBuffer(queue, buffer, UInt32(packetDescriptions.count), &packetDescriptions), "AudioQueueEnqueueBuffer") else {
            return
        }

        if (!started) {
            started = true
            if let cookie:[UInt8] = AudioFileStreamUtil.getMagicCookie(fileStreamID!) {
                AudioQueueUtil.setMagicCookie(queue, cookie)
            }
            AudioQueueUtil.addIsRuuningListener(queue, isRunningProc, nil)
            soundTransform.setParameter(queue)
            AudioQueuePrime(queue, 0, nil)
            AudioQueueStart(queue, nil)
        }

        packetDescriptions.removeAll(keepCapacity: false)
        if (AudioStreamPlayback.numberOfBuffers <= ++current) {
            current = 0
        }
        filledBytes = 0

        var loop:Bool = true
        repeat {
            objc_sync_enter(inuse)
            loop = inuse[current]
            objc_sync_exit(inuse)
        }
        while(loop)
    }

    final func onOutputForQueue(inAQ: AudioQueueRef, _ inBuffer:AudioQueueBufferRef) {
        if let i:Int = buffers.indexOf(inBuffer) {
            objc_sync_enter(inuse)
            inuse[i] = false
            memset(inBuffer.memory.mAudioData, 0x00, Int(AudioStreamPlayback.bufferSize))
            objc_sync_exit(inuse)
        }
    }

    final func onAudioPacketsForFileStream(inNumberBytes:UInt32, _ inNumberPackets:UInt32, _ inInputData:UnsafePointer<Void>, _ inPacketDescriptions:UnsafeMutablePointer<AudioStreamPacketDescription>) {
        for (var i:Int = 0; i < Int(inNumberPackets); ++i) {
            appendBuffer(inInputData, inPacketDescription: inPacketDescriptions[i])
        }
    }

    final func onPropertyChangeForFileStream(inAudioFileStream:AudioFileStreamID, _ inPropertyID:AudioFileStreamPropertyID, _ ioFlags:UnsafeMutablePointer<AudioFileStreamPropertyFlags>) {
        switch inPropertyID {
        case kAudioFileStreamProperty_ReadyToProducePackets:
            guard let
                _:AudioQueueRef = self.queue,
                fileFormatID:AudioFileStreamID = fileStreamID,
                formatDescription:AudioStreamBasicDescription = AudioFileStreamUtil.getFormatDescription(fileFormatID) else {
                logger.warning("ReadyToProducePackets")
                return
            }
            self.formatDescription = formatDescription
            allocateBuffers()
        default:
            break
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

            var fileStreamID = COpaquePointer()
            AudioFileStreamOpen(
                unsafeBitCast(self, UnsafeMutablePointer<Void>.self),
                self.propertyListenerProc,
                self.packetsProc,
                kAudioFileAAC_ADTSType,
                &fileStreamID
            )

            self.queue = AudioQueueRef()
            self.inuse = [Bool](count: AudioStreamPlayback.numberOfBuffers, repeatedValue: false)
            self.started = false
            self.fileStreamID = fileStreamID
            self.packetDescriptions.removeAll(keepCapacity: false)
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
                self.buffers.append(&buffer)
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
            self.inuse.removeAll(keepCapacity: false)
            self.buffers.removeAll(keepCapacity: false)
            self.started = false
            self.current = 0
            self.filledBytes = 0
            self.fileStreamID = nil
            self.packetDescriptions.removeAll(keepCapacity: false)
            self.running = false
        }
    }
}
