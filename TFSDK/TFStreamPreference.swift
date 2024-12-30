//
//  TFStreamPreference.swift
//  TFSRT
//
//  Created by moRui on 2024/12/26.
//

import UIKit
import HaishinKit
import Photos
import UIKit
import VideoToolbox
import Combine
public class TFStreamPreference: NSObject {
    @objc public weak var delegate: (any TFStreamPreferenceDelegate)?

    public var connection: Any?
    private(set) var stream: (any HKStream)?
    
    var streamMode: TFStreamMode = .rtmp
    
    //暂停回调代理
    var pause:Bool = false

    var cancellable: AnyCancellable?
    
    var push_status = TFIngestStreamReadyState.idle
    //推流已经连接
    @objc public var isConnected:Bool = false

    func configuration(_ streamMode: TFStreamMode) async {
        self.streamMode = streamMode
        if streamMode == .srt {
            let connection = SRTConnection()
            self.connection = connection
            stream = SRTStream(connection: connection)

        } else {
            let connection = RTMPConnection()
            self.connection = connection
            stream = RTMPStream(connection: connection)

        }
    }
    // 在需要取消监听的时候调用这个方法
     func stopListening() {
         cancellable?.cancel()
         cancellable = nil
     }
    func close()
    {
        Task {
            switch streamMode {
            case .rtmp:
                guard let connection = connection as? RTMPConnection else {
                    return
                }
                try? await connection.close()
                logger.info("conneciton.close")
            case .srt:
                guard let connection = connection as? SRTConnection else {
                    return
                }
                try? await connection.close()
                logger.info("conneciton.close")
            }
        }
    }
    func shutdown()
    {
        self.stopListening()
        self.close()
    }
    func statusChanged(status:TFIngestStreamReadyState)
    {
        
        DispatchQueue.main.async {
            if self.delegate != nil {
                self.delegate!.haishinKitStatusChanged(status:status )
            }
        }
        
    }
    func readyState() {
     
            Task {
                switch streamMode {
                case .rtmp:
                    guard let stream = stream as? RTMPStream else {
                        return
                    }
                    
                    cancellable = await stream.$readyState.sink {[weak self] newState in
                        guard let `self` = self else { return }
                        if self.pause == false && self.streamMode == .rtmp {
                            var status = TFIngestStreamReadyState.idle
                            if newState == .publishing {
                                status = .publishing
                            }
                            self.push_status = status
                            
                            self.statusChanged(status: status)
                            switch newState {
                            case .idle:
//                                print("rtmp流处于空闲状态。")
                                self.isConnected = false
                            case .publishing:
//                                print("rtmp流正在发布中")
                                 status = .publishing
                                self.isConnected = true
                            case .playing:
//                                print("rtmp流正在播放。")
                                break
                            case .play:
//                                print("rtmp该流已发送播放请求，正在等待服务器批准。")
                                break
                            case .publish:
//                                print("rtmp该流已发送发布请求并正在等待服务器的批准。")
                                break
                            }
                        }
                     
                    }
                 
                case .srt:
                    guard let stream = stream as? SRTStream else {
                        return
                    }
                    cancellable = await stream.$readyState.sink {[weak self] newState in
                        guard let `self` = self else { return }
                        if self.pause == false && self.streamMode == .srt  {
                            var status = TFIngestStreamReadyState.idle
                            if newState == .publishing {
                                status = .publishing
                            }
                            self.push_status = status
                            
                            self.statusChanged(status: status)

                            switch newState {
                            case .idle:
//                                print("srt流处于空闲状态。")
                                self.isConnected = false
                            case .publishing:
//                                print("srt流正在发布中")
                                 status = .publishing
                                self.isConnected = true
                            case .playing:
//                                print("srt流正在播放。")
                                break
                            case .play:
//                                print("srt该流已发送播放请求，正在等待服务器批准。")
                                break
                            case .publish:
//                                print("srt该流已发送发布请求并正在等待服务器的批准。")
                                break
                            }
                        }
                     
                    }
                }
           
            }

        }

}
@objc public protocol TFStreamPreferenceDelegate: AnyObject {
    func haishinKitStatusChanged(status:TFIngestStreamReadyState)
}
@objc public enum TFIngestStreamReadyState: Int, Sendable {
    /// 空闲
    case idle
    /// 连接中
    case publishing
}
@objc public enum TFStreamMode: Int {
    case rtmp = 0
    case srt = 1
}
