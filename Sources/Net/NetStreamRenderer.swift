import AVFoundation
import Foundation
#if canImport(AppKit)
import AppKit
#endif

#if os(macOS)
typealias NetStreamRendererView = NSView
#else
import UIKit
typealias NetStreamRendererView = UIView
#endif

protocol NetStreamRenderer: AnyObject {
#if os(iOS) || os(macOS)
    var orientation: AVCaptureVideoOrientation { get set }
    var position: AVCaptureDevice.Position { get set }
#endif
    var currentSampleBuffer: CMSampleBuffer? { get set }
    var videoFormatDescription: CMVideoFormatDescription? { get }

    func attachStream(_ stream: NetStream?)
    func enqueue(_ sampleBuffer: CMSampleBuffer?)
}

extension NetStreamRenderer where Self: NetStreamRendererView {
    func enqueue(_ sampleBuffer: CMSampleBuffer?) {
        if Thread.isMainThread {
            currentSampleBuffer = sampleBuffer
            #if os(macOS)
            self.needsDisplay = true
            #else
            self.setNeedsDisplay()
            #endif
        } else {
            DispatchQueue.main.async {
                self.enqueue(sampleBuffer)
            }
        }
    }
}
