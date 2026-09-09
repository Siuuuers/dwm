# Lawful-Universe Atlas Presence Refinement Implementation Plan

> **Archive notice — 2026-08-24:** Retired disposable HTML-prototype evidence.
> This document is non-authoritative and must not be executed or treated as a
> current requirement. See `README.md`.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refine the disposable Curated Living Atlas with compact controls, host-local prompts, centred witnessed scenes and captions, full-panel transparent Angela presentation, retained Dual projections, and safe pointer-only micro-parallax.

**Architecture:** Keep the dependency-free single-file atlas and its deterministic fixture store. Add presentation-only CSS/DOM helpers inside the existing HTML, strengthen the PowerShell structural guard before each slice, and use the isolated-Chrome verifier for rendered geometry, focus, motion, and accessibility behavior. The portable atlas has no `.git`; each slice records a SHA-256 checkpoint in its SDD report instead of creating a false implementation commit.

**Tech Stack:** HTML5, CSS custom properties, vanilla JavaScript, PowerShell structural checks, Node.js syntax checks, Chrome DevTools Protocol verification.

## Global Constraints

- Portable atlas root: `C:\Users\glori\Documents\Codex\2026-08-14\new-chat\lawful-universe-atlas`.
- Modify only `content/lawful-universe-design-atlas-01.html`, `state/atlas-structural-check.ps1`, `state/atlas-browser-check.js`, `state/atlas-verification.md`, `state/atlas-browser-result.json`, `state/atlas-evidence/`, and `sdd/presence-refinement-report.md`.
- Do not modify Godot scenes/scripts, accepted design amendments, Beads, production assets, saves, or localization.
- Preserve the exact 1280-by-720 canvas, title 320/960 split, desktop 480/800 split, 64-pixel strips, and Narrative 104/344/272 bands.
- Preserve all 48-by-48 ordinary and 64-by-64 Large Target minima.
- Preserve complete text at 100/125/150 percent without clipping, ellipsis, silent shrink, or outer horizontal scrolling.
- Keep Schedule, Pause, and Minesweeper as excluded dedicated atlas modules.
- Keep Secondary language in current scene captions and History, Contacts slips, and self-talk.
- Keep the full-panel art noncanonical and clearly prototype-only.
- Use `apply_patch` for file edits. Do not use shell write tricks.
- Before every implementation slice, add a guard/assertion and observe the expected RED failure.
- The portable atlas is not a Git worktree. End each slice by appending the file hash and verification result to `sdd/presence-refinement-report.md`.

---

## File Map

- `content/lawful-universe-design-atlas-01.html`: all prototype CSS, fixtures, renderers, modal ownership, art-layer presentation, and parallax behavior.
- `state/atlas-structural-check.ps1`: fast source-level regression contract; every slice starts RED here unless browser behavior is required.
- `state/atlas-browser-check.js`: real-Chrome geometry, focus, accessibility, Dual, and motion assertions.
- `sdd/presence-refinement-report.md`: chronological RED/GREEN evidence and SHA checkpoints for the no-Git portable artifact.
- `state/atlas-verification.md`: final human-readable verification handoff.
- `state/atlas-browser-result.json`: machine-readable final Chrome result.
- `state/atlas-evidence/*.png`: refreshed representative screenshots.

---

### Task 1: One-row Shop selector and compact Backup controls

**Files:**
- Modify: `state/atlas-structural-check.ps1`
- Modify: `content/lawful-universe-design-atlas-01.html`
- Create: `sdd/presence-refinement-report.md`

**Interfaces:**
- Consumes: existing `.shop-quantity__min`, `__minus`, `__value`, `__plus`, `__max`, `.backup-cabinet`, `.backup-actions`, and `[data-backup-action]` hooks.
- Produces: one nonwrapping `.shop-quantity` viewport and compact Backup mode/action rows used by the final browser matrix.

- [ ] **Step 1: Add failing structural requirements**

Append checks that require a one-row selector and compact Backup layout:

```powershell
foreach ($marker in @(
  '.shop-quantity { display:flex;',
  'flex-wrap:nowrap',
  'overflow-x:auto',
  '.shop-quantity > button { flex:0 0 var(--target-min);',
  '.shop-quantity__value { flex:0 0 40px;',
  '.backup-cabinet {',
  'grid-template-rows:auto auto minmax(0,1fr)',
  '.backup-actions { display:flex;',
  'inline-size:fit-content'
)) {
  if (-not $html.Contains($marker)) { throw "Missing presence-refinement layout marker: $marker" }
}
if ($html -match '\.shop-quantity__plus\s*\{\s*grid-column') {
  throw 'Shop quantity controls must not wrap into a second row.'
}
```

