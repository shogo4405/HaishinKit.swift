import AVFoundation

class MP4Box {
    static func create(_ data: Data) throws -> MP4Box {
        let buffer = ByteArray(data: data)
        let size: UInt32 = try buffer.readUInt32()
        let type: String = try buffer.readUTF8Bytes(4)

        buffer.clear()
        switch type {
        case "moov", "trak", "mdia", "minf", "stbl", "edts":
            return MP4ContainerBox(size: size, type: type)
        case "mp4v", "s263", "avc1":
            return MP4VisualSampleEntryBox(size: size, type: type)
        case "mvhd", "mdhd":
            return MP4MediaHeaderBox(size: size, type: type)
        case "mp4a":
            return MP4AudioSampleEntryBox(size: size, type: type)
        case "esds":
            return MP4ElementaryStreamDescriptorBox(size: size, type: type)
        case "stts":
            return MP4TimeToSampleBox(size: size, type: type)
        case "stss":
            return MP4SyncSampleBox(size: size, type: type)
        case "stsd":
            return MP4SampleDescriptionBox(size: size, type: type)
        case "stco":
            return MP4ChunkOffsetBox(size: size, type: type)
        case "stsc":
            return MP4SampleToChunkBox(size: size, type: type)
        case "stsz":
            return MP4SampleSizeBox(size: size, type: type)
        case "elst":
            return MP4EditListBox(size: size, type: type)
        default:
            return MP4Box(size: size, type: type)
        }
    }

    var leafNode: Bool {
        false
    }

    fileprivate(set) var type: String = "undf"
    fileprivate(set) var size: UInt32 = 0
    fileprivate(set) var offset: UInt64 = 0
    fileprivate(set) var parent: MP4Box?

    init() {
    }

    init(size: UInt32, type: String) {
        self.size = size
        self.type = type
    }

    func load(_ fileHandle: FileHandle) throws -> UInt32 {
        if size == 0 {
            size = UInt32(fileHandle.seekToEndOfFile() - offset)
            return size
        }
        fileHandle.seek(toFileOffset: offset + UInt64(size))
        return size
    }

    func getBoxes(byName: String) -> [MP4Box] {
        []
    }

    func clear() {
        parent = nil
    }

    func create(_ data: Data, offset: UInt32) throws -> MP4Box {
        let box: MP4Box = try MP4Box.create(data)
        box.parent = self
        box.offset = self.offset + UInt64(offset)
        return box
    }
}

extension MP4Box: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}

// MARK: -
class MP4ContainerBox: MP4Box {
    fileprivate var children: [MP4Box] = []

    override var leafNode: Bool {
        false
    }

    override func load(_ file: FileHandle) throws -> UInt32 {
        children.removeAll(keepingCapacity: false)

        var offset: UInt32 = parent == nil ? 0 : 8
        file.seek(toFileOffset: self.offset + UInt64(offset))

        while size != offset {
            let child: MP4Box = try create(file.readData(ofLength: 8), offset: offset)
            offset += try child.load(file)
            children.append(child)
        }

        return offset
    }

    override func getBoxes(byName: String) -> [MP4Box] {
        var list: [MP4Box] = []
        for child in children {
            if byName == child.type || byName == "*" {
                list.append(child)
            }
            if !child.leafNode {
                list += child.getBoxes(byName: byName)
            }
        }
        return list
    }

    override func clear() {
        for child in children {
            child.clear()
        }
        children.removeAll(keepingCapacity: false)
        parent = nil
    }
}

// MARK: -
final class MP4MediaHeaderBox: MP4Box {
    var version: UInt8 = 0
    var creationTime: UInt32 = 0
    var modificationTime: UInt32 = 0
    var timeScale: UInt32 = 0
    var duration: UInt32 = 0
    var language: UInt16 = 0
    var quality: UInt16 = 0

    override func load(_ fileHandle: FileHandle) throws -> UInt32 {
        let buffer = ByteArray(data: fileHandle.readData(ofLength: Int(size) - 8))
        version = try buffer.readUInt8()
        buffer.position += 3
        creationTime = try buffer.readUInt32()
        modificationTime = try buffer.readUInt32()
        timeScale = try buffer.readUInt32()
        duration = try buffer.readUInt32()
        language = try buffer.readUInt16()
        quality = try buffer.readUInt16()
        buffer.clear()
        return size
    }
}

// MARK: -
final class MP4ChunkOffsetBox: MP4Box {
    var entries: [UInt32] = []

