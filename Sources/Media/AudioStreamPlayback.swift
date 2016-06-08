import Foundation
import AudioToolbox
import AVFoundation

public class AudioStreamPlayback: NSObject {
    static let numberOfBuffers:Int = 3
    static let defaultBufferSize:UInt32 = 128 * 1024
    static let maxPacketDescriptions:Int = 12

    public var soundTransform:SoundTransform = SoundTransform() {
        didSet {
            guard let queue:AudioQueueRef = queue where running else {
                return
            }
            soundTransform.setParameter(queue)
        }
    }

    public private(set) var running:Bool = false
    public var formatDescription:AudioStreamBasicDescription? = nil
    public var fileTypeHint:AudioFileTypeID? = nil {
        didSet {
            guard let fileTypeHint:AudioFileTypeID = fileTypeHint where fileTypeHint != oldValue else {
                return
            }
            var fileStreamID:COpaquePointer = nil
            if IsNoErr(AudioFileStreamOpen(
                unsafeBitCast(self, UnsafeMutablePointer<Void>.self),
                self.propertyListenerProc,
                self.packetsProc,
                fileTypeHint,
                &fileStreamID
                ), "") {
                self.fileStreamID = fileStreamID
            }
        }
    }

    private var bufferSize:UInt32 = AudioStreamPlayback.defaultBufferSize
    private var queue:AudioQueueRef? = nil {
        didSet {
            guard let oldValue:AudioQueueRef = oldValue else {
                return
            }
            AudioQueueStop(oldValue, true)
            AudioQueueDispose(oldValue, true)
        }
    }
    private var inuse:[Bool] = []
    private var buffers:[AudioQueueBufferRef] = []
    private var current:Int = 0
    private var started:Bool = false
    private var filledBytes:UInt32 = 0
    private var packetDescriptions:[AudioStreamPacketDescription] = []
    private var fileStreamID:AudioFileStreamID? = nil {
        didSet {
            guard let oldValue:AudioFileStreamID = oldValue else {
                return
            }
            AudioFileStreamClose(oldValue)
        }
    }
    private var isPacketDescriptionsFull:Bool {
        return packetDescriptions.count == AudioStreamPlayback.maxPacketDescriptions
    }
    private let backgroundQueue:dispatch_queue_t = {
        var queue:dispatch_queue_t = dispatch_queue_create(
            "com.github.shogo4405.lf.AudioStreamPlayback.background", DISPATCH_QUEUE_CONCURRENT
        )
        dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0))
        return queue
    }()
    let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.AudioStreamPlayback.lock", DISPATCH_QUEUE_SERIAL
    )

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
        playback.initializeForAudioQueue()
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

    func isBufferFull(packetSize:UInt32) -> Bool {
        return (bufferSize - filledBytes) < packetSize
    }

    func appendBuffer(inInputData:UnsafePointer<Void>, inout inPacketDescription:AudioStreamPacketDescription) {
        let offset:Int = Int(inPacketDescription.mStartOffset)
        let packetSize:UInt32 = inPacketDescription.mDataByteSize
        if (isBufferFull(packetSize) || isPacketDescriptionsFull) {
            enqueueBuffer()
            rotateBuffer()
        }
        let buffer:AudioQueueBufferRef = buffers[current]
        memcpy(buffer.memory.mAudioData.advancedBy(Int(filledBytes)), inInputData.advancedBy(offset), Int(packetSize))
        inPacketDescription.mStartOffset = Int64(filledBytes)
        packetDescriptions.append(inPacketDescription)
        filledBytes += packetSize
    }

    func rotateBuffer() {
        current += 1
        packetDescriptions.removeAll(keepCapacity: false)
        if (AudioStreamPlayback.numberOfBuffers <= current) {
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

    func enqueueBuffer() {
        guard let queue:AudioQueueRef = queue where running else {
            return
        }
        inuse[current] = true
        let buffer:AudioQueueBufferRef = buffers[current]
        buffer.memory.mAudioDataByteSize = filledBytes
        guard IsNoErr(AudioQueueEnqueueBuffer(
            queue,
            buffer,
            UInt32(packetDescriptions.count),
            &packetDescriptions),
            "AudioQueueEnqueueBuffer") else {
            return
        }
        startQueueIfNeed()
    }

    func startQueueIfNeed() {
        dispatch_async(backgroundQueue) {
            guard let queue:AudioQueueRef = self.queue where !self.started else {
                return
            }
            self.started = true
            AudioQueuePrime(queue, 0, nil)
            AudioQueueStart(queue, nil)
            while (self.started) {
                CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.25, false)
            }
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 2, false)
        }
    }

    func initializeForAudioQueue() {
        guard let _:AudioStreamBasicDescription = formatDescription where self.queue == nil else {
            return
        }
        var queue:AudioQueueRef = nil
        dispatch_sync(backgroundQueue) {
            IsNoErr(AudioQueueNewOutput(
                &self.formatDescription!,
                self.outputCallback,
                unsafeBitCast(self, UnsafeMutablePointer<Void>.self),
                CFRunLoopGetCurrent(),
                kCFRunLoopCommonModes,
                0,
                &queue),
                "")
        }
        if let cookie:[UInt8] = getMagicCookieForFileStream() {
            setMagicCookieForQueue(cookie)
        }
        soundTransform.setParameter(queue)
        for i in 0..<buffers.count {
            IsNoErr(AudioQueueAllocateBuffer(queue, bufferSize, &buffers[i]), "AllocateBuffer[\(i)]")
        }
        self.queue = queue
    }

    final func onOutputForQueue(inAQ: AudioQueueRef, _ inBuffer:AudioQueueBufferRef) {
        if let i:Int = buffers.indexOf(inBuffer) {
            objc_sync_enter(inuse)
            inuse[i] = false
            objc_sync_exit(inuse)
        }
    }

    final func onAudioPacketsForFileStream(inNumberBytes:UInt32, _ inNumberPackets:UInt32, _ inInputData:UnsafePointer<Void>, _ inPacketDescriptions:UnsafeMutablePointer<AudioStreamPacketDescription>) {
        for i in 0..<Int(inNumberPackets) {
            appendBuffer(inInputData, inPacketDescription: &inPacketDescriptions[i])
        }
    }

    final func onPropertyChangeForFileStream(inAudioFileStream:AudioFileStreamID, _ inPropertyID:AudioFileStreamPropertyID, _ ioFlags:UnsafeMutablePointer<AudioFileStreamPropertyFlags>) {
        switch inPropertyID {
        case kAudioFileStreamProperty_ReadyToProducePackets:
            break
        case kAudioFileStreamProperty_DataFormat:
            formatDescription = getFormatDescriptionForFileStream()
        default:
            break
        }
    }

    func setMagicCookieForQueue(inData: [UInt8]) -> Bool {
        guard let queue:AudioQueueRef = queue else {
            return false
        }
        var status:OSStatus = noErr
        status = AudioQueueSetProperty(queue, kAudioQueueProperty_MagicCookie, inData, UInt32(inData.count))
        if (status != noErr) {
            logger.warning("status \(status)")
            return false
        }
        return true
    }

    func getFormatDescriptionForFileStream() -> AudioStreamBasicDescription? {
        guard let fileStreamID:AudioFileStreamID = fileStreamID else {
            return nil
        }
        var data:AudioStreamBasicDescription = AudioStreamBasicDescription()
        var size:UInt32 = UInt32(sizeof(data.dynamicType))
        guard AudioFileStreamGetProperty(fileStreamID, kAudioFileStreamProperty_DataFormat, &size, &data) == noErr else {
            logger.warning("kAudioFileStreamProperty_DataFormat")
            return nil
        }
        return data
    }
    
    func getMagicCookieForFileStream() -> [UInt8]? {
        guard let fileStreamID:AudioFileStreamID = fileStreamID else {
            return nil
        }
        var size:UInt32 = 0
        var writable:DarwinBoolean = true
        guard AudioFileStreamGetPropertyInfo(fileStreamID, kAudioFileStreamProperty_MagicCookieData, &size, &writable) == noErr else {
            logger.warning("info kAudioFileStreamProperty_MagicCookieData")
            return nil
        }
        var data:[UInt8] = [UInt8](count: Int(size), repeatedValue: 0)
        guard AudioFileStreamGetProperty(fileStreamID, kAudioFileStreamProperty_MagicCookieData, &size, &data) == noErr else {
            logger.warning("kAudioFileStreamProperty_MagicCookieData")
            return nil
        }
        return data
    }
}

// MARK: Runnable
extension AudioStreamPlayback: Runnable {
    public func startRunning() {
        dispatch_async(lockQueue) {
            guard !self.running else {
                return
            }
            self.inuse = [Bool](count: AudioStreamPlayback.numberOfBuffers, repeatedValue: false)
            self.started = false
            self.current = 0
            self.filledBytes = 0
            self.fileTypeHint = nil
            self.packetDescriptions.removeAll(keepCapacity: false)
            for _ in 0..<AudioStreamPlayback.numberOfBuffers {
                let queue:AudioQueueBufferRef = nil
                self.buffers.append(queue)
            }
            self.running = true
            AudioUtil.startRunning()
        }
    }

    public func stopRunning() {
        dispatch_async(lockQueue) {
            guard self.running else {
                return
            }
            self.queue = nil
            self.inuse.removeAll(keepCapacity: false)
            self.buffers.removeAll(keepCapacity: false)
            self.started = false
            self.fileStreamID = nil
            self.packetDescriptions.removeAll(keepCapacity: false)
            self.running = false
            AudioUtil.stopRunning()
        }
    }
}
