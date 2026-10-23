# Recovered group-invitation labels and sample copy

> **Retained historical material.** This is the complete group-invitation label and sample-copy section from the recovered catalog. Its calendar, participant roles and keys describe the older design. Read the [current foundation](../09-priscilla-foundation-amendment.md) before reuse; this move does not reinstate that schedule or make the sample lines current dialogue.

[Exact original section](https://github.com/Siuuuers/dwm/blob/7813de047f5e69b24ea0a84d6857d683f2f0c290/docs/design/recovered/CONTENT.md#6-group-invitation-labels--mapping-keep-narrative-no-code-mirror) · [Recovered technical catalog](../../docs/design/recovered/CONTENT.md)

# 6. Group invitation labels — mapping (KEEP: narrative, no code mirror)
The group timeline parts are `label` segments **inside** the per-friend/day contact `.dtl`
(see `DIALOGIC.md`), not standalone files. The participant-based names are easy to
misread; this table is the canonical meaning.

| Logical ID (example) | Lives in file | Shown when |
| --- | --- | --- |
| `contact.invitation.group.priscilla_lavinia.day2.first_open_priscilla` | `contacts/priscilla_day2.dtl` | Priscilla is the **first** contact opened among the pair (she becomes the inviter) |
| `contact.invitation.group.priscilla_lavinia.day2.second_open_priscilla` | `contacts/priscilla_day2.dtl` | Priscilla is the **second** contact opened (Lavinia opened first) |
| `contact.invitation.group.priscilla_lavinia.day2.first_open_lavinia` | `contacts/lavinia_day2.dtl` | Lavinia is the **first** contact opened among the pair |
| `contact.invitation.group.priscilla_lavinia.day2.second_open_lavinia` | `contacts/lavinia_day2.dtl` | Lavinia is the **second** contact opened (Priscilla opened first) |
| `...need_reply_priscilla_first` | participant dtl | shown when the second opener must reply Priscilla first |
| `...offer` | participant dtl | group offer text |
| `...missed_question_priscilla` / `...missed_question_lavinia` | participant dtl | missed-date question |

> Two distinct namespaces — do not conflate:
> 1. **`.dtl` label IDs** (`first_open_<participant>` / `second_open_<participant>` / `need_reply_<participant>_first`) are `label` segments inside the per-participant `.dtl`, named by **participant**, not by open order. The **first** contact opened among the pair is the inviter (`inviter_id`). Full authority: `DIALOGIC.md §6`.
> 2. **Localization `.text` keys** use the UNIFIED scheme below; never derive a `.text` key from a `.dtl` label name.

**Unified key scheme:** `invitation.group.priscilla_lavinia.day{N}.{inviter}.{part}`
- `{inviter}` ∈ `priscilla` | `lavinia` (the dynamic inviter)
- `{part}` ∈ `first.open.text` | `second.open.text` | `need_reply_<other>_first` (where `<other>` = the non-inviter)
- Day 2 and Day 6 both use this scheme, substituting the day number.

**Group missed-date guilt message (next-day variant).** When a group date is stood up (accepted but unscheduled), EACH participant sends a group-variant guilt message on day D+1 IN ADDITION to the `twofriends` scene. Keyed by the SPEAKING participant (the opened contact), not the inviter: `invitation.group.priscilla_lavinia.day{N}.missed_question_{participant}` (`{participant}` ∈ `priscilla` | `lavinia`). Maps to the `label missed_question_{participant}` segment inside that participant's daily contact `.dtl`.

Meaning is the contract, wording is not.

**When `inviter_id == "priscilla"` (Priscilla invites, Lavinia is the other friend):**
- `invitation.group.priscilla_lavinia.day2.priscilla.first.open.text` — en `I'll swing by and pick you up — want Lavinia to join us?`
- `invitation.group.priscilla_lavinia.day2.priscilla.second.open.text` — en `Lavinia said she'll pick you up too, right?`
- `invitation.group.priscilla_lavinia.day2.priscilla.need_reply_lavinia_first` — en `You need to reply Lavinia first`

**When `inviter_id == "lavinia"` (Lavinia invites, Priscilla is the other friend):**
- `invitation.group.priscilla_lavinia.day2.lavinia.first.open.text` — en `Priscilla said that she will pick me up, would you come too?`
- `invitation.group.priscilla_lavinia.day2.lavinia.second.open.text` — en `Priscilla said that you will also pick me up, right?`
- `invitation.group.priscilla_lavinia.day2.lavinia.need_reply_priscilla_first` — en `You need to reply Priscilla first`

**Swap rule:** `ContactListApp` / `DialogicTimelineCatalog` selects the key by `GameState` `inviter_id` for the pair, inserting `{inviter}` into the unified key. `first_open_*` / `second_open_*` labels inside the `.dtl` still indicate *open order* for layout only; the *voice* (which key) is chosen by `inviter_id`. Day 6 mirrors Day 2 by substituting `day6`.

---