    override func load(_ fileHandle: FileHandle) throws -> UInt32 {
        let buffer = ByteArray(data: fileHandle.readData(ofLength: Int(size) - 8))
        buffer.position += 4

        let numberOfEntries: UInt32 = try buffer.readUInt32()
        for _ in 0..<numberOfEntries {
            entries.append(try buffer.readUInt32())
        }
        buffer.clear()

        return size
    }
}

// MARK: -
final class MP4SyncSampleBox: MP4Box {
    var entries: [UInt32] = []

    override func load(_ fileHandle: FileHandle) throws -> UInt32 {
        entries.removeAll(keepingCapacity: false)

        let buffer = ByteArray(data: fileHandle.readData(ofLength: Int(size) - 8))
        buffer.position += 4

        let numberOfEntries: UInt32 = try buffer.readUInt32()
        for _ in 0..<numberOfEntries {
            entries.append(try buffer.readUInt32())
        }

        return size
    }
}

// MARK: -
final class MP4TimeToSampleBox: MP4Box {
    struct Entry: CustomDebugStringConvertible {
        var sampleCount: UInt32 = 0
        var sampleDuration: UInt32 = 0

        var debugDescription: String {
            Mirror(reflecting: self).debugDescription
        }

        init(sampleCount: UInt32, sampleDuration: UInt32) {
            self.sampleCount = sampleCount
            self.sampleDuration = sampleDuration
        }
    }

    var entries: [Entry] = []

    override func load(_ fileHandle: FileHandle) throws -> UInt32 {
        entries.removeAll(keepingCapacity: false)

        let buffer = ByteArray(data: fileHandle.readData(ofLength: Int(size) - 8))
        buffer.position += 4

        let numberOfEntries: UInt32 = try buffer.readUInt32()
        for _ in 0..<numberOfEntries {
            entries.append(Entry(
                sampleCount: try buffer.readUInt32(),
                sampleDuration: try buffer.readUInt32()
            ))
        }

        return size
    }
}

// MARK: -
final class MP4SampleSizeBox: MP4Box {
    var entries: [UInt32] = []

    override func load(_ fileHandle: FileHandle) throws -> UInt32 {
        entries.removeAll(keepingCapacity: false)

        let buffer = ByteArray(data: fileHandle.readData(ofLength: Int(self.size) - 8))
        buffer.position += 4

        let sampleSize: UInt32 = try buffer.readUInt32()
        if sampleSize != 0 {
            entries.append(sampleSize)
            return size
        }

        let numberOfEntries: UInt32 = try buffer.readUInt32()
        for _ in 0..<numberOfEntries {
            entries.append(try buffer.readUInt32())
        }
        buffer.clear()

        return size
    }
}

// MARK: -
final class MP4ElementaryStreamDescriptorBox: MP4ContainerBox {
    var audioDecorderSpecificConfig = Data()

    var tag: UInt8 = 0
    var tagSize: UInt8 = 0
    var id: UInt16 = 0
    var streamDependenceFlag: UInt8 = 0
    var urlFlag: UInt8 = 0
    var ocrStreamFlag: UInt8 = 0
    var streamPriority: UInt8 = 0

    override func load(_ fileHandle: FileHandle) throws -> UInt32 {
        var tagSize: UInt8 = 0
        let buffer = ByteArray(data: fileHandle.readData(ofLength: Int(self.size) - 8))
        buffer.position += 4

        tag = try buffer.readUInt8()
        self.tagSize = try buffer.readUInt8()
        if self.tagSize == 0x80 {
            buffer.position += 2
            self.tagSize = try buffer.readUInt8()
        }

        id = try buffer.readUInt16()

        let data: UInt8 = try buffer.readUInt8()
        streamDependenceFlag = data >> 7
        urlFlag = (data >> 6) & 0x1
        ocrStreamFlag = (data >> 5) & 0x1
        streamPriority = data & 0x1f

        if streamDependenceFlag == 1 {
            let _: UInt16 = try buffer.readUInt16()
        }

        // Decorder Config Descriptor
        let _: UInt8 = try buffer.readUInt8()
        tagSize = try buffer.readUInt8()
        if tagSize == 0x80 {
            buffer.position += 2
            tagSize = try buffer.readUInt8()
        }
        buffer.position += 13

        // Audio Decorder Spec Info
        let _: UInt8 = try buffer.readUInt8()
        tagSize = try buffer.readUInt8()
        if tagSize == 0x80 {
            buffer.position += 2
            tagSize = try buffer.readUInt8()
        }

        audioDecorderSpecificConfig = try buffer.readBytes(Int(tagSize))

        return size
    }
}

