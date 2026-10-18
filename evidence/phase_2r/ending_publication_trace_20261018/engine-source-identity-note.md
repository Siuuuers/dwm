# Engine source identity qualification

Observed 19 October 2026 Hong Kong time (18 October UTC), during the receipt/ending investigation. This note concerns attribution to engine internals; it does not change the project, engine version, or tested executable.

The retained comparison executable reports `4.6.3.stable.official.7d41c59c4`. The [official Godot 4.6.3 release announcement](https://godotengine.org/article/maintenance-release-godot-4-6-3/) and [source release page](https://github.com/godotengine/godot/releases/tag/4.6.3-stable) identify `35e80b3a8`. The tag API resolves that to `35e80b3a8822a9df9be390814b62f44c0a9c69e8`. The coordinator reopened the announcement/release page independently.

[Issue120038](https://github.com/godotengine/godot/issues/120038) includes a reporter's matching banner and full revision `7d41c59c457bd5a245092b4e7eb2d833e3b3f8c3`. It corroborates an observed banner, not a maintainer-authenticated mapping to the release source. It is unrelated evidence of source identity; its reported macOS crash is not attributed to this project's Windows ending failure.

An independent read-only agent observed the following official GitHub API results:

- Short/full commit metadata for the banner revision: HTTP422, no commit found.
- Full Git commit object: HTTP404.
- Git tree at that revision: HTTP422.
- Comparison from release35e80b3a to the full banner revision: HTTP404.
- Official-organization commit search for the short revision: empty.

However, version.py and four relevant source-file requests at the full banner revision did return content. Therefore do not claim that all corresponding source is unavailable. The four previously audited file lookups reported the same blob IDs at both revision-qualified paths:

| Source path | Reported Git blob |
| --- | --- |
| scene/main/node.cpp | d723df77185ac685c97fb42f63b90b01f874063f |
| scene/main/scene_tree.cpp | 78e2181da18e6792ba51b318365fd4ee5f08a27d |
| scene/main/canvas_item.cpp | ffbe9dc21d37898d1eeff165543e70193fa0bdfe |
| drivers/accesskit/accessibility_driver_accesskit.cpp | f0dfc5e056c4cf6341cda93763e294b7e5fe3df6 |

These are source-file retrieval observations. They do not authenticate a complete source tree, ancestry, or correspondence to the executed binary. Preserve both the successful file lookups and failed commit/tree lookups. Exact build-to-source identity remains unverified.

The passive project trace records actual setter arguments, existing node identities and parent order, visibility, withdrawal and stored Next state. Those observations remain useful without an engine-internal cause claim. No engine binary/source archive was downloaded for this side audit; no Godot or PowerShell ran locally.

Relevant primary endpoints for a later source-identity follow-up:

- https://api.github.com/repos/godotengine/godot/git/ref/tags/4.6.3-stable
- https://api.github.com/repos/godotengine/godot/commits/7d41c59c4
- https://api.github.com/repos/godotengine/godot/git/commits/7d41c59c457bd5a245092b4e7eb2d833e3b3f8c3
- https://api.github.com/repos/godotengine/godot/git/trees/7d41c59c457bd5a245092b4e7eb2d833e3b3f8c3
- https://api.github.com/repos/godotengine/godot/compare/35e80b3a8822a9df9be390814b62f44c0a9c69e8...7d41c59c457bd5a245092b4e7eb2d833e3b3f8c3
