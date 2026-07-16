class_name BgmTrackData
extends Resource
# Descriptive BGM track resource. Authoritative fields in CONTENT.md §10.
# Data-only: must not execute logic.
@export var id: String = ""
@export var display_name: String = ""
@export var localization_key: String = ""
@export var path: String = ""
@export var category: String = "bgm"
@export var mood_tags: Array[String] = []
@export var loop: bool = true
@export var default_volume_db: float = 0.0
@export var fade_in_seconds: float = 1.0
@export var fade_out_seconds: float = 1.0
@export var priority: int = 0
@export var fallback_track_id: String = ""
@export var description_key: String = ""
