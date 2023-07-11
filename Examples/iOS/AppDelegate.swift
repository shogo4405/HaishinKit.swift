import AVFoundation
import HaishinKit
import Logboard
import UIKit

let logger = LBLogger.with("com.haishinkit.Exsample.iOS")

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // LBLogger.with(HaishinKitIdentifier).level = .trace
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
