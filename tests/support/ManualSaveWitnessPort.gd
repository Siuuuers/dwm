extends "res://autoload/SaveManager.gd"
## Diagnostic-only save owner shared by the witness benchmark and correctness tests.
## Production continues to return the full admitted document. Opt in explicitly.

var write_variant := "baseline"

func _write_document_text_validator(text: String, validated_texts: Dictionary) -> Dictionary:
	if write_variant == "baseline":
		# Keep the current production body exact. The legacy source-ablation runner
		# removes that parent method entirely, so a super reference would not parse.
		if validated_texts.has(text):
			return (validated_texts[text] as Dictionary).duplicate(true)
		var baseline_result := _document_text_validator(text)
		if baseline_result.get("ok", false):
			validated_texts[text] = baseline_result.duplicate(true)
		return baseline_result
	# Diagnostic-only ablation. Each write supplies its own exact-text memo; a
	# new text still undergoes the unchanged strict parser and full schema admission.
	if validated_texts.has(text):
		return {"ok": true, "code": &"ok", "value": {}}
	var result := _document_text_validator(text)
	# Preserve every refusal, including a malformed success that storage rejects.
	if not result.get("ok", false) or typeof(result.get("value")) != TYPE_DICTIONARY:
		return result
	validated_texts[text] = {"ok": true, "code": &"ok", "value": {}}
	return {"ok": true, "code": &"ok", "value": {}}
