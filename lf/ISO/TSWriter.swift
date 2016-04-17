import Foundation
import AVFoundation

// MARK: - TSWriter
class TSWriter {
    static let defaultVideoPID:UInt16 = 256
    static let defaultAudioPID:UInt16 = 257
    static let defaultSegmentFilesCount:Int = 10
    static let defaultSegmentTimeInterval:NSTimeInterval = 5

    private var timer:NSTimer?
    private var timestamp:CMTime = kCMTimeZero
    private var currentFileHandle:NSFileHandle? {
        didSet {
            oldValue?.closeFile()
        }
    }
    private let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.TSWriter.lock", DISPATCH_QUEUE_SERIAL
    )

    var segmentFiles:[NSURL] = []
    var segmentFilesCount:Int = TSWriter.defaultSegmentFilesCount
    var segmentTimeInterval:NSTimeInterval = TSWriter.defaultSegmentTimeInterval
    internal(set) var running:Bool = false

    func writePacketizedElementaryStream(PID:UInt16, PES: PacketizedElementaryStream) {
        dispatch_async(lockQueue) {
            for packet in PES.arrayOfPackets(PID) {
                self.currentFileHandle?.writeData(NSData(bytes: packet.bytes))
            }
        }
    }

    @objc func didUpdate(timer:NSTimer) {
        dispatch_async(lockQueue) {
            self.rorateFileHandle()
        }
    }

    private func rorateFileHandle() {
        let temp:String = NSTemporaryDirectory()
        let filename:String = NSDate().timeIntervalSince1970.description + ".ts"
        let url:NSURL = NSURL(fileURLWithPath: temp + "/" + filename)
        do {
            currentFileHandle = try NSFileHandle(forReadingFromURL: url)
            segmentFiles.append(url)
        } catch {
        }
    }
}

// MARK: Runnable
extension TSWriter: Runnable {
    func startRunning() {
        dispatch_async(lockQueue) {
            self.running = true
            self.rorateFileHandle()
            self.timer = NSTimer.scheduledTimerWithTimeInterval(
                self.segmentTimeInterval,
                target: self,
                selector: #selector(TSWriter.didUpdate(_:)),
                userInfo: nil,
                repeats: true
            )
        }
    }

    func stopRunning() {
        dispatch_async(lockQueue) {
            self.timer?.invalidate()
            self.timer = nil
            self.currentFileHandle = nil
            self.segmentFiles = []
            self.running = false
        }
    }
}

// MARK: VideoEncoderDelegate
extension TSWriter: VideoEncoderDelegate {
    func didSetFormatDescription(video formatDescription: CMFormatDescriptionRef?) {
    }
    func sampleOutput(video sampleBuffer: CMSampleBuffer) {
        guard let pes:PacketizedElementaryStream = PacketizedElementaryStream(sampleBuffer: sampleBuffer) else {
            return
        }
        writePacketizedElementaryStream(TSWriter.defaultVideoPID, PES: pes)
    }
}
