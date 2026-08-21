import Foundation

/// Reaps ssh helpers left behind by an app instance that died without cleanup
/// (crash, force quit, SIGKILL — the paths no terminate hook covers). A helper
/// qualifies as orphaned when its argv carries one of this app's spawn markers
/// and launchd has adopted it (ppid 1); a live HerdrM instance's helpers keep
/// that instance as their parent and never match.
public enum OrphanSweep {
    /// argv substrings unique to processes this app spawns: the tunnel's local
    /// socket directory, and the no-op marker in every attach script.
    static let markers = ["herdrm-tunnels/", "herdrm-attach"]

    /// Pure core: picks the orphaned pids out of `ps -axo pid=,ppid=,command=` rows.
    static func orphanPIDs(inPSRows rows: String, markers: [String] = markers) -> [pid_t] {
        rows.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            guard fields.count >= 3,
                  let pid = pid_t(fields[0]),
                  let ppid = pid_t(fields[1]),
                  ppid == 1,
                  markers.contains(where: line.contains)
            else { return nil }
            return pid
        }
    }

    /// Lists processes and terminates the orphans. Best-effort: a failed `ps`
    /// just skips the sweep.
    public static func sweep() {
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-axo", "pid=,ppid=,command="]
        let output = Pipe()
        ps.standardOutput = output
        ps.standardError = FileHandle.nullDevice
        do {
            try ps.run()
        } catch {
            return
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        ps.waitUntilExit()
        for pid in orphanPIDs(inPSRows: String(decoding: data, as: UTF8.self)) {
            kill(pid, SIGTERM)
        }
    }
}
