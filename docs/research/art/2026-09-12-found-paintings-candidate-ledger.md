---
id: research.found_paintings_candidate_ledger
kind: research_ledger
schema_version: 1
status: mixed_candidates_and_acquired
authority: "docs/design/2026-09-12-instrumentarium-drift-deck-all-input-and-week-tint-amendment.md#9-art-direction-found-paintings-r18"
related_authorities: ["story/01-core-story-bible.md","docs/research/audio/2026-08-14-music-candidate-ledger.md"]
beads: dwm-gb6
created_on: "2026-09-12"
retrieval_date: "2026-09-12"
acquisition_authorized: true
acquisition_authorization_scope: "seven_named_works_in_acquisition_record_only"
audience: private_spoiler_complete
---

# Found Paintings: candidate ledger

**Retrieval date:** 2026-09-12

**Scope:** existing public-domain, open-access museum paintings only. The original research pass authorized no acquisition. The later owner grant covered the seven named works in the acquisition record below; it does not extend to other candidates. This ledger records that grant and its provenance rather than issuing new permission.

## Result

Nineteen rows: four for Priscilla, five for Lavinia, four for Sylvia, six for backgrounds. The research pass recorded seventeen as **VERIFIED** and two (one AIC, one Met) as **UNVERIFIED**. Seven rows subsequently moved to `ACQUIRED` under the named owner grant; twelve remain `CANDIDATE`. No new rights verification was performed by the design-reconciliation pass.

## Method and status law

Only the holding museum's own work page supports a row. **VERIFIED**: that page was fetched this pass with a CC0 or explicit public-domain statement visible, quoted in under fifteen words. **UNVERIFIED**: the page could not be read; the reason is given. Nothing comes from a third party.

- **CANDIDATE:** found, checked as stated, not owner-reviewed.
- **APPROVED FOR ACQUISITION REVIEW:** owner-reviewed; the acquisition packet may compare it. Not download or integration approval.
- **ACQUIRED:** downloaded under the later explicit grant, with original file identity and credit recorded in `art_source/found_paintings/sources.json`. Seven rows hold this status; the artwork is uncommitted by owner choice.
- **REJECTED:** rights gate fails or Section 9 conflict.

The aperture crops inside a 1280x720 logical frame. Cleveland's API lists a print-size image per work, given as **Resolution**; no page states one.

## Priscilla

Sought: reading, writing, arranging, at a desk or window, observed from a slight distance.

### P1. Morisot, *Reading* — Cleveland Museum of Art 1950.89

- **Status:** `ACQUIRED` (owner authorization 2026-09-12; see art_source/found_paintings/sources.json) - was `CANDIDATE` — **VERIFIED** (page fetched).
- **Work:** Berthe Morisot, 1873, oil on fabric, 46 x 71.8 cm.
- **Rights:** "You can copy, modify, and distribute this work, all without asking permission."
- **URL:** https://www.clevelandart.org/art/1950.89
- **Resolution:** 3400 x 2174 px per API.
- **Fit:** a seated woman absorbed in a book, eyes down, seen from a few paces; horizontal, so a 16:9 aperture barely crops.
- **Risk:** outdoors, on grass, not a room; moderately reproduced.

### P2. Morisot, *The Artist's Sister at a Window* — National Gallery of Art 1970.17.47

- **Status:** `CANDIDATE` — **VERIFIED** (legacy `art-object-page` URL fetched; new `/artworks/` URL 403).
- **Work:** Berthe Morisot, 1869, oil on canvas, 54.8 x 46.3 cm.
- **Rights:** "This object's media is free and in the public domain."
- **URL:** https://www.nga.gov/collection/art-object-page.52191.html
- **Fit:** seated by a window, head lowered over a fan she is reading, interior light; a woman placed in a room she has arranged.
- **Risk:** near-portrait distance; vertical, so a landscape aperture keeps the window or the sitter, not both.

### P3. Vuillard, *Woman in a Striped Dress* — National Gallery of Art 1983.1.38