// MARK: -
final class MP4AudioSampleEntryBox: MP4ContainerBox {
    var version: UInt16 = 0

    var channelCount: UInt16 = 0
    var sampleSize: UInt16 = 0
    var compressionId: UInt16 = 0
    var packetSize: UInt16 = 0
    var sampleRate: UInt32 = 0
    var samplesPerPacket: UInt32 = 0
    var bytesPerPacket: UInt32 = 0
    var bytesPerFrame: UInt32 = 0
    var bytesPerSample: UInt32 = 0

    var soundVersion2Data: [UInt8] = []

    override func load(_ fileHandle: FileHandle) throws -> UInt32 {
        let buffer = ByteArray(data: fileHandle.readData(ofLength: Int(size) - 8))
        buffer.position += 8

        version = try buffer.readUInt16()
        buffer.position += 6

        channelCount = try buffer.readUInt16()
        sampleSize = try buffer.readUInt16()
        compressionId = try buffer.readUInt16()
        packetSize = try buffer.readUInt16()
        sampleRate = try buffer.readUInt32()

        if type != "mlpa" {
            sampleRate = sampleRate >> 16
        }

        if 0 < version {
            samplesPerPacket = try buffer.readUInt32()
            bytesPerPacket = try buffer.readUInt32()
            bytesPerFrame = try buffer.readUInt32()
            bytesPerSample = try buffer.readUInt32()
        }

        if version == 2 {
            soundVersion2Data += try buffer.readBytes(20)
        }

        var offset = UInt32(buffer.position) + 8
        fileHandle.seek(toFileOffset: self.offset + UInt64(offset))

        let esds: MP4Box = try create(fileHandle.readData(ofLength: 8), offset: offset)
        offset += try esds.load(fileHandle)
        children.append(esds)

        // skip
        fileHandle.seek(toFileOffset: self.offset + UInt64(size))

        return size
    }
}

// MARK: -
final class MP4VisualSampleEntryBox: MP4ContainerBox {
    static var dataSize: Int = 78

    var width: UInt16 = 0
    var height: UInt16 = 0
    var hSolution: UInt32 = 0
    var vSolution: UInt32 = 0
    var frameCount: UInt16 = 1
    var compressorname: String = ""
    var depth: UInt16 = 16

    override func load(_ fileHandle: FileHandle) throws -> UInt32 {
        let buffer = ByteArray(data: fileHandle.readData(ofLength: MP4VisualSampleEntryBox.dataSize))

        buffer.position += 24
        width = try buffer.readUInt16()
        height = try buffer.readUInt16()
        hSolution = try buffer.readUInt32()
        vSolution = try buffer.readUInt32()
        buffer.position += 4
        frameCount = try buffer.readUInt16()
        compressorname = try buffer.readUTF8Bytes(32)
        depth = try buffer.readUInt16()
        _ = try buffer.readUInt16()
        buffer.clear()

        var offset = UInt32(MP4VisualSampleEntryBox.dataSize + 8)
        while size > offset {
            let child: MP4Box = try create(fileHandle.readData(ofLength: 8), offset: offset)
            offset += try child.load(fileHandle)
            children.append(child)
        }
        return offset
    }
}

// MARK: -
final class MP4SampleDescriptionBox: MP4ContainerBox {
    override func load(_ fileHandle: FileHandle) throws -> UInt32 {
        children.removeAll(keepingCapacity: false)

        let buffer = ByteArray(data: fileHandle.readData(ofLength: 8))
        buffer.position = 4

        var offset: UInt32 = 16
        let numberOfEntries: UInt32 = try buffer.readUInt32()
        for _ in 0..<numberOfEntries {
            let child: MP4Box = try create(fileHandle.readData(ofLength: 8), offset: offset)
            offset += try child.load(fileHandle)
            children.append(child)
        }

        return offset
    }
}

// MARK: -
final class MP4SampleToChunkBox: MP4Box {
    struct Entry: CustomDebugStringConvertible {
        var firstChunk: UInt32 = 0
        var samplesPerChunk: UInt32 = 0
        var sampleDescriptionIndex: UInt32 = 0

        var debugDescription: String {
            Mirror(reflecting: self).debugDescription
        }

        init(firstChunk: UInt32, samplesPerChunk: UInt32, sampleDescriptionIndex: UInt32) {
            self.firstChunk = firstChunk
            self.samplesPerChunk = samplesPerChunk
            self.sampleDescriptionIndex = sampleDescriptionIndex
        }
    }