- [ ] **Step 2: Run the guard and verify RED**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\state\atlas-structural-check.ps1
```

Expected: FAIL with `Missing presence-refinement layout marker` before any HTML change.

- [ ] **Step 3: Implement the minimal selector and Backup CSS**

Replace the current Shop and Backup layout rules with:

```css
.shop-quantity {
  display:flex;
  flex-wrap:nowrap;
  gap:8px;
  align-items:center;
  overflow-x:auto;
  overflow-y:hidden;
  scroll-behavior:smooth;
  scrollbar-gutter:stable;
}
.shop-quantity > button { flex:0 0 var(--target-min); }
.motion-reduced .shop-quantity { scroll-behavior:auto; }
.shop-quantity__value {
  flex:0 0 40px;
  min-block-size:var(--target-min);
  display:grid;
  place-items:center;
  border:1px solid var(--soot);
  font-variant-numeric:tabular-nums;
}
.backup-cabinet {
  border-right:1px solid var(--soot);
  display:grid;
  grid-template-rows:auto auto minmax(0,1fr);
  gap:10px;
}
.backup-actions {
  display:flex;
  flex-wrap:wrap;
  align-items:flex-start;
  gap:8px;
  border-top:1px solid var(--soot);
  padding-top:10px;
}
.backup-actions button {
  inline-size:fit-content;
  min-inline-size:max(var(--target-min),96px);
  max-inline-size:160px;
  flex:0 0 auto;
}
.backup-actions__reason { flex:1 0 100%; margin:0; font-size:.8em; }
```

Delete the five grid-column placement rules. Keep the DOM order `MIN`, minus,
output, plus, `MAX`. Add one focus listener after the quantity children are
appended:

```js
quantity.addEventListener('focusin', event => {
  event.target.scrollIntoView({ block:'nearest', inline:'nearest', behavior:'smooth' });
});
```

- [ ] **Step 4: Verify GREEN and syntax**

Run the structural guard, then extract the inline script and check it:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\state\atlas-structural-check.ps1
$html = Get-Content -Raw .\content\lawful-universe-design-atlas-01.html
$script = [regex]::Match($html, '<script>([\s\S]*?)</script>\s*</body>').Groups[1].Value
$tmp = Join-Path $env:TEMP 'atlas-presence-inline.js'
Set-Content -LiteralPath $tmp -Value $script -Encoding utf8
node --check $tmp
```

Expected: both exit 0.

- [ ] **Step 5: Record the checkpoint**

Create `sdd/presence-refinement-report.md` with Task 1 RED output, GREEN output,
and:

```powershell
(Get-FileHash -Algorithm SHA256 .\content\lawful-universe-design-atlas-01.html).Hash
```

---

### Task 2: Host-local trusted prompts

**Files:**
- Modify: `state/atlas-structural-check.ps1`
- Modify: `content/lawful-universe-design-atlas-01.html`
- Modify: `state/atlas-browser-check.js`
- Modify: `sdd/presence-refinement-report.md`

**Interfaces:**
- Consumes: `openDemoDialog(model, sourceEl)`, `closeDemoDialog(options)`, `dialogState`, `.host-desktop__computer`, `.host-title__content`, and `#game-canvas`.
- Produces: `dialogMountForSource(sourceEl)`, `collectModalInertRecords(mount, backdrop)`, and stored restoration records in `dialogState`.

- [ ] **Step 1: Add failing structural and browser assertions**

Require these implementation hooks in the structural guard:

```powershell
foreach ($marker in @(
  'function dialogMountForSource(sourceEl)',
  'function collectModalInertRecords(mount, backdrop)',
  "host.dataset.hostKind==='desktop'",
  "host.dataset.hostKind==='title'",
  "mount.append(backdrop)",
  'inertRecords'
)) {
  if (-not $html.Contains($marker)) { throw "Missing host-local dialog hook: $marker" }
}
if ($html.Contains('canvas.append(backdrop)')) {
  throw 'Dialogs must mount through their host-local owner.'
}
```

Add a Chrome assertion after opening the Supportz prompt:

```js
const supportScope = await cdp.eval(`(() => {
  const b=document.querySelector('.demo-dialog-backdrop');
  const c=document.querySelector('.host-desktop__computer');
  const a=document.querySelector('.host-desktop__angela');
  const br=b.getBoundingClientRect(), cr=c.getBoundingClientRect(), ar=a.getBoundingClientRect();
  return { parent:b.parentElement===c, contained:br.left>=cr.left&&br.right<=cr.right&&br.top>=cr.top&&br.bottom<=cr.bottom, avoidsAngela:br.left>=ar.right };
})()` , session);
assertion(supportScope.parent && supportScope.contained && supportScope.avoidsAngela,
  'computer confirmation stays inside the computer and leaves Angela visible');
```

- [ ] **Step 2: Run RED**

Run the structural guard. Expected: FAIL with `Missing host-local dialog hook`.

- [ ] **Step 3: Implement host selection and reversible inert ownership**

Add:

```js
function dialogMountForSource(sourceEl) {
  const host=sourceEl?.closest('[data-host-kind]');
  if (host?.dataset.hostKind==='desktop') return host.querySelector('.host-desktop__computer');
  if (host?.dataset.hostKind==='title') return host.querySelector('.host-title__content');
  return canvas;
}
function collectModalInertRecords(mount, backdrop) {
  const nodes=[$('atlas-nav'),$('specimen-tray')];
  nodes.push(...[...mount.children].filter(node=>node!==backdrop));
  let branch=mount;
  while (branch && branch!==canvas) {
    const parent=branch.parentElement;
    if (!parent) break;
    nodes.push(...[...parent.children].filter(node=>node!==branch));
    branch=parent;
  }
  return [...new Set(nodes)].map(node=>({
    node,
    inert:node.inert,
    ariaHidden:node.getAttribute('aria-hidden')
  }));
}
function setModalInert(records, active) {
  records.forEach(record=>{
    if (active) {
      record.node.inert=true;
      record.node.setAttribute('aria-hidden','true');
    } else {
      record.node.inert=record.inert;
      if (record.ariaHidden===null) record.node.removeAttribute('aria-hidden');
      else record.node.setAttribute('aria-hidden',record.ariaHidden);
    }
  });
}
```

In `openDemoDialog`, resolve `mount`, append the backdrop to it, collect records,
set them inert, and store them in `dialogState`. In `closeDemoDialog`, restore
those exact records before returning focus. Delete the old global
`inertBackground()` helper.

Add `position:relative` to `.host-title__content`. Keep
`.host-desktop__computer` positioned. Constrain the dialog:

```css
.demo-dialog { width:min(420px,calc(100% - 32px)); max-height:calc(100% - 32px); overflow:auto; }
```

- [ ] **Step 4: Run GREEN and existing modal tests**

Run the structural guard and `node --check` on both inline and verifier scripts.
Run the real Chrome verifier. Expected: existing Cancel-first, Tab wrap,
Shift+Tab wrap, Escape, source-focus restore, and Supportz success checks remain
green; the new host containment assertion is green.

- [ ] **Step 5: Record the checkpoint**

Append RED/GREEN output, Chrome result, and the current HTML SHA-256 to the SDD
report.

---

### Task 3: Centred cast and transparent centred caption deck

**Files:**
- Modify: `state/atlas-structural-check.ps1`
- Modify: `content/lawful-universe-design-atlas-01.html`
- Modify: `state/atlas-browser-check.js`
- Modify: `sdd/presence-refinement-report.md`

**Interfaces:**
- Consumes: `renderWitnessedThreeBandHost(model)`, `.host-three-band__portrait`, `.scene-tableau`, `.caption-scroll`, and `.caption-card`.
- Produces: matching `data-participant-count` projections, count-aware centred tracks, and `captionText(text)` line-backed copy.

- [ ] **Step 1: Add RED contracts**

Require `data-participant-count`, four count rules, `justify-content:center`,
`captionText`, transparent deck/cards, and centred prose. Add browser helpers that
compare each participant-group union midpoint with its container midpoint:

```js
const centreDelta = await cdp.eval(`(() => {
  function delta(containerSelector, childSelector) {
    const container=document.querySelector(containerSelector).getBoundingClientRect();
    const children=[...document.querySelectorAll(childSelector)].map(node=>node.getBoundingClientRect());
    const left=Math.min(...children.map(r=>r.left));
    const right=Math.max(...children.map(r=>r.right));
    return Math.abs(((left+right)/2)-((container.left+container.right)/2));
  }
  return {
    portraits:delta('.host-three-band__portrait','.speaker-frame[data-participant]'),
    bodies:delta('.scene-tableau','.scene-tableau__place[data-participant]')
  };
})()`,session);
assertion(centreDelta.portraits<=1 && centreDelta.bodies<=1,
  'portrait and body ensembles share the canvas centre');
```