- **Status:** `CANDIDATE` — **VERIFIED** (legacy URL fetched on the third attempt).
- **Work:** Édouard Vuillard, 1895, oil on canvas, 65.7 x 58.7 cm.
- **Rights:** "This object's media is free and in the public domain."
- **URL:** https://www.nga.gov/collection/art-object-page.61388.html
- **Fit:** a woman arranging flowers in a dense interior, turned away from us; someone composing a room. Nabis, acceptable under Section 9.
- **Risk:** the pattern-heavy surface loses legibility at a hand-sized crop; the reds will be the warmest thing on screen by far.

### P4. Cassatt, *On a Balcony* — Art Institute of Chicago 1938.18

- **Status:** `CANDIDATE` — **UNVERIFIED.** Page 403 on every fetch; the museum's own API reports `is_public_domain: true`, a lead only.
- **Work:** Mary Cassatt, 1878–79, oil on canvas, 85.2 x 65.5 cm (per API).
- **Rights:** not seen on the page.
- **URL:** https://www.artic.edu/artworks/26650/on-a-balcony
- **Fit:** a woman reading a newspaper in a private garden, head down, unaware of us; reading as information-gathering rather than leisure.
- **Risk:** exterior; vertical; must be re-read in a browser before it can move.

## Lavinia

Sought: rehearsal rooms, stretching, resting, a foot, a shoe, a back; not the stage tutus.

### L1. Degas, *Frieze of Dancers* — Cleveland Museum of Art 1946.83

- **Status:** `ACQUIRED` (owner authorization 2026-09-12; see art_source/found_paintings/sources.json) - was `CANDIDATE` — **VERIFIED** (page fetched).
- **Work:** Edgar Degas, c. 1895, oil on fabric, 70 x 200.5 cm.
- **Rights:** "You can copy, modify, and distribute this work, all without asking permission."
- **URL:** https://www.clevelandart.org/art/1946.83
- **Resolution:** 3400 x 1187 px per API; a one-figure crop is about 850 px wide.
- **Fit:** one seated dancer four times, bent to her shoes, in an undefined room; the aperture can isolate one figure, one foot, one back.
- **Risk:** well known; the 1:2.9 frieze means any crop discards most of it, acceptable under 9.3 if chosen once.

### L2. Degas, *Before the Ballet* — National Gallery of Art 1942.9.19

- **Status:** `CANDIDATE` — **VERIFIED** (legacy URL fetched; new URL 403).
- **Work:** Edgar Degas, 1890/1892, oil on canvas, 40 x 88.9 cm.
- **Rights:** "This object's media is free and in the public domain."
- **URL:** https://www.nga.gov/collection/art-object-page.1158.html
- **Fit:** two dancers on a studio bench, stretching, others waiting behind; a rehearsal room, not a stage.
- **Risk:** pale blue costumes edge toward the tutu cliché; loosely painted faces vanish under a tight crop.

### L3. Degas, *The Dance Lesson* — National Gallery of Art 1995.47.6

- **Status:** `CANDIDATE` — **VERIFIED** (page fetched).
- **Work:** Edgar Degas, c. 1879, oil on canvas, 38 x 88 cm.
- **Rights:** "This object's media is free and in the public domain."
- **URL:** https://www.nga.gov/artworks/93045-dance-lesson
- **Fit:** a seated dancer in a jacket over her practice dress, resting on a chair with empty floor around her; a critic called the mood dismal, which is right.
- **Risk:** the first of the frieze series and often reproduced; the figure is small in the field, so a close crop is soft.

### L4. Degas, *Waiting (L'Attente)* — J. Paul Getty Museum 83.GG.219

