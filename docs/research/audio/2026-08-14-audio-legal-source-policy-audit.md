# Audio Legal Source and Provenance Policy Audit

**Date:** 2026-08-14

**Status:** Gate 4 primary-source policy; no asset selected, downloaded, or
approved

This is a conservative production record, not legal advice. It separates what
each licence or platform says from the stricter rules chosen for this project.
An eligible source family does not make any particular file eligible. Every
file still needs an exact source-page, rights, provenance, and edit audit.

## Gate decision

- `ALLOW FAMILY` means an exact asset may enter research after every condition
  in this document is evidenced.
- `CONDITIONAL` means the platform can be searched, but an unresolved fact will
  reject the individual candidate if it is not resolved.
- `REJECT` means the source/licence combination may not enter this project.
- No missing fact may be inferred from a platform reputation, an absent tag, a
  search-result snippet, or the word “royalty-free.”

## Exact allow/reject matrix

| Source or licence | Primary-source licence fact | Project decision | Conditions and unresolved facts |
|---|---|---|---|
| CC0 1.0 | CC0 permits copying, modification, distribution, and commercial use without legally required attribution, but does not clear trademark, publicity, privacy, moral, or other third-party rights. [CC0 deed](https://creativecommons.org/publicdomain/zero/1.0/) and [legal code](https://creativecommons.org/publicdomain/zero/1.0/legalcode) | `ALLOW FAMILY` | Capture the exact CC0 grant and rights-holder/source chain. Credit is still recorded voluntarily. CC0 is not evidence of authorship, recording consent, underlying composition rights, or non-AI creation. |
| CC BY 4.0 | CC BY permits commercial sharing and adaptation. Distribution requires appropriate credit, a licence link, and an indication of changes; additional legal or effective technological restrictions may not be imposed. [CC BY 4.0 deed](https://creativecommons.org/licenses/by/4.0/) and [legal code](https://creativecommons.org/licenses/by/4.0/legalcode) | `ALLOW FAMILY` | Use the supplied title/creator/copyright/source information, licence/version, and change notice. Review store DRM and encrypted Godot packaging before release; do not assume CC BY media can be placed behind effective technological measures. The licence is not provenance or a warranty of underlying rights. |
| CC BY-NC | Commercial reuse is outside the standard grant. [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/) | `REJECT` | Legal incompatibility with a commercial game; do not seek an informal interpretation of “noncommercial.” A separate written commercial grant would be a new licence and needs a new review. |
| CC BY-ND | Sharing adapted material is not permitted under the standard grant. [CC BY-ND 4.0](https://creativecommons.org/licenses/by-nd/4.0/) | `REJECT` | The project requires freedom to trim, fade, loop, gain-stage, convert, and integrate audio. No candidate may rely on an argument that a planned edit is not an adaptation. |
| CC BY-SA, GPL, and comparable copyleft | These licences can permit commercial use, but impose share-alike, source, redistribution, or compatibility duties. [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) | `REJECT` by project policy | This is a project-policy exclusion, not a claim that the licences prohibit commercial games. It avoids share-alike, DRM, and media/code compatibility uncertainty. |
| OpenGameArt exact download under CC0, CC BY, or OGA-BY | OGA says its assets can be used commercially subject to each exact licence. A submission can be multi-licensed; previews may not share the download’s licence. OGA-BY is based on CC BY but removes the restriction on technical measures and retains credit/change duties. [OGA FAQ](https://opengameart.org/content/faq), [OGA-BY 4.0 text](https://opengameart.org/sites/default/files/archive/oga-by-40.txt), and [OGA-BY FAQ](https://opengameart.org/node/160242) | `ALLOW FAMILY` for exact CC0, CC BY, and OGA-BY downloads only | Choose and record one permitted licence; audit the downloadable member, not its preview. Reject SA/GPL-only members. Check every derivative/sample and the true author rather than treating the uploader as conclusive. |
| OpenGameArt AI-assisted asset | OGA requires disclosure of the AI technology/version and currently download-disables AI-assisted assets. [OGA submission guidelines](https://opengameart.org/content/art-submission-guidelines) | `REJECT` | A disclosed or suspected AI/GAN-assisted asset is rejected. Download availability and absence of disclosure are useful platform signals, not infallible proof; retain creator/process evidence for music, voice, and ambiguous designed audio. |
| PeriTune track published through February 2026 | PeriTune states that tracks published through 2026-02 remain CC BY 4.0. The creator also states that the site is their original-music catalogue and identifies PeriTune / Sei Mutsuki. [PeriTune terms](https://peritune.com/about/) and [2026 terms transition notice](https://peritune.com/blog/2026/03/01/terms-update/) | `CONDITIONAL` | Capture the exact track page and publication date. Follow full CC BY attribution even though the creator offers a supplemental credit waiver. Record any encryption permission separately. Named human authorship is present, but the pages do not expressly certify that generative AI was not used on every track; the exact track needs sufficient dated human-process evidence under the music provenance rule. |
| PeriTune track published from March 2026 | The current creator terms expressly permit commercial, adult, game, and app use; modification including tempo, effects, and loops; and optional credit. They prohibit Content ID registration and standalone resale/redistribution. Paid works bundling free files must prevent direct extraction; purchased WAV files may not be bundled. [PeriTune terms](https://peritune.com/about/) | `CONDITIONAL` | Use only the site’s free permitted format, capture the exact custom terms and track date, protect the file from direct extraction in a sold build, and still credit Title / PeriTune (Sei Mutsuki) / Source / Terms. The terms discuss AI training, not whether a track was AI-generated; exact human-process evidence remains required. |
| Sonniss #GameAudioGDC bundle member | The GDC EULA grants worldwide, non-exclusive, royalty-free, lifetime use in unlimited commercial games; modification and synchronization are allowed; attribution is not required. Raw resale and claiming authorship are prohibited. AI/ML training is prohibited. Sonniss warrants authority to license the included libraries. [GDC bundle licence](https://sonniss.com/gdc-bundle-license/) and [official archive](https://sonniss.com/gameaudiogdc/) | `ALLOW FAMILY` | Record year, archive part, exact filename, source library/recordist from the official track list, copyright holder, and the GDC EULA snapshot. The no-training clause does not prove that a member was not generated with AI. Require member-level recorder/library creation evidence, especially for human, musical, or heavily designed material. Do not redistribute raw files. |
| Kenney asset page marked CC0 | Kenney says assets on its asset pages are CC0, can be used commercially, and require no attribution; the Kenney logo is reserved. Exact audio pack pages also display CC0. [Kenney support](https://www.kenney.nl/support), [UI Audio](https://www.kenney.nl/assets/ui-audio), and [Interface Sounds](https://www.kenney.nl/assets/interface-sounds) | `ALLOW FAMILY` | Capture the exact pack page, included licence file, archive version, exact member filename, and checksum during a later authorized acquisition. Do not use the logo. No first-party catalogue-wide non-GenAI certification was located, so non-AI provenance remains member/creator-process evidence rather than a consequence of CC0. |
| Mixkit stock music | Mixkit’s music FAQ expressly says its music is not permitted in video games. [Mixkit music FAQ](https://mixkit.co/free-stock-music/) | `REJECT` | This is a direct platform-use prohibition. The separate SFX licence does not cure it. Do not reclassify a music track as an SFX because it is short or tagged “sound effects.” |
| Mixkit sound effect | Mixkit says SFX may be used in personal and commercial projects without attribution, and its terms require the item-specific licence while prohibiting standalone resale/exploitation. The terms also warn that third-party components may not have been cleared. [Mixkit SFX page](https://mixkit.co/free-sound-effects/), [licence index](https://mixkit.co/license/), and [user terms](https://mixkit.co/terms/) | `CONDITIONAL` | Archive the exact rendered SFX licence and exact item identity. The accessible first-party text reviewed here does not unambiguously state modification rights for SFX, so any trim, fade, loop, conversion, or edit is `REJECTED` until that permission is captured or clarified in writing. A missing named creator or creation method rejects the candidate under this project’s provenance schema. No first-party Mixkit-audio GenAI labelling/non-use rule was located. |
| Freesound exact CC0 or CC BY sound | Freesound hosts user uploads under CC0, CC BY, or CC BY-NC and gives an attribution pattern for BY files. It warns that user-uploaded material can still be unlawful. [Freesound FAQ](https://freesound.org/help/faq/) | `CONDITIONAL` | Only exact CC0 or CC BY asset pages may advance. Capture title, uploader, actual recorder/creator statement, source page, displayed licence/version, original filename, and description/tags. Reject NC, legacy Sampling+, conflicting metadata, reuploads, and unknown source chains. |
| Freesound AI/GenAI sound | Freesound expressly permits AI-generated audio if it has the `GenAI` tag and names the model in the description. Its separate `gen_ai_preference` concerns training use, not how a sound was created. [Freesound FAQ](https://freesound.org/help/faq/) and [API fields](https://freesound.org/docs/api/resources_apiv2.html) | `REJECT` when tagged/described/suspected AI; otherwise risk-tiered | Reject `GenAI`, model names, generated/synthetic-generation descriptions, and contrary comments. For field/Foley, require an affirmative physical recording account and no AI indicators. For music and human nonverbal audio, require stronger affirmative human composer/performer/recordist provenance. Absence of a `GenAI` tag alone is not proof. |
| Pixabay audio | Pixabay’s Content License permits commercial use, copying, modification, and adaptation without required attribution, but prohibits standalone distribution and leaves third-party permissions to the user. Its terms also prohibit use with specified pornographic, obscene, offensive, and broadly “immoral” contexts. [Pixabay licence summary](https://pixabay.com/service/license-summary/) and [terms](https://pixabay.com/service/terms/) | `CONDITIONAL / LEGAL REVIEW`; fail closed for this game | Exact game use is a larger creative work, but this project is intentionally adult, cruel, and morally disturbing. The application of the broad content restriction is unresolved; no candidate advances without a placement-specific legal decision. Record the exact item, contributor, licence snapshot, and any Content ID certificate/notice. |
| Pixabay AI-labelled or provenance-unknown audio | Pixabay permits generative-AI uploads. Its audio guidance says labels can be wrong and expressly says that absence of an AI label does not prove non-AI creation. [Pixabay audio guidelines](https://pixabay.com/blog/posts/audio-quality-guidelines-182/) and [AI-music guidance](https://pixabay.com/blog/posts/ai-music-on-pixabay-a-pre-upload-guide-to-better-a-523/) | `REJECT` unless affirmative human provenance independently resolves it | Reject AI-labelled/model-described audio. A clean label is insufficient. Music, voice, and human nonverbal assets require affirmative human creation/performance evidence; physical Foley requires a credible recording account. This makes most provenance-light Pixabay audio unsuitable even before the content restriction is considered. |
| ZapSplat Standard Licence, Basic/free account | ZapSplat’s current Standard Licence permits perpetual commercial games and allows editing, adaptation, and combination. Basic users receive MP3 files and must credit ZapSplat; the audio must remain embedded in a larger project and cannot be redistributed raw. The licence is single-user and accepted through the downloader’s own account. [ZapSplat Standard Licence](https://www.zapsplat.com/license-type/standard-license/) and [credit instructions](https://www.zapsplat.com/how-to-credit-us/) | `CONDITIONAL` | Record downloader/account authority, licence date, exact item/contributor/source page, filename, and mandatory in-game credit. Keep the file embedded, and do not transfer raw audio. The EULA prohibits AI training but does not certify non-AI creation. Require exact recording/creator-process evidence; missing provenance rejects the item. |
| “No copyright,” social/video reupload, or unclear royalty-free page | No verifiable rights-holder grant establishes commercial modification and distribution rights. | `REJECT` | Search snippets, mirrors, channel descriptions, and uploader assurances do not replace an exact rights-holder source and licence. |

## Licence fact is not provenance

A licence answers what a rights-holder purports to permit. It does not by itself
prove that the person granting it owns every included layer. The research record
must separately clear:

1. the exact sound recording/master;
2. any composition, edition, or arrangement;
3. every performance and identifiable voice;
4. incorporated samples and derivative sources;
5. privacy, publicity, property, trademark, and location restrictions; and
6. this project’s no-AI provenance rule.

For classical music, public-domain composition status clears only the
composition. Edition/arrangement, performance, and exact master remain separate
rights layers. For field recordings, intelligible speech, patients, students,
branded announcements, transit identities, alarms, and private conversations
are separate rejection risks even when the recording is CC0.

## AI provenance standard

The following evidence tiers apply after the licence passes:

- **Physical field recording and Foley:** the exact page must identify a real
  object/action/location or recording session, name the recorder or creator,
  and contain no AI/GenAI/model contradiction.
- **Designed UI/SFX:** require a named creator or first-party pack, exact member
  identity, and no AI indicator. Purely anonymous stock rows fail.
- **Music, humming, choir, breath, and other human nonverbal material:** require
  affirmative human composer/performer/recordist provenance. A creator username,
  a missing AI tag, or a permissive licence alone is insufficient.
- **Contradiction rule:** any AI label, `GenAI` tag, model name, generation
  description, synthetic/cloned voice statement, or unresolved conflict rejects
  the asset. Do not attempt to decide by listening.

Platform AI-training language is not creation provenance. Sonniss and ZapSplat
prohibit training; PeriTune regulates training; Freesound exposes uploader
training preferences. None of those facts proves how a particular file was
made.

## Evidence packet required before acquisition review

Every candidate must preserve, in one dated row:

- exact title, creator/recorder/performer, uploader when different, filename,
  version, archive/member path, and proposed role;
- direct asset page, direct licence/legal-code page, platform terms, retrieval
  date, and terms revision date when supplied;
- commercial-game permission, modification permission, attribution text,
  change notice, redistribution/embedding rules, DRM/encryption rules, account
  conditions, and Content ID risk;
- the exact creator/process evidence used for the AI-provenance decision;
- underlying composition/arrangement/performance/master and third-party-rights
  findings where applicable;
- the proposed edit recipe, each edit’s licence permission, and a statement
  that no meaningful fact depends on the sound; and
- after a separately authorized acquisition only: original file checksum,
  embedded metadata, archive licence file, and a match back to the captured
  source page.

If any required field is unclear, the candidate is `REJECTED`; it is not given
an optimistic placeholder. Terms must be rechecked on acquisition and again
before release because platform terms can change.

## Source-family order after this audit

The cleanest starting order is exact Kenney CC0 and OGA CC0/OGA-BY for UI,
exact Freesound CC0/CC BY physical recordings with affirmative provenance,
Sonniss members with exact library/recordist metadata, and PeriTune tracks whose
date and human authorship evidence both converge. ZapSplat remains a usable
attribution/account-conditioned fallback. Mixkit SFX is held for modification
and provenance evidence; Pixabay is held for both AI provenance and the
adult/dark-content restriction. Mixkit music remains rejected.

This ordering is a research policy, not an asset recommendation or acquisition
authorization. Authored silence remains preferable to any legally or
provenance-fragile substitute.
