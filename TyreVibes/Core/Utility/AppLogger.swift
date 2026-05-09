import Foundation
import OSLog

// MARK: - Log Level
enum LogLevel: String {
    case debug = "🔍 DEBUG"
    case info = "ℹ️ INFO"
    case warning = "⚠️ WARNING"
    case error = "❌ ERROR"
    case critical = "🔥 CRITICAL"
    case network = "🌐 NETWORK"
    case database = "💾 DATABASE"
    case auth = "🔐 AUTH"
}

// MARK: - App Logger
class AppLogger {
    static let shared = AppLogger()

    private let dateFormatter: DateFormatter
    private let logQueue = DispatchQueue(label: "com.tyrevibes.logger", qos: .utility)

    // OSLog categories
    private let networkLogger = Logger(subsystem: "com.tyrevibes.app", category: "Network")
    private let authLogger = Logger(subsystem: "com.tyrevibes.app", category: "Auth")
    private let databaseLogger = Logger(subsystem: "com.tyrevibes.app", category: "Database")
    private let generalLogger = Logger(subsystem: "com.tyrevibes.app", category: "General")

    // Settings
    var isEnabled: Bool = true
    #if DEBUG
    var logToFile: Bool = true
    #else
    var logToFile: Bool = false
    #endif
    var minimumLogLevel: LogLevel = .debug

    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }

    // MARK: - Logging Methods
    func log(
        _ message: String,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isEnabled else { return }

        logQueue.async { [weak self] in
            guard let self = self else { return }

            let fileName = (file as NSString).lastPathComponent
            let timestamp = self.dateFormatter.string(from: Date())
            let logMessage = "[\(timestamp)] [\(level.rawValue)] [\(fileName):\(line)] \(function) - \(message)"

            #if DEBUG
            print(logMessage)
            #endif

            // Log to OSLog
            self.logToOSLog(message: message, level: level, file: fileName, function: function, line: line)

            // Log to file if enabled
            if self.logToFile {
                self.writeToFile(logMessage)
            }
        }
    }

    // MARK: - Convenience Methods
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }

    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }

    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }

    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }

    func critical(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, file: file, function: function, line: line)
    }

    func network(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .network, file: file, function: function, line: line)
    }

    func database(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .database, file: file, function: function, line: line)
    }

    func auth(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .auth, file: file, function: function, line: line)
    }

    // MARK: - OSLog Integration
    private func logToOSLog(message: String, level: LogLevel, file: String, function: String, line: Int) {
        let formattedMessage = "[\(file):\(line)] \(function) - \(message)"

        switch level {
        case .network:
            networkLogger.info("\(formattedMessage)")
        case .auth:
            authLogger.info("\(formattedMessage)")
        case .database:
            databaseLogger.info("\(formattedMessage)")
        case .debug:
            generalLogger.debug("\(formattedMessage)")
        case .info:
            generalLogger.info("\(formattedMessage)")
        case .warning:
            generalLogger.warning("\(formattedMessage)")
        case .error:
            generalLogger.error("\(formattedMessage)")
        case .critical:
            generalLogger.critical("\(formattedMessage)")
        }
    }

    // MARK: - File Logging
    private func writeToFile(_ message: String) {
        guard let logURL = getLogFileURL() else { return }

        do {
            let fileHandle: FileHandle
            if FileManager.default.fileExists(atPath: logURL.path) {
                fileHandle = try FileHandle(forWritingTo: logURL)
                fileHandle.seekToEndOfFile()
            } else {
                FileManager.default.createFile(atPath: logURL.path, contents: nil)
                fileHandle = try FileHandle(forWritingTo: logURL)
            }

            if let data = (message + "\n").data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        } catch {
            print("Error writing to log file: \(error)")
        }
    }

    private func getLogFileURL() -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let logDirectory = documentsDirectory.appendingPathComponent("Logs", isDirectory: true)

        // Create logs directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: logDirectory.path) {
            try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fileName = "tyrevibes-\(dateFormatter.string(from: Date())).log"

        return logDirectory.appendingPathComponent(fileName)
    }

    // MARK: - Log Management
    func clearLogs() {
        guard let logURL = getLogFileURL() else { return }
        try? FileManager.default.removeItem(at: logURL)
        log("Logs cleared", level: .info)
    }

    func getLogFiles() -> [URL] {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }
        let logDirectory = documentsDirectory.appendingPathComponent("Logs", isDirectory: true)

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: logDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        return files.filter { $0.pathExtension == "log" }
    }

    func deleteOldLogs(olderThanDays days: Int = 7) {
        let logFiles = getLogFiles()
        let now = Date()

        for file in logFiles {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                  let creationDate = attributes[.creationDate] as? Date else {
                continue
            }

            let daysDifference = Calendar.current.dateComponents([.day], from: creationDate, to: now).day ?? 0
            if daysDifference > days {
                try? FileManager.default.removeItem(at: file)
                log("Deleted old log file: \(file.lastPathComponent)", level: .info)
            }
        }
    }
}

// MARK: - Global Log Functions
func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.debug(message, file: file, function: function, line: line)
}

func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.info(message, file: file, function: function, line: line)
}

func logWarning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.warning(message, file: file, function: function, line: line)
}

func logError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.error(message, file: file, function: function, line: line)
}

func logNetwork(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.network(message, file: file, function: function, line: line)
}
