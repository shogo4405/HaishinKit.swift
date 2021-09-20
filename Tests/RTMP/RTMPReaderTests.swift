import Foundation
import XCTest

@testable import HaishinKit

final class RTMPReaderTests: XCTestCase {
    func testReader() {
        let bundle: Bundle = Bundle(for: type(of: self))
        let url: URL = URL(fileURLWithPath: bundle.path(forResource: "SampleVideo_360x240_5mb", ofType: "flv")!)
        let reader = FLVReader(url: url)
        while true {
            guard let _ = reader.next() else {
                return
            }
        }
    }
}
