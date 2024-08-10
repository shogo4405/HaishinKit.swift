import Logboard

#if canImport(SwiftPMSupport)
import SwiftPMSupport
#endif

nonisolated(unsafe) let logger = LBLogger.with(HaishinKitIdentifier)
