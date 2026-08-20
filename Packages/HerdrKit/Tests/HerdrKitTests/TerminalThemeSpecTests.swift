import XCTest
@testable import HerdrKit

final class TerminalThemeSpecTests: XCTestCase {
    /// Verbatim head of ghostty's "Flexoki Light" theme file.
    private let flexokiLight = """
    palette = 0=#100f0f
    palette = 1=#af3029
    palette = 2=#66800b
    palette = 3=#ad8301
    palette = 4=#205ea6
    palette = 5=#a02f6f
    palette = 6=#24837b
    palette = 7=#6f6e69
    palette = 8=#b7b5ac
    palette = 9=#d14d41
    palette = 10=#879a39
    palette = 11=#d0a215
    palette = 12=#4385be
    palette = 13=#ce5d97
    palette = 14=#3aa99f
    palette = 15=#cecdc3
    background = #fffcf0
    foreground = #100f0f
    cursor-color = #100f0f
    cursor-text = #fffcf0
    selection-background = #cecdc3
    selection-foreground = #100f0f
    """

    func testParsesFullGhosttyTheme() throws {
        let spec = try XCTUnwrap(TerminalThemeSpec.parse(name: "Flexoki Light", text: flexokiLight))
        XCTAssertEqual(spec.name, "Flexoki Light")
        XCTAssertEqual(spec.background, .init(red: 0xFF, green: 0xFC, blue: 0xF0))
        XCTAssertEqual(spec.foreground, .init(red: 0x10, green: 0x0F, blue: 0x0F))
        XCTAssertEqual(spec.palette.count, 16)
        XCTAssertEqual(spec.palette[0], .init(red: 0x10, green: 0x0F, blue: 0x0F))
        XCTAssertEqual(spec.palette[15], .init(red: 0xCE, green: 0xCD, blue: 0xC3))
        XCTAssertEqual(spec.cursorColor, .init(red: 0x10, green: 0x0F, blue: 0x0F))
        XCTAssertEqual(spec.cursorText, .init(red: 0xFF, green: 0xFC, blue: 0xF0))
        XCTAssertEqual(spec.selectionBackground, .init(red: 0xCE, green: 0xCD, blue: 0xC3))
        XCTAssertEqual(spec.selectionForeground, .init(red: 0x10, green: 0x0F, blue: 0x0F))
    }

    func testMissingBackgroundOrForegroundIsInvalid() {
        XCTAssertNil(TerminalThemeSpec.parse(name: "x", text: "foreground = #ffffff"))
        XCTAssertNil(TerminalThemeSpec.parse(name: "x", text: "background = #000000"))
    }

    func testTolerantOfNoiseAndFormatVariants() throws {
        let text = """
        # a comment line
          background   =   fffcf0

        foreground = #100F0F
        palette = 3=ad8301
        cursor-style = block
        palette = 200=#123456
        palette = not-a-number=#123456
        palette = 4=#nothex
        """
        let spec = try XCTUnwrap(TerminalThemeSpec.parse(name: "x", text: text))
        // Bare hex (no '#') and uppercase both parse.
        XCTAssertEqual(spec.background, .init(red: 0xFF, green: 0xFC, blue: 0xF0))
        XCTAssertEqual(spec.foreground, .init(red: 0x10, green: 0x0F, blue: 0x0F))
        XCTAssertEqual(spec.palette[3], .init(red: 0xAD, green: 0x83, blue: 0x01))
        // Unknown keys, out-of-range slots, and malformed values are skipped,
        // leaving the untouched slots empty.
        XCTAssertNil(spec.palette[4])
        XCTAssertNil(spec.cursorColor)
        XCTAssertNil(spec.selectionBackground)
        XCTAssertEqual(spec.palette.compactMap { $0 }.count, 1)
    }
}
