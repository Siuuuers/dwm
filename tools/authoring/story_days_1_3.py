"""Source-mapped scene graph for the supplied Day 1–3 manuscripts.

Runtime declarations belong to the shared authoring API. Ranges below refer to
the byte-preserved manuscripts in story/auditions/playable-week-20261023.

Approved adaptation: move Day1's "A voice message" and Day2's impulse after
their remaining shared sentences so the cue is the current Challenge caption.
Day2 now defaults to Benchmark, with Stay/Cruel as separate selectable thoughts.
Their two button prompts are adaptation text; the branch prose is unchanged.
Both Day3 routes temporarily converge on Day4, as directed by the author.
"""


def _next(target):
    return {"kind": "next", "target": target}


def _block(day, line, text):
    return {"text": text, "source_day": day, "source_line": line}


def _call_opening(api, result):
    # The source uses slash-separated editorial call alternatives on single
    # lines. Only the selected dialogue is displayed, one utterance per caption.
    openings = {
        "A": (600, [
            "“Finished?” Lavinia asks.",
            "“Would I call if I hadn't?”",
            "“I thought you were telling me to leave you alone.”",
            "“I wasn't.”", "“Good.”"]),
        "B": (601, [
            "“Later,” Lavinia says.", "“I said I'd answer.”", "“You did.”",
            "“It was a good afternoon.”", "“That took you a while.”",
            "“I wanted to call.”", "“All right. Talk to me.”"]),
        "C": (602, [
            "“You could have waited until tomorrow,” Lavinia says.",
            "“Would you rather I had?”",
            "“No.” The chair tilts back from the desk."]),
        "D": (603, ["“You're alone?” Lavinia asks.", "“Yes.”", "“Good.”"]),
    }
    line, texts = openings["C" if result == "E" else result]
    return api.read(1, 598, 598) + [_block(1, line, text) for text in texts]


def _desk_coda(result):
    # Remove navigation labels, retaining the exact prose and message wording.
    codas = {
        "A": (561, [
            "At my desk, I open the conversation. Good night. I add her name and send it. The lamp is still on when I put the phone down."]),
        "B": (562, [
            "The conversation is open at my desk. About what you asked. I leave the words there while I take off my watch. When I pick up the phone again, I remove them and close the conversation."]),
        "C": (563, [
            "At my desk, the phone lights.",
            "Lavinia, message: Home.",
            "Priscilla, message: Good night, Lavinia.",
            "I leave the conversation open while I turn off the lamp."]),
        "benchmark": (564, [
            "At my desk, the phone lights.",
            "Lavinia, message: Home.",
            "I open the conversation. Thank you for telling me. I read it, then remove it.",
            "Priscilla, message: Good night, Lavinia.",
            "The message goes through. I turn off the lamp and leave the phone face up."]),
    }
    line, texts = codas["C" if result == "E" else result]
    return [_block(2, line, text) for text in texts]


def _challenge(challenge_id, prefix):
    return {"kind": "challenge", "challenge_id": challenge_id, "targets": {
        "never_started": prefix + ".A", "unfinished": prefix + ".B",
        "won": prefix + ".C", "lost": prefix + ".D", "perfect": prefix + ".E"}}


def build(api):
    read = api.read
    scene = api.scene

    scene("Day1", 1, read(1, 20, 82), {
        "kind": "thought", "opportunity_id": "Day1.photo",
        "yes": "Day1.photo.yes", "default": "Day1.photo.default"})
    scene("Day1.photo.yes", 1, read(1, 86, 102), _next("Day1.reading"))
    scene("Day1.photo.default", 1, read(1, 106, 114), _next("Day1.reading"))
    # Cue is moved after the remaining common dialogue, not duplicated.
    scene("Day1.reading", 1,
          read(1, 118, 326) + read(1, 332, 342) + read(1, 330, 330),
          _challenge("Day1.challenge", "Day1.result"))
    day1 = {
        "A": read(1, 350, 404), "B": read(1, 408, 456),
        "C": read(1, 460, 514), "D": read(1, 518, 586),
        # Use the explicit phone-face-down anchor. The source's secondary
        # "Your part" anchor is stale and occurs only in A, never imported here.
        "E": read(1, 460, 478) + read(1, 592, 594) + read(1, 480, 514),
    }
    for result, blocks in day1.items():
        scene("Day1.result." + result, 1,
              blocks + _call_opening(api, result), _next("Day1.coda"))
    scene("Day1.coda", 1, read(1, 607, 703), _next("Day2"))

    scene("Day2", 2, read(2, 9, 81), {
        "kind": "thought", "opportunity_id": "Day2.food",
        "yes": "Day2.food.yes", "default": "Day2.food.default"})
    scene("Day2.food.yes", 2, read(2, 85, 101), _next("Day2.answer"))
    scene("Day2.food.default", 2, read(2, 105, 113), _next("Day2.answer"))
    # The one sensory sentence follows the cue in the manuscript. Move it
    # before the cue so the board opens on the final, meaningful impulse.
    scene("Day2.answer", 2,
          read(2, 117, 149) + read(2, 155, 155) + read(2, 153, 153),
          _challenge("Day2.challenge", "Day2.result"))
    day2 = {
        "A": read(2, 163, 221), "B": read(2, 225, 257),
        "C": read(2, 261, 335),
        "E": read(2, 261, 261) + read(2, 557, 557) + read(2, 263, 335),
    }
    for result, blocks in day2.items():
        scene("Day2.result." + result, 2,
              blocks + _desk_coda(result), _next("Day3"))
    scene("Day2.result.D", 2, read(2, 339, 435), {
        "kind": "options", "opportunity_id": "Day2.threshold",
        "options": [
            {"choice_id": "stay", "text": "Go back to the table and ask her to stay.",
             "target": "Day2.threshold.stay"},
            {"choice_id": "cruel", "text": "Ask her again while her hand is in my hair.",
             "target": "Day2.threshold.cruel"}],
        "default": "Day2.threshold.benchmark"})
    scene("Day2.threshold.stay", 2, read(2, 439, 471), _next("Day3"))
    scene("Day2.threshold.benchmark", 2,
          read(2, 475, 511) + _desk_coda("benchmark"), _next("Day3"))
    scene("Day2.threshold.cruel", 2, read(2, 515, 551), _next("Day3"))

    scene("Day3", 3, read(3, 8, 184), {
        "kind": "thought", "opportunity_id": "Day3.partner",
        "yes": "Day3.sylvia", "default": "Day3.lavinia"})
    scene("Day3.lavinia", 3, read(3, 190, 284),
          _challenge("Day3.lavinia.challenge", "Day3.lavinia.result"))
    scene("Day3.sylvia", 3, read(3, 424, 476),
          _challenge("Day3.sylvia.challenge", "Day3.sylvia.result"))
    lavinia = {
        "A": read(3, 288, 308), "B": read(3, 312, 328),
        "C": read(3, 332, 352), "D": read(3, 356, 402),
        "E": read(3, 332, 352) + read(3, 410, 420),
    }
    sylvia = {
        "A": read(3, 480, 500), "B": read(3, 504, 510),
        "C": read(3, 514, 538), "D": read(3, 558, 616),
        "E": read(3, 514, 538) + read(3, 546, 554),
    }
    for route, outcomes in [("lavinia", lavinia), ("sylvia", sylvia)]:
        for result, blocks in outcomes.items():
            scene("Day3." + route + ".result." + result, 3, blocks, _next("Day4"))
