import Foundation
import XCTest

@testable import HaishinKit

final class TSReaderTests: XCTestCase {
    func testTSFileRead() {
        let bundle = Bundle(for: type(of: self))
        let url = URL(fileURLWithPath: bundle.path(forResource: "SampleVideo_360x240_5mb/000", ofType: "ts")!)
        do {
            let fileHandle = try FileHandle(forReadingFrom: url)
            let reader = TSReader()
            reader.read(fileHandle.readDataToEndOfFile())
        } catch {
            
        }
    }
}
