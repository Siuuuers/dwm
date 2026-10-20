# 3. DTL syntax reference

<!-- BEGIN STORY RELOCATION 2026-10-20 -->
> **Reading this record after relocation.** The complete record now lives in `story/`. Its approval, proposal, reopening and review labels keep their original scope. Read the [current Priscilla foundation](../09-priscilla-foundation-amendment.md) and [story home](../README.md) before applying older cast, viewpoint, calendar, Challenge or ending rules.
>
> [Exact source before this move](https://github.com/Siuuuers/dwm/blob/7813de047f5e69b24ea0a84d6857d683f2f0c290/dialogic%20fx.md). The body is retained with navigation rebased; relocation does not approve a scene, close an audit or authorize implementation. The retained examples are a legacy syntax reference, not the current cast or an approved current Challenge/label contract.
<!-- END STORY RELOCATION 2026-10-20 -->

Use Dialogic 2 timeline text syntax. Every timeline file must use the `.dtl` extension (Dialogic will not register it otherwise).

Shortcode event (parameters separated by spaces, double quotes):
```dtl
[background path="res://art/backgrounds/opening.png" fade="1.0"]
```

Text event:
```dtl
Narrator: A quiet room hums behind the screen.

Angela: Hello?

Angela (uneasy): I don't remember opening this.
```

Multiline text (end a line with `\`):
```dtl
Angela: This message continues \
onto the next line.
```

Character events:
```dtl
join Angela center [animation="Bounce In"]

update Angela (uneasy) left [animation="Tada" wait="true"]

leave Angela [animation="Bounce Out" length="0.3"]
```

Choice event (gameplay state must NOT be mutated directly from choice data):
```dtl
- Yes
	Angela: Yes.

- No
	Angela: No.
```

Condition event (Dialogic-local presentation only unless a safe bridge rule is documented):
```dtl
if {Player.Wisdom} > 3:
	Angela: I understand.
else:
	Angela: I do not understand yet.
```

Set variable (Dialogic-local only unless whitelisted):
```dtl
set {MyVariable} += 10
```

Comments: `# This is a comment.`

Labels and jumps:
```dtl
label Start

Angela: Start here.

jump End

label End
Angela: End here.
```

Return: `return`

Do/call restriction: forbid `do Autoload.method("argument")` for gameplay state. If a marker is unavoidable, only `do DialogicBridge.timeline_marker("safe_marker_id")` (whitelisted) is allowed.