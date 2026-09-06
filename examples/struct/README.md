# Inline Point struct

[struct.fbs](schema/struct.fbs) defines an inline `Point` and a `PointMessage`
table that contains it. Unlike the table in `examples/point`, this Point always
occupies eight bytes: `x` at offset 0 and `y` at offset 4.

Regenerate the classes from the repository root with `just generate`.
Include `runtime/src` and `examples/struct/src` on your AS3 source path.

```as3
import as3flatbuffers.Builder;
import example.geometry.Point;
import example.geometry.PointView;
import example.geometry.PointMessage;
import example.geometry.PointMessageView;
import flash.utils.ByteArray;
import flash.utils.Endian;

const builder:Builder = new Builder();
const message:PointMessage = new PointMessage();
message.point = new Point();
message.point.x = 1.25;
message.point.y = -2.5;

const bytes:ByteArray = builder.finish(message.pack(builder));
bytes.endian = Endian.LITTLE_ENDIAN;
bytes.position = 0;
const messageView:PointMessageView = new PointMessageView().bind(bytes, bytes.readUnsignedInt());
const pointView:PointView = messageView.point;
trace(pointView.x, pointView.y);

const owned:Point = pointView.unpack();
pointView.unpack(owned); // Reuse an independent owned Point.

builder.reset();
message.point.x = 42;
const next:ByteArray = builder.finish(message.pack(builder));
next.endian = Endian.LITTLE_ENDIAN;
next.position = 0;
messageView.bind(next, next.readUnsignedInt());
trace(messageView.point === pointView); // The getter rebinds the cached child view.
trace(pointView.x);                     // 42
trace(owned.x);                         // Still 1.25
```

If you already know the struct's absolute byte position, bind it directly with
`new PointView().bind(bytes, structOffset)`. That offset points at `x`, rather than
at a root-offset word. The struct view checks its byte range and sets little-endian
order when bound.

`PointMessage.point` defaults to null and may be omitted. A present Point always
stores both coordinates, including zeros. `Point.pack(builder)` writes inline;
the generated `PointMessage.pack()` places it inside the table automatically.
