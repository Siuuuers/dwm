# First Windows export: package passed, source custody failed

Run: https://github.com/Siuuuers/dwm/actions/runs/39818363844
Source: d5eb03ef2d72c5b7cad4265bc83d0d4a969c3e29
Original Actions artifact 12442888834: 99,891,314 bytes, SHA256 b4a69ec135c18e5a9706e4dcf664adabe32d67a7b174b93138e37dfb73218936. It includes the generated validation package; original archive remains available from Actions until expiry.

The two binary evidence parts here reconstruct a derived 575,497-byte ZIP (SHA256 cab17a1dbc9b2687ac31ecf23d166909d9042f73fae791c4c46b55079114bfed). It retains every original artifact member except the inner executable-package ZIP, without changing member bytes. It is not the original artifact ZIP.

Export, isolated headless startup (240 iterations) and PCK audit passed: 122 runtime data files, seven DayN DTL files and the order JSON matched source. Final source comparison failed because export generated 11 previously absent .dtl.uid sidecars. No existing retained file changed; registration JSON and excluded development metadata stayed identical.

Independent read-only review verified all retained size/SHA256/Git blob records and the exact new UID set. Correction fa8cf991fcf57d5657c789de522a95e3bb1450bd commits only those 11 native-generated sidecars. No runtime, authored text, registration or deadline change. Export-only rerun 39819038999; no repeated rendered journey. Keep this run's overall result failed even though its package subchecks passed.
