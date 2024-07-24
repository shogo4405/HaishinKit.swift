import Foundation
import XCTest
import CoreMedia

@testable import HaishinKit

final class CMSampleBufferExtensionTests: XCTestCase {
    func testIsNotSync() {
        if let video1 = CMVideoSampleBufferFactory.makeSampleBuffer(width: 100, height: 100) {
            video1.sampleAttachments[0][.notSync] = 1
        } else {
            XCTFail()
        }

        if let video2 = CMVideoSampleBufferFactory.makeSampleBuffer(width: 100, height: 100) {
            XCTAssertFalse(video2.isNotSync)
        } else {
            XCTFail()
        }
    }
}
