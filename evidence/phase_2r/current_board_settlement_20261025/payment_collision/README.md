# Existing next-day payment defect

The probe reproduces a defect. It does not prove corrected behavior.
Each run passed 27 assertions that expect the incorrect refusal.
These assertions are excluded from settlement acceptance totals.

## Revisions

- Master: `b824a99b913e8b2d84a25b52eeed60a42e4c98c9`.
- Candidate: `6b341e0cde34d57791a40c3fee5c66bc75ff85ce`.
- Engine: Godot 4.6.3.

Both runs returned `paid_start_receipt_required` during unpaid next-day Debug preparation.
Both runs retained two available rounds.
Both days used round ordinal 1 in the same Run.
The issued causal-day identities were different.

## Scope

The probe uses real board generation, the coordinator, first Reveal, and live ordinal allocation.
It uses actual GameState day renewal and adoption.
The fixture supplies checkpoint and native-entry connections.
The fixture directly supplies Debug Key after day adoption.
It does not exercise canonical SaveManager persistence, rendered interaction, or complete Save/Load.

The probe uses the existing fake file and durable checkpoint connections.
The shell did not set `DWM_TEST_ROOT` or `XDG_DATA_HOME` explicitly.
GUT reported `/root/.local/share/godot/app_userdata/DWM` as its user directory.

## Original invocation

The candidate checkout contained an identical probe at `.godot/test_next_day_payment_probe.gd`.
The following command ran from the candidate checkout:

```bash
/tmp/dwm-godot/Godot_v4.6.3-stable_linux.x86_64 --headless --path . \
  -s addons/gut/gut_cmdln.gd \
  -gtest=res://.godot/test_next_day_payment_probe.gd \
  -gunit_test_name=test_next_day_payment_probe -gexit \
  > /tmp/dwm-next-day-payment.log 2>&1
```

The master checkout contained the same probe.
Its invocation replaced `--path .` with `--path ../dwm`.
Its log destination was `/tmp/dwm-next-day-payment-master.log`.
The retained logs contain the observed identities and refusal.

## Next regression test

Use actual day renewal and live ordinal allocation.
Require unpaid next-day preparation to succeed without charging.
Require its first successful Reveal to charge exactly one round.
Also require paid F5 preparation to retain payment status.
Do not correct one case by breaking the other case.
