import XCTest
@testable import HerdrKit

final class OrphanSweepTests: XCTestCase {
    private let rows = """
          123     1 /bin/sh -c exec 4<&0 0</dev/null… /usr/bin/ssh -N -L /var/folders/x/T/herdrm-tunnels/254.sock:/home/u/.config/herdr/herdr.sock u@host
          124 65796 /bin/sh -c exec 4<&0 0</dev/null… /usr/bin/ssh -N -L /var/folders/x/T/herdrm-tunnels/931.sock:/home/u/.config/herdr/herdr.sock u@host
          200     1 /usr/bin/ssh -tt u@host exec /bin/sh -c ': herdrm-attach; export PATH=…; exec "$hb" agent attach w1:p1 --takeover'
          201 65796 /usr/bin/ssh -tt u@host exec /bin/sh -c ': herdrm-attach; …'
          300     1 /usr/bin/ssh -N -R 24038:127.0.0.1:17891 u@host
          301     1 /usr/bin/vim notes.txt
        """

    func testKillsOnlyMarkedProcessesReparentedToLaunchd() {
        XCTAssertEqual(OrphanSweep.orphanPIDs(inPSRows: rows), [123, 200])
    }

    func testIgnoresMalformedRows() {
        XCTAssertEqual(OrphanSweep.orphanPIDs(inPSRows: "garbage\n  12\n  x 1 herdrm-tunnels/\n"), [])
    }
}
