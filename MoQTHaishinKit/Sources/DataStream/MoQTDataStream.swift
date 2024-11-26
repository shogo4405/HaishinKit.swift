public enum MoQTDataStreamType: Int, Sendable {
    case objectDatagram = 0x1
    case streamHeaderSubgroup = 0x4
    case fetchHeader = 0x5
}

protocol MoQTDataStream {
    var type: MoQTDataStreamType { get }
}
