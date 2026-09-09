# Minesweeper 3BV: primary-source research note

Date: 2026-08-11  
Status: non-authoritative external research. This note does not amend game design, implementation requirements, plans, or Beads.

## Finding

Stephan Bechtel's first-party explanation defines **3BV** as *Bechtel's Board Benchmark Value* and attributes the name to Benny Benjamin. Its scope is specifically optimal **non-flagging** play. Bechtel's counting rule is:

- one unit for each possible opening; and
- one unit for each numbered safe cell that is not on the border of any opening.

Those claims come directly from [Bechtel's original 3BV page](http://www.stephan-bechtel.de/3bv.htm). His accompanying [3BV = 13 illustration](http://www.stephan-bechtel.de/pix/3bv-counting.png) is an example, not a machine-readable specification.

Under conventional square-grid Minesweeper reveal behavior, the following is an equivalent formalization of that rule for a fixed mine layout:

1. Calculate each safe cell's adjacent-mine number using its eight-neighbourhood.
2. Let `Z` be the safe cells numbered zero.
3. Partition `Z` into connected components using eight-neighbour adjacency. Each component is one **opening** and contributes `1`.
4. Mark every zero cell and every safe numbered cell adjacent to at least one zero cell as covered by an opening.
5. Each remaining safe numbered cell contributes `1` individually.

Therefore:

```text
3BV = number of connected zero-cell components
    + number of safe numbered cells adjacent to no zero cell
```

This formal algorithm is an inference from Bechtel's two-part counting rule and ordinary flood-reveal semantics; Bechtel's page itself does not publish pseudocode.

## Components, "islands," and standalone numbers

- The relevant components are components of **zero cells**, not components of all safe cells and not components formed after adding their numbered borders.
- A numbered border cell can be revealed by clicking a zero in its opening, so it contributes no separate unit.
- A numbered cell outside every opening contributes one unit even when it touches other such numbered cells. “Isolated” is therefore best read as **isolated from zero openings**, not geometrically isolated from all safe neighbours.
- Two distinct zero components must remain two openings even if their revealed numbered borders overlap. Joining components through border numbers would undercount.
- If a board has no zero cells, every safe cell is numbered and contributes one. If all safe cells form one zero component, the board's 3BV is one.

The original page uses **opening**, not **island**. Any implementation or document using “island” should define it explicitly as an eight-connected zero-cell component to avoid the alternative meanings above.

## What 3BV does not count

- **Flags are not part of 3BV.** Bechtel explicitly scopes the metric to non-flagging play, and his rule counts only opening reveals and standalone numbered-cell reveals.
- **Actual player input is not part of 3BV.** It is a property of the completed mine layout and its reveal topology, not a replay counter. Navigation, rejected input, saves, focus changes, and the player's chosen sequence cannot alter it.
- **Reveal, flag, unflag, and chord commands must not be folded into the 3BV calculation.** A game may separately record them as `click_count` or actions, but that is a different metric.
- **Chording is outside the non-flagging baseline.** Consequently, 3BV is not a universal lower bound on commands for control schemes that allow flags and chords. A chord can reveal several cells represented by multiple 3BV units; the flags and chord themselves belong to the separate actual-action count.

Curtis Bright's first-party documentation for his early Minesweeper Clone corroborates this separation: it advertises left/middle/right click recording independently from 3BV and describes 3BV as the minimum for clearing without flagging. See [Bright's Minesweeper project page](https://www.curtisbright.com/msx/v0/minesweeper.html). This is implementation-owner documentation, not the originating definition.

For this project, a ratio such as `three_bv / click_count` therefore combines two deliberately different quantities. Whether flags, unflags, and chords count once each is a **project input-accounting rule**, not part of 3BV. A value above 100% can be coherent when the chosen command grammar and chording allow the terminal board to use fewer counted commands than its no-flag reveal baseline.

## Determinism boundary

3BV can be computed only after a mine layout exists. On a first-click-safe or first-click-zero generator, the uncommitted candidate has no final 3BV until mine placement is fixed. Once fixed, repeated calculation should depend only on board dimensions and mine positions; replay history and flags should be unnecessary inputs.

## Source trust and limitations

| Source | Trust for this question | Limitation |
|---|---|---|
| [Stephan Bechtel, “3BV - What does that mean and what can I use it for?”](http://www.stephan-bechtel.de/3bv.htm) | Highest available: first-person definition by the metric's namesake, including naming attribution and the two-part count | Short and informal; no publication date in the body, formal adjacency definition, pseudocode, test vectors, or source code |
| [Bechtel's 3BV = 13 image](http://www.stephan-bechtel.de/pix/3bv-counting.png) | First-party worked illustration | Visual only and not sufficient as an executable oracle |
| [Curtis Bright's Minesweeper Clone page](https://www.curtisbright.com/msx/v0/minesweeper.html) | First-party documentation for a contemporaneous implementation that distinguishes actual clicks from 3BV | Not authored by Bechtel, Benjamin, or Roll; the downloadable historical package contains an executable and readme but no calculation source |

No accessible source code or formal specification from Bechtel, Benny Benjamin, or Yoni Roll was located in this pass. Bechtel's page names Benjamin and Roll's Minesweeper Board Reader, but its historical download/community route is no longer a usable source-code reference. Accordingly, the component algorithm above should be treated as a precise formalization of the available original prose—not a claim of byte-for-byte compatibility with every historical 3BV tool.