Expected structural RED: missing participant-count projection.

- [ ] **Step 2: Implement matching count-aware tracks**

Set the count on both containers before appending participants:

```js
const participantCount=beat.participants.length;
portrait.dataset.participantCount=String(participantCount);
sceneField.dataset.participantCount=String(participantCount);
```

Use matching CSS:

```css
.witnessed-host .host-three-band__portrait,
.scene-tableau { justify-content:center; }
[data-participant-count="1"] { grid-template-columns:minmax(220px,320px); }
[data-participant-count="2"] { grid-template-columns:repeat(2,minmax(220px,240px)); }
[data-participant-count="3"] { grid-template-columns:repeat(3,minmax(210px,240px)); }
[data-participant-count="4"] { grid-template-columns:repeat(4,minmax(200px,240px)); }
.speaker-frame { display:grid; place-items:center; }
.speaker-frame::before { width:52px; height:52px; }
```

Do not derive positions from the active speaker.

- [ ] **Step 3: Implement transparent centred captions**

Add:

```js
function captionText(text) {
  const paragraph=document.createElement('p');
  paragraph.className='host-copy caption-copy';
  const line=document.createElement('span');
  line.textContent=text;
  paragraph.append(line);
  return paragraph;
}
```

Use `captionText` for Primary and Secondary caption copy. Apply:

```css
.witnessed-host .host-three-band__deck { background:transparent; }
.caption-scroll { display:grid; justify-items:center; align-content:start; }
.caption-card {
  inline-size:min(100%,44ch);
  text-align:center;
  background:transparent;
  border-inline:0;
}
.caption-copy { margin-inline:auto; text-align:center; }
.caption-copy span {
  background:color-mix(in srgb,var(--institutional-cream) 72%,transparent);
  padding:.08em .3em;
  box-decoration-break:clone;
  -webkit-box-decoration-break:clone;
}
.high-contrast .caption-copy span {
  background:color-mix(in srgb,var(--institutional-cream) 94%,transparent);
}
```

Retain a non-colour current/focus boundary and the pinned transport rail.

- [ ] **Step 4: Verify GREEN across scene fixtures**

Run the structural guard, syntax checks, and Chrome checks for Narrative
two-person, ensemble, Hospital, Ending, and replay. At 100/125/150 percent and
Primary/Dual, assert midpoint delta at most 1px, transparent deck/card computed
background, centred text, no clipping, and no outer horizontal overflow.

- [ ] **Step 5: Record the checkpoint**

Append evidence and HTML SHA-256 to the SDD report.

---

### Task 4: Full-panel Angela art and transparent overlays

**Files:**
- Modify: `state/atlas-structural-check.ps1`
- Modify: `content/lawful-universe-design-atlas-01.html`
- Modify: `state/atlas-browser-check.js`
- Modify: `sdd/presence-refinement-report.md`

**Interfaces:**
- Consumes: `renderAngelaPanel(fixture)`, `prototypeFigure`, keepsake projection, `.angela-panel__hud`, `.angela-panel__tableau`, `.angela-panel__self-talk`, and existing Dual state.
- Produces: `.angela-art-stage`, `.angela-art-layer--background`, `--midground`, `--character`, transparent HUD/self-talk overlays, and retained Dual self-talk/Contacts behavior.

- [ ] **Step 1: Add failing contracts**

Add structural assertions requiring all three art layers, `inset:-8px`,
`overflow:hidden`, transparent HUD/self-talk in both palettes, and absence of
the visible `Run status` and `Angela` heading nodes. Keep the existing Dual
Contacts fixture and require a new `.self-talk__secondary` projection.

Add Chrome assertions:

