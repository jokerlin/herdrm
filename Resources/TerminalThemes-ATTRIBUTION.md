# TerminalThemes attribution

The theme files in `TerminalThemes/` are the terminal color schemes bundled with
[Ghostty](https://github.com/ghostty-org/ghostty), generated from
[iTerm2-Color-Schemes](https://github.com/mbadolato/iTerm2-Color-Schemes)
(MIT License, © Mark Badolato and contributors). File format is Ghostty's
theme format: `key = value` lines with `palette = N=#rrggbb` ANSI entries.

To refresh the catalog, copy from a current Ghostty install:

```sh
cp "/Applications/Ghostty.app/Contents/Resources/ghostty/themes/"* Resources/TerminalThemes/
```
