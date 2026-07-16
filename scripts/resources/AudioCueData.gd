class_name AudioCueData
extends Resource
# Descriptive audio-cue resource. Authoritative fields in CONTENT.md §10.
# Data-only: must not execute logic.
@export var id: String = ""
@export var display_name: String = ""
@export var localization_key: String = ""
@export var path: String = ""
@export var bus: String = "SFX"
@export var category: String = "sfx"
@export var default_volume_db: float = 0.0
@export var description_key: String = ""
