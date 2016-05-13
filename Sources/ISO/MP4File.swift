import Foundation

// MARK: - MP4Box
class MP4Box: NSObject {
    static func create(data:NSData) throws -> MP4Box {
        let buffer:ByteArray = ByteArray(data: data)
        let size:UInt32 = try buffer.readUInt32()
        let type:String = try buffer.readUTF8Bytes(4)

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

    private(set) var type:String = "undf"
    private(set) var size:UInt32 = 0
    private(set) var offset:UInt64 = 0
    private(set) var parent:MP4Box? = nil

    var leafNode:Bool {
        return false
    }

    override var description:String {
        return Mirror(reflecting: self).description
    }

    override init() {
    }

    init(size: UInt32, type:String) {
        self.size = size
        self.type = type
    }

    func loadFile(fileHandle: NSFileHandle) throws -> UInt32 {
        if (size == 0) {
            size = UInt32(fileHandle.seekToEndOfFile() - offset)
            return size
        }
        fileHandle.seekToFileOffset(offset + UInt64(size))
        return size
    }

    func getBoxesByName(name:String) -> [MP4Box] {
        return []
    }

    func clear() {
        parent = nil
    }

    func create(data:NSData, offset:UInt32) throws -> MP4Box {
        let box:MP4Box = try MP4Box.create(data)
        box.parent = self
        box.offset = self.offset + UInt64(offset)
        return box
    }
}

// MARK: - MP4ContainerBox
class MP4ContainerBox: MP4Box {

    private var children:[MP4Box] = []

    override var leafNode: Bool {
        return false
    }

    override func loadFile(fileHandle: NSFileHandle) throws -> UInt32 {
        children.removeAll(keepCapacity: false)

        var offset:UInt32 = parent == nil ? 0 : 8
        fileHandle.seekToFileOffset(self.offset + UInt64(offset))

        while (size != offset) {
            let child:MP4Box = try create(fileHandle.readDataOfLength(8), offset: offset)
            offset += try child.loadFile(fileHandle)
            children.append(child)
        }

        return offset
    }

    override func getBoxesByName(name:String) -> [MP4Box] {
        var list:[MP4Box] = []
        for child in children {
            if (name == child.type || name == "*" ) {
                list.append(child)
            }
            if (!child.leafNode) {
                list += child.getBoxesByName(name)
            }
        }
        return list
    }

    override func clear() {
        for child in children {
            child.clear()
        }
        children.removeAll(keepCapacity: false)
        parent = nil
    }
}

// MARK: - MP4MediaHeaderBox
final class MP4MediaHeaderBox: MP4Box {
    var version:UInt8 = 0
    var creationTime:UInt32 = 0
    var modificationTime:UInt32 = 0
    var timeScale:UInt32 = 0
    var duration:UInt32 = 0
    var language:UInt16 = 0
    var quality:UInt16 = 0

