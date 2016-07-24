import Foundation
import AudioToolbox
import AVFoundation

class AudioStreamPlayback {
    static let defaultBufferSize:UInt32 = 128 * 1024
    static let defaultNumberOfBuffers:Int = 128
    static let defaultMaxPacketDescriptions:Int = 1

    var await:Bool = false
    var numberOfBuffers:Int = AudioStreamPlayback.defaultNumberOfBuffers
    var maxPacketDescriptions:Int = AudioStreamPlayback.defaultMaxPacketDescriptions

    var soundTransform:SoundTransform = SoundTransform() {
        didSet {
            guard let queue:AudioQueueRef = queue where running else {
                return
            }
            soundTransform.setParameter(queue)
        }
    }

    private(set) var running:Bool = false
    var formatDescription:AudioStreamBasicDescription? = nil
    var fileTypeHint:AudioFileTypeID? = nil {
        didSet {
            guard let fileTypeHint:AudioFileTypeID = fileTypeHint where fileTypeHint != oldValue else {
                return
            }
            var fileStreamID:COpaquePointer = nil
            if AudioFileStreamOpen(
                unsafeBitCast(self, UnsafeMutablePointer<Void>.self),
                propertyListenerProc,
                packetsProc,
                fileTypeHint,
                &fileStreamID) == noErr {
                self.fileStreamID = fileStreamID
            }
        }
    }
    let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.AudioStreamPlayback.lock", DISPATCH_QUEUE_SERIAL
    )
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
        return packetDescriptions.count == maxPacketDescriptions
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

    func parseBytes(bytes:[UInt8]) {
        guard let fileStreamID:AudioFileStreamID = self.fileStreamID where self.running else {
            return
        }
        AudioFileStreamParseBytes(
            fileStreamID,
            UInt32(bytes.count),
            bytes,
            AudioFileStreamParseFlags(rawValue: 0)
        )
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
        if (numberOfBuffers <= current) {
            current = 0
        }
        filledBytes = 0
        packetDescriptions.removeAll()
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
        guard AudioQueueEnqueueBuffer(
            queue,
            buffer,
            UInt32(packetDescriptions.count),
            &packetDescriptions) == noErr else {
            logger.warning("AudioQueueEnqueueBuffer")
            return
        }
        startQueueIfNeed()
    }

    func startQueueIfNeed() {
        guard let queue:AudioQueueRef = queue where !started else {
            return
        }
        started = true
        AudioQueuePrime(queue, 0, nil)
        AudioQueueStart(queue, nil)
    }

    func initializeForAudioQueue() {
        guard let _:AudioStreamBasicDescription = formatDescription where self.queue == nil else {
            return
        }
        var queue:AudioQueueRef = nil
        AudioQueueNewOutput(
            &self.formatDescription!,
            self.outputCallback,
            unsafeBitCast(self, UnsafeMutablePointer<Void>.self),
            CFRunLoopGetCurrent(),
            kCFRunLoopCommonModes,
            0,
            &queue)
        if let cookie:[UInt8] = getMagicCookieForFileStream() {
            setMagicCookieForQueue(cookie)
        }
        soundTransform.setParameter(queue)
        for i in 0..<buffers.count {
            AudioQueueAllocateBuffer(queue, bufferSize, &buffers[i])
        }
        self.queue = queue
    }

    final func onOutputForQueue(inAQ: AudioQueueRef, _ inBuffer:AudioQueueBufferRef) {
        guard let i:Int = buffers.indexOf(inBuffer) else {
            return
        }
        objc_sync_enter(inuse)
        inuse[i] = false
        objc_sync_exit(inuse)
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
        guard status == noErr else {
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
    func startRunning() {
        dispatch_async(lockQueue) {
            guard !self.running else {
                return
            }
            self.inuse = [Bool](count: self.numberOfBuffers, repeatedValue: false)
            self.started = false
            self.current = 0
            self.filledBytes = 0
            self.fileTypeHint = nil
            self.packetDescriptions.removeAll()
            for _ in 0..<self.numberOfBuffers {
                let queue:AudioQueueBufferRef = nil
                self.buffers.append(queue)
            }
            self.running = true
            AudioUtil.startRunning()
        }
    }

    func stopRunning() {
        dispatch_async(lockQueue) {
            guard self.running else {
                return
            }
            self.queue = nil
            self.inuse.removeAll()
            self.buffers.removeAll()
            self.started = false
            self.fileStreamID = nil
            self.packetDescriptions.removeAll()
            self.running = false
            AudioUtil.stopRunning()
        }
    }
}
