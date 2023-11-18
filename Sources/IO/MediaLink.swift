import AVFoundation

#if canImport(SwiftPMSupport)
import SwiftPMSupport
#endif

protocol MediaLinkDelegate: AnyObject {
    func mediaLink(_ mediaLink: MediaLink<Self>, dequeue sampleBuffer: CMSampleBuffer)
    func mediaLink(_ mediaLink: MediaLink<Self>, didBufferingChanged: Bool)
}

private let kMediaLink_bufferTime = 0.2
private let kMediaLink_bufferingTime = 0.0

final class MediaLink<T: MediaLinkDelegate> {
    var isPaused = false {
        didSet {
            guard isPaused != oldValue else {
                return
            }
            choreographer.isPaused = isPaused
            nstry({
                if self.isPaused {
                    self.playerNode.pause()
                } else {
                    self.playerNode.play()
                }
            }, { exeption in
                logger.warn(exeption)
            })
        }
    }
    var hasVideo = false
    var bufferTime = kMediaLink_bufferTime
    weak var delegate: T?
    private(set) lazy var playerNode = AVAudioPlayerNode()
    private(set) var isRunning: Atomic<Bool> = .init(false)
    private var isBuffering = true {
        didSet {
            if !isBuffering {
                bufferingTime = 0.0
            }
            isPaused = isBuffering
            delegate?.mediaLink(self, didBufferingChanged: isBuffering)
        }
    }
    private var bufferingTime = kMediaLink_bufferingTime
    private lazy var choreographer: any Choreographer = {
        var choreographer = DisplayLinkChoreographer()
        choreographer.delegate = self
        return choreographer
    }()
    private let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.MediaLink.lock")
    private var frameCount: AVAudioFramePosition = 0
    private var bufferQueue: CMBufferQueue?
    private var lastRenderTime: AVAudioTime = .zero
    private var scheduledAudioBuffers: Atomic<Int> = .init(0)
    private var presentationTimeStampOrigin: CMTime = .invalid

    func enqueue(_ buffer: CMSampleBuffer) {
        guard buffer.presentationTimeStamp != .invalid else {
            return
        }
        if presentationTimeStampOrigin == .invalid {
            presentationTimeStampOrigin = buffer.presentationTimeStamp
        }
        if buffer.presentationTimeStamp == presentationTimeStampOrigin {
            delegate?.mediaLink(self, dequeue: buffer)
            return
        }
        if let bufferQueue {
            CMBufferQueueEnqueue(bufferQueue, buffer: buffer)
        }
        if isBuffering {
            bufferingTime += bufferQueue?.duration.seconds ?? 0
            if bufferTime <= bufferingTime {
                bufferTime += 0.1
                isBuffering = false
            }
        }
    }

    func enqueue(_ audioBuffer: AVAudioBuffer, when: AVAudioTime) {
        guard let audioBuffer = audioBuffer as? AVAudioPCMBuffer else {
            return
        }
        if lastRenderTime == .zero {
            lastRenderTime = playerNode.lastRenderTime ?? .zero
        }
        nstry({
            self.scheduledAudioBuffers.mutate { $0 += 1 }
            if let at = AVAudioTime(sampleTime: self.frameCount, atRate: audioBuffer.format.sampleRate).extrapolateTime(fromAnchor: self.lastRenderTime) {
                self.playerNode.scheduleBuffer(audioBuffer, at: at, completionHandler: self.didAVAudioNodeCompletion)
            }
            self.frameCount += Int64(audioBuffer.frameLength)
            if !self.hasVideo && !self.playerNode.isPlaying && 10 <= self.scheduledAudioBuffers.value {
                self.playerNode.play()
            }
        }, { exeption in
            logger.warn(exeption)
        })
    }

    private func duration(_ duraiton: Double) -> Double {
        if playerNode.isPlaying {
            guard let nodeTime = playerNode.lastRenderTime, let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else {
                return 0.0
            }
            return TimeInterval(playerTime.sampleTime) / playerTime.sampleRate
        }
        return duraiton
    }

    private func didAVAudioNodeCompletion() {
        scheduledAudioBuffers.mutate {
            $0 -= 1
            if $0 == 0 {
                isBuffering = true
            }
        }
    }

    private func makeBufferkQueue() {
        CMBufferQueueCreate(
            allocator: kCFAllocatorDefault,
            capacity: 256,
            callbacks: CMBufferQueueGetCallbacksForSampleBuffersSortedByOutputPTS(),
            queueOut: &bufferQueue
        )
    }
}

extension MediaLink: ChoreographerDelegate {
    // MARK: ChoreographerDelegate
    func choreographer(_ choreographer: any Choreographer, didFrame duration: Double) {
        guard let bufferQueue else {
            return
        }
        let duration = self.duration(duration)
        var frameCount = 0
        while !CMBufferQueueIsEmpty(bufferQueue) {
            guard let head = CMBufferQueueGetHead(bufferQueue) else {
                break
            }
            let first = head as! CMSampleBuffer
            if first.presentationTimeStamp.seconds - presentationTimeStampOrigin.seconds <= duration {
                delegate?.mediaLink(self, dequeue: first)
                frameCount += 1
                CMBufferQueueDequeue(bufferQueue)
            } else {
                if 2 < frameCount {
                    logger.info("droppedFrame: \(frameCount)")
                }
                return
            }
        }
        isBuffering = true
    }
}

extension MediaLink: Running {
    // MARK: Running
    func startRunning() {
        lockQueue.async {
            guard !self.isRunning.value else {
                return
            }
            self.hasVideo = false
            self.bufferingTime = kMediaLink_bufferingTime
            self.isBuffering = true
            self.choreographer.startRunning()
            self.makeBufferkQueue()
            self.isRunning.mutate { $0 = true }
        }
    }

    func stopRunning() {
        lockQueue.async {
            guard self.isRunning.value else {
                return
            }
            self.choreographer.stopRunning()
            self.bufferQueue = nil
            self.frameCount = 0
            self.lastRenderTime = .zero
            self.scheduledAudioBuffers.mutate { $0 = 0 }
            self.presentationTimeStampOrigin = .invalid
            self.isRunning.mutate { $0 = false }
        }
    }
}
