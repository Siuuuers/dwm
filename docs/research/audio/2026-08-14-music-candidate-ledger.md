# Acoustic Memory Atlas: music candidate ledger

**Retrieval date:** 2026-08-14

**Scope:** existing music only; no composition, generation, synthesis, download, or game integration performed

**Authority:** candidate research subordinate to `docs/superpowers/specs/2026-08-14-acoustic-memory-atlas-audio-design.md`
**Legal character:** conservative production research, not legal advice

## Result

This pass found **ten legally plausible, creator-first music candidates** for the five approved music roles: one preferred candidate and one fallback per role. None is approved for production yet because the brief prohibited downloading assets and a proper loudness, mono, comfort, repetition, seam, and scene-context audition therefore did not occur. Every surviving asset is marked **CONDITIONAL**: its source/licence evidence is adequate for an audition shortlist, but acquisition and listening tests remain mandatory.

The strongest present palette is deliberately small:

| Role ID | Preferred | Fallback | Current decision |
|---|---|---|---|
| `music.fragile_authorial` | PeriTune, *Piano_Sad2 (Piano Solo)* | PeriTune, *RainDrop* | Both `CONDITIONAL`; prefer a finite island, not a wallpaper loop |
| `music.social_diegetic_classical` | J. S. Bach / Kimiko Ishizaka, *Prelude No. 9 in E major, BWV 854* | PeriTune, *Hesitation* | Both `CONDITIONAL`; use only from a visible playback source |
| `music.rehearsal_playback_classical` | J. S. Bach / Kimiko Ishizaka, *Prelude No. 14 in F-sharp minor, BWV 859* | PeriTune, *Dark_Moon* | Both `CONDITIONAL`; starts and stops must follow rehearsal action |
| `music.post_ending_memory` | PeriTune, *Morning Snowfields* | PeriTune, *Pale_Warmth (instrumental variant)* | Both `CONDITIONAL`; a short entrance/tail only, never a new title theme |
| `music.dream_noir_suspension` | Tri-Tachyon, *Last 31* | PeriTune, *Suspense6* | Both `CONDITIONAL`; authored silence remains the safer default |

No Mixkit music was considered eligible. Mixkit's own music FAQ says its music is not permitted in video games ([Mixkit music FAQ](https://mixkit.co/free-stock-music/)).

## Method and status law

Only an exact track/file page, a creator or rights-holder page, and a direct licence page were allowed to support a surviving candidate. Search-result text alone was never treated as approval. No YouTube reupload was used as source or licence evidence.

Status meanings in this ledger:

- **CANDIDATE:** found but not fully audited.
- **APPROVED FOR ACQUISITION REVIEW:** research evidence is complete enough for the approval packet to compare the prospect for acquisition. It is not download or integration approval. There are no music entries at this status yet.
- **CONDITIONAL:** commercial/adaptation evidence is credible and the item deserves an audition, but an identified production gate remains.
- **LEGAL REVIEW:** the available facts are concrete but a territory or rights-layer question requires qualified review before use.
- **REJECTED:** the legal gate fails, evidence is unclear, or the asset conflicts with the approved artistic/comfort rules.

This document makes metadata-based curation proposals, not claims about unheard sonic details. Phrases such as “candidate for a restrained island” mean that the creator's own description, instrumentation, duration, and tags justify an audition. They do not substitute for listening.

## Shared licence and provenance findings

### PeriTune catalogue used here

