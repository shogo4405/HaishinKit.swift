import Foundation

class MP4Box:NSObject {
    static func create(data:NSData) -> MP4Box {
        let buffer:ByteArray = ByteArray(data: data)
        let size:UInt32 = buffer.readUInt32()
        let type:String = buffer.read(4)

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

    private var _type:String = "undf"
    var type:String {
        return _type
    }
    
    private var _size:UInt32 = 0
    var size:UInt32 {
        return _size
    }

    private var _offset:UInt64 = 0
    var offset:UInt64 {
        return _offset
    }

    private var _parent:MP4Box? = nil
    var parent:MP4Box? {
        return _parent
    }

    var leafNode:Bool {
        return false
    }

    override var description:String {
        return "MP4Box{type:\(type),size:\(size),offset:\(offset)}"
    }

    override init() {
    }

    init(size: UInt32, type:String) {
        _size = size
        _type = type
    }

    func loadFile(fileHandle: NSFileHandle) -> UInt32 {
        if (_size == 0) {
            _size = UInt32(fileHandle.seekToEndOfFile() - _offset)
            return size
        }
        fileHandle.seekToFileOffset(_offset + UInt64(size))
        return size
    }

    func getBoxesByName(name:String) -> [MP4Box] {
        return []
    }

    func clear() {
        _parent = nil
    }

    func create(data:NSData, offset:UInt32) -> MP4Box {
        let box:MP4Box = MP4Box.create(data)
        box._parent = self
        box._offset = _offset + UInt64(offset)
        return box
    }
}

class MP4ContainerBox:MP4Box {

    private var children:[MP4Box] = []

    override var leafNode: Bool {
        return false
    }

    override func loadFile(fileHandle: NSFileHandle) -> UInt32 {
        children.removeAll(keepCapacity: false)

        var offset:UInt32 = _parent == nil ? 0 : 8
        fileHandle.seekToFileOffset(_offset + UInt64(offset))

        while (size != offset) {
            let child:MP4Box = create(fileHandle.readDataOfLength(8), offset: offset)
            offset += child.loadFile(fileHandle)
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
        _parent = nil
    }
}

final class MP4AvcConfigurationBox: MP4Box {
    var version:UInt8 = 0
    var avcProfileIndication:UInt8 = 0
    var profileCompatibility:UInt8 = 0
    var avcLevelIndication:UInt8 = 0
    var lengthSizeMinusOnePaddingBits:UInt8 = 0
    var lengthSizeMinusOne:UInt8 = 0
    var sequenceParameterSets:[UInt8] = [] // SPS
    var pictureParameterSets:[UInt8] = [] // PPS
    var numberOfSequenceParameterSetsPaddingBits:UInt8 = 7

    private var _bytes:[UInt8] = []
    var bytes:[UInt8] {
        set {
            let buffer:ByteArray = ByteArray(bytes: newValue)
            version = buffer.readUInt8()
            avcProfileIndication = buffer.readUInt8()
            profileCompatibility = buffer.readUInt8()
            avcLevelIndication = buffer.readUInt8()

            // skip for 0xFF, 0xFF
            buffer.position += 2
            buffer.position += 1

            let byte:UInt8 = buffer.readUInt8()
            numberOfSequenceParameterSetsPaddingBits = byte & 0b11100000 << 5

            let numberOfSequenceParameterSets:UInt8 = byte & 0b00011111
            // for _ in 0..<numberOfSequenceParameterSets {
                sequenceParameterSets = buffer.readUInt8(Int(numberOfSequenceParameterSets))
            // }

            let numberOfPictureParameterSets:UInt8 = buffer.readUInt8()
            for _ in 0..<numberOfPictureParameterSets {
                let length:UInt16 = buffer.readUInt16()
                pictureParameterSets = buffer.readUInt8(Int(length))
            }

            _bytes = newValue
        }
        get {
            return _bytes
        }
    }
}

final class MP4MediaHeaderBox:MP4Box {
    var version:UInt8 = 0
    var creationTime:UInt32 = 0
    var modificationTime:UInt32 = 0
    var timeScale:UInt32 = 0
    var duration:UInt32 = 0
    var language:UInt16 = 0
    var quality:UInt16 = 0

    override var description:String {
        var description:String = "MP4MediaHeaderBox{"
        description += "version:\(version),"
        description += "creationTime:\(creationTime),"
        description += "modificationTime:\(modificationTime),"
        description += "timeScale:\(timeScale),"
        description += "duration:\(duration),"
        description += "language:\(language),"
        description += "quality:\(quality)"
        description += "}"
        return description
    }

