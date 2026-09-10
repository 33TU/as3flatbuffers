# Inline Point struct

[struct.fbs](schema/struct.fbs) defines an inline `Point` and a `PointMessage`
table that contains it. Unlike the table in `examples/point`, this Point always
occupies eight bytes: `x` at offset 0 and `y` at offset 4.

Regenerate the classes from the repository root with `just generate`.
Include `runtime/src` and `examples/struct/src` on your AS3 source path.

```as3
import example.geometry.Point;
import example.geometry.PointView;
import example.geometry.PointMessage;
import example.geometry.PointMessageView;
import flash.utils.ByteArray;
import flash.utils.Endian;

const message:PointMessage = new PointMessage();
message.point = new Point();
message.point.x = 1.25;
message.point.y = -2.5;

const bytes:ByteArray = new ByteArray();
bytes.endian = Endian.LITTLE_ENDIAN;
PointMessage.pack(message, bytes);
const messageView:PointMessageView = new PointMessageView();
messageView.bind(bytes, bytes.readUnsignedInt());
const pointView:PointView = messageView.point;
trace(pointView.x, pointView.y);

const decoded:PointMessage = PointMessage.unpack(bytes);
const owned:Point = decoded.point;
PointMessage.unpack(bytes, decoded); // Reuse the message and its owned Point.

message.point.x = 42;
PointMessage.pack(message, bytes); // Replaces the same destination directly.
messageView.bind(bytes, bytes.readUnsignedInt());
trace(messageView.point === pointView); // The getter rebinds the cached child view.
trace(pointView.x);                     // 42
trace(owned.x);                         // Still 1.25
```

If you already know the struct's absolute byte position, bind it directly with
`new PointView().bind(bytes, structOffset)`. That offset points at `x`, rather than
at a root-offset word. The struct view checks its byte range and sets little-endian
order when bound.

`PointMessage.point` defaults to null and may be omitted. A present Point always
stores both coordinates, including zeros. `PointMessage.pack(message, dst)` places
it inside the table automatically, sharing the parent’s builder through `Point.packInto()`.
`Point.pack(point, dst)` writes a standalone raw Point at offset zero, with no root
word. Both public pack methods write little-endian bytes without changing `dst.endian`,
replace its contents, and return it positioned at zero.

For standalone struct bytes, use `Point.unpack(bytes, destination, structOffset)`.

The same schema includes a `Transform` with `matrix:[float:16]`:

```as3
import example.geometry.Transform;
import example.geometry.TransformView;

const transform:Transform = new Transform(); // Sixteen zeros, fixed length.
transform.matrix[0] = transform.matrix[5] = transform.matrix[10] = transform.matrix[15] = 1;
Transform.pack(transform, bytes); // 64 raw struct bytes.
const transformView:TransformView = new TransformView().bind(bytes, 0);
trace(transformView.matrixLength, transformView.matrix(5)); // 16, 1
Transform.unpack(bytes, transform); // Reuses the matrix vector.
Transform.reset(transform);         // Zeros its elements; length stays 16.
```

Fixed arrays support scalars, enums, and inline structs. Struct and 64-bit word
elements are initialized eagerly and reused by reset and unpack. Packing requires
the declared length and non-null struct/word elements. Indexed view access checks
bounds; struct elements use a cached child view, rebound on each access.
