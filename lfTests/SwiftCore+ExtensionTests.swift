import Foundation
import XCTest

@testable import lf

class SwiftCoreExtensionTests: XCTestCase {
    
    func testInt32() {
        XCTAssertEqual(Int32.min, Int32(bytes: Int32.min.bytes))
        XCTAssertEqual(Int32.max, Int32(bytes: Int32.max.bytes))
    }
    
    func testPreIncrement() {
        
        var x: Int = 0
        XCTAssert(1 == preIncrement(&x) && x == 1)
        
    }
    
    func testPostIncrement() {
        
        var x: Int = 0
        XCTAssert(0 == postIncrement(&x) && x == 1)
        
    }
    
    func testPreDecrement() {
        
        var x: Int = 0
        XCTAssert(-1 == preDecrement(&x) && x == -1)
        
    }
    
    func testPostDecrement() {
        
        var x: Int = 0
        XCTAssert(0 == postDecrement(&x) && x == -1)
        
    }
    
}
