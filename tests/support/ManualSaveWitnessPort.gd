extends "res://autoload/SaveManager.gd"
## Frozen full-result control for the compact production witness comparison.
## The candidate always calls the actual production helper; it is not copied here.

const BASELINE_SOURCE_REF := "9a4c63f05d13bc2960aae4fa6c58db9911916f86"
const BASELINE_HELPER_SHA256 := "316ff83a7f767daefb05e9afd63c5d1557e05526a2282306b0728c36b2a68946"

var write_variant := "production"

func _write_document_text_validator(text: String, validated_texts: Dictionary) -> Dictionary:
	if write_variant == "baseline":
		# Keep the full-result body exact to BASELINE_SOURCE_REF. The performance
		# driver verifies both its Git provenance and the sole production change.
		if validated_texts.has(text):
			return (validated_texts[text] as Dictionary).duplicate(true)
		var baseline_result := _document_text_validator(text)
		if baseline_result.get("ok", false):
			validated_texts[text] = baseline_result.duplicate(true)
		return baseline_result
	return super._write_document_text_validator(text, validated_texts)
