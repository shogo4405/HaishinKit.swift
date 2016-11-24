import Foundation
import XCTest

@testable import lf

final class TimerDriverTests: XCTestCase {
    func testMain() {
        let timerDriver:TimerDriver = TimerDriver()
        let delegate:TimerDriverDelegate = LoggerTimerDriverDelegate()
        timerDriver.delegate = delegate
        DispatchQueue.global().async {
            timerDriver.startRunning()
        }
        sleep(10)
        timerDriver.stopRunning()
    }
}
