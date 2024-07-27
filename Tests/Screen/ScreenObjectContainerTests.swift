import Foundation
import XCTest
import AVFoundation

@testable import HaishinKit

final class ScreenObjectContainerTests: XCTestCase {
    func testLookUpVideoTrackScreenObject() {
        Task { @ScreenActor in
            let container1 = ScreenObjectContainer()
            
            let videoTrack1 = VideoTrackScreenObject()
            let videoTrack2 = VideoTrackScreenObject()
            
            try? container1.addChild(videoTrack1)
            try? container1.addChild(videoTrack2)
            
            let videoTracks1 = container1.getScreenObjects() as [VideoTrackScreenObject]
            XCTAssertEqual(videoTracks1.count, 2)
            
            let container2 = ScreenObjectContainer()
            let videoTrack3 = VideoTrackScreenObject()
            try? container2.addChild(videoTrack3)
            try? container1.addChild(container2)
            
            let videoTracks2 = container1.getScreenObjects() as [VideoTrackScreenObject]
            XCTAssertEqual(videoTracks2.count, 3)
        }
    }
}
