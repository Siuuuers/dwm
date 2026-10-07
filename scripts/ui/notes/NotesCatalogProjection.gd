extends RefCounted
## Read-only projection of committed run counts and explicitly registered notes.

const PurchaseRules = preload("res://scripts/domain/shop/RunNotePurchaseRules.gd")


static func project(counts: Variant, catalogue: Variant) -> Dictionary:
	var validation: Dictionary = PurchaseRules.validate_counts_and_catalogue(counts, catalogue)
	if not validation["ok"]:
		return validation
	var validated: Dictionary = validation["value"]
	var validated_counts: Dictionary = validated["shop_purchase_counts"]
	var registered_catalogue: Dictionary = validated["catalogue"]
	var groups: Array = []
	for item_id: String in PurchaseRules.ITEM_IDS:
		var count: int = validated_counts.get(item_id, 0)
		var registered_notes: Array = registered_catalogue[item_id]
		groups.append({
			"item_id": item_id,
			"count": count,
			"notes": registered_notes.slice(0, count).duplicate(true),
		})
	return {"ok": true, "code": "", "value": {"groups": groups}}