```js
const angelaPresentation = await cdp.eval(`(() => {
  const panel=document.querySelector('.angela-panel');
  const art=document.querySelector('.angela-art-stage');
  const hud=document.querySelector('.angela-panel__hud');
  const talk=document.querySelector('.angela-panel__self-talk');
  return {
    artCovers:art.getBoundingClientRect().left<=panel.getBoundingClientRect().left && art.getBoundingClientRect().right>=panel.getBoundingClientRect().right,
    noArtScroll:art.scrollHeight===art.clientHeight && art.scrollWidth===art.clientWidth,
    hudTransparent:getComputedStyle(hud).backgroundColor==='rgba(0, 0, 0, 0)',
    talkTransparent:getComputedStyle(talk).backgroundColor==='rgba(0, 0, 0, 0)',
    visibleHeadings:[...panel.querySelectorAll('.host-kicker')].map(n=>n.textContent)
  };
})()`,session);
assertion(angelaPresentation.artCovers && angelaPresentation.noArtScroll &&
  angelaPresentation.hudTransparent && angelaPresentation.talkTransparent &&
  !angelaPresentation.visibleHeadings.includes('Run status') &&
  !angelaPresentation.visibleHeadings.includes('Angela'),
  'full-panel Angela art stays fixed behind transparent unlabeled overlays');
```

Expected RED: missing `.angela-art-stage`.

- [ ] **Step 2: Build the fixed layered stage**

In `renderAngelaPanel`, keep the semantic DOM order HUD, tableau, self-talk, but
make the tableau the absolute full-panel art owner. Build:

```js
const scene=document.createElement('div');
scene.className='angela-art-stage angela-tableau__scene';
const background=document.createElement('div');
background.className='angela-art-layer angela-art-layer--background';
const midground=document.createElement('div');
midground.className='angela-art-layer angela-art-layer--midground';
const character=document.createElement('div');
character.className='angela-art-layer angela-art-layer--character';
character.append(prototypeFigure('angela','working'));
scene.append(background,midground,character);
```

Append keepsakes to `midground`. Use:

```css
.angela-panel { position:relative; overflow:hidden; isolation:isolate; }
.angela-panel__tableau { position:absolute; inset:0; z-index:0; padding:0; overflow:hidden; border:0; background:transparent; }
.angela-art-stage { position:absolute; inset:-8px; overflow:hidden; pointer-events:none; }
.angela-art-layer { position:absolute; inset:0; will-change:transform; }
.angela-art-layer--background {
  background:
    linear-gradient(to bottom,var(--green-grey) 0 44%,var(--institutional-cream) 44% 100%);
}
.angela-art-layer--background::before {
  content:'';
  position:absolute;
  inset:48px 42px auto auto;
  inline-size:152px;
  block-size:176px;
  border:3px double var(--soot);
  background:linear-gradient(145deg,var(--faded-blue),var(--bruised-lavender));
}
.angela-art-layer--midground::before {
  content:'';
  position:absolute;
  inset:auto 20px 86px 20px;
  block-size:112px;
  border:2px solid var(--soot);
  background:color-mix(in srgb,var(--panel) 82%,transparent);
}
.angela-art-layer--character {
  display:grid;
  align-items:end;
  justify-items:center;
  padding-bottom:72px;
}
.angela-art-layer--character .figure-study { margin:0; }
.angela-panel__hud { grid-row:1; z-index:2; background:transparent; border:0; }
.angela-panel__self-talk { grid-row:3; z-index:2; background:transparent; border:0; display:grid; align-content:end; }
```

Remove the two visible heading nodes. Keep `aria-label="Angela status panel"` and
give self-talk an assistive-only `aria-label="Angela self-talk"`.

- [ ] **Step 3: Retain exact Dual projections**

For Dual self-talk, render Primary and Secondary in the same semantic lane:

```js
const primary=textNode('I can continue from here.','host-copy');
const secondary=textNode('我可以從這裡繼續。','host-copy self-talk__secondary');
talk.append(primary,secondary);
```

Do not remove `.contact-slip__secondary` or the `dual_slip` fixture. Add a
History Secondary line when `state.language==='dual'`, using each beat's
existing `secondary` field.

- [ ] **Step 4: Add transparent readability washes**

Use pseudo-elements behind content rather than opaque panels:

```css
.angela-panel__hud::before {
  content:''; position:absolute; inset:0 0 38% 0; z-index:-1;
  background:linear-gradient(to bottom,color-mix(in srgb,var(--panel) 65%,transparent),transparent);
  pointer-events:none;
}
.angela-panel__self-talk::before {
  content:''; position:absolute; inset:35% 0 0; z-index:-1;
  background:linear-gradient(to top,color-mix(in srgb,var(--panel) 65%,transparent),transparent);
  pointer-events:none;
}
.high-contrast .angela-panel__hud::before {
  background:linear-gradient(to bottom,color-mix(in srgb,var(--panel) 92%,transparent),transparent);
}
.high-contrast .angela-panel__self-talk::before {
  background:linear-gradient(to top,color-mix(in srgb,var(--panel) 92%,transparent),transparent);
}
```

