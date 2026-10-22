"""Authored Days 4–7 graph, with explicit history-dependent echo destinations.

Source line ranges are inclusive in the immutable imported manuscripts. Altered
captions retain their source anchor and carry an adaptation explanation. No live
flags are introduced: Day1/Day2 effects use the existing Challenge receipt echo;
Day7's local clipboard history is carried by distinct authored scene paths.
"""

OUTCOMES = ("never_started", "unfinished", "won", "lost", "perfect")
ENDING = "ending.alone.normal"
ADAPTATIONS = [
    "Day4 lines26/345: neutral flower description avoids asserting Day3 Lavinia's damaged bouquet after the Sylvia fork or another outcome.",
    "Day5 lines126–162: cheek-injury exchange is reachable only through Day2 lost; other outcomes echo directly to the shared folder scene.",
    "Day5 Perfect: split line222 around the recognition passage so page-turning precedes finishing the folder.",
    "Day5 unfinished: append the existing invitation from line190 after departure preparation, ensuring the Day6 invitation reference has an authored source.",
    "Day5 D-Note/D-Arch: continue with lines279–281 (work completion and invitation), omitting D-Default's incompatible opening actions.",
    "Day6 Yes: add a minimal notebook handover before the shared scene; Day6 unfinished references the notebook on her lap rather than an unshown move to the table.",
    "Day6 unfinished: replace the separate-chairs closing with an equivalent distance-neutral line because the earlier Yes already moved Priscilla beside the sofa.",
    "Day7: clipboard Yes/default use distinct challenge scene paths; no persistent flag or duplicate history owner.",
    "Day7 lost: echo Day1's Challenge receipt; include the Monday recording confession only for Day1 lost, and clipboard confession only for clipboard Yes.",
    "Day7 lost/default clipboard: Board option and destination describe the untouched sheet rather than inventing a crossed-out entry.",
    "Perfect passages expand their specified C continuation; editorial cut/selection instructions are not audience text.",
]


def _next(target):
    return {"kind": "next", "target": target}


def _targets(prefix):
    return dict(zip(OUTCOMES, (prefix + suffix for suffix in ("A", "B", "C", "D", "E"))))


def _echo(challenge_id, ordinary, lost):
    return {"kind": "recall", "challenge_id": challenge_id,
            "targets": {outcome: lost if outcome == "lost" else ordinary for outcome in OUTCOMES}}


def _options(opportunity_id, default, choices):
    return {"kind": "options", "opportunity_id": opportunity_id, "default": default,
            "options": [{"choice_id": key, "text": text, "target": target}
                        for key, text, target in choices]}


def _adapt(day, line, text, why):
    return {"text": text, "source_day": day, "source_line": line, "adaptation": why}


def _replace(blocks, line, text, why):
    """Replacement must match one source paragraph; fail rather than silently drift."""
    result = [dict(block) for block in blocks]
    matches = [block for block in result if block["source_line"] == line]
    if len(matches) != 1:
        raise ValueError(f"Expected one paragraph at line {line}; got {len(matches)}")
    matches[0]["text"] = text
    matches[0]["adaptation"] = why
    return result


def build(api):
    _day4(api)
    _day5(api)
    _day6(api)
    _day7(api)


def _day4(api):
    opening = _replace(api.read(4, 8, 146), 26,
        "On the narrow wooden ledge beside the bench stands a low glass jar of water. White flowers sit inside it, their heads just above the rim.",
        "Neutral intake: neither the Sylvia fork nor every Lavinia outcome contains the damaged bouquet.")
    api.scene("Day4", 4, opening, {"kind": "thought", "opportunity_id": "Day4.pastille",
        "yes": "Day4.pastille.yes", "default": "Day4.pastille.default"})
    api.scene("Day4.pastille.yes", 4, api.read(4, 152, 170), _next("Day4.impulse"))
    api.scene("Day4.pastille.default", 4, api.read(4, 174, 180), _next("Day4.impulse"))
    api.scene("Day4.impulse", 4, api.read(4, 184, 208),
        {"kind": "challenge", "challenge_id": "Day4.challenge", "targets": _targets("Day4.")})
    for suffix, start, end in (("A", 214, 228), ("B", 232, 244), ("C", 248, 262)):
        api.scene("Day4." + suffix, 4, api.read(4, start, end), _next("Day5"))
    api.scene("Day4.D", 4, api.read(4, 266, 300), _options("Day4.aftermath", "Day4.D.default", [
        ("mirror", "Make her look in the mirror at whose hand is on her waist now.", "Day4.D.mirror"),
        ("friday", "Tell her I'll be here before the other door opens on Friday.", "Day4.D.friday"),
    ]))
    for suffix, start, end in (("default", 309, 315), ("mirror", 319, 327), ("friday", 331, 337)):
        api.scene("Day4.D." + suffix, 4, api.read(4, start, end), _next("Day5"))
    recognition = _replace(api.read(4, 345, 357), 345,
        "In the mirror: the bench, the barre, the white flowers in the glass jar, and the narrow strip of corridor pane behind the door.",
        "Matches the neutral flower intake without asserting a prior lost outcome.")
    api.scene("Day4.E", 4, api.read(4, 248, 262) + recognition, _next("Day5"))


