import Foundation

public enum MoQTMessageType: Int, Sendable {
    case subscribeUpdate = 0x02
    case subscribe = 0x03
    case subscribeOk = 0x04
    case subscribeError = 0x05
    case announce = 0x06
    case announceOk = 0x07
    case announceError = 0x08
    case unannounce = 0x09
    case unsubscribe = 0x0A
    case subscribeDone = 0x0B
    case announceCancel = 0x0C
    case trackStatusRequest = 0x0D
    case trackStatus = 0x0E
    case goaway = 0x10
    case subscribeAnnounuces = 0x11
    case subscribeAnnounucesOk = 0x12
    case subscribeAnnounucesError = 0x13
    case clientSetup = 0x40
    case serverSetup = 0x41

    func makeMessage(_ payload: inout MoQTPayload) throws -> (any MoQTControlMessage)? {
        switch self {
        case .subscribeUpdate:
            return nil
        case .subscribe:
            return try MoQTSubscribe(&payload)
        case .subscribeOk:
            return try MoQTSubscribeOk(&payload)
        case .subscribeError:
            return try MoQTSubscribeError(&payload)
        case .announce:
            return nil
        case .announceOk:
            return try MoQTAnnounceOk(&payload)
        case .announceError:
            return try MoQTAnnounceError(&payload)
        case .unannounce:
            return nil
        case .unsubscribe:
            return nil
        case .subscribeDone:
            return nil
        case .announceCancel:
            return nil
        case .trackStatusRequest:
            return nil
        case .trackStatus:
            return nil
        case .goaway:
            return nil
        case .subscribeAnnounuces:
            return nil
        case .subscribeAnnounucesOk:
            return try MoQTSubscribeAnnouncesOk(&payload)
        case .subscribeAnnounucesError:
            return try MoQTSubscribeAnnouncesError(&payload)
        case .clientSetup:
            return nil
        case .serverSetup:
            return try MoQTServerSetup(&payload)
        }
    }
}

enum MoQTControlMessageError: Swift.Error {
    case notImplemented
}

public protocol MoQTControlMessage: Sendable {
    var type: MoQTMessageType { get }
    var payload: Data { get throws }
}
