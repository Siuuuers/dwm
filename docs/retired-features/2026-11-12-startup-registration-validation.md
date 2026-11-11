# Repeated shipped-registration validation at startup

Retired the startup structural-validation and canonical-re-encoding pass.
Generation and exact-package checks own these checks for shipped content.
The existing registration owner builds immutable lookup tables directly and keeps
one canonical-text SHA for save/content identity. Generic caller-data validators,
debug fixture checks, saved-data fields and recovery behavior remain.

Caller audit, ownership tests and matched measurements:
[direct registration evidence](../agent/2026-11-12-direct-registration.md).
