import XCTest
@testable import HerdrKit

final class DeathPactTests: XCTestCase {
    /// The wrapper must keep the command alive while the owner holds the stdin
    /// pipe, and reap it once the write end vanishes — the "app died without
    /// tearDown" case that leaves orphan ssh tunnels behind.
    func testWrappedCommandDiesWhenOwnerPipeCloses() throws {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", SSHTunnel.processDeathPactScript, "/bin/sleep", "100"]
        let pipe = Pipe()
        proc.standardInput = pipe
        try proc.run()

        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertTrue(proc.isRunning, "command must survive while the owner lives")

        try pipe.fileHandleForWriting.close()
        let deadline = Date().addingTimeInterval(3)
        while proc.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        XCTAssertFalse(proc.isRunning, "command must die once the owner's pipe closes")
    }

    /// The watcher subshell must not inherit the command's stderr pipe: the
    /// tunnel's failure path reads that pipe to EOF, and a lingering holder of
    /// the write end would deadlock `ensureUp` when ssh dies at startup.
    func testWrapperReleasesStderrWhenCommandExits() throws {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", SSHTunnel.processDeathPactScript, "/bin/sh", "-c", "echo oops >&2; exit 3"]
        proc.standardInput = Pipe() // stays open: the owning app is alive
        let errorPipe = Pipe()
        proc.standardError = errorPipe
        try proc.run()

        let eof = expectation(description: "stderr reaches EOF")
        var captured = Data()
        DispatchQueue.global().async {
            captured = errorPipe.fileHandleForReading.readDataToEndOfFile()
            eof.fulfill()
        }
        wait(for: [eof], timeout: 3)
        XCTAssertEqual(String(decoding: captured, as: UTF8.self), "oops\n")
    }

    /// terminate() (the tearDown path) must still reach the command itself:
    /// the wrapper execs into it, so the pid Process signals is the command's.
    func testWrappedCommandStopsOnTerminate() throws {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", SSHTunnel.processDeathPactScript, "/bin/sleep", "100"]
        proc.standardInput = Pipe()
        try proc.run()
        Thread.sleep(forTimeInterval: 0.4)

        proc.terminate()
        let deadline = Date().addingTimeInterval(3)
        while proc.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        XCTAssertFalse(proc.isRunning)
    }
}
