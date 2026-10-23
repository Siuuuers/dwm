# Contacts integration review — final fix verification

**Result: no remaining blocking finding in the four reviewed fixes.** This is
an independent source review of the isolated Contacts integration, with a readback
of the real-owner test receipt. It is not a full-game startup or release claim.

| Earlier finding | Verified correction |
|---|---|
| Desktop scene freed before day advancement | `ApplicationBootstrap.gd` retains a `RefCounted` `ContactsDesktopEvictionPort`. Its `WeakRef` resolves the current view; an absent view succeeds because its UI cache is already gone. Host day advancement still executes. |
| Saved active Contacts restored only in host state | `ComputerDesktop.configure_contacts()` mounts Contacts when the restored host reports it active. A newly constructed panel begins with no selected thread. |
| Reply focus lost when the thread is rebuilt | `ContactListApp._present()` captures visible reply focus and restores it to the replacement reply button, or the transcript when reply is no longer required. |
| Missing translation adopted a pending locale | `refresh_view()` obtains the requested-locale projection before adopting it. A failed projection retains the current locale and content. Presentation rejection restores the locale field. |

`ContactStatus` displays a localized technical “Conversation unavailable” message
outside correspondence after a failed operation. Missing content does not become
invented story text or a silent apparent success. Locale preservation was reviewed
against the real presentation port's validated output; this is not a claim of
transactional rollback for arbitrary malformed third-party projection objects.

## Evidence and source scope

Readback: `.godot/contacts-real-owner-j7d6pe6u/result.json`, SHA-256
`abde73db0f7e5a2c09ba59857ed709620c9bce1656d38030462c8efcac282fcd`.
It reports `passed: true` for real GameState preview/commit and real Bootstrap
Contacts configuration under manually prepared fixture startup. Its test source
covers disposal of the desktop, host day advancement without a view, rebinding a
replacement view to the same retained adapter, and one eviction to the live view.

Of 139 recorded source bindings, 138 matched on this review. The sole mismatch
was `scripts/ui/ContactListApp.gd`, edited subsequently for UI layout. Therefore
this receipt supports the unchanged owner/lifecycle code; final shell geometry
and input checks must cover the latest app bytes separately. The receipt records
inherited sandbox certificate and NUL-character diagnostics; no clean-log claim
is made. This reviewer did not rerun the engine.

Reviewed source hashes:

| File | SHA-256 |
|---|---|
| `autoload/ApplicationBootstrap.gd` | `3a62828c65f7e86da6433fd982b6c5f41ea98f331bb5102e6f82bf38f850f575` |
| `scripts/ui/ComputerDesktop.gd` | `58dd31ec4489a410ddf178e202ec93176ad544ad404113cdf37965a6c41dc20e` |
| `scripts/ui/ContactListApp.gd` | `bb3ba8537acd4d7cd9fa708685d1881dfa9be03728eedd9c970c5faf6e2427f0` |
| `scripts/ui/contacts/ContactsPanel.gd` | `4f6e692fa50f571ce90aa2689c0bcff0d0916cb73339199f455d701d111d18ab` |

## Remaining product scope

- The production correspondence catalog is intentionally empty. Approved body
  text, translations, and authored timestamps still need to be supplied before
  real unlocked conversations can display. Test prose is not production content.
- The adapter uses existing solo/link open and reply owners. It supplies no
  general history/follow-up read command; UI-owned mutations were not invented
  to fill that gap. Complete Contacts read/witness behavior is not claimed.
- This review does not certify full application startup, all restored app types,
  cross-app board transitions, GPU rendering, hardware accessibility, or release
  packaging. Those are outside the four fixes and real-owner receipt examined.
- Normal restore replaces MainGameScene through SceneRouter. The earlier
  hypothesis that the same live Contacts cache necessarily survives that normal
  path was withdrawn; it did not justify an additional restore listener.

Only this review receipt was written during the verification pass.