    var entries: [Entry] = []

    override func load(_ fileHandle: FileHandle) throws -> UInt32 {
        let buffer = ByteArray(data: fileHandle.readData(ofLength: Int(size) - 8))
        buffer.position += 4

        let numberOfEntries: UInt32 = try buffer.readUInt32()
        for _ in 0..<numberOfEntries {
            entries.append(Entry(
                firstChunk: try buffer.readUInt32(),
                samplesPerChunk: try buffer.readUInt32(),
                sampleDescriptionIndex: try buffer.readUInt32()
            ))
        }
        buffer.clear()

        return size
    }
}

// MARK: -
final class MP4EditListBox: MP4Box {
    struct Entry: CustomDebugStringConvertible {
        var segmentDuration: UInt32 = 0
        var mediaTime: UInt32 = 0
        var mediaRate: UInt32 = 0

        var debugDescription: String {
            Mirror(reflecting: self).debugDescription
        }

        init(segmentDuration: UInt32, mediaTime: UInt32, mediaRate: UInt32) {
            self.segmentDuration = segmentDuration
            self.mediaTime = mediaTime
            self.mediaRate = mediaRate
        }
    }

    var version: UInt32 = 0
    var entries: [Entry] = []

    override func load(_ fileHandle: FileHandle) throws -> UInt32 {
        let buffer = ByteArray(data: fileHandle.readData(ofLength: Int(size) - 8))

        version = try buffer.readUInt32()
        entries.removeAll(keepingCapacity: false)

        let numberOfEntries: UInt32 = try buffer.readUInt32()
        for _ in 0..<numberOfEntries {
            entries.append(Entry(
                segmentDuration: try buffer.readUInt32(),
                mediaTime: try buffer.readUInt32(),
                mediaRate: try buffer.readUInt32()
            ))
        }

        return size
    }
}

// MARK: -
final class MP4Reader: MP4ContainerBox {
    private(set) var url: URL

    var isEmpty: Bool {
        getBoxes(byName: "mdhd").isEmpty
    }

    private var fileHandle: FileHandle?

    init(url: URL) {
        do {
            self.url = url
            super.init()
            fileHandle = try FileHandle(forReadingFrom: url)
        } catch let error as NSError {
            logger.error("\(error)")
        }
    }

    func seek(toFileOffset: UInt64) {
        fileHandle!.seek(toFileOffset: toFileOffset)
    }

    func readData(ofLength: Int) -> Data {
        fileHandle!.readData(ofLength: ofLength)
    }

    func readData(ofBox: MP4Box) -> Data {
        guard let fileHandle: FileHandle = fileHandle else {
            return Data()
        }
        let currentOffsetInFile: UInt64 = fileHandle.offsetInFile
        fileHandle.seek(toFileOffset: ofBox.offset + 8)
        let data: Data = fileHandle.readData(ofLength: Int(ofBox.size) - 8)
        fileHandle.seek(toFileOffset: currentOffsetInFile)
        return data
    }

    func load() throws -> UInt32 {
        guard let fileHandle: FileHandle = self.fileHandle else {
            return 0
        }
        return try load(fileHandle)
    }

    func close() {
        fileHandle?.closeFile()
    }

    override func load(_ fileHandle: FileHandle) throws -> UInt32 {
        let size: UInt64 = fileHandle.seekToEndOfFile()
        fileHandle.seek(toFileOffset: 0)
        self.size = UInt32(size)
        return try super.load(fileHandle)
    }
}

// MARK: -
final class MP4TrakReader {
    static let defaultBufferTime: Double = 500

    var trak: MP4Box
    var bufferTime: Double = MP4TrakReader.defaultBufferTime
    weak var delegate: MP4SamplerDelegate?

    private var id: Int = 0
    private var handle: FileHandle?
    private lazy var timerDriver: TimerDriver = {
        var timerDriver = TimerDriver()
        timerDriver.delegate = self
        return timerDriver
    }()
    private var currentOffset: UInt64 {
        UInt64(offset[cursor])
    }
    private var currentIsKeyframe: Bool {
        keyframe[cursor] != nil
    }
    private var currentDuration: Double {
        Double(totalTimeToSample) * 1000 / Double(timeScale)
    }
    private var currentTimeToSample: Double {
        Double(timeToSample[cursor]) * 1000 / Double(timeScale)
    }
    private var currentSampleSize: Int {
        Int((sampleSize.count == 1) ? sampleSize[0] : sampleSize[cursor])
    }
    private var cursor: Int = 0
    private var offset: [UInt32] = []
    private var keyframe: [Int: Bool] = [:]
    private var timeScale: UInt32 = 0
    private var sampleSize: [UInt32] = []
    private var timeToSample: [UInt32] = []
    private var totalTimeToSample: UInt32 = 0

