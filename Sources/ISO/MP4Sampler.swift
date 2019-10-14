import AVFoundation

protocol MP4SamplerDelegate: class {
    func didOpen(_ reader: MP4Reader)
    func didSet(config: Data, withID: Int, type: AVMediaType)
    func output(data: Data, withID: Int, currentTime: Double, keyframe: Bool)
}

// MARK: -
public class MP4Sampler {
    public typealias Handler = () -> Void

    weak var delegate: MP4SamplerDelegate?

    private var files: [URL] = []
    private var handlers: [URL: Handler?] = [:]
    private let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.MP4Sampler.lock")
    private let loopQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.MP4Sampler.loop")
    private let operations = OperationQueue()
    public private(set) var isRunning: Atomic<Bool> = .init(false)

    func appendFile(_ file: URL, completionHandler: Handler? = nil) {
        lockQueue.async {
            self.handlers[file] = completionHandler
            self.files.append(file)
        }
    }

    private func execute(url: URL) {
        let reader = MP4Reader(url: url)

        do {
            _ = try reader.load()
        } catch {
            logger.warn("")
            return
        }

        delegate?.didOpen(reader)
        let traks: [MP4Box] = reader.getBoxes(byName: "trak")
        for i in 0..<traks.count {
            let trakReader = MP4TrakReader(id: i, trak: traks[i])
            trakReader.delegate = delegate
            operations.addOperation {
                trakReader.execute(reader)
            }
        }
        operations.waitUntilAllOperationsAreFinished()

        reader.close()
    }

    private func run() {
        if files.isEmpty {
            return
        }
        let url: URL = files.first!
        let handler: Handler? = handlers[url]!
        files.remove(at: 0)
        handlers[url] = nil
        execute(url: url)
        handler?()
    }
}

extension MP4Sampler: Running {
    // MARK: Running
    public func startRunning() {
        loopQueue.async {
            self.isRunning.mutate { $0 = true }
            while self.isRunning.value {
                self.lockQueue.sync {
                    self.run()
                    if self.files.isEmpty {
                        sleep(1)
                    }
                }
            }
        }
    }

    public func stopRunning() {
        lockQueue.async {
            self.isRunning.mutate { $0 = false }
        }
    }
}
