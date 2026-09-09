# Steam Early Access and store-page requirements: primary-source research note

Date: 2026-08-30
Status: non-authoritative external research. This note does not select a platform,
amend canon or design, authorize implementation, or approve a release.

## Scope and reading rule

This is a current-state research note, checked on 2026-08-30. Every external
claim below is based on Valve's official Steamworks documentation; no developer
blog, press, forum, or store-page example is used as authority. **Valve rule**
means the source uses a requirement/prohibition or describes a release gate.
**Valve recommendation** means the source says *recommend*, *should*,
*ideally*, or frames the item as a best practice. **Project inference** is a
conclusion limited to the three project documents named below, not a claim that
the repository as a whole has no additional evidence.

## Bottom line

Steam Early Access is for a playable alpha/beta that is worth the price of the
build a buyer receives now, while the developer continues development with
player feedback. It is neither crowdfunding nor pre-purchase. A product that
only has a technical demonstration, little gameplay, or needs its sales to fund
completion is not the described use case. Buyers must receive a playable game
at purchase, and Valve says an Early Access launch needs, at minimum, a
gameplay-showing trailer. [Valve rule and eligibility context: Steamworks,
*Early Access*](https://partner.steamgames.com/doc/store/earlyaccess?l=english)

On the evidence in the scoped project documents, this project is **not ready to
make an evidence-based Early Access claim today**. The public profile is
platform-neutral; the central design specification has
`implementation_authorized: false` and a proposed implementation plan; and the
causal matrix has only its Day 1 constellation approved while twelve of fourteen
physical encounter-window records remain unselected. That does not prove a
build cannot exist elsewhere, but it does mean those documents cannot support a
truthful customer-facing statement of a playable current build, its implemented
routes, its language support, or its exact mature-content disclosure.

## Valve rules and release gates

### Early Access eligibility, promises, and third-party keys

- **Valve rule:** Do not use Early Access as crowdfunding or pre-purchase. Do
  not make specific promises that the game will finish at a known time, will
  finish at all, or will definitely receive planned additions. Customers must be
  able to decide on the present build rather than bet on that future. The same
  source also requires a playable game, says not to launch merely for final bug
  testing, and requires clear expectations wherever the game is discussed.
  [*Early Access*](https://partner.steamgames.com/doc/store/earlyaccess?l=english)

- **Valve rule:** When Steam Early Access keys are sold on a third-party site,
  that site must show the Early Access branding, current-state information, and
  a link to the Early Access FAQ; Valve also says to include the questionnaire.
  Its branding page supplies the mandatory Early Access notice and requires a
  clear current-state description. [*Steam Branding
  Guidelines*](https://partner.steamgames.com/doc/marketing/branding?l=english)

- **Valve rule:** Make Early Access available for sale on Steam no later than
  anywhere else, and do not price the Steam Early Access offer above the offer
  on another service or website. Transparently disclose known material effects
  of updates, including known save-breaking changes, wherever Steam keys are
  sold. [*Early Access*](https://partner.steamgames.com/doc/store/earlyaccess?l=english)

### Required Early Access Q&A

**Valve rule:** Enable the Early Access setting and complete the Early Access
Q&A. Valve reviews the product page and Q&A before an Early Access release; the
review documentation also says every question in the Early Access section must
be answered. [*Early
Access*](https://partner.steamgames.com/doc/store/earlyaccess?l=english),
[*Review Process*](https://partner.steamgames.com/doc/store/review_process?language=english)

The player-facing prompts currently read:

1. `Why Early Access?`
2. `Approximately how long will this game be in Early Access?`
3. `How is the full version planned to differ from the Early Access version?`
4. `What is the current state of the Early Access version?`
5. `Will the game be priced differently during and after Early Access?`
6. `How are you planning on involving the Community in your development process?`

Valve's accompanying guidance is to be detailed and transparent: give a target
range where possible (or say why there is none); describe what is purchasable
today in concrete modes/features/levels; distinguish planned additions from
present content; explain community communication; and keep the current-state
answer current as progress changes. This guidance is not permission to make a
guarantee: the explicit prohibition on specific future promises still governs
the wording. [*Early
Access*](https://partner.steamgames.com/doc/store/earlyaccess?l=english)

### Pricing and transition out of Early Access

- **Valve rule:** A permanent discount cannot run while the product is in Early
  Access. If the intended Early Access price is lower, set a lower base price.
  A price rise has a 30-day no-discount window; raising the price within 30 days
  of the 1.0 transition prevents a launch discount from applying. The price may
  be raised on transition, but the change should be requested early enough to
  be approved. [*Early
  Access*](https://partner.steamgames.com/doc/store/earlyaccess?l=english),
  [*Pricing*](https://partner.steamgames.com/doc/store/pricing?l=english)

- **Valve recommendation:** There is no fixed requirement that Early Access
  cost less than 1.0. Valve instead recommends a fair current-build price,
  transparency about a contemplated increase, and some value for early
  supporters. [*Early
  Access*](https://partner.steamgames.com/doc/store/earlyaccess?l=english)

- **Valve rule:** Do not represent a game as fully released until it is feature
  complete and no longer significantly changing; a post-Early-Access product is
  expected to be stable and complete. [*Early
  Access*](https://partner.steamgames.com/doc/store/earlyaccess?l=english)

### Store, build, review, Coming Soon, and title gates

- **Valve rule:** Both the store-presence checklist and the build/configuration
  checklist must be completed, submitted, reviewed, and approved. Submit store
  presence before the build. The build should be mostly final and contain every
  feature presented on the store page; it must start correctly on every listed
  operating system. [*Release
  Process*](https://partner.steamgames.com/doc/store/releasing), [*Review
  Process*](https://partner.steamgames.com/doc/store/review_process?language=english)

- **Valve rule:** A store page must contain only features and content available
  at launch. Remove unreleased/planned screenshots, trailers, and feature
  claims; any future feature mentioned in the written description must be
  clearly identified as not yet released. The description must be detailed and
  coherent, and it may not link to other websites. [*Review
  Process*](https://partner.steamgames.com/doc/store/review_process?language=english),
  [*Store Page, Building and
  Editing*](https://partner.steamgames.com/doc/store/page?l=english&language=english)

- **Valve rule:** A new product, including an Early Access product, must have a
  public Coming Soon page for at least two weeks before it can become playable.
  The page itself needs Valve approval before posting. Once the displayed
  release date is within 14 days, changing it requires contacting Valve.
  [*Coming Soon*](https://partner.steamgames.com/doc/store/coming_soon?l=english),
  [*Release Options*](https://partner.steamgames.com/doc/store/types?l=english)

- **Valve recommendation / planning fact:** Store and build reviews typically
  take 3–5 business days, and Valve asks partners to allow at least 7 business
  days. A page marked `Adult Only Sexual Content` can take longer because the
  completed page and product build are both required before that page can be
  reviewed. [*Review
  Process*](https://partner.steamgames.com/doc/store/review_process?language=english)

- **Valve rule:** A game name may be changed only until the store page has gone
  through pre-release review. Later changes require unlocked Profile Features or
  advance contact with Valve. [*Changing Your Game's
  Name*](https://partner.steamgames.com/doc/store/editing/name)

- **Valve recommendation:** Put up Coming Soon when the art direction and core
  feature set are reasonably stable; a long Coming Soon period is acceptable,
  but substantial change can confuse early wishlisters. The basic page setup
  calls for branding images and written description, with a gameplay trailer
  described as ideal. [*Coming
  Soon*](https://partner.steamgames.com/doc/store/coming_soon?l=english)

### Required marketing materials

- **Valve rule:** Release requires a trailer; do not release while one is still
  encoding. For Early Access, the minimum trailer must show gameplay. Valve
  highly recommends that the first store trailer be primarily gameplay from the
  player's perspective, but that ordering is a recommendation rather than the
  release gate. [*Trailers*](https://partner.steamgames.com/doc/store/trailer),
  [*Early Access*](https://partner.steamgames.com/doc/store/earlyaccess?l=english)

- **Valve rule:** Required store graphics are Header (920×430), Small Capsule
  (462×174), Main Capsule (1232×706), Vertical Capsule (748×896), and
  screenshots (minimum 1920×1080, 16:9). At least five screenshots are
  required. Screenshots must show the game as played, rather than concept art,
  pre-rendered cinematic stills, awards, marketing copy, or written
  descriptions. Capsules need a readable title or logo and may not use quotes
  or other text beyond the game title. [*Graphical Assets
  Overview*](https://partner.steamgames.com/doc/store/assets?l=english),
  [*Store Graphical
  Assets*](https://partner.steamgames.com/doc/store/assets/standard?l=english),
  [*Review
  Process*](https://partner.steamgames.com/doc/store/review_process?language=english)

### Content survey and language claims

- **Valve rule:** Complete all three Content Survey sections—general content,
  mature content, and generative-AI content—before review. Valve compares the
  answers against both the submitted build and the store page. The mature survey
  requires honest, accurate disclosure of all adult content uploaded in builds,
  including content not accessible or presented in the product. General-content
  answers feed regional ratings. [*Content
  Survey*](https://partner.steamgames.com/doc/gettingstarted/contentsurvey?language=english)

- **Valve rule:** If `Adult Only Sexual Content` is selected, submit both the
  completed store page and completed build before the store page can be reviewed
  as ready; allow more than the usual review time. This is a workflow
  consequence, not a rule that every adult-themed or horror work must receive
  that mark. [*Review
  Process*](https://partner.steamgames.com/doc/store/review_process?language=english)

- **Valve rule / configuration constraint:** Steam lets a developer declare
  actual in-game support separately for Interface, Subtitles, and Full Audio;
  set the game's base languages in Steamworks. Store-page localization (copy,
  images, and trailers) is independent of in-game localization. The store's
  language-support indication is determined by in-game settings, not merely
  translated marketing copy. [*Localization and
  Languages*](https://partner.steamgames.com/doc/store/localization?l=english),
  [*Languages Supported on
  Steam*](https://partner.steamgames.com/doc/store/localization/languages)

### Updates, roadmap, and ongoing honesty

- **Valve rule / current operation:** An Early Access page should always reflect
  the current game and the most up-to-date 1.0 plans. If 12 months pass since
  either a default-branch build or an update-type news event, Steam adds a
  store-page notice that the game has not been updated recently. [*Early
  Access*](https://partner.steamgames.com/doc/store/earlyaccess?l=english)

- **Valve recommendation:** Revisit the Q&A at least annually, update marketing
  material as needed, and consider a news event for a major update or delay.
  A roadmap is optional; Valve advises keeping it accurate and avoiding specific
  promises unless delivery is reliable regardless of sales or feedback.
  [*Early Access*](https://partner.steamgames.com/doc/store/earlyaccess?l=english),
  [*Roadmaps*](https://partner.steamgames.com/doc/store/roadmap)

## Project-specific facts and inferences

### Facts in the requested project records

- The public profile describes an adult psychological-horror visual novel and
  relationship mystery with four adult women; a first clear of about two hours;
  full completion of about five; layered 2D presentation; no recorded character
  voice acting; meaningful Cantonese and Romanian; and configurable localized
  display languages. It explicitly says the profile is platform-neutral and
  implies no release platform. [Public project
  profile](../../story/04-public-project-profile.md)

- The seven-day design front matter records an approved written/conversational
  specification, but `implementation_authorized: false`; its implementation
  roadmap is `proposed`. The scope excludes finished dialogue, art, audio,
  animation, cinematics, Chinese translation prose, and final numerical
  balance. [Seven-Day Flow and Dialogic
  Structure](../design/2026-08-07-seven-day-dialogic-flow-design.md)

- The causal matrix records Pass One frozen and only the Day 1 constellation
  approved in Pass Two. Twelve of fourteen physical encounter-window records
  remain `UNSELECTED`; exact final DTL, interface timing, and runtime labels
  are also unselected. [Seven-Day Causal
  Matrix](../../story/07-seven-day-causal-matrix.md)

### Project inferences and recommended preparation

1. **Do not draft an Early Access store page as if these specifications were
   shippable content.** The current-state Q&A must inventory a build a buyer can
   run now, while the review gate forbids representing unimplemented planned
   features as available. The cited design status and selection state make a
   confident complete-seven-day, all-route, or exact-ending count unsafe until
   an actual build, route ledger, and captured gameplay establish those facts.

2. **A Steam title should be selected, cleared, and represented consistently in
   Store Info, Steamworks Info, and the selling package before pre-release
   review.** The scoped public profile gives a description but no confirmed
   public product name. This is a project inference from the named files, not a
   claim that no title exists elsewhere. Name lock makes postponing that choice
   past review costly.

3. **Treat “adult” as a content-disclosure task, not a genre label.** The known
   profile supports accurate tags/copy such as adult protagonists, psychological
   horror, romance, and no recorded voice acting. It does not determine the
   Content Survey's actual mature selections. Before submission, audit the
   submitted build—including inaccessible material—and its screenshots/trailer
   for violence, sexual material, and every other survey category. Do not infer
   `Adult Only Sexual Content` merely from the profile's use of “adult,” and do
   not omit it if the build warrants it.

4. **Make language claims narrow and build-verifiable.** The profile's
   character-language and dual-language-reading intent does not by itself prove
   an in-game Interface or Subtitles localization option has shipped. In
   particular, no recorded voice acting means a `Full Audio` claim would need
   independent implementation evidence. Only list each Steam-supported
   interface/subtitle/audio language once it is selectable and present in the
   shipping build; describe embedded Cantonese/Romanian dialogue separately
   rather than overstating it as whole-game localization.

5. **If Early Access becomes appropriate, sell the smallest presently complete
   experience and call later work a plan, not a promise.** A safe Q&A structure
   is: (a) name the playable build's exact day(s), routes, UI, saves, languages,
   and known limitations; (b) give a contingent timeframe or explain why none
   can be supplied; (c) identify intended work as subject to change; (d) say
   exactly where feedback is collected and how often updates are communicated;
   and (e) revise the Q&A, page, screenshots, trailer, and roadmap whenever the
   current build changes. This is a project recommendation derived from the
   Valve rules above, not approved public copy.

6. **Use a release worksheet before publishing Coming Soon.** It should pair
   every store claim, tag, platform, language setting, screenshot, trailer shot,
   survey answer, and Q&A sentence with the specific current-build proof. Then
   schedule: submit the store page at least seven business days before desired
   public visibility; obtain approval; keep Coming Soon public for at least 14
   days; submit a mostly-final build; and leave time for any adult-content
   review expansion. This is a practical project recommendation; Valve controls
   the actual review outcome and timing.

## Primary sources

All external links below are official Valve/Steamworks documentation, checked
2026-08-30.

- [Early Access](https://partner.steamgames.com/doc/store/earlyaccess?l=english)
- [Review Process](https://partner.steamgames.com/doc/store/review_process?language=english)
- [Release Process](https://partner.steamgames.com/doc/store/releasing)
- [Release Options](https://partner.steamgames.com/doc/store/types?l=english)
- [Coming Soon](https://partner.steamgames.com/doc/store/coming_soon?l=english)
- [Pricing](https://partner.steamgames.com/doc/store/pricing?l=english)
- [Store Page, Building and Editing](https://partner.steamgames.com/doc/store/page?l=english&language=english)
- [Changing Your Game's Name](https://partner.steamgames.com/doc/store/editing/name)
- [Graphical Assets Overview](https://partner.steamgames.com/doc/store/assets?l=english)
- [Store Graphical Assets](https://partner.steamgames.com/doc/store/assets/standard?l=english)
- [Trailers](https://partner.steamgames.com/doc/store/trailer)
- [Content Survey](https://partner.steamgames.com/doc/gettingstarted/contentsurvey?language=english)
- [Localization and Languages](https://partner.steamgames.com/doc/store/localization?l=english)
- [Languages Supported on Steam](https://partner.steamgames.com/doc/store/localization/languages)
- [Roadmaps](https://partner.steamgames.com/doc/store/roadmap)
- [Steam Branding Guidelines](https://partner.steamgames.com/doc/marketing/branding?l=english)
