# 3. DTL syntax reference
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