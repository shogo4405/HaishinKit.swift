import Foundation
import libsrt

/// The SRTPerformanceData represents the SRT's performance statistics. This struct is wrapper for an CBytePerfMon.
/// - seealso: https://github.com/Haivision/srt/blob/master/srtcore/srt.h
public struct SRTPerformanceData {
    static let zero: SRTPerformanceData = .init(
        msTimeStamp: 0,
        pktSentTotal: 0,
        pktRecvTotal: 0,
        pktSndLossTotal: 0,
        pktRcvLossTotal: 0,
        pktRetransTotal: 0,
        pktSentACKTotal: 0,
        pktRecvACKTotal: 0,
        pktSentNAKTotal: 0,
        pktRecvNAKTotal: 0,
        usSndDurationTotal: 0,
        pktSndDropTotal: 0,
        pktRcvDropTotal: 0,
        pktRcvUndecryptTotal: 0,
        byteSentTotal: 0,
        byteRecvTotal: 0,
        byteRcvLossTotal: 0,
        byteRetransTotal: 0,
        byteSndDropTotal: 0,
        byteRcvDropTotal: 0,
        byteRcvUndecryptTotal: 0,
        pktSent: 0,
        pktRecv: 0,
        pktSndLoss: 0,
        pktRcvLoss: 0,
        pktRetrans: 0,
        pktRcvRetrans: 0,
        pktSentACK: 0,
        pktRecvACK: 0,
        pktSentNAK: 0,
        pktRecvNAK: 0,
        mbpsSendRate: 0,
        mbpsRecvRate: 0,
        usSndDuration: 0,
        pktReorderDistance: 0,
        pktRcvAvgBelatedTime: 0,
        pktRcvBelated: 0,
        pktSndDrop: 0,
        pktRcvDrop: 0,
        pktRcvUndecrypt: 0,
        byteSent: 0,
        byteRecv: 0,
        byteRcvLoss: 0,
        byteRetrans: 0,
        byteSndDrop: 0,
        byteRcvDrop: 0,
        byteRcvUndecrypt: 0,
        usPktSndPeriod: 0,
        pktFlowWindow: 0,
        pktCongestionWindow: 0,
        pktFlightSize: 0,
        msRTT: 0,
        mbpsBandwidth: 0,
        byteAvailSndBuf: 0,
        byteAvailRcvBuf: 0,
        mbpsMaxBW: 0,
        byteMSS: 0,
        pktSndBuf: 0,
        byteSndBuf: 0,
        msSndBuf: 0,
        msSndTsbPdDelay: 0,
        pktRcvBuf: 0,
        byteRcvBuf: 0,
        msRcvBuf: 0,
        msRcvTsbPdDelay: 0,
        pktSndFilterExtraTotal: 0,
        pktRcvFilterExtraTotal: 0,
        pktRcvFilterSupplyTotal: 0,
        pktRcvFilterLossTotal: 0,
        pktSndFilterExtra: 0,
        pktRcvFilterExtra: 0,
        pktRcvFilterSupply: 0,
        pktRcvFilterLoss: 0,
        pktReorderTolerance: 0
    )

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

