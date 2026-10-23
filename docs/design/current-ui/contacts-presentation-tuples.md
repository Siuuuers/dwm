# Contacts presentation tuple implementation

`ContactsTheme` projects the sixteen exact authored combinations from
[SettingsPaletteRegistry](../../../scripts/settings/SettingsPaletteRegistry.gd)
into the Contacts materials. It is an implementation map, not a second literal
palette table or a change to the accepted [Contacts dossier](contacts.md).
Unknown palette/contrast/preset keys and days outside 1–7 fail resolution.

| Contacts role | Source | Week treatment |
| --- | --- | --- |
| instrument, paper, outgoing plum | face, paper, inward_preview | shared room tint |
| ink, bone | paper_ink, ink | fixed copy |
| filed, gold | filed, focus | fixed selection and Focus |
| paper_mark | untinted paper | fixed Unread punch and outgoing notch |
| identity_1 | structure | fixed Fog Blue identity |
| void | invariant `#0b0d13` | fixed identity backing in both masters |
| identity_0, identity_2 | provisional `#756477`, `#4f665c` | fixed Mauve and Verdigris identities |

The two identity literals have no equivalent Settings tuple role. Their fixed
morphologies and Void backing preserve the three person identities while the
shared filed and focus accents vary by authored accessibility tuple. Day 1
Standard retains all prior Contacts colours. High Contrast has zero week
amplitude; CVD presets age room lightness only. Copy, Focus, selection, identity,
Unread, and the outgoing notch do not tint. The unit test checks the drawn
text, row, scroll Focus, state, message, and identity colour pairings for all
sixteen tuples on all seven days. Rendered and assistive-technology review are
separate acceptance work.

The installed Desktop palette and day now reach Contacts. Colour-only preference
signals repaint existing nodes without reading correspondence or issuing a reply
command. Text, timestamps, friend selection, scroll, focus, and pending reply
receipts remain in place. The Desktop also keeps its displayed unread fact when
only colours change; normal source events still refresh it.

The eleven former component colour literals remain exact in Day 1 Standard.
This does not claim identical full-app pixels: Contacts previously never received
the installed Midnight palette, and the expanded transcript-button focus ring
previously used Gold on paper (1.55:1 in Day 1 Standard). That ring now uses paper
ink, while the hidden top-bar button retains Gold on its dark surface. The
component's identity backing, unread punch and outgoing notch remain fixed.
Disabled reply/retry captions now also use authored Bone rather than the engine's
default disabled-text colour; pending/busy input admission remains unchanged.
