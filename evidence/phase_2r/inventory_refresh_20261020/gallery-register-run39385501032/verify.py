import hashlib, json, pathlib, sys, zipfile

archive = pathlib.Path(sys.argv[1])
expected_digest = sys.argv[2].removeprefix('sha256:')
raw = archive.read_bytes()
assert hashlib.sha256(raw).hexdigest() == expected_digest
with zipfile.ZipFile(archive) as z:
    names = z.namelist()
    assert len(names) == len(set(names))
    assert all(not n.startswith('/') and '..' not in pathlib.PurePosixPath(n).parts for n in names)
    assert z.testzip() is None
    members = {n: z.read(n) for n in names}
    report = json.loads(members['measurements.json']) if 'measurements.json' in members else None
    provenance = json.loads(members['provenance.json'])
    assert provenance['source'] == '27fe2eb5dbea6345e62d83c611146a2e5199a944'
    assert provenance['tree'] == 'ed3493c40dc36d8346e42ee60d466e01bcc53ee3'
    assert provenance['controller'] == 'a3c37fb2417092f3aa783154cc2b0fec88da4ce6'
    assert provenance['run_id'] == '39385501032' and provenance['attempt'] == '1'
    receipts = {p: json.loads(members[p + '-process.json']) if p + '-process.json' in members else None for p in ['import','render']}
    result = {'archive_bytes':len(raw),'archive_sha256':expected_digest,'provenance':provenance,
        'processes':receipts,'report':report,'members':[{'path':n,'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()} for n,b in members.items()]}
    if report and report['ok']:
        assert not report['failures'] and report['collapsed_counts'] == [0,1]
        samples = report['samples']
        assert report['requested_tuples'] == len(samples) == 18
        assert {(s['locale'],s['percent'],s['palette']) for s in samples} == {(l,n,p) for l in ['en','zh_CN','zh_HK'] for n in [100,125,150] for p in ['AfterHours','Midnight']}
        assert len([n for n in names if n.endswith('.png')]) == 18
        from PIL import Image
        import io
        for s in samples:
            assert Image.open(io.BytesIO(members[s['file']])).size == (640,360)
            assert s['inspection_writes'] == s['replay_starts'] == 0
            assert s['focus_perimeter_enclosed'] and s['plane_and_focus_pixels']
        setup = report['setup_receipts']
        assert len(setup) == 9
        assert [r['expected_count'] for r in setup if 'owner_variants' in r] == [0,1,2]
        for r in setup:
            if 'owner_variants' in r:
                assert r['owner_variants']['ok'] and len(r['owner_variants']['value']['records']) == r['expected_count']
            else:
                allowed = r['entry_id'] in ['ending.alone.normal','ending.alone.dark_mode'] and r['locale']=='en'
                assert r['resolution']['ok'] is allowed
        assert all(r and r['exit_code']==0 for r in receipts.values())
    pathlib.Path('review/gallery-result-verification.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'bytes':len(raw),'sha256':expected_digest,'members':len(names),'report':report,'processes':receipts},indent=2))
