//
//  SampleBufferRTMPStream.swift
//  HaishinKit
//
//  Created by Linda Fitzpatrick on 10/17/22.
//  Copyright © 2022 Shogo Endo. All rights reserved.
//

import UIKit

open class SampleBufferRTMPStream: RTMPStream {

    public var includeAudioMetaData: Bool = false
    public var includeVideoMetaData: Bool = false
    
    override open func createMetaData() -> ASObject {
        metadata.removeAll()
        #if os(iOS) || os(macOS)
        if includeVideoMetaData {
            metadata["width"] = mixer.videoIO.codec.width
            metadata["height"] = mixer.videoIO.codec.height
            metadata["framerate"] = mixer.videoIO.fps
            metadata["videocodecid"] = FLVVideoCodec.avc.rawValue
            metadata["videodatarate"] = mixer.videoIO.codec.bitrate / 1000
        }
        if includeAudioMetaData {
            metadata["audiocodecid"] = FLVAudioCodec.aac.rawValue
            metadata["audiodatarate"] = mixer.audioIO.codec.bitrate / 1000
        }
        #endif
        return metadata
    }
    
}
