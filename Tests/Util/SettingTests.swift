import Foundation
import XCTest
import AVFoundation

@testable import HaishinKit

final class SettingTests: XCTestCase {
    func testH264Encoder() {
        let encoder = H264Encoder()
        XCTAssertEqual(encoder.settings[.muted] as? Bool, encoder.muted)
        XCTAssertEqual(encoder.settings[.width] as? Int32, encoder.width)
        XCTAssertEqual(encoder.settings[.height] as? Int32, encoder.height)
        XCTAssertEqual(encoder.settings[.profileLevel] as? String, encoder.profileLevel)
        XCTAssertEqual(encoder.settings[.scalingMode] as? ScalingMode, encoder.scalingMode)
        XCTAssertEqual(encoder.settings[.maxKeyFrameIntervalDuration] as? Double, encoder.maxKeyFrameIntervalDuration)

        encoder.settings[.width] = Int8(100)
        XCTAssertEqual(100, encoder.width)

        encoder.settings[.scalingMode] = ScalingMode.letterbox
        XCTAssertEqual(encoder.settings[.scalingMode] as? ScalingMode, ScalingMode.letterbox)

        encoder.settings[.maxKeyFrameIntervalDuration] = Float(5.0)
        XCTAssertEqual(5.0, encoder.maxKeyFrameIntervalDuration)
    }

    func testAVMixer() {
        let mixier = AVMixer()
        XCTAssertEqual(mixier.settings[.fps] as? Float64, mixier.fps)
        XCTAssertEqual(mixier.settings[.continuousAutofocus] as? Bool, mixier.continuousAutofocus)
        XCTAssertEqual(mixier.settings[.continuousExposure] as? Bool, mixier.continuousExposure)
        XCTAssertEqual(mixier.settings[.sessionPreset] as? AVCaptureSession.Preset, mixier.sessionPreset)

        mixier.settings[.sessionPreset] = AVCaptureSession.Preset.high
        XCTAssertEqual(AVCaptureSession.Preset.high, mixier.sessionPreset)

        mixier.settings = [
            .sessionPreset: AVCaptureSession.Preset.hd1280x720,
            .continuousAutofocus: false,
            .continuousExposure: false,
        ]
        XCTAssertEqual(false, mixier.continuousAutofocus)
        XCTAssertEqual(false, mixier.continuousExposure)
        XCTAssertEqual(AVCaptureSession.Preset.hd1280x720, mixier.sessionPreset)
    }
}
