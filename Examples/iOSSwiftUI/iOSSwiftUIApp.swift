import AVFoundation
import HaishinKit
import Logboard
import SwiftUI

let logger = LBLogger.with("com.haishinkit.HaishinKit.iOSSwiftUI")

// swiftlint:disable type_name
@main
struct iOSSwiftUIApp: App {
    // swiftlint:disable:next attributes
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Logboard.with(HaishinKitIdentifier).level = .trace
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            logger.error(error)
        }
        return true
    }
}

// swiftlint:enable type_name
