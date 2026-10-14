"""Inspect exact official PE metadata only; never infer source symbols from exports."""
import hashlib
import json
import os
from pathlib import Path
import struct

engine = Path(os.environ['GODOT_CONSOLE_PATH']).with_name('Godot_v4.6.3-stable_win64.exe')
data = engine.read_bytes()
digest = hashlib.sha256(data).hexdigest()
assert digest == 'ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00'
u16 = lambda offset: struct.unpack_from('<H', data, offset)[0]
u32 = lambda offset: struct.unpack_from('<I', data, offset)[0]
pe = u32(0x3c)
assert data[pe:pe+4] == b'PE\0\0'
coff = pe + 4
symbol_offset, symbol_count = u32(coff+8), u32(coff+12)
optional = coff + 20
assert u16(optional) == 0x20b
image_base = struct.unpack_from('<Q', data, optional+24)[0]
sections = []
for index in range(u16(coff+2)):
    row = optional + u16(coff+16) + index*40
    name = data[row:row+8].split(b'\0')[0].decode('ascii')
    if name.startswith('/') and symbol_offset:
        start = symbol_offset + symbol_count*18 + int(name[1:])
        name = data[start:data.index(b'\0', start)].decode('ascii')
    sections.append(dict(name=name, virtual_size=u32(row+8), rva=u32(row+12),
                         raw_size=u32(row+16), offset=u32(row+20)))

def file_offset(rva):
    for section in sections:
        if section['rva'] <= rva < section['rva'] + max(section['virtual_size'], section['raw_size']):
            return section['offset'] + rva - section['rva']
    raise ValueError(f'Unmapped RVA: {rva:#x}')

debug_entries = []
if u32(optional+108) > 6:
    debug_rva, debug_size = struct.unpack_from('<II', data, optional+112+6*8)
    if debug_rva:
        assert debug_size % 28 == 0
        for index in range(debug_size//28):
            row = file_offset(debug_rva) + index*28
            kind, size, address, pointer = struct.unpack_from('<IIII', data, row+12)
            record = dict(type=kind, size=size, rva=address, offset=pointer)
            payload = data[pointer:pointer+size]
            if kind == 2:
                record['signature'] = payload[:4].decode('ascii', errors='replace')
                if payload[:4] == b'RSDS':
                    record.update(guid_bytes=payload[4:20].hex(), age=struct.unpack_from('<I',payload,20)[0],
                                  pdb_path=payload[24:].split(b'\0')[0].decode('utf-8',errors='replace'))
            debug_entries.append(record)
result = dict(diagnostic_only=True, engine=str(engine), engine_sha256=digest,
              image_base=hex(image_base), coff_symbol_count=symbol_count, coff_symbol_offset=symbol_offset,
              sections=sections, debug_entries=debug_entries,
              fault_rva='0x22efe5b', fault_preferred_va=hex(image_base+0x22efe5b))
out = Path('.godot/ci/engine-pe.json')
out.write_text(json.dumps(result,indent=2), encoding='utf-8')
print(json.dumps(result))