Ensure both overlay sections are positioned and remain visually transparent in
computed `background-color`.

- [ ] **Step 5: Verify GREEN**

Run the structural guard, syntax checks, and Chrome tests at Light/Dark,
100/125/150, 48/64, Primary/Dual, and High Contrast. Verify safe stat maxima,
all three keepsakes, bottom self-talk, Contacts Secondary, scene Secondary,
History Secondary, and no art scrollbar.

- [ ] **Step 6: Record the checkpoint**

Append evidence and HTML SHA-256 to the SDD report.

---

### Task 5: Pointer-only micro-parallax and neutral recentering

**Files:**
- Modify: `state/atlas-browser-check.js`
- Modify: `state/atlas-structural-check.ps1`
- Modify: `content/lawful-universe-design-atlas-01.html`
- Modify: `sdd/presence-refinement-report.md`

**Interfaces:**
- Consumes: the three `.angela-art-layer` elements from Task 4, atlas presentation state, and `openDemoDialog` from Task 2.
- Produces: `bindAngelaParallax(panel)`, `setAngelaParallax(panel,x,y,immediate)`, and `recenterAngelaParallax(immediate)`.

- [ ] **Step 1: Write browser RED cases before behavior**

Add tests that dispatch pointer movement inside the Angela panel and compare
layer transforms. Assert bounds of 8/4, 5/3, and 3/2 logical pixels. Then
dispatch `pointerleave`, window `blur`, document visibility simulation through
the exposed helper, and modal opening; assert every transform returns to zero.
Set Reduced Motion and repeat pointer movement; assert transforms remain zero.

Define a test-safe read-only snapshot and include it as the
`parallaxSnapshot` property in the existing frozen `window.DesignAtlas` object:

```js
function parallaxSnapshot() {
  return [...document.querySelectorAll('.angela-art-layer')]
  .map(node=>({ layer:node.className, transform:getComputedStyle(node).transform }));
}
```

Expected RED: `bindAngelaParallax is not defined` or unchanged transforms under
standard pointer motion.

- [ ] **Step 2: Implement clamped layer movement**

Add:

```js
const ANGELA_PARALLAX=Object.freeze({
  background:{x:8,y:4},
  midground:{x:5,y:3},
  character:{x:3,y:2}
});
function setAngelaParallax(panel,x=0,y=0,{immediate=false,duration=140}={}) {
  const layers=[['background',ANGELA_PARALLAX.background],['midground',ANGELA_PARALLAX.midground],['character',ANGELA_PARALLAX.character]];
  layers.forEach(([name,bounds])=>{
    const node=panel?.querySelector(`.angela-art-layer--${name}`);
    if (!node) return;
    node.style.transition=immediate?'none':`transform ${duration}ms ease-out`;
    node.style.transform=`translate(${(-x*bounds.x).toFixed(2)}px,${(-y*bounds.y).toFixed(2)}px)`;
  });
}
function recenterAngelaParallax(immediate=false) {
  document.querySelectorAll('.angela-panel').forEach(panel=>setAngelaParallax(panel,0,0,{immediate,duration:180}));
}
function bindAngelaParallax(panel) {
  const fine=matchMedia('(hover:hover) and (pointer:fine)').matches;
  if (!fine || state.motion==='reduced') return setAngelaParallax(panel,0,0,{immediate:true});
  panel.addEventListener('pointermove',event=>{
    const rect=panel.getBoundingClientRect();
    const x=Math.max(-1,Math.min(1,((event.clientX-rect.left)/rect.width)*2-1));
    const y=Math.max(-1,Math.min(1,((event.clientY-rect.top)/rect.height)*2-1));
    setAngelaParallax(panel,x,y,{duration:140});
  });
  panel.addEventListener('pointerleave',()=>setAngelaParallax(panel,0,0,{duration:180}));
}
```

Call `bindAngelaParallax(panel)` from `renderSpecimen()` after the rendered host
has been appended to `canvas`. Recenter before a dialog opens, on `window.blur`,
on hidden visibility, and when Reduced Motion is selected. A fresh pointermove
is the only resumption trigger. Add `parallaxSnapshot` to the existing
`Object.freeze({ ... })` export literal; do not mutate that frozen object after
creation.

