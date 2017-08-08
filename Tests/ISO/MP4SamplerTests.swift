import Foundation
import XCTest

@testable import HaishinKit

final class MP4SamplerTests: XCTestCase {
    func testMain() {
        guard Config.enabledTimerTest else {
            return
        }
        let bundle:Bundle = Bundle(for: type(of: self))
        let url:URL = URL(fileURLWithPath: bundle.path(forResource: "SampleVideo_360x240_5mb", ofType: "mp4")!)
        let sampler:MP4Sampler = MP4Sampler()
        sampler.appendFile(url)
        sampler.startRunning()
        sleep(10)
        sampler.stopRunning()
    }
}