    override func loadFile(fileHandle: NSFileHandle) -> UInt32 {
        let buffer:ByteArray = ByteArray(data: fileHandle.readDataOfLength(Int(size) - 8))
        version = buffer.readUInt8()
        buffer.position += 3
        creationTime = buffer.readUInt32()
        modificationTime = buffer.readUInt32()
        timeScale = buffer.readUInt32()
        duration = buffer.readUInt32()
        language = buffer.readUInt16()
        quality = buffer.readUInt16()
        buffer.clear()
        return size
    }
}

final class MP4ChunkOffsetBox: MP4Box {
    var entries:[UInt32] = []

    override func loadFile(fileHandle: NSFileHandle) -> UInt32 {
        let buffer:ByteArray = ByteArray(data: fileHandle.readDataOfLength(Int(size) - 8))
        buffer.position += 4

        let numberOfEntries:UInt32 = buffer.readUInt32()
        for _ in 0..<numberOfEntries {
            entries.append(buffer.readUInt32())
        }
        buffer.clear()

        return size
    }
}

final class MP4SyncSampleBox: MP4Box {
    var entries:[UInt32] = []

    override func loadFile(fileHandle: NSFileHandle) -> UInt32 {
        entries.removeAll(keepCapacity: false)

        let buffer:ByteArray = ByteArray(data: fileHandle.readDataOfLength(Int(size) - 8))
        buffer.position += 4

        let numberOfEntries:UInt32 = buffer.readUInt32()
        for _ in 0..<numberOfEntries {
            entries.append(buffer.readUInt32())
        }

        return size
    }
}

final class MP4TimeToSampleBox: MP4Box {
    struct Entry: CustomStringConvertible {
        var sampleCount:UInt32 = 0
        var sampleDuration:UInt32 = 0

        var description:String {
            var description:String = "MP4TimeToSample{"
            description += "sampleCount:\(sampleCount),"
            description += "sampleDuration:\(sampleDuration)"
            description += "}"
            return description
        }
        
        init (sampleCount:UInt32, sampleDuration:UInt32) {
            self.sampleCount = sampleCount
            self.sampleDuration = sampleDuration
        }
    }

    var entries:[Entry] = []

    override func loadFile(fileHandle: NSFileHandle) -> UInt32 {
        entries.removeAll(keepCapacity: false)

        let buffer:ByteArray = ByteArray(data: fileHandle.readDataOfLength(Int(size) - 8))
        buffer.position += 4

        let numberOfEntries:UInt32 = buffer.readUInt32()
        for _ in 0..<numberOfEntries {
            entries.append(Entry(
                sampleCount: buffer.readUInt32(),
                sampleDuration: buffer.readUInt32()
            ))
        }

        return size
    }
}

final class MP4SampleSizeBox: MP4Box {
    var entries:[UInt32] = []

    override func loadFile(fileHandle: NSFileHandle) -> UInt32 {
        entries.removeAll(keepCapacity: false)

        let buffer:ByteArray = ByteArray(data: fileHandle.readDataOfLength(Int(self.size) - 8))
        buffer.position += 4

        let sampleSize:UInt32 = buffer.readUInt32()

        if (sampleSize != 0) {
            entries.append(sampleSize)
            return size
        }

        let numberOfEntries:UInt32 = buffer.readUInt32()
        for _ in 0..<numberOfEntries {
            entries.append(buffer.readUInt32())
        }
        buffer.clear()

        return size
    }
}

final class MP4ElementaryStreamDescriptorBox:MP4ContainerBox {
    var audioDecorderSpecificConfig:[UInt8] = []

    var tag:UInt8 = 0
    var tagSize:UInt8 = 0
    var id:UInt16 = 0
    var streamDependenceFlag:UInt8 = 0
    var urlFlag:UInt8 = 0
    var ocrStreamFlag:UInt8 = 0
    var streamPriority:UInt8 = 0