PeriTune identifies itself as a personally operated **original-music** site and names the creator as **PeriTune / Sei Mutsuki**. The profile says Mutsuki has made music since 2002 and produces fantasy/scenic music. Its current terms state that tracks published in February 2026 or earlier remain under **CC BY 4.0**; they also expressly allow commercial, adult, and game use and allow tempo changes, effects, looping, and other modifications ([PeriTune terms and profile](https://peritune.com/about/)).

[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) allows commercial copying and adaptation but requires appropriate credit, a licence link, and an indication of changes. For this project, all PeriTune candidates will therefore be credited even though PeriTune's additional site permission says credit may be optional. Use the more conservative attribution rule.

Operational restrictions retained from the creator's current terms:

- do not register a track or derivative in Content ID;
- do not sell, re-upload, or redistribute the music as a stand-alone file;
- use it as background inside the game, not in a “music showcase” whose purpose is to expose the full track; and
- before a paid build ships, confirm that Godot packaging prevents casual extraction to the degree requested by the creator's current commercial-embedding language.

AI provenance is positive but not absolute: the first-party site calls the catalogue original music, identifies a long-standing human creator, and the selected track pages carry no AI/GenAI music label. That is credible human-authorship evidence. It is not an explicit track-by-track “no generative AI was used” declaration, so the acquisition record should preserve the pages and, if the project later requires absolute certification, seek written creator confirmation before integration. An AI-generated **page image** is not evidence that the audio is AI-generated; artwork and audio are separate assets.

### OpenGameArt candidate used here

The exact OpenGameArt page for *Last 31* identifies uploader **Tri-Tachyon** as a composer, musician, sound designer, and working sound engineer; it lists the exact `Last 31.mp3` file and applies **CC BY 4.0** ([exact asset page](https://opengameart.org/content/soundscape-last-31-cinematic-piano)). The 2018 creator-upload record and named music practice are credible human provenance; there is no AI/GenAI claim on the page. Attribution and change notice remain mandatory under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

### Open Well-Tempered Clavier recordings used here

The selected Bach files have a substantially stronger human-performance trail than ordinary stock music. The exact Wikimedia file pages identify **Johann Sebastian Bach** as composer, **Kimiko Ishizaka** as pianist, a 19 March 2015 recording date, and the exact Ogg master as **CC0 1.0**. The source album identifies the pianist and production team and states that the recording was released under CC0 ([creator album page](https://kimikoishizaka.bandcamp.com/album/bach-well-tempered-clavier-book-1)). [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) permits copying, modification, distribution, and performance, including commercially, without required attribution.

The Bandcamp licence field on the album resolves to CC BY 4.0 while the album description and exact Wikimedia file pages say CC0. These are two project-accepted grants with the same commercial/adaptation permissions, but different attribution duties. The project should conservatively **attribute as though CC BY 4.0 applies** and preserve both pages. The exact Prelude No. 9 file additionally carries Wikimedia VRT permission confirmation. Neither candidate becomes `APPROVED FOR ACQUISITION REVIEW` until the downloaded file identity and metadata match the exact Commons record.

For the four classical rights layers:

1. **Composition:** the file pages identify Bach's *Well-Tempered Clavier, Book I*; no modern composition is claimed.
2. **Edition/arrangement:** no arranger, completion author, or modern orchestration is identified on either exact file page. Intake must confirm that the chosen master is the unaltered solo-piano file and is not paired with a separately copyrighted score or arrangement.
3. **Performance:** Kimiko Ishizaka is expressly named as pianist.
4. **Recording/master:** the exact Ogg file is marked CC0; the creator album supplies the recording and production provenance.

This is a sufficiently clear path for a `CONDITIONAL` audition, not a blanket conclusion that other Bach recordings are free.

## Normalized candidate records

### `music.fragile_authorial` — Candidate: Piano_Sad2 (Piano Solo)

- **Status:** `CONDITIONAL` — named gaps: no acquisition-time checksum or formal mono, comfort, repetition, and scene-context audition.
- **Creator / recorder / performers:** PeriTune / Sei Mutsuki; separate performer and recorder credits are not supplied.
- **Source page:** [PeriTune exact track page](https://peritune.com/blog/2018/09/06/piano_sad2/).
- **Exact file identity:** `PerituneMaterial_Piano_Sad2.mp3`; the source page separately identifies this as the piano-solo variant and also advertises an MP3/OGG/M4A archive.
- **License:** Creative Commons Attribution 4.0 International (CC BY 4.0).
- **License page:** [CC BY 4.0 deed](https://creativecommons.org/licenses/by/4.0/) and [PeriTune creator terms](https://peritune.com/about/).
- **Commercial game use:** Yes.
- **Modification:** Yes.
- **Attribution:** Required under CC BY 4.0: `Piano_Sad2 (Piano Solo) / PeriTune (Sei Mutsuki) / https://peritune.com/ / CC BY 4.0`; indicate changes.
- **Restrictions:** no Content ID registration, stand-alone resale/reupload, or music-showcase distribution; preserve the original and confirm paid-build packaging against PeriTune's current embedding language.
- **Composition / arrangement / performance / master:** not applicable as a classical-rights audit; this is a creator-owned original catalogue track, while separate arranger, performer, recorder, and master-owner credits are not supplied.
- **Human / AI provenance:** the first-party site identifies Sei Mutsuki as a long-standing human music creator and calls the catalogue original music; no track-level AI/GenAI audio notice or explicit no-AI certification is supplied.
- **Proposed placement:** rare sourceless authorial island at an already-visible threshold or fragment, with *No Task Left* after the final clasp as the first scene test; never a relationship-tier signal.
- **Permitted edit concept:** finite excerpt, gain adjustment, clean trim/fade, stereo narrowing, and one quieter horizontal variant; do not create a false cadence.
- **Loop and mono notes:** a loop archive is offered, but a finite island is preferred; mono behavior is not supplied and requires mono-first audition.
- **Comfort and repetition risk:** untested attack and resonance levels; repetition could turn a delicate cue into explicit “sad scene” instruction.
- **Why it fits or fails:** solo piano, quiet/melancholic metadata, and an exact variant make it the strongest fragile lead, but it fails if it tells the audience what to feel.
- **Retrieved:** 2026-08-14

### `music.fragile_authorial` — Candidate: RainDrop

- **Status:** `CONDITIONAL` — named gaps: exact archive filename, checksum, complete audition, mono collapse, and emotional-overstatement testing are pending.
- **Creator / recorder / performers:** PeriTune / Sei Mutsuki; separate performer and recorder credits are not supplied.
- **Source page:** [PeriTune exact track page](https://peritune.com/blog/2022/07/11/raindrop/).
- **Exact file identity:** not exposed before download; the source page identifies `RainDrop`, a 192 kbps MP3, and an MP3/OGG/M4A loop archive.
- **License:** Creative Commons Attribution 4.0 International (CC BY 4.0).
- **License page:** [CC BY 4.0 deed](https://creativecommons.org/licenses/by/4.0/) and [PeriTune creator terms](https://peritune.com/about/).
- **Commercial game use:** Yes.
- **Modification:** Yes.
- **Attribution:** Required under CC BY 4.0: `RainDrop / PeriTune (Sei Mutsuki) / https://peritune.com/ / CC BY 4.0`; indicate changes.
- **Restrictions:** no Content ID registration or stand-alone redistribution; confirm paid-build packaging and do not add unlicensed rain or impulse-response material.
- **Composition / arrangement / performance / master:** not applicable as a classical-rights audit; the official site presents an original PeriTune track, but separate arrangement, performance, recording, and master credits are not supplied.
- **Human / AI provenance:** named human creator on an original-music site; no AI/GenAI audio label or explicit no-AI certification is supplied.
- **Proposed placement:** fallback short authorial suspension only beside already-present rain, water, or memory imagery; never manufacture a relationship symbol.
- **Permitted edit concept:** gain, clean trim/fade, optional stereo narrowing, and a short horizontal excerpt; no added third-party textures.
- **Loop and mono notes:** ordinary and loop versions are advertised; audition the ordinary version first, and test mono because channel behavior is not documented.
- **Comfort and repetition risk:** richer guitar, strings, piano, and synth-pad metadata may become picturesque, soothing, or fatiguing under repetition.
- **Why it fits or fails:** quiet ambient metadata offers a less declarative fallback, but it fails if it beautifies cruelty or turns water into symbolism.
- **Retrieved:** 2026-08-14

### `music.social_diegetic_classical` — Candidate: Prelude No. 9 in E major, BWV 854

- **Status:** `CONDITIONAL` — named gaps: acquired-file verification, historic edition/arrangement confirmation, and diegetic scene, mono, and comfort auditions remain.
- **Creator / recorder / performers:** Johann Sebastian Bach, composer; Kimiko Ishizaka, piano; Anne-Marie Sylvestre, session producer/editing/mixing/mastering; Tobias Lehmann, session engineer; Robert Douglass, executive producer.
- **Source page:** [exact Wikimedia Commons file page](https://commons.wikimedia.org/wiki/File:Kimiko_Ishizaka_-_Bach_-_Well-Tempered_Clavier,_Book_1_-_17_Prelude_No._9_in_E_major,_BWV_854.ogg), corroborated by the [creator album page](https://kimikoishizaka.bandcamp.com/album/bach-well-tempered-clavier-book-1).
- **Exact file identity:** `Kimiko Ishizaka - Bach - Well-Tempered Clavier, Book 1 - 17 Prelude No. 9 in E major, BWV 854.ogg`; approximately 1:45; exact Commons file page carries VRT permission confirmation.
- **License:** Creative Commons CC0 1.0 Universal Public Domain Dedication; conservatively honor CC BY 4.0 attribution because the creator album's licence field points there.
- **License page:** [CC0 1.0 deed](https://creativecommons.org/publicdomain/zero/1.0/) and [CC BY 4.0 deed](https://creativecommons.org/licenses/by/4.0/).
- **Commercial game use:** Yes.
- **Modification:** Yes.
- **Attribution:** not legally required under CC0; required by this project as conservative treatment: `Prelude No. 9 in E major, BWV 854 / J. S. Bach; performed by Kimiko Ishizaka / Wikimedia Commons and Open Well-Tempered Clavier / CC0 1.0`; indicate changes.
- **Restrictions:** exact Ogg master only; preserve Commons, VRT, and creator-album evidence; do not infer clearance for another performance, edition, remaster, or score.
- **Composition / arrangement / performance / master:** composition: Bach's historic *Well-Tempered Clavier, Book I*; arrangement/edition: no modern arranger, completion, or orchestration identified, requiring intake confirmation; performance: Kimiko Ishizaka; master: exact 2015 Ogg marked CC0, with the creator album documenting production credits.
- **Human / AI provenance:** strong affirmative human evidence: named pianist, engineer, producer, 2015 studio recording, and VRT confirmation; no contrary AI evidence.
- **Proposed placement:** visible playback source in *After the Music*, already playing at scene entry and ending only at a plausible movement boundary or visible player action.
- **Permitted edit concept:** prefer complete movement; otherwise gain, format conversion, and a clean musically complete trim/fade verified by audition.
- **Loop and mono notes:** do not loop; exact page does not document mono compatibility, so test the complete movement in mono and in the intended room treatment.
- **Comfort and repetition risk:** repeated use could make a recognizable Bach movement an importance label; piano transients and room/master dynamics require comfort testing.
- **Why it fits or fails:** exact human performance, short duration, and strong file-level evidence suit plausible campus playback; it fails if cultural familiarity overwhelms the conversation.
- **Retrieved:** 2026-08-14

### `music.social_diegetic_classical` — Candidate: Hesitation

- **Status:** `CONDITIONAL` — named gaps: exact downloaded filename, chorus content, fey/gothic overstatement, mono, comfort, and scene-fit tests remain.
- **Creator / recorder / performers:** PeriTune / Sei Mutsuki; separate instrumentalists, chorus performers, and recorder credits are not supplied.
- **Source page:** [PeriTune exact track page](https://peritune.com/blog/2022/02/26/hesitation/).
- **Exact file identity:** not exposed before download; use the source page's full `Hesitation` chamber version, not its separately listed `Hesitation (Piano Solo)` variant.
- **License:** Creative Commons Attribution 4.0 International (CC BY 4.0).
- **License page:** [CC BY 4.0 deed](https://creativecommons.org/licenses/by/4.0/) and [PeriTune creator terms](https://peritune.com/about/).
- **Commercial game use:** Yes.
- **Modification:** Yes.
- **Attribution:** Required under CC BY 4.0: `Hesitation / PeriTune (Sei Mutsuki) / https://peritune.com/ / CC BY 4.0`; indicate changes.
- **Restrictions:** no Content ID, stand-alone redistribution, or raw-track showcase; confirm paid-build embedding and verify that any chorus is non-lyrical.
- **Composition / arrangement / performance / master:** not applicable as a public-domain classical audit; this is an original contemporary chamber-styled track, while separate arrangement, performer, recording, and master-owner credits are not supplied.
- **Human / AI provenance:** official site identifies a named human original-music creator; no AI/GenAI audio label or explicit no-AI certification is supplied.
- **Proposed placement:** visible campus playback fallback for *After the Music*; never a Lavinia theme or hidden-romance indicator.
- **Permitted edit concept:** non-loop full version, restrained gain, clean source fade or visible stop, and stereo narrowing only if mono testing permits.
- **Loop and mono notes:** source advertises loop files, but diegetic playback should not loop invisibly; mono behavior is undocumented and must be tested.
- **Comfort and repetition risk:** waltz pulse, strings, and chorus may become melodramatic, fey, or emotionally instructive; repeated playback could reveal importance.
- **Why it fits or fails:** explicit chamber instrumentation offers a creator-cleared classical alternative; it fails if the waltz or chorus romanticizes the scene.
- **Retrieved:** 2026-08-14

### `music.rehearsal_playback_classical` — Candidate: Prelude No. 14 in F-sharp minor, BWV 859

- **Status:** `CONDITIONAL` — named gaps: exact acquired-file match, modern edition/arrangement confirmation, and rehearsal, mono, comfort, and repetition auditions remain.
- **Creator / recorder / performers:** Johann Sebastian Bach, composer; Kimiko Ishizaka, piano; Anne-Marie Sylvestre, session producer/editing/mixing/mastering; Tobias Lehmann, session engineer; Robert Douglass, executive producer.
- **Source page:** [exact Wikimedia Commons file page](https://commons.wikimedia.org/wiki/File:Kimiko_Ishizaka_-_Bach_-_Well-Tempered_Clavier,_Book_1_-_27_Prelude_No._14_in_F-sharp_minor,_BWV_859.ogg), corroborated by the [creator album page](https://kimikoishizaka.bandcamp.com/album/bach-well-tempered-clavier-book-1).
- **Exact file identity:** `Kimiko Ishizaka - Bach - Well-Tempered Clavier, Book 1 - 27 Prelude No. 14 in F-sharp minor, BWV 859.ogg`; approximately 1:05.
- **License:** Creative Commons CC0 1.0 Universal Public Domain Dedication; conservatively honor CC BY 4.0 attribution because the creator album's licence field points there.
- **License page:** [CC0 1.0 deed](https://creativecommons.org/publicdomain/zero/1.0/) and [CC BY 4.0 deed](https://creativecommons.org/licenses/by/4.0/).
- **Commercial game use:** Yes.
- **Modification:** Yes.
- **Attribution:** not legally required under CC0; required by this project as conservative treatment: `Prelude No. 14 in F-sharp minor, BWV 859 / J. S. Bach; performed by Kimiko Ishizaka / Wikimedia Commons and Open Well-Tempered Clavier / CC0 1.0`; indicate changes.
- **Restrictions:** exact Ogg master only; preserve file and creator evidence; do not extend clearance to another edition, performance, remaster, or score.
- **Composition / arrangement / performance / master:** composition: Bach's historic *Well-Tempered Clavier, Book I*; arrangement/edition: no modern arranger, completion, or orchestration identified, requiring intake confirmation; performance: Kimiko Ishizaka; master: exact 2015 Ogg marked CC0 with creator-side production provenance.
- **Human / AI provenance:** strong affirmative human evidence from a named pianist and documented 2015 studio production; no contrary AI evidence.
- **Proposed placement:** visible rehearsal device in *Three Versions of the Sky*; every start, stop, and restart follows visible practical action and reveals no hidden attraction.
- **Permitted edit concept:** complete movement preferred; otherwise gain, format conversion, and a musically complete trim/fade; no generated variations.
- **Loop and mono notes:** do not manufacture a loop; use visible restarts, and test the exact master in mono because channel behavior is not documented.
- **Comfort and repetition risk:** three rehearsal repetitions could fatigue or turn minor-key material into an ominous clue; piano attacks require comfort testing.
- **Why it fits or fails:** the short exact movement supports plausible rehearsal repetition with strong human provenance; it fails if minor-key familiarity codes the scene as dangerous.
- **Retrieved:** 2026-08-14

### `music.rehearsal_playback_classical` — Candidate: Dark_Moon

- **Status:** `CONDITIONAL` — named gaps: exact downloaded filename, glockenspiel cliché, mono, comfort, repetition, and visible-source fit remain untested.
- **Creator / recorder / performers:** PeriTune / Sei Mutsuki; separate piano, guitar, glockenspiel, recorder, and master credits are not supplied.
- **Source page:** [PeriTune exact track page](https://peritune.com/blog/2022/01/30/dark_moon/).
- **Exact file identity:** not exposed before download; the source page identifies `Dark_Moon` and advertises WAV, 192 kbps MP3, and MP3/OGG/M4A loop files.
- **License:** Creative Commons Attribution 4.0 International (CC BY 4.0).
- **License page:** [CC BY 4.0 deed](https://creativecommons.org/licenses/by/4.0/) and [PeriTune creator terms](https://peritune.com/about/).
- **Commercial game use:** Yes.
- **Modification:** Yes.
- **Attribution:** Required under CC BY 4.0: `Dark_Moon / PeriTune (Sei Mutsuki) / https://peritune.com/ / CC BY 4.0`; indicate changes.
- **Restrictions:** no Content ID or stand-alone redistribution; confirm paid-build packaging and use a neutral runtime ID unrelated to darkness, romance, route, or character.
- **Composition / arrangement / performance / master:** not applicable as a public-domain classical audit; this is an original chamber-styled asset, but separate arrangement, performance, recording, and master-owner credits are not supplied.
- **Human / AI provenance:** named human original-music creator; no AI/GenAI audio notice or explicit no-AI certification is supplied.
- **Proposed placement:** visible rehearsal-source fallback for *Three Versions of the Sky*, controlled only by paper/control/rehearsal actions.
- **Permitted edit concept:** ordinary file first, restrained gain, clean stop/fade, and optional narrowing; prefer visible restart over a hidden loop.
- **Loop and mono notes:** a loop archive exists, but rehearsal should use visible restarts; mono compatibility is undocumented and requires testing.
- **Comfort and repetition risk:** glockenspiel can become music-box horror shorthand, and “dark/sad” framing may over-signal the scene under repetition.
- **Why it fits or fails:** minimal piano, classical guitar, and glockenspiel form a compact chamber palette; it fails if the title's advertised darkness becomes audible instruction.
- **Retrieved:** 2026-08-14

### `music.post_ending_memory` — Candidate: Morning Snowfields

- **Status:** `CONDITIONAL` — named gaps: exact archive filename, brightness/sentimentality, mono, comfort, repetition, and title-context auditions remain.
- **Creator / recorder / performers:** PeriTune / Sei Mutsuki; separate performer and recorder credits are not supplied.
- **Source page:** [PeriTune exact track page](https://peritune.com/blog/2026/01/02/morning_snowfields/).
- **Exact file identity:** not exposed before download; the source page identifies `Morning Snowfields`, MP3/OGG/M4A formats, and an included loop version.
- **License:** Creative Commons Attribution 4.0 International (CC BY 4.0).
- **License page:** [CC BY 4.0 deed](https://creativecommons.org/licenses/by/4.0/) and [PeriTune creator terms](https://peritune.com/about/).
- **Commercial game use:** Yes.
- **Modification:** Yes.
- **Attribution:** Required under CC BY 4.0: `Morning Snowfields / PeriTune (Sei Mutsuki) / https://peritune.com/ / CC BY 4.0`; indicate changes.
- **Restrictions:** no Content ID, stand-alone redistribution, or track-showcase use; confirm paid-build embedding.
- **Composition / arrangement / performance / master:** not applicable as a classical-rights audit; official creator-owned original music, with separate arrangement, performance, recording, and master credits not supplied.
- **Human / AI provenance:** first-party original-music site and named human creator; no AI/GenAI audio notice or explicit no-AI certification is supplied; page photography is separate from audio provenance.
- **Proposed placement:** short deterministic island on the post-ending title or an approved rare desktop residue, using completed profile facts only and never naming a “true” ending.
- **Permitted edit concept:** short entrance/tail, restrained gain, clean trim/fade, possible narrowing, and at most one quieter horizontal edit.
- **Loop and mono notes:** a loop version is included, but title memory should remain finite; mono behavior is undocumented and requires testing.
- **Comfort and repetition risk:** sparkle or luminous ambience may become comforting, sentimental, or an ending-success label across repeated title visits.
- **Why it fits or fails:** quiet ambient metadata supports memory without a full theme; it fails if brightness rewards an ending or explains the title's mood.
- **Retrieved:** 2026-08-14

### `music.post_ending_memory` — Candidate: Pale_Warmth (instrumental variant)

- **Status:** `CONDITIONAL` — named gaps: exact instrumental filename, brass/music-box cliché, mono, comfort, repetition, and title-context auditions remain.
- **Creator / recorder / performers:** PeriTune / Sei Mutsuki; separate instrumentalists, recorder, and master-owner credits are not supplied.
- **Source page:** [PeriTune exact track page](https://peritune.com/blog/2024/12/05/pale_warmth/).
- **Exact file identity:** not exposed before download; the page identifies `Pale_Warmth`, says an instrumental version is included, and lists WAV plus MP3/OGG/M4A formats.
- **License:** Creative Commons Attribution 4.0 International (CC BY 4.0).
- **License page:** [CC BY 4.0 deed](https://creativecommons.org/licenses/by/4.0/) and [PeriTune creator terms](https://peritune.com/about/).
- **Commercial game use:** Yes.
- **Modification:** Yes.
- **Attribution:** Required under CC BY 4.0: `Pale_Warmth (instrumental variant) / PeriTune (Sei Mutsuki) / https://peritune.com/ / CC BY 4.0`; indicate changes.
- **Restrictions:** no Content ID or stand-alone redistribution; confirm paid-build embedding and record the exact instrumental filename before advancement.
- **Composition / arrangement / performance / master:** not applicable as a classical-rights audit; official original track, with separate arrangement, instrumentalist, recording, and master-owner credits not supplied.
- **Human / AI provenance:** named human original-music creator; no AI/GenAI audio notice or explicit no-AI certification is supplied.
- **Proposed placement:** brief post-ending title residue only if *Morning Snowfields* is too bright; instrumental file only, with no childhood/insanity symbolism.
- **Permitted edit concept:** restrained gain, clean finite trim/fade at a defensible musical boundary, and mono-safe narrowing; no loop recommended.
- **Loop and mono notes:** no loop requirement is adopted; exact variant and mono behavior must be verified after acquisition.
- **Comfort and repetition risk:** cornet/flugelhorn, strings, and music-box-like colour may become cinematic, cute, or fatiguing on repeated returns.
- **Why it fits or fails:** the slow quiet instrumentation could form a brief altered memory, but it fails if warmth becomes reward or music-box shorthand.
- **Retrieved:** 2026-08-14

### `music.dream_noir_suspension` — Candidate: Last 31

- **Status:** `CONDITIONAL` — named gaps: lossless-source availability, checksum, full audition, mono collapse, resonance comfort, and long-session fatigue remain.
- **Creator / recorder / performers:** Tri-Tachyon, credited uploader, composer/musician, sound designer, and sound engineer; separate performers are not supplied.
- **Source page:** [OpenGameArt exact asset page](https://opengameart.org/content/soundscape-last-31-cinematic-piano).
- **Exact file identity:** `Last 31.mp3`, listed as a 1.5 MB audio/mpeg file on the exact asset page.
- **License:** Creative Commons Attribution 4.0 International (CC BY 4.0).
- **License page:** [CC BY 4.0 deed](https://creativecommons.org/licenses/by/4.0/).
- **Commercial game use:** Yes.
- **Modification:** Yes.
- **Attribution:** Required, including the uploader's requested credit: `Last 31 / Tri-Tachyon / OpenGameArt; https://soundcloud.com/tri-tachyon/albums / CC BY 4.0`; indicate changes.
- **Restrictions:** no endorsement implication; preserve supplied attribution/source link and do not redistribute the isolated file as a product.
- **Composition / arrangement / performance / master:** not applicable as a classical-rights audit; creator-uploaded original asset, with separate arrangement, performance, recording, and master-owner credits not supplied.
- **Human / AI provenance:** first-party 2018 upload by a named composer/musician/sound designer; no AI/GenAI claim or explicit no-AI certification is supplied.
- **Proposed placement:** rare sourceless authorial suspension after an already-visible incompatibility, never routine route scoring or supernatural confirmation.
- **Permitted edit concept:** gain, clean finite trim/fade, format conversion if a verified source permits, and mono-safe narrowing after audition.
- **Loop and mono notes:** exact page supplies only MP3 and advertises no loop; treat as finite, and test mono because the reverberant field may collapse.
- **Comfort and repetition risk:** drone/reverb may create sustained resonance, headphone fatigue, or excessive atmosphere; repeated use could become a truth cue.
- **Why it fits or fails:** ambient, minimal, drone, piano, slow, and soft metadata make it the strongest noir/electroacoustic lead; it fails if reverb becomes cinematic or physically uncomfortable.
- **Retrieved:** 2026-08-14

### `music.dream_noir_suspension` — Candidate: Suspense6

- **Status:** `CONDITIONAL` — named gaps: exact filename, prepared-piano attack level, sustained-pad comfort, mono, repetition, and non-cliché scene fit remain.
- **Creator / recorder / performers:** PeriTune / Sei Mutsuki; separate performer, recorder, and master-owner credits are not supplied.
- **Source page:** [PeriTune exact track page](https://peritune.com/blog/2016/04/12/suspense6/).
- **Exact file identity:** not exposed before download; the page identifies `Suspense6`, a 192 kbps MP3, and an MP3/OGG/M4A loop archive.
- **License:** Creative Commons Attribution 4.0 International (CC BY 4.0).
- **License page:** [CC BY 4.0 deed](https://creativecommons.org/licenses/by/4.0/) and [PeriTune creator terms](https://peritune.com/about/).
- **Commercial game use:** Yes.
- **Modification:** Yes.
- **Attribution:** Required under CC BY 4.0: `Suspense6 / PeriTune (Sei Mutsuki) / https://peritune.com/ / CC BY 4.0`; indicate changes.
- **Restrictions:** no Content ID, stand-alone redistribution, or full-track showcase; confirm paid-build embedding.
- **Composition / arrangement / performance / master:** not applicable as a classical-rights audit; official original PeriTune track, with separate arrangement, performance, recording, and master credits not supplied.
- **Human / AI provenance:** named human original-music creator and a 2016 creator page; no AI/GenAI audio notice or explicit no-AI certification is supplied.
- **Proposed placement:** sparse authorial suspension after a concrete visible action; never routine dialogue, hidden-variable transition, or truth confirmation.
- **Permitted edit concept:** short finite island, restrained gain, clean trim/fade, EQ only if corrective, and mono-safe narrowing after testing.
- **Loop and mono notes:** a loop archive exists, but first audition must use a finite excerpt; mono behavior is undocumented.
- **Comfort and repetition risk:** prepared-piano attacks may imitate a sting, while synth pad may create painful or fatiguing sustained resonance; horror framing may become obvious under repetition.
- **Why it fits or fails:** prepared piano and synth-pad metadata provide the requested electroacoustic edge, but it is fallback-only because the creator explicitly frames it as horror/fear/mystery.
- **Retrieved:** 2026-08-14

## Silence recommendation for `music.dream_noir_suspension`

Authored stripped silence remains the production default unless a candidate passes blind testing. Retain the established physical room while removing the expected ordinary layer; reserve absolute silence for a separately authored rare state. This is an accepted design fallback, not an audio asset or ledger approval status.

## Rejection log

| Candidate/source | Status | Evidence-backed reason |
|---|---|---|
| All Mixkit stock music | **REJECTED** | Mixkit's own FAQ says its music is not permitted in video games ([official music FAQ](https://mixkit.co/free-stock-music/)). This does not reject Mixkit SFX, which has a separate licence. |
| Kimiko Ishizaka, *The Art of the Fugue* collection | **REJECTED pending exact-track reconciliation** | The album description says CC0 “despite what Bandcamp tells you,” while the page instructs readers to check individual tracks and Bandcamp metadata can report other rights states; the final fugue also contains Ishizaka's modern completion ([creator album page](https://kimikoishizaka.bandcamp.com/album/j-s-bach-the-art-of-the-fugue-kunst-der-fuge-bwv-1080)). The existing classical-rights note already rejects this collection pending clarification. |
| PeriTune, *Scene_Tragic* | **REJECTED — artistic** | The creator describes it as grand cinematic/choral, intense, battle-oriented music with organ, celesta, strings, and other conspicuous scoring ([exact track page](https://peritune.com/blog/2021/05/09/scene_tragic/)). That conflicts with “subtle, not cinematic or dramatic,” no route fanfare, and no grand ending theme. |
| PeriTune, *Obsession* | **REJECTED — artistic** | The creator labels it intense classical waltz/battle/cinematic/orchestral music with timpani and chorus ([exact track page](https://peritune.com/blog/2022/07/01/obsession/)). It would over-label obsessive romance and likely reveal importance. |
| PeriTune, *Ominous3_Calm* | **REJECTED — artistic for this palette** | Although legally usable, the creator's own description foregrounds horror, incident, nightmare, graveyard, fear, choir, industrial colour, and cinematic suspense ([exact track page](https://peritune.com/blog/2018/06/06/ominous3/)). It is too ready-made as an “ominous scene” instruction. |
| PeriTune, *Memories* | **REJECTED — artistic for current roles** | The exact page frames it as nostalgic, emotional, dramatic piano-and-strings memory music ([exact track page](https://peritune.com/blog/2015/08/21/memories/)). It risks turning profile memory into sentimental explanation. |
| PeriTune, *Silent_Shadows* | **REJECTED — artistic, not for AI-audio reasons** | The page describes a gothic/fairy-tale/fantasy waltz with harpsichord, accordion, clarinet, bassoon, celesta, and piano ([exact track page](https://peritune.com/blog/2023/10/09/silent_shadows/)); this is too fey and decorative for the approved restraint. The page says its **image** was AI-generated; that statement does not prove the music was AI-generated, so the rejection is artistic rather than a false AI-audio accusation. |
| nene, *Night of the Streets* | **REJECTED — quality and style** | The uploader acknowledges poor quality; the track uses choir, brass, strings, timpani, and horror/suspense framing ([exact OpenGameArt page](https://opengameart.org/content/night-of-the-streets-horrorsuspense)). It conflicts with delicate, quiet, non-sting design. |
| Generic “public-domain classical” downloads, Spotify/YouTube/CD recordings, and Musopen badges without exact rights layers | **REJECTED as a class** | An old composition does not clear a modern edition, performance, or master. The governing evidence and source policy are documented in `docs/research/2026-08-14-classical-music-recording-rights-and-free-sources.md`. |

## Required audition and intake sequence

No candidate may advance merely because this ledger lists it.

1. Acquire only from the exact source page; preserve the original and capture source/licence evidence on the same date.
2. Record the exact filename, duration, sample rate, channels, embedded metadata, and checksum. If these do not match the page, stop and mark `REJECTED` until reconciled.
3. For PeriTune archives, identify which file is ordinary, loop, alternate, or instrumental. Do not infer from filenames.
4. Conduct a normal-level full-track audition before editing. Reject loud attacks, sustained painful resonances, jump-scare shapes, lyrical vocals, stock-horror cliché, excessive pathos, or hidden importance signalling.
5. Test the proposed scene entry and exit with dialogue/TTS ducking; the cue must survive the uniform duck without needing to become louder.
6. Test mono first without telling listeners which moments matter, then conduct a non-interpretive stereo comfort/collapse pass.
7. Create only the permitted edit master, log every change, and retain attribution/change notices.
8. Prefer the documented silence fallback whenever a candidate is merely legal rather than excellent.

## Provisional attribution block

The following text is a draft, not a substitute for the final exact-file ledger:

```text
Piano_Sad2 (Piano Solo) — PeriTune (Sei Mutsuki) — https://peritune.com/ — CC BY 4.0
RainDrop — PeriTune (Sei Mutsuki) — https://peritune.com/ — CC BY 4.0
Hesitation — PeriTune (Sei Mutsuki) — https://peritune.com/ — CC BY 4.0
Dark_Moon — PeriTune (Sei Mutsuki) — https://peritune.com/ — CC BY 4.0
Morning Snowfields — PeriTune (Sei Mutsuki) — https://peritune.com/ — CC BY 4.0
Pale_Warmth (instrumental variant) — PeriTune (Sei Mutsuki) — https://peritune.com/ — CC BY 4.0
Suspense6 — PeriTune (Sei Mutsuki) — https://peritune.com/ — CC BY 4.0
Last 31 — Tri-Tachyon — https://opengameart.org/content/soundscape-last-31-cinematic-piano — CC BY 4.0
Prelude No. 9 in E major, BWV 854 — J. S. Bach; performed by Kimiko Ishizaka — Wikimedia Commons / Open Well-Tempered Clavier — CC0 1.0 (voluntary attribution; conservative treatment)
Prelude No. 14 in F-sharp minor, BWV 859 — J. S. Bach; performed by Kimiko Ishizaka — Wikimedia Commons / Open Well-Tempered Clavier — CC0 1.0 (voluntary attribution; conservative treatment)
```

For every modified CC BY asset, append an accurate statement such as `Trimmed, gain-adjusted, and faded for game use; no endorsement implied.`

## Decision

Proceed to **audition**, not integration, with the ten candidates above. The two human-performed Bach masters are the best current classical leads; the small PeriTune set supplies coherent original alternatives; *Last 31* is the most promising independent electroacoustic/noir lead. The shortlist deliberately leaves most of the game unscored. Silence and physical ambience remain the correct result whenever music would explain too much.
