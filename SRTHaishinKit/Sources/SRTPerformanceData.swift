import Foundation
import libsrt

/// The SRTPerformanceData represents the SRT's performance statistics. This struct is wrapper for an CBytePerfMon.
/// - seealso: https://github.com/Haivision/srt/blob/master/srtcore/srt.h
public struct SRTPerformanceData: Sendable {
    /// The time since the UDT entity is started, in milliseconds.
    public let msTimeStamp: Int64
    /// The total number of sent data packets, including retransmissions.
    public let pktSentTotal: Int64
    /// The total number of received packets.
    public let pktRecvTotal: Int64
    /// The total number of lost packets (sender side)
    public let pktSndLossTotal: Int32
    /// The total number of lost packets (receiver side)
    public let pktRcvLossTotal: Int32
    /// The total number of retransmitted packets
    public let pktRetransTotal: Int32
    /// The total number of sent ACK packets
    public let pktSentACKTotal: Int32
    /// The total number of received ACK packets
    public let pktRecvACKTotal: Int32
    /// The total number of sent NAK packets
    public let pktSentNAKTotal: Int32
    /// The total number of received NAK packets
    public let pktRecvNAKTotal: Int32
    /// The total time duration when UDT is sending data (idle time exclusive)
    public let usSndDurationTotal: Int64
    /// The number of too-late-to-send dropped packets
    public let pktSndDropTotal: Int32
    /// The number of too-late-to play missing packets
    public let pktRcvDropTotal: Int32
    /// The number of undecrypted packets
    public let pktRcvUndecryptTotal: Int32
    /// The total number of sent data bytes, including retransmissions
    public let byteSentTotal: UInt64
    /// The total number of received bytes
    public let byteRecvTotal: UInt64
    /// The total number of lost bytes
    public let byteRcvLossTotal: UInt64
    /// The total number of retransmitted bytes
    public let byteRetransTotal: UInt64
    /// The number of too-late-to-send dropped bytes
    public let byteSndDropTotal: UInt64
    /// The number of too-late-to play missing bytes (estimate based on average packet size)
    public let byteRcvDropTotal: UInt64
    /// The number of undecrypted bytes
    public let byteRcvUndecryptTotal: UInt64
    /// The number of sent data packets, including retransmissions
    public let pktSent: Int64
    /// The number of received packets
    public let pktRecv: Int64
    /// The number of lost packets (sender side)
    public let pktSndLoss: Int32
    /// The number of lost packets (receiver side)
    public let pktRcvLoss: Int32
    /// The number of retransmitted packets
    public let pktRetrans: Int32
    /// The number of retransmitted packets received
    public let pktRcvRetrans: Int32
    /// The number of sent ACK packets
    public let pktSentACK: Int32
    /// The number of received ACK packets
    public let pktRecvACK: Int32
    /// The number of sent NAK packets
    public let pktSentNAK: Int32
    /// The number of received NAK packets
    public let pktRecvNAK: Int32
    /// The sending rate in Mb/s
    public let mbpsSendRate: Double
    /// The receiving rate in Mb/s
    public let mbpsRecvRate: Double
    /// The busy sending time (i.e., idle time exclusive)
    public let usSndDuration: Int64
    /// The size of order discrepancy in received sequences
    public let pktReorderDistance: Int32
    /// The average time of packet delay for belated packets (packets with sequence past the ACK)
    public let pktRcvAvgBelatedTime: Double
    /// The number of received AND IGNORED packets due to having come too late
    public let pktRcvBelated: Int64
    /// The number of too-late-to-send dropped packets
    public let pktSndDrop: Int32
    /// The number of too-late-to play missing packets
    public let pktRcvDrop: Int32
    /// The number of undecrypted packets
    public let pktRcvUndecrypt: Int32
    /// The number of sent data bytes, including retransmissions
    public let byteSent: UInt64
    /// The number of received bytes
    public let byteRecv: UInt64
    /// The number of retransmitted bytes
    public let byteRcvLoss: UInt64
    /// The number of retransmitted bytes
    public let byteRetrans: UInt64
    /// The number of too-late-to-send dropped bytes
    public let byteSndDrop: UInt64
    /// The number of too-late-to play missing bytes (estimate based on average packet size)
    public let byteRcvDrop: UInt64
    /// The number of undecrypted bytes
    public let byteRcvUndecrypt: UInt64
    /// The packet sending period, in microseconds
    public let usPktSndPeriod: Double
    /// The flow window size, in number of packets
    public let pktFlowWindow: Int32
    /// The congestion window size, in number of packets
    public let pktCongestionWindow: Int32
    /// The number of packets on flight
    public let pktFlightSize: Int32
    /// The RTT, in milliseconds
    public let msRTT: Double
    /// The estimated bandwidth, in Mb/s
    public let mbpsBandwidth: Double
    /// The available UDT sender buffer size
    public let byteAvailSndBuf: Int32
    /// The available UDT receiver buffer size
    public let byteAvailRcvBuf: Int32
    /// The transmit Bandwidth ceiling (Mbps)
    public let mbpsMaxBW: Double
    /// The MTU
    public let byteMSS: Int32
    /// The UnACKed packets in UDT sender
    public let pktSndBuf: Int32
    /// The UnACKed bytes in UDT sender
    public let byteSndBuf: Int32
    /// The UnACKed timespan (msec) of UDT sender
    public let msSndBuf: Int32
    /// Timestamp-based Packet Delivery Delay
    public let msSndTsbPdDelay: Int32
    /// Undelivered packets in UDT receiver
    public let pktRcvBuf: Int32
    /// The undelivered bytes of UDT receiver
    public let byteRcvBuf: Int32
    /// The undelivered timespan (msec) of UDT receiver
    public let msRcvBuf: Int32
    /// The Timestamp-based Packet Delivery Delay
    public let msRcvTsbPdDelay: Int32
    /// The number of control packets supplied by packet filter
    public let pktSndFilterExtraTotal: Int32
    /// The number of control packets received and not supplied back
    public let pktRcvFilterExtraTotal: Int32
    /// The number of packets that the filter supplied extra (e.g. FEC rebuilt)
    public let pktRcvFilterSupplyTotal: Int32
    /// The number of packet loss not coverable by filter
    public let pktRcvFilterLossTotal: Int32
    /// The number of control packets supplied by packet filter
    public let pktSndFilterExtra: Int32
    /// The number of control packets received and not supplied back
    public let pktRcvFilterExtra: Int32
    /// The number of packets that the filter supplied extra (e.g. FEC rebuilt)
    public let pktRcvFilterSupply: Int32
    /// The number of packet loss not coverable by filter
    public let pktRcvFilterLoss: Int32
    /// The packet reorder tolerance value
    public let pktReorderTolerance: Int32

