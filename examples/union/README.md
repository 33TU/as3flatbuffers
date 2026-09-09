# Typed union payloads

[packet.fbs](schema/packet.fbs) defines a union containing a table, a struct, and a
string. Regenerate with `just generate` and include `runtime/src` and
`examples/union/src` on your source path.

```as3
import example.protocol.Packet;
import example.protocol.PacketView;
import example.protocol.Payload;
import example.protocol.Move;
import example.protocol.Damage;
import flash.utils.ByteArray;
import flash.utils.Endian;

const packet:Packet = new Packet(); // Owns a Payload, initially NONE.
packet.payload.move = new Move();
packet.payload.move.x = 12.5;
packet.payload.move.y = -4;
packet.payload.type = Payload.MOVE;

const bytes:ByteArray = new ByteArray();
Packet.pack(packet, bytes);
const decoded:Packet = Packet.unpack(bytes);
const cachedMove:Move = decoded.payload.move;

packet.payload.damage = new Damage();
packet.payload.damage.amount = 42;
packet.payload.type = Payload.DAMAGE;
Packet.pack(packet, bytes);
Packet.unpack(bytes, decoded); // Retains decoded.payload.move while filling damage.

packet.payload.type = Payload.MOVE;
Packet.pack(packet, bytes);
Packet.unpack(bytes, decoded);
trace(decoded.payload.move === cachedMove); // true

bytes.endian = Endian.LITTLE_ENDIAN;
bytes.position = 0;
const view:PacketView = new PacketView();
view.bind(bytes, bytes.readUnsignedInt());
trace(view.payload.type, view.payload.move.x);
trace(view.payload.damage); // null: inactive borrowed getters return null.

Payload.reset(decoded.payload); // Clears cached values in place; selects NONE.
```

The tag is authoritative: packing ignores inactive fields and requires the selected
field to be non-null. An empty string is a valid selected value. To select no
payload, set `type = Payload.NONE`; this keeps all cached values unchanged.

Unpacking allocates a member on first use and reuses it on later visits, including
after another member type was selected. Reset clears all cached values while
retaining object identities. Clone deep-copies active and inactive owned objects.
Cached members therefore retain memory until you clear their fields or discard
the wrapper. There are no standalone root pack/unpack APIs on `Payload`; use its
containing table.

A borrowed `PayloadView` is cached by its parent and rebound on each access. Its
typed member getters return cached table/struct views or a decoded string; inactive
getters return null. Each alias has its own field and cache, even when aliases use
the same underlying type.

Unknown tags, missing active payloads, and nonzero payload references tagged NONE
are rejected. Python's generator supports
table union members; the mixed-member tests use official `flatc` binary/JSON
conversion instead.

## Union vectors

`Packet.payloads:[Payload]` uses an ordinary resizable `Vector.<Payload>`:

```as3
const text:Payload = new Payload();
text.type = Payload.TEXT;
text.text = "hello";
packet.payloads.push(text);
packet.payloads.push(new Payload()); // NONE entry, not a null wrapper.

Packet.pack(packet, bytes);
Packet.unpack(bytes, decoded); // Reuses surviving indices and their member caches.
bytes.position = 0;
view.bind(bytes, bytes.readUnsignedInt());
trace(view.payloadsLength);        // 2
trace(view.payloads(0).text);       // hello
trace(view.payloads(1).type);       // Payload.NONE
trace(view.payloads(0) === view.payloads(1)); // Same borrowed union view, rebound.
```

The tag vector and payload vector are managed by generated code. Their wire
lengths must match. Empty vectors are omitted, and absent vectors decode as empty.
Reset empties the vector; shrinking releases removed wrappers and their caches.
Clone creates independent wrappers, including copies of inactive member objects.

`flatc` 25.12.19 cannot convert NONE entries through JSON. Their zero-tag,
zero-reference wire encoding is accepted by its generated C++ verifier; the test
suite checks raw NONE entries separately from JSON interoperability.
