@preconcurrency import Logboard

#if canImport(SwiftPMSupport)
import SwiftPMSupport
#endif

nonisolated let logger = LBLogger.with(HaishinKitIdentifier)
