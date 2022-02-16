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
    var currentImageBuffer: CVImageBuffer? { get set }
    var videoFormatDescription: CMVideoFormatDescription? { get }

    func attachStream(_ stream: NetStream?)
    func enqueue(_ sampleBuffer: CVImageBuffer?)
}

extension NetStreamRenderer where Self: NetStreamRendererView {
    func enqueue(_ sampleBuffer: CVImageBuffer?) {
        if Thread.isMainThread {
            currentImageBuffer = sampleBuffer
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
