import XCTest
@testable import HerdrKit

final class SocketRPCTimeoutTests: XCTestCase {
    /// A timed read must not leave its receive timeout armed on the fd: the event
    /// stream reads the subscribe ack with a 15 s timeout and then streams with
    /// `timeoutSeconds: nil`, so a leftover SO_RCVTIMEO makes every quiet gap
    /// longer than the ack timeout kill the stream (the sidebar's red/green
    /// connection flapping on quiet devices).
    func testUntimedReadSurvivesQuietGapLongerThanEarlierTimeout() throws {
        var fds: [Int32] = [0, 0]
        XCTAssertEqual(socketpair(AF_UNIX, SOCK_STREAM, 0, &fds), 0)
        let reader = fds[0]
        let writer = fds[1]
        defer {
            close(reader)
            close(writer)
        }

        try SocketRPC.writeLine(fd: writer, data: Data("ack\n".utf8))
        let ack = try SocketRPC.readLine(fd: reader, timeoutSeconds: 1)
        XCTAssertEqual(ack.map { String(decoding: $0, as: UTF8.self) }, "ack")

        // the next line lands only after a quiet gap longer than the ack timeout
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
            try? SocketRPC.writeLine(fd: writer, data: Data("event\n".utf8))
        }
        var buffer = Data()
        let line = try SocketRPC.readLine(fd: reader, timeoutSeconds: nil, buffer: &buffer)
        XCTAssertEqual(line.map { String(decoding: $0, as: UTF8.self) }, "event")
    }
}
