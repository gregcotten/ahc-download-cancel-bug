@testable import AsyncHTTPClient
import Foundation
import Testing
import Logging

@Test func ensureDownloadIsCancellable() async throws {
    let downloadURL = FileManager.default.temporaryDirectory.appendingPathComponent("centos7_download_test.tmp", isDirectory: false)
    try? FileManager.default.removeItem(at: downloadURL)
    defer { try? FileManager.default.removeItem(at: downloadURL) }

    let delegate = try FileDownloadDelegate(path: downloadURL.path)

    print("downloading to \(downloadURL.path)")

    var clientLogger = Logger(label: "download-task")
    clientLogger.logLevel = .trace
    let clientTask = try HTTPClient.shared.execute(request: .init(url: "http://vault.centos.org/7.9.2009/isos/x86_64/CentOS-7-x86_64-Minimal-2009.iso"),
                                                   delegate: delegate,
                                                   logger: clientLogger)

    let task = Task {
        _ = try await withTaskCancellationHandler {
            try await clientTask.get()
        } onCancel: {
            clientTask.cancel()
        }
    }

    try await Task.sleep(for: .seconds(5))
    print("cancelling...")
    task.cancel()
    print("cancelled")

    await #expect(throws: HTTPClientError.cancelled) {
        try await task.value
    }
}
