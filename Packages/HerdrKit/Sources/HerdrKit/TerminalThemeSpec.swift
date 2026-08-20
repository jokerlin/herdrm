import Foundation

/// A terminal color theme parsed from ghostty's theme-file format: `key = value`
/// lines, with ANSI slots as `palette = N=#rrggbb`. Pure data — mapping to UI
/// color types stays in the app layer.
public struct TerminalThemeSpec: Equatable, Sendable {
    public struct RGB: Equatable, Sendable {
        public let red: UInt8
        public let green: UInt8
        public let blue: UInt8

        public init(red: UInt8, green: UInt8, blue: UInt8) {
            self.red = red
            self.green = green
            self.blue = blue
        }
    }

    public let name: String
    public let background: RGB
    public let foreground: RGB
    /// The 16 ANSI slots; nil where the theme file leaves a slot unset.
    public let palette: [RGB?]
    public let cursorColor: RGB?
    public let cursorText: RGB?
    public let selectionBackground: RGB?
    public let selectionForeground: RGB?

    /// Parses one theme file. Unknown keys and malformed lines are skipped —
    /// theme files in the wild carry extras like `cursor-style` — but a theme
    /// without both `background` and `foreground` is no theme at all.
    public static func parse(name: String, text: String) -> TerminalThemeSpec? {
        let entries = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .compactMap(keyValue)

        var palette = [RGB?](repeating: nil, count: 16)
        for (key, value) in entries where key == "palette" {
            if let (slot, color) = paletteEntry(value) {
                palette[slot] = color
            }
        }

        func color(_ key: String) -> RGB? {
            entries.last { $0.key == key }.flatMap { RGB(hex: $0.value) }
        }

        guard let background = color("background"),
              let foreground = color("foreground")
        else { return nil }

        return TerminalThemeSpec(
            name: name,
            background: background,
            foreground: foreground,
            palette: palette,
            cursorColor: color("cursor-color"),
            cursorText: color("cursor-text"),
            selectionBackground: color("selection-background"),
            selectionForeground: color("selection-foreground")
        )
    }

    private static func keyValue(_ line: String) -> (key: String, value: String)? {
        guard let separator = line.firstIndex(of: "=") else { return nil }
        let key = line[..<separator].trimmingCharacters(in: .whitespaces)
        let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, !value.isEmpty else { return nil }
        return (key, value)
    }

    /// `N=#rrggbb` → (slot, color), keeping only the 16 ANSI slots.
    private static func paletteEntry(_ value: String) -> (Int, RGB)? {
        guard let separator = value.firstIndex(of: "=") else { return nil }
        guard let slot = Int(value[..<separator].trimmingCharacters(in: .whitespaces)),
              (0..<16).contains(slot),
              let color = RGB(hex: value[value.index(after: separator)...].trimmingCharacters(in: .whitespaces))
        else { return nil }
        return (slot, color)
    }
}

extension TerminalThemeSpec.RGB {
    /// Accepts `#rrggbb` or bare `rrggbb`, case-insensitive.
    public init?(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(
            red: UInt8((value >> 16) & 0xFF),
            green: UInt8((value >> 8) & 0xFF),
            blue: UInt8(value & 0xFF)
        )
    }
}
