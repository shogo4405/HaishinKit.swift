import UIKit
import Foundation
import AVFoundation

enum RTMPStreamReadyState:UInt8 {
    case INITLIZED = 0
    case OPEN = 1
    case PLAY = 2
    case PLAYING = 3
    case PUBLISH = 4
    case PUBLISHING = 5
    case CLOSED = 6
}

public final class RTMPStream: EventDispatcher, RTMPMuxerDelegate {
    static let defaultID:UInt32 = 0

    var id:UInt32 = RTMPStream.defaultID
    var readyState:RTMPStreamReadyState = RTMPStreamReadyState.INITLIZED

    public var objectEncoding:UInt8 = RTMPConnection.defaultObjectEncoding
    private var rtmpConnection:RTMPConnection
    private var chunkTypes:Dictionary<RTMPSampleType, RTMPChunkType> = [:]
    private var muxer:RTMPMuxer = RTMPMuxer()
    private var encoder:MP4Encoder = MP4Encoder()
    private var sessionManager:AVCaptureSessionManager = AVCaptureSessionManager()
    private let lockQueue:dispatch_queue_t = dispatch_queue_create("com.github.shogo4405.lf.RTMPStream.lock", DISPATCH_QUEUE_SERIAL)

    public var receiveAudio:Bool = true {
        didSet {
            dispatch_async(lockQueue) {
                self.rtmpConnection.doWrite(RTMPChunk(message: RTMPCommandMessage(
                    streamId: self.id,
                    transactionId: 0,
                    objectEncoding: self.objectEncoding,
                    commandName: "receiveAudio",
                    commandObject: nil,
                    arguments: [self.receiveAudio]
                )))
            }
        }
    }

    public var receiveVideo:Bool = true {
        didSet {
            dispatch_async(lockQueue) {
                self.rtmpConnection.doWrite(RTMPChunk(message: RTMPCommandMessage(
                    streamId: self.id,
                    transactionId: 0,
                    objectEncoding: self.objectEncoding,
                    commandName: "receiveVideo",
                    commandObject: nil,
                    arguments: [self.receiveVideo]
                )))
            }
        }
    }

    public init(rtmpConnection: RTMPConnection) {
        self.rtmpConnection = rtmpConnection
        super.init()
        self.rtmpConnection.addEventListener("rtmpStatus", selector: "rtmpStatusHandler:", observer: self)
    }

    public func attachFile(file:NSURL) {
        encoder.push(file)
    }

    public func attachAudio(audio:AVCaptureDevice?) {
        sessionManager.attachAudio(audio)
        sessionManager.audioDataOutput.setSampleBufferDelegate(encoder, queue: encoder.audioQueue)
    }

    public func attachCamera(camera:AVCaptureDevice?) {
        sessionManager.syncOrientation = true
        sessionManager.attachCamera(camera)
        sessionManager.videoDataOutput.setSampleBufferDelegate(encoder, queue: encoder.videoQueue)
    }

    public func play(arguments:Any?...) {
        dispatch_async(lockQueue) {
            self.rtmpConnection.doWrite(RTMPChunk(message: RTMPCommandMessage(
                streamId: self.id,
                transactionId: 0,
                objectEncoding: self.objectEncoding,
                commandName: "play",
                commandObject: nil,
                arguments: arguments
            )))
        }
    }

    public func publish(name:String?) {
        self.publish(name, type: "live")
    }

    public func seek(offset:Double) {
        dispatch_async(lockQueue) {
            self.rtmpConnection.doWrite(RTMPChunk(message: RTMPCommandMessage(
                streamId: self.id,
                transactionId: 0,
                objectEncoding: self.objectEncoding,
                commandName: "seek",
                commandObject: nil,
                arguments: [offset]
            )))
        }
    }

    public func publish(name:String?, type:String) {
        dispatch_async(lockQueue) {
            if (name == nil) {
                self.muxer.stopRunnning()
                return
            }

            while (self.readyState == RTMPStreamReadyState.INITLIZED) {
                usleep(100)
            }

            self.muxer.delegate = self
            self.muxer.encoder = self.encoder
            self.rtmpConnection.doWrite(RTMPChunk(
                type: RTMPChunkType.ZERO,
                streamId: RTMPChunkStreamId.AUDIO.rawValue,
                message: RTMPCommandMessage(
                    streamId: self.id,
                    transactionId: 0,
                    objectEncoding: self.objectEncoding,
                    commandName: "publish",
                    commandObject: nil,
                    arguments: [name!, type]
                )
            ))

            self.muxer.startRunning()
            self.readyState = RTMPStreamReadyState.PUBLISH
            self.encoder.recording = true
        }
    }

    public func close() {
        dispatch_async(lockQueue) {
            self.encoder.recording = false
            self.muxer.stopRunnning()
            self.rtmpConnection.doWrite(RTMPChunk(
                type: RTMPChunkType.ZERO,
                streamId: RTMPChunkStreamId.AUDIO.rawValue,
                message: RTMPCommandMessage(
                    streamId: self.id,
                    transactionId: 0,
                    objectEncoding: self.objectEncoding,
                    commandName: "deleteStream",
                    commandObject: nil,
                    arguments: [self.id]
                )
            ))
            self.rtmpConnection.removeEventListener("rtmpStatus", selector: "rtmpStatusHandler:", observer: self)
        }
    }

    public func send(handlerName:String, arguments:Any?...) {
        rtmpConnection.doWrite(RTMPChunk(message: RTMPDataMessage(
            streamId: id,
            objectEncoding: objectEncoding,
            handlerName: handlerName,
            arguments: arguments
        )))
    }

    public func toPreviewLayer() -> AVCaptureVideoPreviewLayer {
        sessionManager.startRunning();
        return sessionManager.previewLayer
    }

    func sampleOutput(muxer:RTMPMuxer, type:RTMPSampleType, timestamp:Double, buffer:NSData) {
        rtmpConnection.doWrite(RTMPChunk(
            type: chunkTypes[type] == nil ? RTMPChunkType.ZERO : RTMPChunkType.ONE,
            streamId: type == RTMPSampleType.Audio ? RTMPChunkStreamId.AUDIO.rawValue : RTMPChunkStreamId.VIDEO.rawValue,
            message: RTMPMediaMessage(
                streamId: id,
                timestamp: UInt32(timestamp),
                type: type,
                buffer: buffer
            )
        ))
        chunkTypes[type] = RTMPChunkType.ONE
    }

    func didSetSampleTables(muxer:RTMPMuxer, sampleTables:[MP4SampleTable]) {
        send("@setDataFrame", arguments: "onMetaData", muxer.createMetadata(sampleTables))
    }

    func rtmpStatusHandler(notification:NSNotification) {
        let e:Event = Event.from(notification)
        if let data:ECMAObject = e.data as? ECMAObject {
            if let code:String = data["code"] as? String {
                switch code {
                case "NetConnection.Connect.Success":
                    rtmpConnection.createStream(self)
                    break
                default:
                    break
                }
            }
        }
    }
}
