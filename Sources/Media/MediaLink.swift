import AVFoundation

#if canImport(SwiftPMSupport)
import SwiftPMSupport
#endif

protocol MediaLinkDelegate: AnyObject {
    func mediaLink(_ mediaLink: MediaLink, dequeue sampleBuffer: CMSampleBuffer)
    func mediaLink(_ mediaLink: MediaLink, didBufferingChanged: Bool)
}

final class MediaLink {
    static let defaultBufferTime: Double = 0.2

    var isPaused = false {
        didSet {
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
    var bufferTime = MediaLink.defaultBufferTime
    weak var delegate: MediaLinkDelegate?
    lazy var playerNode = AVAudioPlayerNode()
    private(set) var isRunning: Atomic<Bool> = .init(false)
    private var buffer: RingBuffer<CMSampleBuffer> = .init(256)
    private var isBuffering = true {
        didSet {
            if !isBuffering {
                bufferingTime = 0.0
            }
            isPaused = isBuffering
            delegate?.mediaLink(self, didBufferingChanged: isBuffering)
        }
    }
    private var bufferingTime: Double = 0.0
    private lazy var choreographer: Choreographer = {
        var choreographer = DisplayLinkChoreographer()
        choreographer.delegate = self
        return choreographer
    }()
    private var scheduledAudioBuffers: Atomic<Int> = .init(0)
    private let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.DisplayLinkedQueue.lock")

    func enqueueVideo(_ buffer: CMSampleBuffer) {
        guard buffer.presentationTimeStamp != .invalid else {
            return
        }
        if buffer.presentationTimeStamp.seconds == 0.0 {
            delegate?.mediaLink(self, dequeue: buffer)
            return
        }
        _ = self.buffer.append(buffer)
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
}

extension MediaLink: ChoreographerDelegate {
    // MARK: ChoreographerDelegate
    func choreographer(_ choreographer: Choreographer, didFrame duration: Double) {
        let duration = self.duration(duration)
        var frameCount = 0
        while !buffer.isEmpty {
            guard let first = buffer.first else {
                break
            }
            if first.presentationTimeStamp.seconds <= duration {
                delegate?.mediaLink(self, dequeue: first)
                frameCount += 1
                buffer.removeFirst()
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
            self.bufferingTime = Self.defaultBufferTime
            self.choreographer.startRunning()
            self.isRunning.mutate { $0 = true }
        }
    }

    func stopRunning() {
        lockQueue.async {
            guard self.isRunning.value else {
                return
            }
            self.choreographer.stopRunning()
            self.buffer.removeAll()
            self.scheduledAudioBuffers.mutate { $0 = 0 }
            self.isRunning.mutate { $0 = false }
        }
    }
}
