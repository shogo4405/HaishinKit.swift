#if os(iOS) || os(tvOS) || os(visionOS)
import AVFoundation
import Foundation
import UIKit

/// A view that displays a video content of a NetStream object which uses AVSampleBufferDisplayLayer api.
public class PiPHKView: UIView {
    /// The view’s background color.
    public static var defaultBackgroundColor: UIColor = .black

    /// Returns the class used to create the layer for instances of this class.
    override public class var layerClass: AnyClass {
        AVSampleBufferDisplayLayer.self
    }

    /// The view’s Core Animation layer used for rendering.
    override public var layer: AVSampleBufferDisplayLayer {
        super.layer as! AVSampleBufferDisplayLayer
    }

    /// A value that specifies how the video is displayed within a player layer’s bounds.
    public var videoGravity: AVLayerVideoGravity = .resizeAspect {
        didSet {
            layer.videoGravity = videoGravity
        }
    }

    /// Initializes and returns a newly allocated view object with the specified frame rectangle.
    override public init(frame: CGRect) {
        super.init(frame: frame)
        awakeFromNib()
    }

    /// Returns an object initialized from data in a given unarchiver.
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    /// Prepares the receiver for service after it has been loaded from an Interface Builder archive, or nib file.
    override public func awakeFromNib() {
        super.awakeFromNib()
        Task { @MainActor in
            backgroundColor = Self.defaultBackgroundColor
            layer.backgroundColor = Self.defaultBackgroundColor.cgColor
            layer.videoGravity = videoGravity
        }
    }
}
#else

import AppKit
import AVFoundation

/// A view that displays a video content of a NetStream object which uses AVSampleBufferDisplayLayer api.
public class PiPHKView: NSView {
    /// The view’s background color.
    public static var defaultBackgroundColor: NSColor = .black

    /// A value that specifies how the video is displayed within a player layer’s bounds.
    public var videoGravity: AVLayerVideoGravity = .resizeAspect {
        didSet {
            layer?.setValue(videoGravity, forKey: "videoGravity")
        }
    }

    /// Specifies how the video is displayed with in track.
    public var track = UInt8.max

    /// Initializes and returns a newly allocated view object with the specified frame rectangle.
    override public init(frame: CGRect) {
        super.init(frame: frame)
        awakeFromNib()
    }

    /// Returns an object initialized from data in a given unarchiver.
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    /// Prepares the receiver for service after it has been loaded from an Interface Builder archive, or nib file.
    override public func awakeFromNib() {
        super.awakeFromNib()
        Task { @MainActor in
            wantsLayer = true
            layer = AVSampleBufferDisplayLayer()
            layer?.backgroundColor = PiPHKView.defaultBackgroundColor.cgColor
            layer?.setValue(videoGravity, forKey: "videoGravity")
        }
    }
}

extension PiPHKView: IOMixerOutput {
    // MARK: IOMixerOutput
    nonisolated public func mixer(_ mixer: IOMixer, track: UInt8, didOutput buffer: AVAudioPCMBuffer, when: AVAudioTime) {
    }

    nonisolated public func mixer(_ mixer: IOMixer, track: UInt8, didOutput sampleBuffer: CMSampleBuffer) {
        Task { @MainActor in
            guard self.track == track else {
                return
            }
            (layer as? AVSampleBufferDisplayLayer)?.enqueue(sampleBuffer)
            #if os(macOS)
            self.needsDisplay = true
            #else
            self.setNeedsDisplay()
            #endif
        }
    }
}

extension PiPHKView: HKStreamOutput {
    // MARK: HKStreamOutput
    nonisolated public func stream(_ stream: some HKStream, didOutput audio: AVAudioBuffer, when: AVAudioTime) {
    }

    nonisolated public func stream(_ stream: some HKStream, didOutput video: CMSampleBuffer) {
        Task { @MainActor in
            (layer as? AVSampleBufferDisplayLayer)?.enqueue(video)
            #if os(macOS)
            self.needsDisplay = true
            #else
            self.setNeedsDisplay()
            #endif
        }
    }
}

#endif
