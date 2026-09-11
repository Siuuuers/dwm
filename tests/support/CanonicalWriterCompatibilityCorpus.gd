# Fixed corpus for persisted canonical bytes and refusal compatibility.
extends RefCounted
static func values() -> Array:
    var unicode = String.chr(0x4E2D) + String.chr(0x1F63D)
    var all_controls = ""
    for cp in range(1, 32): all_controls += String.chr(cp)
    var items = [null, true, false, 0, 9223372036854775807, -9223372036854775807-1, -0.0, 1.0, 0.1, 1.2345678901234567, 1.0e-200, 1.0e200, INF, -INF, NAN, "", "ascii", unicode, &"named", all_controls + "\"\\", {"a":1, "aa":2, "A":3, "":4, unicode:5}, [null,true,1,1.0,&"name"], {"nested":[{"v":unicode},[]]}, {"bad":Vector2.ZERO}, {1:"bad"}]
    var rng = RandomNumberGenerator.new()
    rng.seed = 7341926
    var bytes = PackedByteArray()
    bytes.resize(8)
    for i in range(1024):
        bytes.encode_u32(0, rng.randi())
        bytes.encode_u32(4, rng.randi())
        var value = bytes.decode_double(0)
        items.append(value)
        if i % 16 == 0:
            items.append({"array":[value,{"typed":1.0,"name":&"value"}]})
            items.append({"a":value,"z":Vector2.ZERO})
    return items
