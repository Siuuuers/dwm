"""Add identical observation-only UI timing to disposable cloud checkouts.

Inclusive method timings overlap; never sum nested spans as elapsed latency.
The native journey owns the input-to-drawing clock and enables attribution only
during its measured actions. No production instrumentation is committed.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re


METHODS = {
    "scripts/ui/witnessed/WitnessedCaptionLayer.gd": (
        "_on_text_started", "_refresh_reading_session", "_refresh_bilingual_caption",
        "_apply_story_fonts", "_layout_stack", "_measure_leaves", "_refresh_self_talk",
    ),
    "scripts/ui/witnessed/WitnessedSelfTalk.gd": (
        "configure", "project", "_shape", "_update_window",
    ),
    "scripts/ui/witnessed/WitnessedHistory.gd": ("present",),
    "autoload/DialogicBridge.gd": (
        "capture_current_bilingual_presentation", "capture_self_talk_presentation",
        "get_scene_caption_memory", "get_reading_history",
    ),
}


def instrument(source, owner, name):
    pattern = rf"^func {re.escape(name)}\(([^\n]*)\) -> (void|bool|Dictionary|float):\n"
    match = re.search(pattern, source, re.M)
    if match is None:
        raise ValueError(f"Missing synchronous observation seam: {owner}.{name}")
    header, arguments, returns = match.group(0), match.group(1), match.group(2)
    body = re.split(r"\nfunc ", source[match.end():], maxsplit=1)[0]
    if re.search(r"\bawait\b", body):
        raise ValueError(f"Async observation seam: {owner}.{name}")
    internal = "_reading_latency_body_" + name.lstrip("_")
    params = ", ".join(p.strip().split(":", 1)[0] for p in arguments.split(",") if p.strip())
    call = f"{internal}({params})"
    wrapper = header + '\tvar observation: Dictionary = Engine.get_meta(&"dwm_reading_latency", {})\n'
    wrapper += '\tvar observing: bool = observation.get("enabled", false)\n'
    wrapper += '\tvar began := Time.get_ticks_usec() if observing else 0\n'
    wrapper += f"\t{call}\n" if returns == "void" else f"\tvar result: {returns} = {call}\n"
    key = json.dumps(f"{owner}.{name}")
    wrapper += (
        '\tif observing:\n'
        '\t\tvar elapsed := Time.get_ticks_usec() - began\n'
        f'\t\tif not observation.methods.has({key}):\n'
        f'\t\t\tobservation.methods[{key}] = {{"calls": 0, "elapsed_us": 0, "max_us": 0}}\n'
        f'\t\tvar row: Dictionary = observation.methods[{key}]\n'
        '\t\trow.calls += 1\n'
        '\t\trow.elapsed_us += elapsed\n'
        '\t\trow.max_us = maxi(row.max_us, elapsed)\n'
    )
    if returns != "void":
        wrapper += "\treturn result\n"
    wrapper += "\n" + header.replace(f"func {name}(", f"func {internal}(", 1)
    return source[:match.start()] + wrapper + source[match.end():]


def prepare(root):
    receipt = {}
    for relative, methods in METHODS.items():
        path = root / relative
        original = path.read_bytes()
        source = original.decode("utf-8")
        for method in methods:
            source = instrument(source, path.stem, method)
        path.write_text(source, encoding="utf-8", newline="\n")
        receipt[relative] = {
            "before_sha256": hashlib.sha256(original).hexdigest(),
            "after_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "methods": methods,
        }
    output = root / ".godot/ci/reading-latency-instrumentation.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, type=Path)
    prepare(parser.parse_args().root)
