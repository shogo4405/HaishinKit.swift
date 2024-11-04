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

    public var videoTrackId: UInt8? = UInt8.max
    public var audioTrackId: UInt8?

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
    public var videoTrackId: UInt8? = UInt8.max
    public var audioTrackId: UInt8?

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

#endif

extension PiPHKView: MediaMixerOutput {
    // MARK: MediaMixerOutput
    public func selectTrack(_ id: UInt8?, mediaType: CMFormatDescription.MediaType) async {
        switch mediaType {
        case .audio:
            break
        case .video:
            videoTrackId = id
        default:
            break
        }
    }

    nonisolated public func mixer(_ mixer: MediaMixer, didOutput buffer: AVAudioPCMBuffer, when: AVAudioTime) {
    }

    nonisolated public func mixer(_ mixer: MediaMixer, didOutput sampleBuffer: CMSampleBuffer) {
        Task { @MainActor in
            #if os(macOS)
            (layer as? AVSampleBufferDisplayLayer)?.enqueue(sampleBuffer)
            self.needsDisplay = true
            #else
            (layer as AVSampleBufferDisplayLayer).enqueue(sampleBuffer)
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
            #if os(macOS)
            (layer as? AVSampleBufferDisplayLayer)?.enqueue(video)
            self.needsDisplay = true
            #else
            (layer as AVSampleBufferDisplayLayer).enqueue(video)
            self.setNeedsDisplay()
            #endif
        }
    }
}