def _day5(api):
    api.scene("Day5", 5, api.read(5, 8, 124),
        _echo("Day2.challenge", "Day5.impulse", "Day5.cheek"))
    api.scene("Day5.cheek", 5, api.read(5, 126, 132),
        {"kind": "thought", "opportunity_id": "Day5.cheek",
         "yes": "Day5.cheek.yes", "default": "Day5.cheek.default"})
    api.scene("Day5.cheek.yes", 5, api.read(5, 138, 152), _next("Day5.impulse"))
    api.scene("Day5.cheek.default", 5, api.read(5, 156, 162), _next("Day5.impulse"))
    api.scene("Day5.impulse", 5, api.read(5, 166, 174),
        {"kind": "challenge", "challenge_id": "Day5.challenge", "targets": _targets("Day5.")})
    api.scene("Day5.A", 5, api.read(5, 180, 190), _next("Day6"))
    invitation = api.read(5, 190, 190)
    for block in invitation:
        block["adaptation"] = "Existing invitation also closes the unfinished branch, before the next day's visit."
    api.scene("Day5.B", 5, api.read(5, 194, 204) + invitation, _next("Day6"))
    api.scene("Day5.C", 5, api.read(5, 208, 224), _next("Day6"))
    api.scene("Day5.D", 5, api.read(5, 228, 266), _options("Day5.aftermath", "Day5.D.default", [
        ("note", "Fish the yellow slip out of the bin and tear it in half.", "Day5.D.note"),
        ("arch", "Reach under the table and close my hand around her damp stockinged arch.", "Day5.D.arch"),
    ]))
    api.scene("Day5.D.default", 5, api.read(5, 275, 281), _next("Day6"))
    for suffix, start, end in (("note", 285, 289), ("arch", 293, 297)):
        completion = api.read(5, 279, 281)
        for block in completion:
            block["adaptation"] = "Shared work-completion and invitation after this selected aftermath."
        api.scene("Day5.D." + suffix, 5, api.read(5, start, end) + completion, _next("Day6"))
    # The source puts an ongoing page-turn after C's completion. Split its exact
    # paragraph at the sentence boundary and insert recognition while work is open.
    opening = _adapt(5, 222,
        "She pulls the second folder across the two-inch gap between the chairs and opens it across her knees.",
        "First sentence of source paragraph; recognition occurs before work is finished.")
    completion = _adapt(5, 222, "When we finish, she closes the folder.",
        "Second sentence of source paragraph, after Perfect recognition.")
    api.scene("Day5.E", 5, api.read(5, 208, 220) + [opening] + api.read(5, 305, 317)
        + [completion] + api.read(5, 224, 224), _next("Day6"))


def _day6(api):
    api.scene("Day6", 6, api.read(6, 12, 247),
        {"kind": "thought", "opportunity_id": "Day6.rehearsal",
         "yes": "Day6.rehearsal.yes", "default": "Day6.rehearsal.default"})
    handover = _adapt(6, 265,
        "When her hand loosens around my wrist, I give the closed notebook back to her.",
        "Minimal prop handover so both options join with the notebook on Lavinia's lap.")
    api.scene("Day6.rehearsal.yes", 6, api.read(6, 253, 265) + [handover], _next("Day6.impulse"))
    api.scene("Day6.rehearsal.default", 6, api.read(6, 269, 279), _next("Day6.impulse"))
    api.scene("Day6.impulse", 6, api.read(6, 283, 295),
        {"kind": "challenge", "challenge_id": "Day6.challenge", "targets": _targets("Day6.")})
    api.scene("Day6.A", 6, api.read(6, 301, 315), _next("Day7"))
    unfinished = _replace(api.read(6, 319, 331), 319,
        "My fingers touch the linen corner of the notebook on her lap, then draw back.",
        "Preserves the shared scene's actual notebook position.")
    unfinished = _replace(unfinished, 331,
        "Neither of us moves closer; the stronger tea cools in the two porcelain cups while the corridor tape runs on.",
        "Distance-neutral join: the prior Yes already brought Priscilla beside the sofa.")
    api.scene("Day6.B", 6, unfinished, _next("Day7"))
    api.scene("Day6.C", 6, api.read(6, 335, 349), _next("Day7"))
    api.scene("Day6.D", 6, api.read(6, 355, 377), _options("Day6.aftermath", "Day6.D.default", [
        ("word", "Make her say the crossed-out word she wrote first on the page.", "Day6.D.word"),
        ("dark", "Reach over and switch off the television so the room goes dark.", "Day6.D.dark"),
    ]))
    for suffix, start, end in (("default", 386, 392), ("word", 398, 400), ("dark", 406, 408)):
        api.scene("Day6.D." + suffix, 6, api.read(6, start, end), _next("Day7"))
    api.scene("Day6.E", 6, api.read(6, 335, 349) + api.read(6, 418, 430), _next("Day7"))


