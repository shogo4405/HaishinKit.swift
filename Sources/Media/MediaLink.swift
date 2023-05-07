import AVFoundation

#if canImport(SwiftPMSupport)
import SwiftPMSupport
#endif

protocol MediaLinkDelegate: AnyObject {
    func mediaLink(_ mediaLink: MediaLink, dequeue sampleBuffer: CMSampleBuffer)
    func mediaLink(_ mediaLink: MediaLink, didBufferingChanged: Bool)
}

final class MediaLink {
    private static let bufferTime = 0.2
    private static let bufferingTime = 0.0

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
    var bufferTime = MediaLink.bufferTime
    weak var delegate: (any MediaLinkDelegate)?
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
    private var bufferingTime = MediaLink.bufferingTime
    private lazy var choreographer: any Choreographer = {
        var choreographer = DisplayLinkChoreographer()
        choreographer.delegate = self
        return choreographer
    }()
    private let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.DisplayLinkedQueue.lock")
    private var bufferQueue: CMBufferQueue?
    private var scheduledAudioBuffers: Atomic<Int> = .init(0)
    private var presentationTimeStampOrigin: CMTime = .invalid

    func enqueueVideo(_ buffer: CMSampleBuffer) {
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
            bufferingTime += buffer.duration.seconds
            if bufferTime <= bufferingTime {
                bufferTime += 0.1
                isBuffering = false
            }
        }
    }

    func enqueueAudio(_ buffer: AVAudioPCMBuffer) {
        nstry({
            self.scheduledAudioBuffers.mutate { $0 += 1 }
            self.playerNode.scheduleBuffer(buffer, completionHandler: self.didAVAudioNodeCompletion)
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
            self.bufferingTime = Self.bufferingTime
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
            self.scheduledAudioBuffers.mutate { $0 = 0 }
            self.presentationTimeStampOrigin = .invalid
            self.isRunning.mutate { $0 = false }
        }
    }
}
