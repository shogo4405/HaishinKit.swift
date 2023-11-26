//
//  App.swift
//

import CompositorServices
import Logboard
import SwiftUI

let logger = LBLogger.with("com.haishinkit.HaishinKit.visionOSApp")

@main
struct TestingApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
