import AppKit
import HerdrKit
import SwiftTerm

/// Terminal themes in ghostty's theme-file format. The bundled catalog ships as
/// Resources/TerminalThemes (see Resources/TerminalThemes-ATTRIBUTION.md); themes
/// in ~/.config/ghostty/themes are also offered and override bundled ones by name,
/// matching ghostty's own lookup order.
enum TerminalThemeCatalog {
    private static let bundledDirectory = Bundle.main.resourceURL?
        .appendingPathComponent("TerminalThemes", isDirectory: true)
    private static let userDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/ghostty/themes", isDirectory: true)

    /// Every selectable theme name, for the settings pickers.
    static func availableNames() -> [String] {
        let names = [userDirectory, bundledDirectory]
            .compactMap { $0 }
            .flatMap { (try? FileManager.default.contentsOfDirectory(atPath: $0.path)) ?? [] }
            .filter { !$0.hasPrefix(".") }
        return Set(names).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Parse results are cached: the pane background is recomputed on every
    /// SwiftUI body evaluation and must not hit the filesystem each time.
    @MainActor private static var cache: [String: TerminalThemeSpec?] = [:]

    @MainActor
    static func spec(named name: String) -> TerminalThemeSpec? {
        if let cached = cache[name] { return cached }
        let loaded = load(name)
        cache[name] = loaded
        return loaded
    }

    private static func load(_ name: String) -> TerminalThemeSpec? {
        guard !name.isEmpty, !name.contains("/") else { return nil }
        return [userDirectory, bundledDirectory]
            .compactMap { $0?.appendingPathComponent(name) }
            .lazy
            .compactMap { url in
                (try? String(contentsOf: url, encoding: .utf8))
                    .flatMap { TerminalThemeSpec.parse(name: name, text: $0) }
            }
            .first
    }
}

extension TerminalThemeSpec.RGB {
    /// Perceived-luminance test, for pairing surrounding chrome (sidebar text,
    /// forced color scheme) with the theme.
    var isDark: Bool {
        (0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722 * Double(blue)) / 255 < 0.5
    }

    var nsColor: NSColor {
        NSColor(
            srgbRed: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: 1
        )
    }

    var terminalColor: SwiftTerm.Color {
        SwiftTerm.Color(red8: UInt16(red), green8: UInt16(green), blue8: UInt16(blue))
    }
}

extension TerminalThemeSpec {
    /// The 16 ANSI slots as SwiftTerm colors; slots the theme leaves unset keep
    /// the built-in defaults.
    var terminalPalette: [SwiftTerm.Color] {
        zip(palette, TerminalDefaults.darkPalette).map { themed, fallback in
            themed.map(\.terminalColor) ?? fallback
        }
    }
}
