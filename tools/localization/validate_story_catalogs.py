"""Check translated display data against the actual English DTL/choice source."""
import json
from pathlib import Path
import re
import unicodedata

ROOT = Path(__file__).resolve().parents[2]


def unique_object(pairs):
    value = {}
    for key, item in pairs:
        assert key not in value, f"Duplicate JSON key: {key}"
        value[key] = item
    return value


def read(path):
    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique_object)


source = {}
for path in sorted((ROOT / "dialogic/timelines/authored_week").glob("Day*.dtl")):
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.fullmatch(r"\\(.*) #id:(\S+)", line)
        if match:
            assert match[2] not in source
            source[match[2]] = match[1].replace(r"\:", ":")
assert len(source) == 1666, "Expected all seven authored days"


def choices(value):
    if isinstance(value, dict):
        if "options" in value:
            for option in value["options"]:
                source[f"choice.{value['opportunity_id']}.{option['choice_id']}"] = option["text"]
        for child in value.values():
            choices(child)
    elif isinstance(value, list):
        for child in value:
            choices(child)


choices(read(ROOT / "data/manifests/authored_week_source.json"))
assert len(source) == 1682
assert read(ROOT / "localization/story/en.json") == source, "English source drift"
for locale in ("zh_HK", "zh_CN", "ja", "ko"):
    translated = read(ROOT / f"localization/story/{locale}.json")
    assert translated.keys() == source.keys(), f"{locale}: missing or extra IDs"
    for key, text in translated.items():
        assert isinstance(text, str) and text.strip(), f"{locale}/{key}: empty text"
        assert unicodedata.normalize("NFC", text) == text, f"{locale}/{key}: non-NFC"
        assert not any(token in text for token in ("[", "{", "<")), f"{locale}/{key}: executable markup"
        for name in ("Priscilla", "Lavinia", "Sylvia"):
            assert text.count(name) == source[key].count(name), f"{locale}/{key}: changed name {name}"
    print(f"{locale}: 1,666 captions + 16 choices; keys, names, NFC and plain text verified")
