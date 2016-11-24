import Foundation
import XCTest

@testable import lf

final class MachUtilTests: XCTestCase {
    
    static let nonosTime:UInt64 = MachUtil.nanosToAbs(5)
    
    func testMain() {
    }
}
