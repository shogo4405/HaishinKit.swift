# Enhanced RTMP
The support status of Enhanced RTMP in HaishinKit.

## Overview
An extended RTMP standard called Enhanced RTMP is being developed by the Veovera Software Organization.
Please check [this repository](https://github.com/veovera/enhanced-rtmp/) for the specifications.

## Notice
Enhanced RTMP also requires support on the server side. Please check the support status of the server you are using.

## Supports Enhanced RTMP Status
### [v1](https://github.com/veovera/enhanced-rtmp/blob/main/docs/enhanced/enhanced-rtmp-v1.md)
Support for AV1 is planned to be implemented once the hardware becomes compatible.
- [x] Enhancing onMetaData
- [ ] Defining Additional Video Codecs
  - [ ] Ingest
    - [x] HEVC
    - [ ] VP9
    - [ ] AV1
  - [ ] Playback
    - [x] HEVC
    - [ ] VP9
    - [ ] AV1
- [ ] Extending NetConnection connect Command
- [ ] Metadata Frame

### [v2](https://github.com/veovera/enhanced-rtmp/blob/main/docs/enhanced/enhanced-rtmp-v2.md)
- [ ] Enhancements to RTMP and FLV
- [ ] Enhancing onMetaData
- [ ] Reconnect Request
- [ ] Enhanced Video
  - [ ] Ingest
    - [ ] VP8
    - [ ] AV1(HDR)
  - [ ] Playback
    - [ ] VP8
    - [ ] AV1(HDR)
- [ ] Enhanced Audio
  - [ ] Ingest
    - [x] OPUS
  - [ ] Playback
    - [ ] OPUS
- [ ] Multitrack Streaming via Enhanced RTMP
- [ ] Enhancing NetConnection connect Command

