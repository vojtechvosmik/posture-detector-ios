//
//  DebugLogger.swift
//  PostureDetector
//
//  Debug logging system for background monitoring
//

import Foundation

class DebugLogger {
    static let shared = DebugLogger()

    private let fileManager = FileManager.default
    private var logFileURL: URL?
    private let dateFormatter = DateFormatter()
    private let queue = DispatchQueue(label: "cz.peachdev.postureplus.logger")

    private init() {
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        setupLogFile()
    }

    private func setupLogFile() {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Failed to get documents directory")
            return
        }

        logFileURL = documentsURL.appendingPathComponent("posture_debug.log")

        // Create new log file on each app launch
        if fileManager.fileExists(atPath: logFileURL!.path) {
            try? fileManager.removeItem(at: logFileURL!)
        }

        fileManager.createFile(atPath: logFileURL!.path, contents: nil)
        log("=== Debug Log Started ===")
    }

    func log(_ message: String, category: String = "INFO") {
        queue.async { [weak self] in
            guard let self = self, let logFileURL = self.logFileURL else { return }

            let timestamp = self.dateFormatter.string(from: Date())
            let logEntry = "[\(timestamp)] [\(category)] \(message)\n"

            // Print to console
            print(logEntry.trimmingCharacters(in: .newlines))

            // Write to file
            if let data = logEntry.data(using: .utf8) {
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            }
        }
    }

    func getLogContents() -> String {
        guard let logFileURL = logFileURL,
              let data = try? Data(contentsOf: logFileURL),
              let contents = String(data: data, encoding: .utf8) else {
            return "No logs available"
        }
        return contents
    }

    func clearLogs() {
        queue.async { [weak self] in
            guard let self = self, let logFileURL = self.logFileURL else { return }
            try? self.fileManager.removeItem(at: logFileURL)
            self.fileManager.createFile(atPath: logFileURL.path, contents: nil)
            self.log("=== Logs Cleared ===")
        }
    }

    func getLogFileURL() -> URL? {
        return logFileURL
    }
}
