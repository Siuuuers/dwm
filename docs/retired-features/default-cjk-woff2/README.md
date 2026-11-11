# Default-size CJK WOFF2 representation

Replaced the four10px CJK WOFF2 files/imports with compressed Godot FontFile resources containing the same decoded OTF tables. Glyphs, metrics, names, language coverage and pixel rendering remain. Original bytes/hashes are recorded in sources.json and recoverable from the parent commit/pinned upstream archive. No font family, glyph or persisted setting was removed.

See `docs/agent/2026-11-12-settings-font-resources.md` for measurements, equivalence and isolated package checks.
