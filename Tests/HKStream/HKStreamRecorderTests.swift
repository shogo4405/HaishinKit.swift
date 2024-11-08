import Foundation
import Testing

@testable import HaishinKit

@Suite struct HKStreamRecorderTests {
    @Test func startRunning_nil() async throws {
        let recorder = HKStreamRecorder()
        try await recorder.startRecording(nil)
        let moviesDirectory = await recorder.moviesDirectory
        // $moviesDirectory/B644F60F-0959-4F54-9D14-7F9949E02AD8.mp4
        #expect(((await recorder.outputURL?.path.contains(moviesDirectory.path())) != nil))
    }

    @Test func startRunning_fileName() async throws {
        let recorder = HKStreamRecorder()
        try? await recorder.startRecording(URL(string: "dir/sample.mp4"))
        let moviesDirectory = await recorder.moviesDirectory
        // $moviesDirectory/dir/sample.mp4
        #expect(((await recorder.outputURL?.path.contains("dir/sample.mp4")) != nil))
    }

    @Test func startRunning_fullPath() async {
        let recorder = HKStreamRecorder()
        let fullPath = await recorder.moviesDirectory.appendingPathComponent("sample.mp4")
        // $moviesDirectory/sample.mp4
        try? await recorder.startRecording(fullPath)
        #expect(await recorder.outputURL == fullPath)
    }

    @Test func startRunning_dir() async {
        let recorder = HKStreamRecorder()
        try? await recorder.startRecording(URL(string: "dir"))
        // $moviesDirectory/dir/33FA7D32-E0A8-4E2C-9980-B54B60654044.mp4
        #expect(((await recorder.outputURL?.path.contains("dir")) != nil))
    }

    @Test func startRunning_fileAlreadyExists() async {
        let recorder = HKStreamRecorder()
        let filePath = await recorder.moviesDirectory.appendingPathComponent("duplicate-file.mp4")
        FileManager.default.createFile(atPath: filePath.path, contents: nil)
        do {
            try await recorder.startRecording(filePath)
            fatalError()
        } catch {
            try? FileManager.default.removeItem(atPath: filePath.path)
        }
    }
}
