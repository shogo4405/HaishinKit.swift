import Foundation

// MARK: -
protocol MP4SamplerDelegate: class {
    func didSet(avcC:Data, withType:Int)
    func didSet(audioDecorderSpecificConfig:Data, withType:Int)
    func output(data:Data, withType:Int, currentTime:Double, keyframe:Bool)
}

// MARK: -
class MP4Sampler {
    typealias Handler = () -> Void

    weak var delegate:MP4SamplerDelegate?

    fileprivate(set) var running:Bool = false
    fileprivate var files:[URL:Handler?] = [:]
    fileprivate let lockQueue:DispatchQueue = DispatchQueue(label: "com.github.shogo4405.lf.MP4Sampler.lock")
    fileprivate let loopQueue:DispatchQueue = DispatchQueue(label: "com.github.shgoo4405.lf.MP4Sampler.loop")
    fileprivate let operations:OperationQueue = OperationQueue()

    private var reader:MP4Reader = MP4Reader()
    private var trakReaders:[MP4TrakReader] = []

    func appendFile(_ file:URL, completionHandler: Handler? = nil) {
        lockQueue.async {
            self.files[file] = completionHandler
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

        trakReaders.removeAll()
        let traks:[MP4Box] = reader.getBoxes(byName: "trak")
        for i in 0..<traks.count {
            trakReaders.append(MP4TrakReader(id:i, trak:traks[i]))
        }

        for i in 0..<trakReaders.count {
            if let avcC:MP4Box = trakReaders[i].trak.getBoxes(byName: "avcC").first {
                delegate?.didSet(avcC: reader.readData(ofBox: avcC), withType: i)
            }
            if let esds:MP4ElementaryStreamDescriptorBox = trakReaders[i].trak.getBoxes(byName: "esds").first as? MP4ElementaryStreamDescriptorBox {
                delegate?.didSet(audioDecorderSpecificConfig: Data(esds.audioDecorderSpecificConfig), withType: i)
            }
        }

        for i in 0..<trakReaders.count {
            operations.addOperation {
                self.trakReaders[i].delegate = self.delegate
                self.trakReaders[i].execute(url: url)
            }
        }
        operations.waitUntilAllOperationsAreFinished()

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
                        sleep(1)
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