- **Status:** `CANDIDATE` — **VERIFIED** (page fetched; per-work licence field in the page's structured data, as B1).
- **Work:** Edgar Degas, about 1882, pastel on paper, 48.3 x 61 cm.
- **Rights:** "available under CC0 through Getty's Open Content Program."
- **URL:** https://www.getty.edu/art/collection/object/103RF9
- **Fit:** a dancer bent double over her foot beside a woman in black with an umbrella; the foot, the load, and the person waiting beside it.
- **Risk:** jointly owned with the Norton Simon Museum, so the credit line needs both names; famous; pastel, so soft at crop.

### L5. Degas, *Dancers in the Rehearsal Room with a Double Bass* — Metropolitan Museum of Art 29.100.127

- **Status:** `CANDIDATE` — **UNVERIFIED.** Page 429 on every attempt; the Met's own API reports `isPublicDomain: true`, a lead only.
- **Work:** Edgar Degas, ca. 1882–85, oil on canvas, 39.1 x 89.5 cm (per API).
- **Rights:** not seen on the page.
- **URL:** https://www.metmuseum.org/art/collection/search/436138
- **Fit:** a seated dancer bent to tie her slipper beside a double bass in a rehearsal room; a frieze format that crops kindly.
- **Risk:** the instrument makes the composition a little knowing; re-fetch required.

Also seen, verified CC0 at Cleveland: *Dancers* 1916.1043 (pastel, three dancers stretching) and *Dancer at Rest* 1924.329 (charcoal). No eligible non-Degas rehearsal room was found.

## Sylvia

Sought: attending, pouring, holding, tending, waiting.

Five Met Cassatts (62.72, 22.16.22, 23.101, 22.16.17, 29.100.47) are **REJECTED**: the Met's own API reports `isPublicDomain: false` for each. Bonnard's *The Letter* (NGA 1963.10.86) is rejected for Priscilla: its page says the media is not available for download.

### S1. Bracquemond, *Le goûter* — Petit Palais, Paris Musées PPP636

- **Status:** `CANDIDATE` — **VERIFIED** (page fetched).
- **Work:** Marie Bracquemond, c. 1880, oil on canvas, 81.5 x 61.5 cm.
- **Rights:** "CC0 Paris Musées / Petit Palais"
- **URL:** https://www.parismuseescollections.paris.fr/fr/petit-palais/oeuvres/le-gouter
- **Fit:** the artist's sister at an afternoon-tea table, the service before her: a woman attending a table and waiting to be needed.
- **Risk:** vertical; the sitter is close and lit like a portrait, so "mid-task" depends on cropping to hands and cups.

### S2. Gonzalès, *Nanny and Child* — National Gallery of Art 2006.72.1

- **Status:** `CANDIDATE` — **VERIFIED** (legacy URL fetched; new URL 403).
- **Work:** Eva Gonzalès, 1877/1878, oil on canvas, 65 x 81.4 cm.
- **Rights:** "This object's media is free and in the public domain."
- **URL:** https://www.nga.gov/collection/art-object-page.135512.html
- **Fit:** a paid carer seated beside a small charge at a garden fence; care as a post, held, slightly distracted. Horizontal.
- **Risk:** the nanny looks out at us, closer to posed than wanted; the child must be cropped out or explained by nothing.

### S3. Cassatt, *After the Bath* — Cleveland Museum of Art 1920.379

- **Status:** `ACQUIRED` (owner authorization 2026-09-12; see art_source/found_paintings/sources.json) - was `CANDIDATE` — **VERIFIED** (page fetched).
- **Work:** Mary Cassatt, 1901, pastel, 66 x 100 cm.
- **Rights:** "You can copy, modify, and distribute this work, all without asking permission."
- **URL:** https://www.clevelandart.org/art/1920.379
- **Resolution:** 3400 x 2297 px per API.
- **Fit:** a woman holding a baby while an older child watches; the arms, the towel, the holding. Horizontal.
- **Risk:** reads maternal rather than volunteer, and Sylvia's canon has no child; two children make the crop hard.

### S4. Morisot, *The Mother and Sister of the Artist* — National Gallery of Art 1963.10.186

- **Status:** `CANDIDATE` — **VERIFIED** (page fetched).
- **Work:** Berthe Morisot, 1869/1870, oil on canvas, 101 x 81.8 cm.
- **Rights:** "This object's media is free and in the public domain."
- **URL:** https://www.nga.gov/artworks/46661-mother-and-sister-artist
- **Fit:** a young woman at the edge of a sofa beside an older one who reads; attending, waiting, in the room but not its centre; a sister beside a reader.
- **Risk:** Salon-scale and well reproduced; the white dress dominates any crop; keeping both women would pre-empt a two-painting scene.

Also seen, verified CC0 at Cleveland: Cassatt, *In the Omnibus* 1941.71, a nursemaid tending a child, but a colour print.

## Scene backgrounds

Rooms, not people; a figure is noted as a crop cost. The rehearsal room is served by L2, L3 and L5 above and not repeated.

### B1. University-like interior / corridor — Hammershøi, *Interior with an Easel, Bredgade 25* — Getty 2018.59

- **Status:** `ACQUIRED` (owner authorization 2026-09-12; see art_source/found_paintings/sources.json) - was `CANDIDATE` — **VERIFIED** (page fetched; per-work licence `creativecommons.org/publicdomain/zero/1.0/` in the page's structured data).
- **Work:** Vilhelm Hammershøi, 1912, oil on canvas, 78.7 x 70.5 cm.
- **Rights:** "available under CC0 through Getty's Open Content Program."
- **URL:** https://www.getty.edu/art/collection/object/109PF5
- **Fit:** an empty grey room, an easel, a half-open door, light on the floor: an institution's corridor without saying so.
- **Risk:** not impressionist and cool rather than warm, against 9.1's "one warm thing"; the easel names a studio.

### B2. Café at night — Vuillard, *At the Café* — Cleveland Museum of Art 1958.57

- **Status:** `ACQUIRED` (owner authorization 2026-09-12; see art_source/found_paintings/sources.json) - was `CANDIDATE` — **VERIFIED** (page fetched).
- **Work:** Édouard Vuillard, c. 1897–99, oil on board, 28.8 x 27.5 cm.
- **Rights:** "You can copy, modify, and distribute this work, all without asking permission."
- **URL:** https://www.clevelandart.org/art/1958.57
- **Resolution:** 3237 x 3400 px per API; the board is under 30 cm square, so a wide crop is soft.
- **Fit:** gaslight, a table, warm brown air; the bar where Priscilla first recognised Lavinia.
- **Risk:** two seated women occupy it; a room-only crop leaves very little board.

### B3. Café at night — Van Gogh, *Le café de nuit (The Night Café)* — Yale University Art Gallery 1961.18.34

- **Status:** `CANDIDATE` — **VERIFIED** (page fetched).
- **Work:** Vincent van Gogh, 1888, oil on canvas, 72.4 x 92.1 cm.
- **Rights:** "No Copyright - United States"
- **URL:** https://artgallery.yale.edu/collections/objects/12507
- **Fit:** an all-night café under gaslight; the billiard table and empty chairs carry the room and the figures sit small at the edges.
- **Risk:** among the most reproduced paintings there are, so it reads as a quotation; the statement is US-scoped, an owner call under 9.2.

### B4. Bar at night — Toulouse-Lautrec, *A Corner of the Moulin de la Galette* — National Gallery of Art 1963.10.67

- **Status:** `CANDIDATE` — **VERIFIED** (legacy URL fetched; new URL 403).
- **Work:** Henri de Toulouse-Lautrec, 1892, oil on cardboard, 100 x 89.2 cm.
- **Rights:** "This object's media is free and in the public domain."
- **URL:** https://www.nga.gov/collection/art-object-page.46542.html
- **Fit:** a dance-hall table at night, a rail and a floor behind; the crowd can be cropped to a corner of table and light.
- **Risk:** crowded and by a famous hand; outlined faces make any crop feel populated.

### B5. Window with weather — Monet, *The Red Kerchief* — Cleveland Museum of Art 1958.39

- **Status:** `ACQUIRED` (owner authorization 2026-09-12; see art_source/found_paintings/sources.json) - was `CANDIDATE` — **VERIFIED** (page fetched).
- **Work:** Claude Monet, c. 1868–73, oil on fabric, 99 x 79.8 cm.
- **Rights:** "You can copy, modify, and distribute this work, all without asking permission."
- **URL:** https://www.clevelandart.org/art/1958.39
- **Resolution:** 2732 x 3400 px per API.
- **Fit:** the interior side of French doors with snow beyond; a window seen from inside a warm room, weather as the subject.
- **Risk:** the red-caped figure outside is the painting's point and well known; a room-only crop is a band of curtain and glass.

### B6. Sickroom-adjacent / plain interior — Gwen John, *Interior* — Cleveland Museum of Art 1982.6

- **Status:** `ACQUIRED` (owner authorization 2026-09-12; see art_source/found_paintings/sources.json) - was `CANDIDATE` — **VERIFIED** (page fetched).
- **Work:** Gwen John, 1915, oil on canvas, 33 x 24.2 cm.
- **Rights:** "You can copy, modify, and distribute this work, all without asking permission."
- **URL:** https://www.clevelandart.org/art/1982.6
- **Resolution:** 2497 x 3400 px per API.
- **Fit:** a bare lodging room, a table with teapot and cups, nobody present; the nearest eligible thing to a ward's side room.
- **Risk:** small and vertical; 1915 and post-impressionist; muted, so it may not read as the warm visitor.

Also seen, not rowed: SMK *Den syge pige* (Ancher, KMS4002, a literal sickroom) and *Room in Strandgade with Sunlight on the Floor* (Hammershøi, KMS3696) sit behind a script shell and carry a public-domain mark, not CC0; Getty *The Convalescent* (Degas, 2002.57, CC0) is a figure; Met 60.174 (Pissarro, a winter boulevard from a window), Met 29.100.184 (*The Dancing Class*) and AIC 1981.77 (Vuillard, a window onto woods) are API-only leads.

## Summary of verification

| Section | Rows | Verified on page | Unverified |
|---|---|---|---|
| Priscilla | 4 | 3 | 1 (AIC 403) |
| Lavinia | 5 | 4 | 1 (Met 429) |
| Sylvia | 4 | 4 | 0 |
| Backgrounds | 6 | 6 | 0 |
| **Total** | **19** | **17** | **2** |

Access notes: Art Institute of Chicago pages 403 and Met pages 429 on every fetch; their APIs answered and are leads only. NGA, Cleveland, Paris Musées and Yale served statements in plain text; Getty pages ship a per-work licence field in script data; SMK Open is a script shell whose API answered. Smithsonian and Nationalmuseum Sweden were not searched; Rijksmuseum yielded nothing impressionist.

## Acquisition record (2026-09-12)

The owner authorized download on 2026-09-12 (third-round ruling: portraits are for vibe and testing; Angela's panel receives a room painting). Seven rows moved to `ACQUIRED`: P1, L1, S3, B1, B2, B5, B6. Each was verified on the museum's own record (Cleveland API `share_license_status: CC0`; Getty work-page structured data `license: creativecommons.org/publicdomain/zero/1.0/`). Originals, checksums, credit lines and the crop recipe are recorded in `art_source/found_paintings/sources.json`; game crops sit under `art/` at the catalog paths and `art/environments/paintings/`. Yale (B3, US-scoped statement), the jointly owned Getty *Waiting* (L4) and the two unverified rows (P4, L5) were not acquired. All other rows remain `CANDIDATE`.

## What this ledger does not do

This ledger issues no new acquisition or placement authorization. The original research fetched source records; the later acquisition record separately documents downloaded originals and installed crops. The three friends retain fixed portrait structure, treatment law 9.3 remains binding, and Angela's later-authorized desktop room painting does not add an Angela scene portrait.

## Next step

The seven acquired rows already have an acquisition record; do not ask for that authorization again. Review remaining candidates only if another art selection is requested. The two unverified rows require fresh source verification before any later acquisition decision. No additional download or art edit is part of `dwm-gb6` design review.
