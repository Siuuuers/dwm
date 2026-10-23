# DWM local patches

The bundled version is Dialogic 2.0-Alpha-19 (see `plugin.cfg`). Check this local
patch when updating the addon.

## Subsystem lifetime — dwm-380

`Core/DialogicGameHandler.gd` exposes the subsystem children installed during
`_ready()` through typed getters. Their old inferred-type initializers also
constructed unused nodes: one handler construction/free cycle leaked 24 nodes.

Use private script constants as explicit property types, without constructing a
second subsystem graph. `Core/DialogicUtil.gd` must generate the same declarations
when the editor reloads extensions. Custom subsystem names and anonymous script
types remain supported; installation, getters, and playback are unchanged.
The editor refreshes the saved script with `EditorFileSystem.update_file()`;
sending a `.gd` file through asset reimport produced an importer-not-found error.

Regression coverage: `tests/unit/test_dialogic_subsystem_lifecycle.gd` checks bare
construction, real tree ownership/cleanup, and executable editor-generated code.
`tools/dialogic/DialogicApiAudit.gd` follows the explicit property declarations.
Historical sealed API evidence remains historical; run the audit on current
source when collecting new evidence.

Godot supports preloaded script constants as types:
[Static typing in GDScript](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html).
