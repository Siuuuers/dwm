# Software responsibility boundary — 4 October 2026

Owner-approved scope clarification, recorded from the 4 October 2026 conversation.
Applies to continuing game work on PR #1; Settings `dwm-eei.2` is its first application.
This records a decision, not implementation or test acceptance.

## Promise and scope

Deliver the promised game behavior through the simplest coherent implementation.
We own our software's response, not repair of someone else's system.

In scope:
- Correct behavior for supported inputs and supported environments.
- Truthful success/failure reporting and preservation of existing save, recovery,
  History and consequence-once guarantees.
- Small fixes for reachable software gaps, reusing canonical owners.
- Proportionate tests of our response to relevant dependency errors.

Out of scope:
- Hardware diagnosis or repair, operating-system repair, and repair of other software.
- Guaranteeing successful operation on a failing or unavailable external dependency.
- Elaborate automatic recovery, speculative defensive frameworks, and defenses
  against states excluded by an established authoritative contract without a
  concrete reachable counterexample.

An externally caused error still reaches our software. Handling that result
honestly is in scope; diagnosing or repairing its external cause is not.
Valid UI input does not establish that a file operation succeeded.

## Settings application

Normal changes apply and save through the existing owners.
A confirmed uncommitted change retains or restores the proven previous value
and reports a concise error; ordinary use may continue where safe.
An indeterminate result reports uncertainty, never success or a falsely proven
rollback. Preserve existing mutation fences and prevent conflicting actions
from proceeding on an assumed storage result.

Do not force an automatic restart. Do not make live, uninterrupted recovery a
new requirement merely to handle an external failure. No new live Retry API,
fatal-gate reset, or recovery manager is authorized by this scope clarification.
Existing canonical reconciliation remains authoritative wherever already used;
resumption that depends on durable state requires its proof. A message does not
itself establish reconciliation or authorize bypassing a safety fence.

This narrows the earlier handoff/Bead wording about recovery and Retry to truthful
failure handling and preservation of existing protections. It does not require
building hardware recovery, a mandatory-restart flow, or a new in-process recovery
architecture. It does not remove supported-format correctness or existing recovery
contracts, and it does not close the whole Settings Bead.

## Work and evidence rule

Trace an ordinary supported action through its existing owners before changing it.
Establish a reachable gap; inspect parent-host handling before adding a local
subscription or another owner. If the promise is already satisfied, no runtime
change is needed. Test our response at the appropriate boundary, not whether we
can repair the external system. Reuse accepted evidence, and do not turn this
scope clarification into a new broad fault-injection campaign.

Runtime changes still require the relevant cloud-only Godot 4.6.3 standard
GDScript/PowerShell checks. This records-only publication claims no new engine
pass, runtime fix, or Bead completion.
