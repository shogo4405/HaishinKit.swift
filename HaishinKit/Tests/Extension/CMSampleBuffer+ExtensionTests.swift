import CoreMedia
import Foundation
import Testing

@testable import HaishinKit

@Suite struct CMSampleBufferExtensionTests {
    @Test func isNotSync() {
        if let video1 = CMVideoSampleBufferFactory.makeSampleBuffer(width: 100, height: 100) {
            video1.sampleAttachments[0][.notSync] = 1
        } else {
            Issue.record()
        }

        if let video2 = CMVideoSampleBufferFactory.makeSampleBuffer(width: 100, height: 100) {
            #expect(!video2.isNotSync)
        } else {
            Issue.record()
        }
    }
}
