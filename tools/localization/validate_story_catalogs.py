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
days = sorted((ROOT / "dialogic/timelines/authored_week").glob("Day*.dtl"))
assert {path.name for path in days} == {f"Day{day}.dtl" for day in range(1, 8)}, "Expected Day1.dtl through Day7.dtl"
for path in days:
    before = len(source)
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.fullmatch(r"\\(.*) #id:(\S+)", line)
        if match:
            assert match[2] not in source
            source[match[2]] = match[1].replace(r"\:", ":")
    assert len(source) > before, f"{path.name}: no authored captions"
caption_count = len(source)


def choices(value):
    if isinstance(value, dict):
        if "options" in value:
            for option in value["options"]:
                key = f"choice.{value['opportunity_id']}.{option['choice_id']}"
                assert key not in source, f"Duplicate choice ID: {key}"
                source[key] = option["text"]
        for child in value.values():
            choices(child)
    elif isinstance(value, list):
        for child in value:
            choices(child)


choices(read(ROOT / "data/manifests/authored_week_source.json"))
choice_count = len(source) - caption_count
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
    print(f"{locale}: {caption_count:,} captions + {choice_count:,} choices; keys, names, NFC and plain text verified")