    override func loadFile(fileHandle: NSFileHandle) throws -> UInt32 {
        let buffer:ByteArray = ByteArray(data: fileHandle.readDataOfLength(Int(size) - 8))
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

// MARK: - MP4ChunkOffsetBox
final class MP4ChunkOffsetBox: MP4Box {
    var entries:[UInt32] = []

    override func loadFile(fileHandle: NSFileHandle) throws -> UInt32 {
        let buffer:ByteArray = ByteArray(data: fileHandle.readDataOfLength(Int(size) - 8))
        buffer.position += 4

        let numberOfEntries:UInt32 = try buffer.readUInt32()
        for _ in 0..<numberOfEntries {
            entries.append(try buffer.readUInt32())
        }
        buffer.clear()

        return size
    }
}

// MARK: - MP4SyncSampleBox
final class MP4SyncSampleBox: MP4Box {
    var entries:[UInt32] = []

    override func loadFile(fileHandle: NSFileHandle) throws -> UInt32 {
        entries.removeAll(keepCapacity: false)

        let buffer:ByteArray = ByteArray(data: fileHandle.readDataOfLength(Int(size) - 8))
        buffer.position += 4

        let numberOfEntries:UInt32 = try buffer.readUInt32()
        for _ in 0..<numberOfEntries {
            entries.append(try buffer.readUInt32())
        }

        return size
    }
}

// MARK: - MP4TimeToSampleBox
final class MP4TimeToSampleBox: MP4Box {
    struct Entry: CustomStringConvertible {
        var sampleCount:UInt32 = 0
        var sampleDuration:UInt32 = 0

        var description:String {
            return Mirror(reflecting: self).description
        }
        
        init(sampleCount:UInt32, sampleDuration:UInt32) {
            self.sampleCount = sampleCount
            self.sampleDuration = sampleDuration
        }
    }

    var entries:[Entry] = []

    override func loadFile(fileHandle: NSFileHandle) throws -> UInt32 {
        entries.removeAll(keepCapacity: false)

        let buffer:ByteArray = ByteArray(data: fileHandle.readDataOfLength(Int(size) - 8))
        buffer.position += 4

        let numberOfEntries:UInt32 = try buffer.readUInt32()
        for _ in 0..<numberOfEntries {
            entries.append(Entry(
                sampleCount: try buffer.readUInt32(),
                sampleDuration: try buffer.readUInt32()
            ))
        }

        return size
    }
}

// MARK: - MP4SampleSizeBox
final class MP4SampleSizeBox: MP4Box {
    var entries:[UInt32] = []

    override func loadFile(fileHandle: NSFileHandle) throws -> UInt32 {
        entries.removeAll(keepCapacity: false)

        let buffer:ByteArray = ByteArray(data: fileHandle.readDataOfLength(Int(self.size) - 8))
        buffer.position += 4

        let sampleSize:UInt32 = try buffer.readUInt32()

        if (sampleSize != 0) {
            entries.append(sampleSize)
            return size
        }

        let numberOfEntries:UInt32 = try buffer.readUInt32()
        for _ in 0..<numberOfEntries {
            entries.append(try buffer.readUInt32())
        }
        buffer.clear()

        return size
    }
}

// MARK: - MP4ElementaryStreamDescriptorBox
final class MP4ElementaryStreamDescriptorBox: MP4ContainerBox {
    var audioDecorderSpecificConfig:[UInt8] = []

    var tag:UInt8 = 0
    var tagSize:UInt8 = 0
    var id:UInt16 = 0
    var streamDependenceFlag:UInt8 = 0
    var urlFlag:UInt8 = 0
    var ocrStreamFlag:UInt8 = 0
    var streamPriority:UInt8 = 0

    override func loadFile(fileHandle: NSFileHandle) throws -> UInt32 {
        var tagSize:UInt8 = 0
        let buffer:ByteArray = ByteArray(data: fileHandle.readDataOfLength(Int(self.size) - 8))
        buffer.position += 4

        tag = try buffer.readUInt8()
        self.tagSize = try buffer.readUInt8()
        if (self.tagSize == 0x80) {
            buffer.position += 2
            self.tagSize = try buffer.readUInt8()
        }

        id = try buffer.readUInt16()

        let data:UInt8 = try buffer.readUInt8()
        streamDependenceFlag = data >> 7
        urlFlag = (data >> 6) & 0x1
        ocrStreamFlag = (data >> 5) & 0x1
        streamPriority = data & 0x1f

        if (streamDependenceFlag == 1) {
            try buffer.readUInt16()
        }
    
        // Decorder Config Descriptor
        try buffer.readUInt8()
        tagSize = try buffer.readUInt8()
        if (tagSize == 0x80) {
            buffer.position += 2
            tagSize = try buffer.readUInt8()
        }
        buffer.position += 13

        // Audio Decorder Spec Info
        try buffer.readUInt8()
        tagSize = try buffer.readUInt8()
        if (tagSize == 0x80) {
            buffer.position += 2
            tagSize = try buffer.readUInt8()
        }

        audioDecorderSpecificConfig = try buffer.readBytes(Int(tagSize))

        return size
    }
}

// MARK: - MP4AudioSampleEntryBox
final class MP4AudioSampleEntryBox: MP4ContainerBox {
    var version:UInt16 = 0

    var channelCount:UInt16 = 0
    var sampleSize:UInt16 = 0
    var compressionId:UInt16 = 0
    var packetSize:UInt16 = 0
    var sampleRate:UInt32 = 0
    var samplesPerPacket:UInt32 = 0
    var bytesPerPacket:UInt32 = 0
    var bytesPerFrame:UInt32 = 0
    var bytesPerSample:UInt32 = 0

    var soundVersion2Data:[UInt8] = []

    override func loadFile(fileHandle: NSFileHandle) throws -> UInt32 {
        let buffer:ByteArray = ByteArray(data: fileHandle.readDataOfLength(Int(size) - 8))
        buffer.position += 8

        version = try buffer.readUInt16()
        buffer.position += 6

        channelCount = try buffer.readUInt16()
        sampleSize = try buffer.readUInt16()
        compressionId = try buffer.readUInt16()
        packetSize = try buffer.readUInt16()
        sampleRate = try buffer.readUInt32()

        if (type != "mlpa") {
            sampleRate = sampleRate >> 16
        }

        if (0 < version) {
            samplesPerPacket = try buffer.readUInt32()
            bytesPerPacket = try buffer.readUInt32()
            bytesPerFrame = try buffer.readUInt32()
            bytesPerSample = try buffer.readUInt32()
        }

        if (version == 2) {
            soundVersion2Data += try buffer.readBytes(20)
        }

        var offset:UInt32 = UInt32(buffer.position) + 8
        fileHandle.seekToFileOffset(self.offset + UInt64(offset))

        let esds:MP4Box = try create(fileHandle.readDataOfLength(8), offset: offset)
        offset += try esds.loadFile(fileHandle)
        children.append(esds)

        // skip
        fileHandle.seekToFileOffset(self.offset + UInt64(size))

        return size
    }
}

// MARK: - MP4VisualSampleEntryBox
final class MP4VisualSampleEntryBox: MP4ContainerBox {
    static var dataSize:Int = 78

    var width:UInt16 = 0
    var height:UInt16 = 0
    var hSolution:UInt32 = 0
    var vSolution:UInt32 = 0
    var frameCount:UInt16 = 1
    var compressorname:String = ""
    var depth:UInt16 = 16

    override func loadFile(fileHandle: NSFileHandle) throws -> UInt32 {
        let buffer:ByteArray = ByteArray(data: fileHandle.readDataOfLength(MP4VisualSampleEntryBox.dataSize))

        buffer.position += 24
        width = try buffer.readUInt16()
        height = try buffer.readUInt16()
        hSolution = try buffer.readUInt32()
        vSolution = try buffer.readUInt32()
        buffer.position += 4
        frameCount = try buffer.readUInt16()
        compressorname = try buffer.readUTF8Bytes(32)
        depth = try buffer.readUInt16()
        try buffer.readUInt16()
        buffer.clear()

        var offset:UInt32 = UInt32(MP4VisualSampleEntryBox.dataSize)
        let child:MP4Box = try MP4Box.create(fileHandle.readDataOfLength(8))
        child.parent = self
        child.offset = self.offset + UInt64(offset) + 8
        offset += try child.loadFile(fileHandle)
        children.append(child)

        // skip
        fileHandle.seekToFileOffset(self.offset + UInt64(size))

        return size
    }
}

final class MP4SampleDescriptionBox: MP4ContainerBox {
    override func loadFile(fileHandle: NSFileHandle) throws -> UInt32 {
        children.removeAll(keepCapacity: false)

        let buffer:ByteArray = ByteArray(data: fileHandle.readDataOfLength(8))
        buffer.position = 4

        var offset:UInt32 = 16
        let numberOfEntries:UInt32 = try buffer.readUInt32()
        for _ in 0..<numberOfEntries {
            let child:MP4Box = try create(fileHandle.readDataOfLength(8), offset: offset)
            offset += try child.loadFile(fileHandle)
            children.append(child)
        }

        return offset
    }
}

// MARK: - MP4SampleToChunkBox
final class MP4SampleToChunkBox: MP4Box {
    struct Entry:CustomStringConvertible {
        var firstChunk:UInt32 = 0
        var samplesPerChunk:UInt32 = 0
        var sampleDescriptionIndex:UInt32 = 0

        var description:String {
            return Mirror(reflecting: self).description
        }

        init(firstChunk:UInt32, samplesPerChunk:UInt32, sampleDescriptionIndex:UInt32) {
            self.firstChunk = firstChunk
            self.samplesPerChunk = samplesPerChunk
            self.sampleDescriptionIndex = sampleDescriptionIndex
        }
    }

    var entries:[Entry] = []

    override func loadFile(fileHandle: NSFileHandle) throws -> UInt32 {
        let buffer:ByteArray = ByteArray(data: fileHandle.readDataOfLength(Int(size) - 8))
        buffer.position += 4

        let numberOfEntries:UInt32 = try buffer.readUInt32()
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

// MARK: - MP4EditListBox
final class MP4EditListBox: MP4Box {
    struct Entry: CustomStringConvertible {
        var segmentDuration:UInt32 = 0
        var mediaTime:UInt32 = 0
        var mediaRate:UInt32 = 0

        var description:String {
            return Mirror(reflecting: self).description
        }

        init(segmentDuration:UInt32, mediaTime:UInt32, mediaRate:UInt32) {
            self.segmentDuration = segmentDuration
            self.mediaTime = mediaTime
            self.mediaRate = mediaRate
        }
    }

    var version:UInt32 = 0
    var entries:[Entry] = []

    override func loadFile(fileHandle: NSFileHandle) throws -> UInt32 {
        let buffer:ByteArray = ByteArray(data: fileHandle.readDataOfLength(Int(size) - 8))
        
        version = try buffer.readUInt32()
        entries.removeAll(keepCapacity: false)
        
        let numberOfEntries:UInt32 = try buffer.readUInt32()
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

// MARK: - MP4File
final class MP4File: MP4ContainerBox {
    var url:NSURL? = nil {
        didSet {
            if (url == nil) {
                return
            }
            do {
                fileHandle = try NSFileHandle(forReadingFromURL: url!)
            } catch let error as NSError {
                print(error)
            }
        }
    }

    override var description:String {
        var description:String = ""
        for box in getBoxesByName("*") {
            description += box.description
        }
        return description
    }

    private var fileHandle:NSFileHandle? = nil

    func isEmpty() -> Bool {
        return getBoxesByName("mdhd").isEmpty
    }

    func readDataOfLength(length: Int) -> NSData {
        return fileHandle!.readDataOfLength(length)
    }

    func seekToFileOffset(offset: UInt64) {
        return fileHandle!.seekToFileOffset(offset)
    }

    func readDataOfBox(box:MP4Box) -> NSData {
        if (fileHandle == nil) {
            return NSData()
        }
        let currentOffsetInFile:UInt64 = fileHandle!.offsetInFile
        fileHandle!.seekToFileOffset(box.offset + 8)
        let data:NSData = fileHandle!.readDataOfLength(Int(box.size) - 8)
        fileHandle!.seekToFileOffset(currentOffsetInFile)
        return data
    }

    func loadFile() throws -> UInt32 {
        if (fileHandle == nil) {
            return 0
        }
        return try self.loadFile(fileHandle!)
    }

    func closeFile() {
        fileHandle?.closeFile()
    }

    override func loadFile(fileHandle: NSFileHandle) throws -> UInt32 {
        let size:UInt64 = fileHandle.seekToEndOfFile()
        fileHandle.seekToFileOffset(0)
        self.size = UInt32(size)
        return try super.loadFile(fileHandle)
    }
}