    init(mon: CBytePerfMon) {
        self.msTimeStamp = mon.msTimeStamp
        self.pktSentTotal = mon.pktSentTotal
        self.pktRecvTotal = mon.pktRecvTotal
        self.pktSndLossTotal = mon.pktSndLossTotal
        self.pktRcvLossTotal = mon.pktRcvLossTotal
        self.pktRetransTotal = mon.pktRetransTotal
        self.pktSentACKTotal = mon.pktSentACKTotal
        self.pktRecvACKTotal = mon.pktRecvACKTotal
        self.pktSentNAKTotal = mon.pktSentNAKTotal
        self.pktRecvNAKTotal = mon.pktRecvNAKTotal
        self.usSndDurationTotal = mon.usSndDurationTotal
        self.pktSndDropTotal = mon.pktSndDropTotal
        self.pktRcvDropTotal = mon.pktRcvDropTotal
        self.pktRcvUndecryptTotal = mon.pktRcvUndecryptTotal
        self.byteSentTotal = mon.byteSentTotal
        self.byteRecvTotal = mon.byteRecvTotal
        self.byteRcvLossTotal = mon.byteRcvLossTotal
        self.byteRetransTotal = mon.byteRetransTotal
        self.byteSndDropTotal = mon.byteSndDropTotal
        self.byteRcvDropTotal = mon.byteRcvDropTotal
        self.byteRcvUndecryptTotal = mon.byteRcvUndecryptTotal
        self.pktSent = mon.pktSent
        self.pktRecv = mon.pktRecv
        self.pktSndLoss = mon.pktSndLoss
        self.pktRcvLoss = mon.pktRcvLoss
        self.pktRetrans = mon.pktRetrans
        self.pktRcvRetrans = mon.pktRcvRetrans
        self.pktSentACK = mon.pktSentACK
        self.pktRecvACK = mon.pktRecvACK
        self.pktSentNAK = mon.pktSentNAK
        self.pktRecvNAK = mon.pktRecvNAK
        self.mbpsSendRate = mon.mbpsSendRate
        self.mbpsRecvRate = mon.mbpsRecvRate
        self.usSndDuration = mon.usSndDuration
        self.pktReorderDistance = mon.pktReorderDistance
        self.pktRcvAvgBelatedTime = mon.pktRcvAvgBelatedTime
        self.pktRcvBelated = mon.pktRcvBelated
        self.pktSndDrop = mon.pktSndDrop
        self.pktRcvDrop = mon.pktRcvDrop
        self.pktRcvUndecrypt = mon.pktRcvUndecrypt
        self.byteSent = mon.byteSent
        self.byteRecv = mon.byteRecv
        self.byteRcvLoss = mon.byteRcvLoss
        self.byteRetrans = mon.byteRetrans
        self.byteSndDrop = mon.byteSndDrop
        self.byteRcvDrop = mon.byteRcvDrop
        self.byteRcvUndecrypt = mon.byteRcvUndecrypt
        self.usPktSndPeriod = mon.usPktSndPeriod
        self.pktFlowWindow = mon.pktFlowWindow
        self.pktCongestionWindow = mon.pktCongestionWindow
        self.pktFlightSize = mon.pktFlightSize
        self.msRTT = mon.msRTT
        self.mbpsBandwidth = mon.mbpsBandwidth
        self.byteAvailSndBuf = mon.byteAvailSndBuf
        self.byteAvailRcvBuf = mon.byteAvailRcvBuf
        self.mbpsMaxBW = mon.mbpsMaxBW
        self.byteMSS = mon.byteMSS
        self.pktSndBuf = mon.pktSndBuf
        self.byteSndBuf = mon.byteSndBuf
        self.msSndBuf = mon.msSndBuf
        self.msSndTsbPdDelay = mon.msSndTsbPdDelay
        self.pktRcvBuf = mon.pktRcvBuf
        self.byteRcvBuf = mon.byteRcvBuf
        self.msRcvBuf = mon.msRcvBuf
        self.msRcvTsbPdDelay = mon.msRcvTsbPdDelay
        self.pktSndFilterExtraTotal = mon.pktSndFilterExtraTotal
        self.pktRcvFilterExtraTotal = mon.pktRcvFilterExtraTotal
        self.pktRcvFilterSupplyTotal = mon.pktRcvFilterSupplyTotal
        self.pktRcvFilterLossTotal = mon.pktRcvFilterLossTotal
        self.pktSndFilterExtra = mon.pktSndFilterExtra
        self.pktRcvFilterExtra = mon.pktRcvFilterExtra
        self.pktRcvFilterSupply = mon.pktRcvFilterSupply
        self.pktRcvFilterLoss = mon.pktRcvFilterLoss
        self.pktReorderTolerance = mon.pktReorderTolerance
    }
}
