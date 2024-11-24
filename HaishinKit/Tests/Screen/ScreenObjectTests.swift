import AVFoundation
import Foundation
import Testing

@testable import HaishinKit

@ScreenActor
@Suite struct ScreenObjectTests {
    @Test func screenHorizontalAlignmentRect() {
        let screen = Screen()

        let object1 = ScreenObject()
        object1.size = .init(width: 100, height: 100)
        object1.horizontalAlignment = .left

        let object2 = ScreenObject()
        object2.size = .init(width: 100, height: 100)
        object2.horizontalAlignment = .center

        let object3 = ScreenObject()
        object3.size = .init(width: 100, height: 100)
        object3.horizontalAlignment = .right

        try? screen.addChild(object1)
        try? screen.addChild(object2)
        try? screen.addChild(object3)

        if let sampleBuffer = CMVideoSampleBufferFactory.makeSampleBuffer(width: 1600, height: 900) {
            _ = screen.render(sampleBuffer)
        }
        #expect(object1.bounds == .init(origin: .zero, size: object1.size))
        #expect(object2.bounds == .init(x: 750, y: 0, width: 100, height: 100))
        #expect(object3.bounds == .init(x: 1500, y: 0, width: 100, height: 100))
    }

    @Test func screenVerticalAlignmentRect() {
        let screen = Screen()

        let object0 = ScreenObject()
        object0.size = .zero
        object0.verticalAlignment = .top

        let object1 = ScreenObject()
        object1.size = .init(width: 100, height: 100)
        object1.verticalAlignment = .top

        let object2 = ScreenObject()
        object2.size = .init(width: 100, height: 100)
        object2.verticalAlignment = .middle

        let object3 = ScreenObject()
        object3.size = .init(width: 100, height: 100)
        object3.verticalAlignment = .bottom

        try? screen.addChild(object0)
        try? screen.addChild(object1)
        try? screen.addChild(object2)
        try? screen.addChild(object3)

        if let sampleBuffer = CMVideoSampleBufferFactory.makeSampleBuffer(width: 1600, height: 900) {
            _ = screen.render(sampleBuffer)
        }
        #expect(object0.bounds == .init(x: 0, y: 0, width: 1600, height: 900))
        #expect(object1.bounds == .init(x: 0, y: 0, width: object1.size.width, height: object1.size.height))
        #expect(object2.bounds == .init(x: 0, y: 400, width: 100, height: 100))
        #expect(object3.bounds == .init(x: 0, y: 800, width: 100, height: 100))
    }

    @Test func screenWithContainerTests() {
        let screen = Screen()

        let container = ScreenObjectContainer()
        container.size = .init(width: 200, height: 100)
        container.layoutMargin = .init(top: 16, left: 16, bottom: 0, right: 0)

        let object0 = ScreenObject()
        object0.size = .zero
        object0.verticalAlignment = .top

        let object1 = ScreenObject()
        object1.size = .init(width: 100, height: 100)
        object1.layoutMargin = .init(top: 16, left: 16, bottom: 0, right: 0)
        object1.verticalAlignment = .top

        try? container.addChild(object0)
        try? container.addChild(object1)
        try? screen.addChild(container)

        if let sampleBuffer = CMVideoSampleBufferFactory.makeSampleBuffer(width: 1600, height: 900) {
            _ = screen.render(sampleBuffer)
        }

        #expect(object0.bounds == .init(x: 16, y: 16, width: 200, height: 100))
        #expect(object1.bounds == .init(x: 32, y: 32, width: 100, height: 100))
    }
}
