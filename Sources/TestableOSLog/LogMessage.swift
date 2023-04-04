import CryptoKit
import OSLog

public struct LogMessage {
    enum Fragment {
        case string(String)
        case value(() -> String, OSLogPrivacy)
    }

    var fragments: [Fragment] = []

    public func createOutput(forceMasking: Bool = false) -> String {
        var sum = ""
        for fragment in fragments {
            switch fragment {
            case let .string(value):
                sum += value
            case let .value(toString, privacy):
                let resolved = ResolvedPrivacy(privacy: privacy, forceMasking: forceMasking)
                switch resolved {
                case .public:
                    sum += toString()
                case .private:
                    sum += "<private>"
                case .hash:
                    var value = toString()
                    let digest = value.withUTF8 {
                        let buffer = UnsafeRawBufferPointer(start: $0.baseAddress, count: $0.count)
                        var sha256 = Self.sha256
                        sha256.update(bufferPointer: buffer)
                        return sha256.finalize()
                    }
                    var bytes = Array(digest)
                    bytes.removeSubrange((bytes.count / 2)...)
                    let output = Data(bytes).base64EncodedString()
                    sum += "<mask.hash: '\(output)'>"
                }
            }
        }
        return sum
    }
}

private extension LogMessage {
    enum ResolvedPrivacy {
        case `public`
        case `private`
        case hash

        init(privacy: OSLogPrivacy, forceMasking: Bool) {
            let shouldMask = Self.shouldMask(privacy: privacy, forceMasking: forceMasking)
            guard shouldMask else {
                self = .public
                return
            }

            let actualHashFlag = unsafeBitCast(privacy, to: UInt16.self) & 0xF00
            let shouldHashFlag = unsafeBitCast(OSLogPrivacy.auto(mask: .hash), to: UInt16.self) & 0xF00
            self = actualHashFlag == shouldHashFlag ? .hash : .private
        }

        static func shouldMask(privacy: OSLogPrivacy, forceMasking: Bool) -> Bool {
            let rawValue = unsafeBitCast(privacy, to: UInt16.self) & 0xF

            if rawValue == unsafeBitCast(OSLogPrivacy.public, to: UInt16.self) & 0xF {
                return false
            }
            if rawValue == unsafeBitCast(OSLogPrivacy.auto, to: UInt16.self) & 0xF {
                if forceMasking {
                    return true
                }
                #if DEBUG
                return false
                #else
                return true
                #endif
            }

            return true
        }
    }

    /// A SHA256 with a different initial “seed” each time the code executes.
    static let sha256: SHA256 = {
        var sha256 = SHA256()
        var seed = UUID()
        withUnsafePointer(to: seed) {
            let raw = UnsafeRawPointer($0)
            let buffer = UnsafeRawBufferPointer(start: raw, count: MemoryLayout<UUID>.size)
            sha256.update(bufferPointer: buffer)
        }
        return sha256
    }()
}

extension LogMessage: ExpressibleByStringInterpolation {
    public init(stringLiteral value: String) {
        fragments = [.string(value)]
    }

    public init(stringInterpolation: StringInterpolation) {
        fragments = stringInterpolation.fragments
    }
}

extension LogMessage {
    public struct StringInterpolation: StringInterpolationProtocol {
        var fragments: [Fragment] = []

        public init(literalCapacity: Int, interpolationCount: Int) {}

        public mutating func appendLiteral(_ literal: String) {
            fragments.append(.string(literal))
        }

        public mutating func appendInterpolation<T: CustomStringConvertible>(
            _ value: @autoclosure @escaping () -> T,
            privacy: OSLogPrivacy = .auto
        ) {
            fragments.append(.value({ value().description }, privacy))
        }
    }
}

/// Represents a log message.
///
/// When we want to test if our code logs correctly, we might as well make log messages strongly typed.
/// This protocol can help you to do just that. Instead of writing string literals all over the place,
/// you can centralize to a few types, and define the actual human readable strings in one place.
public protocol LogMessageConvertible {
    func toLogMessage() -> LogMessage
}

extension LogMessage: LogMessageConvertible {
    public func toLogMessage() -> LogMessage {
        self
    }
}
