import XCTest
import Foundation
import AVFoundation

@testable import lf

struct ClockedQueueTestBuffer {
    var duration:NSTimeInterval = 0
}

final class TestBufferClockedQueue:ClockedQueue<ClockedQueueTestBuffer> {
    override func getDuration(buffer: ClockedQueueTestBuffer) -> NSTimeInterval {
        return buffer.duration
    }
}

final class ClockedQueueTests: XCTestCase {
    func testTestBufferClockedQueue() {
        let queue:TestBufferClockedQueue = TestBufferClockedQueue()
        queue
            .enqueue(ClockedQueueTestBuffer(duration: 0.033))
            .enqueue(ClockedQueueTestBuffer(duration: 0.033))
            .enqueue(ClockedQueueTestBuffer(duration: 0.033))
            .enqueue(ClockedQueueTestBuffer(duration: 0.033))
    }
}
