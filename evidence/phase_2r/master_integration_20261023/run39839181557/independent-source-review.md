# Independent finite inverse review

Static acceptance of patch SHA256 `8c2ccc42fd5043b8c8885ba7e9324079440d1bfede8f1063ebd33977f0fb1428` for focused cloud qualification. No runtime acceptance claimed.

Independently read exact Git GameState source7606e994 and accepted23d8b3df. Both equal proposal source copies after CRLF→LF normalization. Parsed18 spans directly from the proposed GDScript, checked ordered non-overlap, positive lengths, bounds and valid UTF8 boundaries, applied inclusive-start/exclusive-end byte slices, and obtained exact accepted Git bytes. Current whole-source SHA c3b9949b… and accepted SHA6cbd8f93… independently match.

Compared every pre-existing test/helper body: only _assert_frozen_provenance changes. All five test bodies, six-direction historical loop, four current case bodies, historical methods/artifact restoration and existing Notes/marker/scene-extension inverse helpers remain unchanged. The supplied inspected Python layer verifier also confirms all existing intermediate seals unchanged. No historical hash is resealed.

The new whole-current hash is checked before span application. Sample unknown byte mutations inside removed spans and outside them fail that guard. The bounded89KB removal is not a wildcard exemption: every byte is authenticated by the complete current hash, the18 fixed spans reconstruct exact accepted source, and the existing full historical reconstruction remains mandatory. The helper is about2KB and does not introduce a general patch engine.

GDScript static review: source.to_utf8_buffer infers PackedByteArray; slice(begin,end) uses end-exclusive indices and slice(cursor) appends the remaining bytes; append_array mutates the owned restored buffer; typed int/String assignments read literal array values; all selected boundaries are valid UTF8. Existing code already uses typed Array iteration. No obvious parse/type issue found, but engine compilation still belongs to cloud qualification.

Known scope retained: historical classes inherit current GameState and override selected old methods; these probes exercise reset legacy gameplay, not every scene-assignment path. The inverse authenticates source relationship and unknown-drift rejection; it does not prove semantic correctness of all newly removed scene functions. No new limitation is introduced by this finite helper. Do not generalize its passing result into scene-wide restore acceptance.

No blocker found. Use focused original tests/negative controls on the concrete candidate, retain unchanged old failure evidence, and inspect cloud result before broad acceptance.