    init(msTimeStamp: Int64, pktSentTotal: Int64, pktRecvTotal: Int64, pktSndLossTotal: Int32, pktRcvLossTotal: Int32, pktRetransTotal: Int32, pktSentACKTotal: Int32, pktRecvACKTotal: Int32, pktSentNAKTotal: Int32, pktRecvNAKTotal: Int32, usSndDurationTotal: Int64, pktSndDropTotal: Int32, pktRcvDropTotal: Int32, pktRcvUndecryptTotal: Int32, byteSentTotal: UInt64, byteRecvTotal: UInt64, byteRcvLossTotal: UInt64, byteRetransTotal: UInt64, byteSndDropTotal: UInt64, byteRcvDropTotal: UInt64, byteRcvUndecryptTotal: UInt64, pktSent: Int64, pktRecv: Int64, pktSndLoss: Int32, pktRcvLoss: Int32, pktRetrans: Int32, pktRcvRetrans: Int32, pktSentACK: Int32, pktRecvACK: Int32, pktSentNAK: Int32, pktRecvNAK: Int32, mbpsSendRate: Double, mbpsRecvRate: Double, usSndDuration: Int64, pktReorderDistance: Int32, pktRcvAvgBelatedTime: Double, pktRcvBelated: Int64, pktSndDrop: Int32, pktRcvDrop: Int32, pktRcvUndecrypt: Int32, byteSent: UInt64, byteRecv: UInt64, byteRcvLoss: UInt64, byteRetrans: UInt64, byteSndDrop: UInt64, byteRcvDrop: UInt64, byteRcvUndecrypt: UInt64, usPktSndPeriod: Double, pktFlowWindow: Int32, pktCongestionWindow: Int32, pktFlightSize: Int32, msRTT: Double, mbpsBandwidth: Double, byteAvailSndBuf: Int32, byteAvailRcvBuf: Int32, mbpsMaxBW: Double, byteMSS: Int32, pktSndBuf: Int32, byteSndBuf: Int32, msSndBuf: Int32, msSndTsbPdDelay: Int32, pktRcvBuf: Int32, byteRcvBuf: Int32, msRcvBuf: Int32, msRcvTsbPdDelay: Int32, pktSndFilterExtraTotal: Int32, pktRcvFilterExtraTotal: Int32, pktRcvFilterSupplyTotal: Int32, pktRcvFilterLossTotal: Int32, pktSndFilterExtra: Int32, pktRcvFilterExtra: Int32, pktRcvFilterSupply: Int32, pktRcvFilterLoss: Int32, pktReorderTolerance: Int32) {
        self.msTimeStamp = msTimeStamp
        self.pktSentTotal = pktSentTotal
        self.pktRecvTotal = pktRecvTotal
        self.pktSndLossTotal = pktSndLossTotal
        self.pktRcvLossTotal = pktRcvLossTotal
        self.pktRetransTotal = pktRetransTotal
        self.pktSentACKTotal = pktSentACKTotal
        self.pktRecvACKTotal = pktRecvACKTotal
        self.pktSentNAKTotal = pktSentNAKTotal
        self.pktRecvNAKTotal = pktRecvNAKTotal
        self.usSndDurationTotal = usSndDurationTotal
        self.pktSndDropTotal = pktSndDropTotal
        self.pktRcvDropTotal = pktRcvDropTotal
        self.pktRcvUndecryptTotal = pktRcvUndecryptTotal
        self.byteSentTotal = byteSentTotal
        self.byteRecvTotal = byteRecvTotal
        self.byteRcvLossTotal = byteRcvLossTotal
        self.byteRetransTotal = byteRetransTotal
        self.byteSndDropTotal = byteSndDropTotal
        self.byteRcvDropTotal = byteRcvDropTotal
        self.byteRcvUndecryptTotal = byteRcvUndecryptTotal
        self.pktSent = pktSent
        self.pktRecv = pktRecv
        self.pktSndLoss = pktSndLoss
        self.pktRcvLoss = pktRcvLoss
        self.pktRetrans = pktRetrans
        self.pktRcvRetrans = pktRcvRetrans
        self.pktSentACK = pktSentACK
        self.pktRecvACK = pktRecvACK
        self.pktSentNAK = pktSentNAK
        self.pktRecvNAK = pktRecvNAK
        self.mbpsSendRate = mbpsSendRate
        self.mbpsRecvRate = mbpsRecvRate
        self.usSndDuration = usSndDuration
        self.pktReorderDistance = pktReorderDistance
        self.pktRcvAvgBelatedTime = pktRcvAvgBelatedTime
        self.pktRcvBelated = pktRcvBelated
        self.pktSndDrop = pktSndDrop
        self.pktRcvDrop = pktRcvDrop
        self.pktRcvUndecrypt = pktRcvUndecrypt
        self.byteSent = byteSent
        self.byteRecv = byteRecv
        self.byteRcvLoss = byteRcvLoss
        self.byteRetrans = byteRetrans
        self.byteSndDrop = byteSndDrop
        self.byteRcvDrop = byteRcvDrop
        self.byteRcvUndecrypt = byteRcvUndecrypt
        self.usPktSndPeriod = usPktSndPeriod
        self.pktFlowWindow = pktFlowWindow
        self.pktCongestionWindow = pktCongestionWindow
        self.pktFlightSize = pktFlightSize
        self.msRTT = msRTT
        self.mbpsBandwidth = mbpsBandwidth
        self.byteAvailSndBuf = byteAvailSndBuf
        self.byteAvailRcvBuf = byteAvailRcvBuf
        self.mbpsMaxBW = mbpsMaxBW
        self.byteMSS = byteMSS
        self.pktSndBuf = pktSndBuf
        self.byteSndBuf = byteSndBuf
        self.msSndBuf = msSndBuf
        self.msSndTsbPdDelay = msSndTsbPdDelay
        self.pktRcvBuf = pktRcvBuf
        self.byteRcvBuf = byteRcvBuf
        self.msRcvBuf = msRcvBuf
        self.msRcvTsbPdDelay = msRcvTsbPdDelay
        self.pktSndFilterExtraTotal = pktSndFilterExtraTotal
        self.pktRcvFilterExtraTotal = pktRcvFilterExtraTotal
        self.pktRcvFilterSupplyTotal = pktRcvFilterSupplyTotal
        self.pktRcvFilterLossTotal = pktRcvFilterLossTotal
        self.pktSndFilterExtra = pktSndFilterExtra
        self.pktRcvFilterExtra = pktRcvFilterExtra
        self.pktRcvFilterSupply = pktRcvFilterSupply
        self.pktRcvFilterLoss = pktRcvFilterLoss
        self.pktReorderTolerance = pktReorderTolerance
    }
}
