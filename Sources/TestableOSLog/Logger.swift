import Dependencies
import OSLog
import XCTestDynamicOverlay


public struct LoggerClient {
    var createDefaultLogger: (Bool) -> Logger
    var createLogger: (String, String, Bool) -> Logger

    public init(
        createDefaultLogger: @escaping (Bool) -> Logger,
        createLogger: @escaping (String, String, Bool) -> Logger) {
        self.createDefaultLogger = createDefaultLogger
        self.createLogger = createLogger
    }

    /// Creates a logger that writes to the default subsystem.
    public func logger(forceMasking: Bool = false) -> Logger {
        createDefaultLogger(forceMasking)
    }

    /// Creates a logger using the specified subsystem and category.
    ///
    /// Parameters:
    ///   - subsystem: The string that identifies the subsystem that emits signposts. Typically, you use the same value as your app’s bundle ID. For more information, see `CFBundleIdentifier`.
    ///   - category: The string that the system uses to categorize emitted signposts.
    public func logger(subsystem: String, category: String, forceMasking: Bool = false) -> Logger {
        createLogger(subsystem, category, forceMasking)
    }
}

extension LoggerClient {
    public static let testValue = LoggerClient { _ in
        unimplemented("createDefaultLogger is unimplemented.")
    } createLogger: { _, _, _ in
        unimplemented("createLogger is unimplemented.")
    }

    private static func logClosure(for log: OSLog, forceMasking: Bool) -> ((OSLogType, LogMessage) -> Void) {
        return { type, message in
            guard log.isEnabled(type: type) else { return }
            let output = message.createOutput(forceMasking: forceMasking)
            output.withCString {
                os_log(type, log: log, "%{public}s", $0)
            }
        }
    }

    public static let liveValue = LoggerClient { forceMasking in
        Logger(log: logClosure(for: OSLog.default, forceMasking: forceMasking))
    } createLogger: { subsystem, category, forceMasking in
        Logger(log: logClosure(for: OSLog(subsystem: subsystem, category: category), forceMasking: forceMasking))
    }
}

extension DependencyValues {
    private enum LoggerClientKey: DependencyKey {
        static var testValue = LoggerClient.testValue
        static var liveValue = LoggerClient.liveValue
    }

    public var loggerClient: LoggerClient {
        get { self[LoggerClientKey.self] }
        set { self[LoggerClientKey.self] = newValue }
    }

    private enum LoggerKey: DependencyKey {
        static var testValue: Logger { .init { _, _ in } }

        static var liveValue: Logger {
            LoggerClient.liveValue.logger()
        }
    }

    public var logger: Logger {
        get { self[LoggerKey.self] }
        set { self[LoggerKey.self] = newValue }
    }
}

public struct Logger {
    var logClosure: (OSLogType, LogMessage) -> Void

    public init(log: @escaping (OSLogType, LogMessage) -> Void) {
        logClosure = log
    }

    public func log<L: LogMessageConvertible>(level: OSLogType, _ message: L) {
        logClosure(level, message.toLogMessage())
    }
}

extension Logger {
    public func log<L: LogMessageConvertible>(_ message: L) {
        log(level: .default, message)
    }

    /// Writes a message to the log using the default log type.
    public func notice<L: LogMessageConvertible>(_ message: L) {
        log(level: .default, message)
    }

    /// Writes a debug message to the log.
    public func debug<L: LogMessageConvertible>(_ message: L) {
        log(level: .debug, message)
    }

    /// Writes a trace message to the log.
    ///
    /// This method is functionally equivalent to the `debug(_:)` method.
    public func trace<L: LogMessageConvertible>(_ message: L) {
        log(level: .debug, message)
    }

    /// Writes an informative message to the log.
    public func info<L: LogMessageConvertible>(_ message: L) {
        log(level: .info, message)
    }

    /// Writes information about an error to the log.
    public func error<L: LogMessageConvertible>(_ message: L) {
        log(level: .error, message)
    }

    /// Writes information about a warning to the log.
    ///
    /// This method is functionally equivalent to the error(_:) method.
    public func warning<L: LogMessageConvertible>(_ message: L) {
        log(level: .error, message)
    }

    /// Writes a message to the log about a bug that occurs when your app executes.
    ///
    /// Use this method to write messages with the fault log level to both the in-memory and on-disk log stores.
    public func fault<L: LogMessageConvertible>(_ message: L) {
        log(level: .fault, message)
    }

    /// Writes a message to the log about a critical event in your app’s execution.
    ///
    /// This method is functionally equivalent to the `critical(_:)` method.
    public func critical<L: LogMessageConvertible>(_ message: L) {
        log(level: .fault, message)
    }
}
