import UIKit
import AVFoundation
import Logboard
import HaishinKit

let logger: Logboard = Logboard.with("com.haishinkit.Exsample.iOS")

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Logboard.with(HaishinKitIdentifier).level = .trace
        let session: AVAudioSession = AVAudioSession.sharedInstance()
        do {
            try session.setPreferredSampleRate(44_100)
            try session.setCategory(convertFromAVAudioSessionCategory(AVAudioSession.Category.playAndRecord), with: .allowBluetooth)
            try session.setMode(AVAudioSession.Mode.default)
            try session.setActive(true)
        } catch {
        }
        return true
    }
}

// Helper function inserted by Swift 4.2 migrator.
private func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
	return input.rawValue
}