def _day7(api):
    api.scene("Day7", 7, api.read(7, 15, 71),
        {"kind": "thought", "opportunity_id": "Day7.clipboard",
         "yes": "Day7.clipboard.yes", "default": "Day7.clipboard.default"})
    for crossed, start, end in ((True, 77, 91), (False, 95, 107)):
        branch = "crossed" if crossed else "untouched"
        prefix = "Day7." + branch
        api.scene("Day7.clipboard." + ("yes" if crossed else "default"), 7,
            api.read(7, start, end), _next(prefix + ".impulse"))
        targets = _targets("Day7.")
        targets["lost"] = prefix + ".D"
        api.scene(prefix + ".impulse", 7, api.read(7, 111, 117),
            {"kind": "challenge", "challenge_id": prefix + ".challenge", "targets": targets})
        api.scene(prefix + ".D", 7, api.read(7, 183, 195),
            _echo("Day1.challenge", prefix + ".D.no_recording", prefix + ".D.recording"))
        for recorded in (True, False):
            variant = prefix + ".D." + ("recording" if recorded else "no_recording")
            disclosure = []
            if recorded or crossed:
                disclosure += api.read(7, 197, 197)
                speech = []
                if recorded:
                    speech.append("When you asked for an answer on Monday, I recorded Sylvia reading a line out of her novel and sent it to your phone so you wouldn't hear how badly I wanted you back.")
                if crossed:
                    speech.append(("And two" if recorded else "Two") + " minutes ago I crossed your second piece off the stage manager's board behind your back.")
                disclosure.append(_adapt(7, 199,
                    '“No,” I whisper, sliding my right hand from her gold bracelet to lace tightly between her fingers and pressing our joined hands flat against the door panel beside her hip. “'
                    + " ".join(speech) + '”',
                    "Only confesses acts actually selected in Day1 and the clipboard branch."))
            # If neither act occurred, omit the extra-disclosure exchange rather
            # than replacing it with an invented confession or rewriting history.
            api.scene(variant, 7, disclosure + api.read(7, 201, 207),
                _options(variant + ".aftermath", "Day7.D.default", [
                    ("pocket", "Put Sylvia's lower-gate card into Lavinia's coat pocket myself and tell her she won't be using it.", "Day7.D.pocket"),
                    ("board", "Make her look at the " + ("crossed-out" if crossed else "untouched") + " clipboard on our way out the door.", prefix + ".D.board"),
                ]))
        board = api.read(7, 234, 236)
        if not crossed:
            board = [_adapt(7, 234,
                "After I kneel to tie her street shoes and draw her coat over her shoulders, I pause for half a second beside the inner door where Second Variation remains untouched on the hanging clipboard.",
                "Clipboard default left the row untouched; no crossed-out entry is fabricated."),
                _adapt(7, 236,
                "Lavinia looks at the unchanged row on the board, then up at my mouth, her fingers tightening around mine as we turn toward the rear courtyard door.",
                "Matches the unchanged clipboard selected earlier in this path.")]
        api.scene(prefix + ".D.board", 7, board, _next(ENDING))
    for suffix, start, end in (("A", 123, 137), ("B", 143, 157), ("C", 163, 177)):
        api.scene("Day7." + suffix, 7, api.read(7, start, end), _next(ENDING))
    api.scene("Day7.D.default", 7, api.read(7, 216, 218), _next(ENDING))
    api.scene("Day7.D.pocket", 7, api.read(7, 224, 228), _next(ENDING))
    api.scene("Day7.E", 7, api.read(7, 163, 177) + api.read(7, 246, 256), _next(ENDING))
    api.scene(ENDING, 7, api.read(7, 262, 304), {"kind": "end"}, role="ending")