    override func loadFile(fileHandle: NSFileHandle) -> UInt32 {
        var tagSize:UInt8 = 0
        let buffer:ByteArray = ByteArray(data: fileHandle.readDataOfLength(Int(self.size) - 8))
        buffer.position += 4

        tag = buffer.readUInt8()
        self.tagSize = buffer.readUInt8()
        if (self.tagSize == 0x80) {
            buffer.position += 2
            self.tagSize = buffer.readUInt8()
        }

        id = buffer.readUInt16()

        let data:UInt8 = buffer.readUInt8()
        streamDependenceFlag = data >> 7
        urlFlag = (data >> 6) & 0x1
        ocrStreamFlag = (data >> 5) & 0x1
        streamPriority = data & 0x1f

        if (streamDependenceFlag == 1) {
            buffer.readUInt16()
        }
    
        // Decorder Config Descriptor
        buffer.readUInt8()
        tagSize = buffer.readUInt8()
        if (tagSize == 0x80) {
            buffer.position += 2
            tagSize = buffer.readUInt8()
        }
        buffer.position += 13

        // Audio Decorder Spec Info
        buffer.readUInt8()
        tagSize = buffer.readUInt8()
        if (tagSize == 0x80) {
            buffer.position += 2
            tagSize = buffer.readUInt8()
        }

        audioDecorderSpecificConfig = buffer.readUInt8(Int(tagSize))

        return size
    }
}

final class MP4AudioSampleEntryBox:MP4ContainerBox {
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

    override var description:String {
        var description:String = "MP4AudioSampleEntryBox{"
        description += "type:\(type),"
        description += "size:\(size),"
        description += "version:\(version),"
        description += "channelCount:\(channelCount),"
        description += "sampleSize:\(sampleSize),"
        description += "compressionId:\(compressionId),"
        description += "packetSize:\(packetSize),"
        description += "sampleRate:\(sampleRate),"
        description += "samplesPerPacket:\(samplesPerPacket),"
        description += "bytesPerPacket:\(bytesPerPacket),"
        description += "bytesPerFrame:\(bytesPerFrame),"
        description += "bytesPerSample:\(bytesPerSample),"
        description += "soundVersion2Data:\(soundVersion2Data)"
        description += "}"
        return description
    }

    override func loadFile(fileHandle: NSFileHandle) -> UInt32 {
        let buffer:ByteArray = ByteArray(data: fileHandle.readDataOfLength(Int(size) - 8))
        buffer.position += 8

        version = buffer.readUInt16()
        buffer.position += 6

        channelCount = buffer.readUInt16()
        sampleSize = buffer.readUInt16()
        compressionId = buffer.readUInt16()
        packetSize = buffer.readUInt16()
        sampleRate = buffer.readUInt32()

        if (type != "mlpa") {
            sampleRate = sampleRate >> 16
        }

        if (0 < version) {
            samplesPerPacket = buffer.readUInt32()
            bytesPerPacket = buffer.readUInt32()
            bytesPerFrame = buffer.readUInt32()
            bytesPerSample = buffer.readUInt32()
        }

        if (version == 2) {
            soundVersion2Data += buffer.readUInt8(20)
        }

        var offset:UInt32 = UInt32(buffer.position) + 8
        fileHandle.seekToFileOffset(_offset + UInt64(offset))

        let esds:MP4Box = create(fileHandle.readDataOfLength(8), offset: offset)
        offset += esds.loadFile(fileHandle)
        children.append(esds)

        // skip
        fileHandle.seekToFileOffset(_offset + UInt64(size))

        return size
    }
}

final class MP4VisualSampleEntryBox:MP4ContainerBox {
    static var dataSize:Int = 78

    var width:UInt16 = 0
    var height:UInt16 = 0
    var hSolution:UInt32 = 0
    var vSolution:UInt32 = 0
    var frameCount:UInt16 = 1
    var compressorname:String = ""
    var depth:UInt16 = 16

    override var description:String {
        var description:String = "MP4VisualSampleEntryBox{"
        description += "type:\(type),"
        description += "size:\(size),"
        description += "offset:\(offset),"
        description += "width:\(width)),"
        description += "height:\(height),"
        description += "hSolution:\(hSolution),"
        description += "vSolution:\(vSolution),"
        description += "frameCount:\(frameCount),"
        description += "compressorname:\(compressorname),"
        description += "depth:\(depth)"
        description += "}"
        return description
    }

