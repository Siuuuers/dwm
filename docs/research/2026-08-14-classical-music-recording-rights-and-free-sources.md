# Classical music recording rights and free-source gate

Date: 2026-08-14
Status: non-authoritative external research. This note does not amend game design, implementation requirements, plans, or asset approvals. It is a conservative intake policy, not legal advice.

## Finding

**“Classical music is free” is not a reliable legal rule.** “Classical” describes repertoire and style, not copyright status. An old composition can be in the public domain while a modern arrangement, performance, or recording of it remains protected.

The U.S. Copyright Office treats a musical composition and a sound recording as separate works. A composition covers the music and any lyrics; a sound recording is the fixation of a particular performance, and its authors may include performers, producers, and sound engineers. Rights in one do not substitute for rights in the other. See [U.S. Copyright Office Circular 56A](https://www.copyright.gov/circs/circ56a.pdf). WIPO separately identifies performers and phonogram producers as beneficiaries of related rights in the digital environment. See the [WIPO Performances and Phonograms Treaty overview](https://www.wipo.int/en/web/treaties/ip/wppt/index).

For this project, every classical recording therefore needs four checks:

1. **Composition:** the melody, harmony, rhythm, and any text must be public domain in the intended distribution territories or covered by a project-accepted license.
2. **Edition or arrangement:** a modern orchestration, completion, transcription, critical edition, or other original contribution may have its own rights even when the underlying composition is old. IMSLP gives the example that a new arrangement of public-domain Mozart contains copyrighted arrangement material unless it is released under a suitable license. See [IMSLP's licensing policy](https://imslp.org/wiki/IMSLP%3AFree_content_licenses).
3. **Performance:** the musicians' performance may carry performers' or neighbouring rights. WIPO's treaty overview expressly distinguishes performers from phonogram producers.
4. **Sound recording/master:** the fixed audio file has rights separate from the composition. A publisher, label, producer, performer, or engineer may own or share those rights.

The practical consequence is simple: **the fact that Bach, Mozart, or another composer is long dead does not clear a recording downloaded from Spotify, YouTube, a CD, or an unlabeled “royalty-free” page.** Musopen's own FAQ warns that free online availability and age do not establish public-domain status, and that a public-domain composition can still have a protected recording. See [Musopen's FAQ](https://musopen.org/faq/).

## Territory and global-distribution risk

Copyright terms and public-domain status vary by country. The European Commission notes that terms can be 50, 70, 80, or another number of years, with rules also varying by publication date and later legislative changes; a work can be public domain in one country and protected in another. See the [European Commission IP Helpdesk's public-domain overview](https://intellectual-property-helpdesk.ec.europa.eu/news-events/news/public-domain-2020-11-19_en). Creative Commons likewise warns that a work carrying the Public Domain Mark may not be free of known restrictions in every jurisdiction. See [Public Domain Mark 1.0](https://creativecommons.org/publicdomain/mark/1.0/).

The difference is concrete for recordings. IMSLP's current simplified table lists different expiration rules for the EU, Canada, the United States, and Taiwan, and expressly says recording copyright sits on top of composition copyright. See [IMSLP: Copyright Made Simple](https://imslp.org/wiki/IMSLP%3ACopyright_Made_Simple). The U.S. Copyright Office also explains that many pre-1972 U.S. recordings remain protected under special term rules. See [Circular 57](https://www.copyright.gov/circs/circ57.pdf).

Because the game may be sold internationally, this project should not treat an expiry-based “public domain in country X” label as a worldwide clearance. A recording-specific **CC0 dedication or CC BY license from the apparent rights holder is the preferred route**. Expiry-only candidates should be held for territory-specific legal review unless their provenance and status are exceptionally clear across every intended store territory.

## Project license gate

### Shortlist-ready license classes

| Asset-level evidence | Commercial game use | Editing | Attribution | Project decision |
|---|---:|---:|---:|---|
| **CC0 1.0**, applied to the particular recording by the apparent recording rights holder | Yes | Yes | Not legally required | Accept for shortlist after provenance and composition checks |
| **CC BY**, with a named licensor/creator and versioned license link on the recording page | Yes | Yes | Required; changes must be indicated | Accept for shortlist after provenance and composition checks |
| Explicit public-domain dedication by the performer/producer or other apparent recording rights holder, with recording-specific provenance | Generally intended to allow all uses | Generally intended | Usually not required | Accept for shortlist; preserve the exact dedication evidence and check territorial wording |
| **Public Domain Mark (PDM)** on a recording with complete provenance | The mark describes a status; it is not a rights-holder license | Described as permitted | Not required by the mark | Conditional shortlist only; verify the status in intended territories or escalate |

[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) permits copying, modification, distribution, and performance, including commercially, without permission. [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) permits commercial sharing and adaptation but requires appropriate credit, a license link, and an indication of changes. Both deeds warn that other rights and jurisdictional issues may remain.

### Reject or escalate

- Reject **CC BY-NC**, any NonCommercial term, and “free for personal use.” [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/) prohibits commercial use.
- Reject **CC BY-ND**, NoDerivatives, or any term that blocks trimming, looping, fades, restoration, format conversion, or other needed adaptation. [CC BY-ND 4.0](https://creativecommons.org/licenses/by-nd/4.0/) does not permit distribution of adapted material.
- Reject **CC BY-SA** and other copyleft/ShareAlike licenses under this project's existing hard filter, even though CC BY-SA can allow commercial adaptation. The license requires adapted contributions to be distributed under the same or a compatible license. See [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
- Reject a bare “royalty-free,” “copyright-free,” “no copyright,” “free download,” or “public domain music” claim without an asset-specific license/status page and identifiable provenance.
- Reject YouTube or social-media reuploads, Content ID descriptions, streaming availability, and user comments as license evidence.
- Reject a score license as proof of recording rights, and reject a recording license as proof that a modern arrangement or completion is cleared.
- Reject conflicting metadata, a missing performer/producer, an unresolved license-review flag, or a source page that does not identify the exact file.
- Escalate expiry-only recordings, Public Domain Mark-only recordings intended for worldwide release, government recordings whose public-domain rule may be domestic only, and any candidate involving a modern editor, arranger, completion, or restored master with unclear rights.

## Source assessment

### Wikimedia Commons — useful, file-specific, not blanket-cleared

Wikimedia Commons accepts media that are freely licensed or public domain in at least the United States and the source country, and its free-license policy requires commercial use and derivative works to be allowed. It also says reusers remain responsible for compliance. See [Commons: Licensing](https://commons.wikimedia.org/wiki/Commons%3ALicensing). Its reuse guide says the applicable license and credit requirements must be read from each file description page. See [Commons: Reusing content outside Wikimedia](https://commons.wikimedia.org/wiki/Commons%3AReusing_content_outside_Wikimedia/licenses/en).

**Project rule:** use Commons as a discovery and evidence host. Shortlist only an individual audio file marked CC0 or CC BY whose page names the performer/producer, identifies the recorded composition and arrangement, links the license, and has no unresolved review or provenance warning. PDM files remain conditional because Commons' U.S.-plus-source-country test is not a worldwide guarantee. Reject CC BY-SA under project policy even though Commons accepts it.

### IMSLP — useful, but server eligibility is not worldwide clearance

IMSLP states that both the composition and recording must be public domain or under an acceptable license before a recording can be added. It also hosts original editions, arrangements, and recordings under several licenses, including CC0, CC BY, CC BY-SA, and special performance-restricted terms. See [IMSLP: Copyright Made Simple](https://imslp.org/wiki/IMSLP%3ACopyright_Made_Simple) and [IMSLP's licensing policy](https://imslp.org/wiki/IMSLP%3AFree_content_licenses).

**Project rule:** shortlist only the individual recording's CC0 or CC BY entry with complete performer, arranger/editor, source, and license evidence. Do not infer worldwide safety merely because IMSLP hosts a file: its own copyright guide explains that its Canadian, U.S., and Asian servers apply different eligibility rules. Reject performance-restricted, NC, ND, SA, and unclear entries.

### Musopen — discovery lead only unless independent asset-level evidence is strong

Musopen says uploaders represent that music is public domain, but it does not review uploaded music to determine that status and cannot guarantee the claim. It tells reusers to assess each composition and recording independently. See [Musopen's FAQ](https://musopen.org/faq/). Its current English [Terms of Use](https://musopen.org/tos/) also contain a general personal/non-commercial use clause and disclaim any warranty that all music content is public domain.

**Project rule:** a Musopen badge or general site description is insufficient. A Musopen-hosted recording may enter the shortlist only when its exact recording page supplies a clear CC0 or CC BY license, the performer/producer and arrangement are identified, and the license can be corroborated from the creator or original project. Otherwise mark it **REJECTED**, not “probably safe.”

### Purpose-built open classical projects — strongest pattern when the recording itself is dedicated

The [Open Goldberg Variations](https://opengoldbergvariations.org/) identifies J. S. Bach's *Goldberg Variations*, pianist Kimiko Ishizaka, and a project specifically created as a public-domain recording and score; its download description says all uses are allowed. This is the strongest source pattern found in this pass: an old composition plus a modern human performance whose project explicitly releases the recording itself, not merely the score.

The creator's page for [Bach: Well-Tempered Clavier, Book 1](https://kimikoishizaka.bandcamp.com/album/bach-well-tempered-clavier-book-1) likewise identifies Ishizaka's human performance and expressly states that the recording uses CC0. It is a strong shortlist lead, but the exact chosen track and download metadata should still be captured during asset intake.

In contrast, [The Art of the Fugue album page](https://kimikoishizaka.bandcamp.com/album/j-s-bach-the-art-of-the-fugue-kunst-der-fuge-bwv-1080) says CC0 in its description while at least one [individual track page](https://kimikoishizaka.bandcamp.com/track/canon-per-augmentationem-in-contrario-motu-2) reports “all rights reserved.” Under this project's no-guessing rule, that collection is **REJECTED pending written clarification**, despite the promising album-level statement. It is also a reminder to check modern completions separately from Bach's underlying work.

These examples establish a source pattern, not an artistic recommendation. Musical fit, editability, loop behavior, dynamics, and scene placement remain separate curation decisions.

## Required evidence record for every classical candidate

Before a file can move from `CANDIDATE` to `APPROVED`, record:

- exact track/movement title and stable source page;
- composer and composition/publication basis;
- edition, arranger, orchestrator, completion author, or “none identified”;
- performer(s), ensemble, conductor, producer/engineer, and recording date where supplied;
- exact downloadable file and a checksum after acquisition;
- recording/master license or public-domain dedication, license version, and direct legal-code/deed link;
- separate evidence for the composition and any modern arrangement/completion;
- commercial game use: yes/no;
- modification permission: yes/no, including trims, fades, looping, restoration, and conversion;
- attribution text and change notice, even when attribution is voluntary;
- territorial or neighbouring-rights caveats;
- source-page and license-page evidence captured with retrieval date;
- status: `APPROVED`, `CONDITIONAL`, `REJECTED`, or `LEGAL REVIEW`.

Keep the original download unchanged. Make edits only from a preserved source copy, document every edit, and never replace the evidence record with a later search result or a platform-generated credit guess.

## Actionable conclusion for this game

Classical recordings may be added as **optional music-island candidates**, not as default continuous score. The cleanest route is a small number of human-performed CC0 or CC BY recordings with recording-specific provenance, selected for fragile chamber intimacy, unreliable memory, or emotional counterreading. Their age or fame should never be the reason they pass the legal gate.

Recommended order of operations:

1. Search purpose-built CC0 recording projects and individual CC0/CC BY files first.
2. Use Wikimedia Commons and IMSLP as file-level catalogs, not blanket licenses.
3. Use Musopen only as a discovery lead unless independent creator-side evidence closes every rights layer.
4. Keep PDM and expiry-only recordings out of production until territorial review is complete.
5. Apply the same `Title / Author or Performer / Source / License / Commercial / Modification / Attribution / Restrictions` ledger used for all other audio assets.

This preserves the user's idea—classical music can be a beautiful optional color—while correcting the unsupported physical-world claim: **some compositions and some recordings are free to use; “classical music” as a whole is not.**

## Sources retrieved 2026-08-14

- [U.S. Copyright Office, Circular 56A: Musical Compositions and Sound Recordings](https://www.copyright.gov/circs/circ56a.pdf)
- [U.S. Copyright Office, Circular 57: Pre-1972 Sound Recordings](https://www.copyright.gov/circs/circ57.pdf)
- [WIPO Performances and Phonograms Treaty overview](https://www.wipo.int/en/web/treaties/ip/wppt/index)
- [European Commission IP Helpdesk: Public domain](https://intellectual-property-helpdesk.ec.europa.eu/news-events/news/public-domain-2020-11-19_en)
- [Creative Commons: CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/), [PDM 1.0](https://creativecommons.org/publicdomain/mark/1.0/), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/), [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/), and [CC BY-ND 4.0](https://creativecommons.org/licenses/by-nd/4.0/)
- [Wikimedia Commons: Licensing](https://commons.wikimedia.org/wiki/Commons%3ALicensing)
- [Wikimedia Commons: Reusing content outside Wikimedia](https://commons.wikimedia.org/wiki/Commons%3AReusing_content_outside_Wikimedia/licenses/en)
- [IMSLP: Copyright Made Simple](https://imslp.org/wiki/IMSLP%3ACopyright_Made_Simple)
- [IMSLP: Licensing Policy and Guidelines](https://imslp.org/wiki/IMSLP%3AFree_content_licenses)
- [Musopen: FAQ](https://musopen.org/faq/) and [Terms of Use](https://musopen.org/tos/)
- [Open Goldberg Variations](https://opengoldbergvariations.org/)
- [Kimiko Ishizaka: Open Well-Tempered Clavier, Book 1](https://kimikoishizaka.bandcamp.com/album/bach-well-tempered-clavier-book-1)
- [Kimiko Ishizaka: The Art of the Fugue album](https://kimikoishizaka.bandcamp.com/album/j-s-bach-the-art-of-the-fugue-kunst-der-fuge-bwv-1080) and [conflicting individual track page](https://kimikoishizaka.bandcamp.com/track/canon-per-augmentationem-in-contrario-motu-2)