    init(id: Int, trak: MP4Box) {
        self.id = id
        self.trak = trak

        let mdhd: MP4Box? = trak.getBoxes(byName: "mdhd").first
        if let mdhd: MP4MediaHeaderBox = mdhd as? MP4MediaHeaderBox {
            timeScale = mdhd.timeScale
        }

        let stss: MP4Box? = trak.getBoxes(byName: "stss").first
        if let stss: MP4SyncSampleBox = stss as? MP4SyncSampleBox {
            let keyframes: [UInt32] = stss.entries
            for i in 0..<keyframes.count {
                keyframe[Int(keyframes[i]) - 1] = true
            }
        }

        let stts: MP4Box? = trak.getBoxes(byName: "stts").first
        if let stts: MP4TimeToSampleBox = stts as? MP4TimeToSampleBox {
            let timeToSample: [MP4TimeToSampleBox.Entry] = stts.entries
            for i in 0..<timeToSample.count {
                let entry: MP4TimeToSampleBox.Entry = timeToSample[i]
                for _ in 0..<entry.sampleCount {
                    self.timeToSample.append(entry.sampleDuration)
                }
            }
        }

        let stsz: MP4Box? = trak.getBoxes(byName: "stsz").first
        if let stsz: MP4SampleSizeBox = stsz as? MP4SampleSizeBox {
            sampleSize = stsz.entries
        }

        let stco: MP4Box = trak.getBoxes(byName: "stco").first!
        let stsc: MP4Box = trak.getBoxes(byName: "stsc").first!
        let offsets: [UInt32] = (stco as! MP4ChunkOffsetBox).entries
        let sampleToChunk: [MP4SampleToChunkBox.Entry] = (stsc as! MP4SampleToChunkBox).entries

        var index: Int = 0
        let count: Int = sampleToChunk.count
        for i in 0..<count {
            let m: Int = (i + 1 < count) ? Int(sampleToChunk[i + 1].firstChunk) - 1 : offsets.count
            for j in (Int(sampleToChunk[i].firstChunk) - 1)..<m {
                var offset: UInt32 = offsets[j]
                for _ in 0..<sampleToChunk[i].samplesPerChunk {
                    self.offset.append(offset)
                    offset += sampleSize[index]
                    index += 1
                }
            }
        }
        totalTimeToSample = timeToSample[cursor]
    }

    func execute(_ reader: MP4Reader) {
        do {
            handle = try FileHandle(forReadingFrom: reader.url)

            if let avcC: MP4Box = trak.getBoxes(byName: "avcC").first {
                delegate?.didSet(config: reader.readData(ofBox: avcC), withID: id, type: .video)
            }
            if let esds: MP4ElementaryStreamDescriptorBox = trak.getBoxes(byName: "esds").first as? MP4ElementaryStreamDescriptorBox {
                delegate?.didSet(config: Data(esds.audioDecorderSpecificConfig), withID: id, type: .audio)
            }

            timerDriver.interval = MachUtil.nanosToAbs(UInt64(currentTimeToSample * 1000 * 1000))
            while currentDuration <= bufferTime {
                tick(timerDriver)
            }
            timerDriver.startRunning()
        } catch {
            logger.warn("file open error : \(reader.url)")
        }
    }

    private func hasNext() -> Bool {
        cursor + 1 < offset.count
    }

    private func next() {
        defer {
            cursor += 1
        }
        totalTimeToSample += timeToSample[cursor]
    }
}

extension MP4TrakReader: TimerDriverDelegate {
    // MARK: TimerDriverDelegate
    func tick(_ driver: TimerDriver) {
        guard let handle: FileHandle = handle else {
            driver.stopRunning()
            return
        }
        driver.interval = MachUtil.nanosToAbs(UInt64(currentTimeToSample * 1000 * 1000))
        handle.seek(toFileOffset: currentOffset)
        autoreleasepool {
            delegate?.output(
                data: handle.readData(ofLength: currentSampleSize),
                withID: id,
                currentTime: currentTimeToSample,
                keyframe: currentIsKeyframe
            )
        }
        if hasNext() {
            next()
        } else {
            driver.stopRunning()
        }
    }
}

extension MP4TrakReader: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}
