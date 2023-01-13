/// Constans that defines the RTMPObject encoding type.
public enum RTMPObjectEncoding: UInt8 {
    /// The AMF0 Encoding.
    case amf0 = 0x00
    /// The AMF3 Encoding.
    case amf3 = 0x03

    var dataType: RTMPMessageType {
        switch self {
        case .amf0:
            return .amf0Data
        case .amf3:
            return .amf3Data
        }
    }

    var sharedObjectType: RTMPMessageType {
        switch self {
        case .amf0:
            return .amf0Shared
        case .amf3:
            return .amf3Shared
        }
    }

    var commandType: RTMPMessageType {
        switch self {
        case .amf0:
            return .amf0Command
        case .amf3:
            return .amf3Command
        }
    }
}