- [ ] **Step 3: Preserve neutral non-pointer behavior**

Do not bind touchmove, deviceorientation, keyboard focus, controller focus, or
pointer capture. Add:

```css
.motion-reduced .angela-art-layer { transition:none !important; transform:none !important; }
```

- [ ] **Step 4: Run GREEN dynamic verification**

Run Chrome at standard motion and move to all four panel corners. Assert each
layer stays within its exact bounds. Verify pointer leave, modal open/cancel,
blur, and Reduced Motion return zero transforms without moving HUD/self-talk
rectangles. Assert narrative `.scene-tableau` transforms never change.

- [ ] **Step 5: Record the checkpoint**

Append RED/GREEN Chrome evidence and HTML SHA-256 to the SDD report.

---

### Task 6: Full atlas regression, visual evidence, and handoff

**Files:**
- Modify: `state/atlas-browser-check.js`
- Modify: `state/atlas-verification.md`
- Modify: `state/atlas-browser-result.json`
- Modify: `state/atlas-evidence/*.png`
- Modify: `sdd/presence-refinement-report.md`

**Interfaces:**
- Consumes: Tasks 1-5 and the existing live server at `http://127.0.0.1:9417/`.
- Produces: final real-Chrome pass, refreshed evidence, exact hash/byte handoff, and a reviewer-ready atlas link.

- [ ] **Step 1: Extend the final browser matrix**

Cover:

- every existing fixture route;
- Shop batchable at 48 and 64 targets;
- Backup Save, Load, and title Log in;
- desktop and title confirmations;
- Narrative two-person, ensemble, Dual, History, Hospital, Ending, and replay;
- Angela ordinary HUD, condition HUD, self-talk, Dark refusal, and keepsakes;
- Light/Dark, 100/125/150, 48/64, Standard/High Contrast, all colour presets,
  Primary/Dual, Standard/Reduced Motion; and
- 1440-by-900, 1280-by-720, and 1280-by-900 physical viewports.

- [ ] **Step 2: Run all static and syntax gates**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\state\atlas-structural-check.ps1
node --check .\state\atlas-browser-check.js
$html = Get-Content -Raw .\content\lawful-universe-design-atlas-01.html
$script = [regex]::Match($html, '<script>([\s\S]*?)</script>\s*</body>').Groups[1].Value
$tmp = Join-Path $env:TEMP 'atlas-presence-final-inline.js'
Set-Content -LiteralPath $tmp -Value $script -Encoding utf8
node --check $tmp
```

Expected: all exit 0 with no output indicating warnings.

- [ ] **Step 3: Run isolated Chrome**

Run:

```powershell
node .\state\atlas-browser-check.js
```

Expected: HTTP 200, every assertion green, console errors 0, console warnings
0, external requests 0, and requests limited to the local HTML and lineup PNG.

- [ ] **Step 4: Inspect representative screenshots**

Inspect at minimum:

- Shop batch selector at 48 and 64;
- Supportz computer-contained confirmation;
- compact Backup Save and Load;
- centred two-person and ensemble scenes;
- transparent centred Dual captions;
- full-panel Angela ordinary, self-talk, keepsakes, and Dark states;
- High Contrast transparent overlays; and
- Reduced Motion neutral Angela composition.

Reject any exposed overscan edge, opaque HUD/self-talk rectangle, visible `RUN
STATUS`/`ANGELA`, left-packed cast, off-centre caption, modal over Angela,
truncated control, or leaked Secondary copy outside its approved surfaces.

- [ ] **Step 5: Request fresh-context review**

Give the current HTML hash, spec, plan, structural guard, browser result, and
representative screenshots to an independent reviewer. Resolve every Critical
or Important finding with a new RED/GREEN round before proceeding.

- [ ] **Step 6: Write the final report**

Update `state/atlas-verification.md` with the exact byte count, SHA-256, Chrome
version, fixture count, screenshot count, viewport matrix, motion matrix, and
zero-error/warning/external-request claims. Update
`state/atlas-browser-result.json` from the final run and close the SDD report
with the same hash.

- [ ] **Step 7: Hand off the live and permanent links**

Verify `http://127.0.0.1:9417/` returns 200 and that the permanent HTML file
opens directly. Hand both links to the user and explicitly invite visual
amendments before any Godot implementation.
