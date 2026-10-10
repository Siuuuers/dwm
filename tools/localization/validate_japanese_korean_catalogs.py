"""Check draft UI completeness and Unicode before native layout captures."""

from collections import Counter
import json
from pathlib import Path
import re
import unicodedata


ROOT = Path(__file__).resolve().parents[2]
PLACEHOLDER = re.compile(r"\{([A-Za-z_][A-Za-z0-9_]*)\}")
source = json.loads((ROOT / "localization/ui/en.json").read_text(encoding="utf-8"))
source_messages = {item["id"]: item["text"] for item in source["messages"]}

for locale in ("ja", "ko"):
    catalog = json.loads((ROOT / f"localization/ui/{locale}.json").read_text(encoding="utf-8"))
    assert catalog["schema_version"] == 1 and catalog["locale"] == locale
    messages = {item["id"]: item["text"] for item in catalog["messages"]}
    assert len(messages) == len(catalog["messages"]), f"{locale}: duplicate message ID"
    assert messages.keys() == source_messages.keys(), f"{locale}: incomplete UI catalog"
    for key, text in messages.items():
        assert text.strip(), f"{locale}/{key}: empty translation"
        assert unicodedata.normalize("NFC", text) == text, f"{locale}/{key}: non-NFC text"
        assert Counter(PLACEHOLDER.findall(text)) == Counter(PLACEHOLDER.findall(source_messages[key])), \
            f"{locale}/{key}: changed placeholders"
        assert text.count("\n") == source_messages[key].count("\n"), f"{locale}/{key}: changed line breaks"
    print(f"{locale}: {len(messages)} UI messages; IDs, placeholders, line breaks and NFC verified.")