    override func loadFile(fileHandle: NSFileHandle) -> UInt32 {
        let buffer:ByteArray = ByteArray(data: fileHandle.readDataOfLength(MP4VisualSampleEntryBox.dataSize))

        buffer.position += 24
        width = buffer.readUInt16()
        height = buffer.readUInt16()
        hSolution = buffer.readUInt32()
        vSolution = buffer.readUInt32()
        buffer.position += 4
        frameCount = buffer.readUInt16()
        compressorname = buffer.read(32)
        depth = buffer.readUInt16()
        buffer.readUInt16()
        buffer.clear()

        var offset:UInt32 = UInt32(MP4VisualSampleEntryBox.dataSize)
        let child:MP4Box = MP4Box.create(fileHandle.readDataOfLength(8))
        child._parent = self
        child._offset = _offset + UInt64(offset) + 8
        offset += child.loadFile(fileHandle)
        children.append(child)

        // skip
        fileHandle.seekToFileOffset(_offset + UInt64(size))

        return size
    }
}

final class MP4SampleDescriptionBox: MP4ContainerBox {
    override func loadFile(fileHandle: NSFileHandle) -> UInt32 {
        children.removeAll(keepCapacity: false)

        let buffer:ByteArray = ByteArray(data: fileHandle.readDataOfLength(8))
        buffer.position = 4

        var offset:UInt32 = 16
        let numberOfEntries:UInt32 = buffer.readUInt32()
        for _ in 0..<numberOfEntries {
            let child:MP4Box = create(fileHandle.readDataOfLength(8), offset: offset)
            offset += child.loadFile(fileHandle)
            children.append(child)
        }

        return offset
    }
}

final class MP4SampleToChunkBox: MP4Box {
    struct Entry:CustomStringConvertible {
        var firstChunk:UInt32 = 0
        var samplesPerChunk:UInt32 = 0
        var sampleDescriptionIndex:UInt32 = 0

        var description:String {
            var description:String = "MP4SampleToChunkBox.Entry{"
            description += "firstChunk:\(firstChunk),"
            description += "samplesPerChunk:\(samplesPerChunk),"
            description += "sampleDescriptionIndex:\(sampleDescriptionIndex)"
            description += "}";
            return description
        }

        init(firstChunk:UInt32, samplesPerChunk:UInt32, sampleDescriptionIndex:UInt32) {
            self.firstChunk = firstChunk
            self.samplesPerChunk = samplesPerChunk
            self.sampleDescriptionIndex = sampleDescriptionIndex
        }
    }

    var entries:[Entry] = []

    override func loadFile(fileHandle: NSFileHandle) -> UInt32 {
        let buffer:ByteArray = ByteArray(data: fileHandle.readDataOfLength(Int(size) - 8))
        buffer.position += 4

        let numberOfEntries:UInt32 = buffer.readUInt32()
        for _ in 0..<numberOfEntries {
            entries.append(Entry(
                firstChunk: buffer.readUInt32(),
                samplesPerChunk: buffer.readUInt32(),
                sampleDescriptionIndex: buffer.readUInt32()
            ))
        }
        buffer.clear()

        return size
    }
}

final class MP4EditListBox: MP4Box {
    struct Entry:CustomStringConvertible {
        var segmentDuration:UInt32 = 0
        var mediaTime:UInt32 = 0
        var mediaRate:UInt32 = 0

        var description:String {
            var description:String = "MP4EditListBox.Entry("
            description += "segmentDuration:\(segmentDuration),"
            description += "mediaTime:\(mediaTime),"
            description += "mediaRate:\(mediaRate)"
            description += ")"
            return description
        }

        init(segmentDuration:UInt32, mediaTime:UInt32, mediaRate:UInt32) {
            self.segmentDuration = segmentDuration
            self.mediaTime = mediaTime
            self.mediaRate = mediaRate
        }
    }

    var version:UInt32 = 0
    var entries:[Entry] = []

    override func loadFile(fileHandle: NSFileHandle) -> UInt32 {
        let buffer:ByteArray = ByteArray(data: fileHandle.readDataOfLength(Int(size) - 8))
        
        version = buffer.readUInt32()
        entries.removeAll(keepCapacity: false)
        
        let numberOfEntries:UInt32 = buffer.readUInt32()
        for _ in 0..<numberOfEntries {
            entries.append(Entry(
                segmentDuration: buffer.readUInt32(),
                mediaTime: buffer.readUInt32(),
                mediaRate: buffer.readUInt32()
            ))
        }

        return size
    }
}

final class MP4File:MP4ContainerBox {
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

    func loadFile() -> UInt32 {
        if (fileHandle == nil) {
            return 0
        }
        return self.loadFile(fileHandle!)
    }

    func closeFile() {
        fileHandle?.closeFile()
    }

    override func loadFile(fileHandle: NSFileHandle) -> UInt32 {
        let size:UInt64 = fileHandle.seekToEndOfFile()
        fileHandle.seekToFileOffset(0)
        _size = UInt32(size)
        return super.loadFile(fileHandle)
    }
}
