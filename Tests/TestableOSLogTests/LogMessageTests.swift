import XCTest
import Dependencies
@testable import TestableOSLog

final class LogMessageTests: XCTestCase {
    func testBasic() {
        let msg1: LogMessage = "hello, \("world"), 123, \(456)"
        XCTAssertEqual(msg1.createOutput(), "hello, world, 123, 456")

        let msg2: LogMessage = "hello, \("world", privacy: .private), 123, \(456, privacy: .private)"
        XCTAssertEqual(msg2.createOutput(), "hello, <private>, 123, <private>")
    }

    func testHash() {
        let val1 = "world"
        let msg1: LogMessage = "hello, \(val1, privacy: .private(mask: .hash))"

        let prefix = "hello, <mask.hash: '"
        let suffix = "'>"
        let output = msg1.createOutput()
        XCTAssert(output.hasPrefix(prefix))
        XCTAssert(output.hasSuffix(suffix))

        let base64String = String(output.dropFirst(prefix.count).dropLast(suffix.count))
        let data = Data(base64Encoded: base64String.data(using: .utf8)!)!
        // We only keep the first 16 bytes of SHA256 output.
        XCTAssertEqual(data.count, 16)

        let val2 = "world"
        let msg2: LogMessage = "hello, \(val2, privacy: .private(mask: .hash))"
        XCTAssertEqual(msg1.createOutput(), msg2.createOutput())
    }

    func testAdjustableMasking() {
        let msg: LogMessage = "hello, \("world")"

        let output1 = msg.createOutput(forceMasking: false)
        let output2 = msg.createOutput(forceMasking: true)

        #if DEBUG
        XCTAssertEqual(output1, "hello, world")
        #else
        XCTAssertEqual(output1, "hello, <private>")
        #endif
        XCTAssertEqual(output2, "hello, <private>")
    }
}
