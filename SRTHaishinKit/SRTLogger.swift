import Foundation
import libsrt

public enum SRTLogLevel {
    /// Highly detailed and very frequent messages.
    case debug
    /// Occasionally displayed information.
    case notice
    /// Unusual behavior.
    case warning
    /// Abnormal behavior
    case error
    /// Error that makes the current socket unusabl
    case crit

    var value: Int32 {
        switch self {
        case .debug:
            return LOG_DEBUG
        case .notice:
            return LOG_NOTICE
        case .warning:
            return LOG_WARNING
        case .error:
            return LOG_ERR
        case .crit:
            return LOG_CRIT
        }
    }
}

public enum SRTLogFunctionalArea: Int32 {
    /// General uncategorized log, for serious issues only
    case general = 0
    /// Socket create/open/close/configure activities
    case bstats = 1
    /// Connection establishment and handshake
    case control = 2
    /// The checkTimer and around activities
    case data = 3
    /// The TsBPD thread
    case tsbpd = 4
    /// System resource allocation and management
    case rsrc = 5
    /// Haicrypt module area
    case haicrypt = 6
    /// Congestion control module
    case congest = 7
    /// Packet filter module
    case pfilter = 8
    /// Applications
    case applog
    /// API part for socket and library managmenet
    case apiCtrl = 11
    /// Queue control activities
    case queCtrl = 13
    /// EPoll, internal update activities
    case epollUpd = 16
    /// API part for receiving
    case apiRecv = 21
    /// Buffer, receiving side
    case bufRecv = 22
    /// Queue, receiving side
    case queRecv = 23
    /// CChannel, receiving side
    case chanRecv = 24
    /// Group, receiving side
    case grpRecv = 25
    /// API part for sending
    case apiSend = 31
    /// Buffer, sending side
    case bufSend = 32
    /// Queue, sending side
    case queSend = 33
    /// CChannel, sending side
    case chnSend = 34
    /// Group, sending side
    case grpSend = 35
    /// Internal activities not connected directly to a socket
    case `internal` = 41
    /// Queue, management part
    case queMgmt = 43
    /// CChannel, management part
    case chnMgmt = 44
    /// Group, management part
    case grpMgmt = 45
    /// EPoll, API part
    case epollApi = 46

    func addLogFA() {
        srt_addlogfa(rawValue)
    }

    func delLogFA() {
        srt_dellogfa(rawValue)
    }
}

///  An object for writing interpolated string messages to srt logging system.
public class SRTLogger {
    public static let shared = SRTLogger()

    private init() {
        srt_setloglevel(level.value)
    }

    /// Specifies the current logging level.
    public var level: SRTLogLevel = .notice {
        didSet {
            guard level != oldValue else {
                return
            }
            srt_setloglevel(level.value)
        }
    }

    /// Specifies the current logging functional areas.
    public var functionalAreas: Set<SRTLogFunctionalArea> = [] {
        didSet {
            for area in oldValue.subtracting(functionalAreas) {
                area.delLogFA()
            }
            for area in functionalAreas.subtracting(oldValue) {
                area.addLogFA()
            }
        }
    }
}
