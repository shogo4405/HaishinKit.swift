import Foundation

struct MP4SampleTable {
    var trak:MP4Box
    var currentOffset:UInt64 {
        return UInt64(offset[cursor])
    }
    var currentIsKeyframe:Bool {
        return keyframe[cursor] != nil
    }
    var currentDuration:Double {
        return Double(totalTimeToSample) * 1000 / Double(timeScale)
    }
    var currentTimeToSample:Double {
        return Double(timeToSample[cursor]) * 1000 / Double(timeScale)
    }
    var currentSampleSize:Int {
        return Int((sampleSize.count == 1) ? sampleSize[0] : sampleSize[cursor])
    }
    private var cursor:Int = 0
    private var offset:[UInt32] = []
    private var keyframe:[Int:Bool] = [:]
    private var timeScale:UInt32 = 0
    private var sampleSize:[UInt32] = []
    private var timeToSample:[UInt32] = []
    private var totalTimeToSample:UInt32 = 0

    init(trak:MP4Box) {
        self.trak = trak

        let mdhd:MP4Box? = trak.getBoxes(byName: "mdhd").first
        if let mdhd:MP4MediaHeaderBox = mdhd as? MP4MediaHeaderBox {
            timeScale = mdhd.timeScale
        }

        let stss:MP4Box? = trak.getBoxes(byName: "stss").first
        if let stss:MP4SyncSampleBox = stss as? MP4SyncSampleBox {
            var keyframes:[UInt32] = stss.entries
            for i in 0..<keyframes.count {
                keyframe[Int(keyframes[i])] = true
            }
        }

        let stts:MP4Box? = trak.getBoxes(byName: "stts").first
        if let stts:MP4TimeToSampleBox = stts as? MP4TimeToSampleBox {
            var timeToSample:[MP4TimeToSampleBox.Entry] = stts.entries
            for i in 0..<timeToSample.count {
                let entry:MP4TimeToSampleBox.Entry = timeToSample[i]
                for _ in 0..<entry.sampleCount {
                    self.timeToSample.append(entry.sampleDuration)
                }
            }
        }

        let stsz:MP4Box? = trak.getBoxes(byName: "stsz").first
        if let stsz:MP4SampleSizeBox = stsz as? MP4SampleSizeBox {
            sampleSize = stsz.entries
        }

        let stco:MP4Box = trak.getBoxes(byName: "stco").first!
        let stsc:MP4Box = trak.getBoxes(byName: "stsc").first!
        var offsets:[UInt32] = (stco as! MP4ChunkOffsetBox).entries
        var sampleToChunk:[MP4SampleToChunkBox.Entry] = (stsc as! MP4SampleToChunkBox).entries

        var index:Int = 0
        let count:Int = sampleToChunk.count

        for i in 0..<count {
            let j:Int = Int(sampleToChunk[i].firstChunk) - 1
            let m:Int = (i + 1 < count) ? Int(sampleToChunk[i + 1].firstChunk) - 1 : offsets.count
            for _ in j..<m {
                var offset:UInt32 = offsets[j]
                for _ in 0..<sampleToChunk[i].samplesPerChunk {
                    self.offset.append(offset)
                    offset += sampleSize[index]
                    index += 1
                }
            }
        }

        totalTimeToSample = timeToSample[cursor]
    }

    func hasNext() -> Bool {
        return cursor + 1 < offset.count
    }

    mutating func next() {
        defer {
            cursor += 1
        }
        totalTimeToSample += timeToSample[cursor]
    }
}

extension MP4SampleTable: CustomStringConvertible {
    // MARK: CustomStringConvertible
    var description:String {
        return Mirror(reflecting: self).description
    }
}

// MARK: -
protocol MP4SamplerDelegate: class {
    func didSet(avcC: Data, withType:Int)
    func didSet(audioDecorderSpecificConfig: Data, withType:Int)
    func output(data: Data, withType:Int, currentTime:Double, keyframe:Bool)
}

// MARK: -
class MP4Sampler {
    typealias Handler = () -> Void

    weak var delegate:MP4SamplerDelegate?

    fileprivate(set) var running:Bool = false
    fileprivate var files:[URL:Handler?] = [:]
    fileprivate let mutex:Mutex = Mutex()
    fileprivate let lockQueue:DispatchQueue = DispatchQueue(label: "com.github.shogo4405.lf.MP4Sampler.lock")
    fileprivate let loopQueue:DispatchQueue = DispatchQueue(label: "com.github.shgoo4405.lf.MP4Sampler.loop")

    private var reader:MP4Reader = MP4Reader()
    private var sampleTables:[MP4SampleTable] = []

    func append(file:URL, completionHandler: Handler? = nil) {
        lockQueue.async {
            self.files[file] = completionHandler
            let _:Bool = self.mutex.signal()
        }
    }

    fileprivate func execute(url:URL) {

        reader.url = url

        do {
            let _:UInt32 = try reader.load()
        } catch {
            logger.warning("")
            return
        }

        sampleTables.removeAll()
        var traks:[MP4Box] = reader.getBoxes(byName: "trak")
        for i in 0..<traks.count {
            sampleTables.append(MP4SampleTable(trak: traks[i]))
        }

        for i in 0..<sampleTables.count {
            if let avcC:MP4Box = sampleTables[i].trak.getBoxes(byName: "avcC").first {
                delegate?.didSet(avcC: reader.readData(ofBox: avcC), withType: i)
            }
            if let esds:MP4ElementaryStreamDescriptorBox = sampleTables[i].trak.getBoxes(byName: "esds").first as? MP4ElementaryStreamDescriptorBox {
                delegate?.didSet(audioDecorderSpecificConfig: Data(esds.audioDecorderSpecificConfig), withType: i)
            }
        }

        repeat {
            for i in 0..<sampleTables.count {
                autoreleasepool {
                    reader.seek(toFileOffset: sampleTables[i].currentOffset)
                    let length:Int = sampleTables[i].currentSampleSize
                    delegate?.output(
                        data: reader.readData(ofLength: length),
                        withType: i,
                        currentTime: sampleTables[i].currentTimeToSample,
                        keyframe: sampleTables[i].currentIsKeyframe
                    )
                }
                if (sampleTables[i].hasNext()) {
                    sampleTables[i].next()
                }
            }
        }
        while inLoop(sampleTables: sampleTables)

        reader.close()
    }

    fileprivate func run() {
        if (files.isEmpty) {
            return
        }
        let (key: url, value: handler) = files.popFirst()!
        execute(url: url)
        handler?()
    }

    private func inLoop(sampleTables:[MP4SampleTable]) -> Bool{
        for i in sampleTables {
            if (i.hasNext()) {
                return true
            }
        }
        return false
    }
}

extension MP4Sampler: Runnable {
    // MARK: Runnable
    final func startRunning() {
        loopQueue.async {
            self.running = true
            while (self.running) {
                self.lockQueue.sync {
                    self.run()
                    if (self.files.isEmpty) {
                        let _:Bool = self.mutex.wait()
                    }
                }
            }
        }
    }

    final func stopRunning() {
        lockQueue.async {
            self.running = false
        }
    }
}
