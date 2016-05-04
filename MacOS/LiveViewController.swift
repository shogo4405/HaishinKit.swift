import Cocoa
import AVFoundation

final class LiveViewController: NSViewController {

    var popUpButton:NSPopUpButton!

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.frame = NSMakeRect(0, 0, 640, 360)
        popUpButton = NSPopUpButton()
        let devices:[AnyObject]! = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        for device in devices {
            if let device:AVCaptureDevice = device as? AVCaptureDevice {
                popUpButton.addItemWithTitle(device.localizedName)
            }
        }
        view.addSubview(popUpButton)
    }

    override func viewWillLayout() {
        super.viewWillLayout()
        popUpButton.frame = NSMakeRect(view.frame.width - 220, 20, 200, 20)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
    }
}
