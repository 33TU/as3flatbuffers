# Vectors

Run `just generate` and include `runtime/src` and `examples/vector/src` on your
compiler's source path.

```as3
import example.inventory.Inventory;
import example.inventory.InventoryView;
import example.inventory.Item;
import example.inventory.Position;
import flash.utils.ByteArray;
import flash.utils.Endian;

const inventory:Inventory = new Inventory();
const item:Item = new Item();
item.id = 42;
item.quantity = 3;
inventory.items = new <Item>[item];
const point:Position = new Position();
point.x = 1.5;
point.y = -2;
inventory.path = new <Position>[point];
inventory.tags = new <String>["equipment", "rare"];
inventory.scores = new <int>[]; // Empty vectors are omitted when packing.

const bytes:ByteArray = new ByteArray();
bytes.endian = Endian.LITTLE_ENDIAN;
Inventory.pack(inventory, bytes);

const view:InventoryView = new InventoryView();
view.bind(bytes, bytes.readUnsignedInt());
trace(view.itemsLength, view.items(0).quantity); // 1, 3
trace(view.tags(1));                            // rare
trace(view.scoresLength);                      // 0

const owned:Inventory = Inventory.unpack(bytes);
Inventory.unpack(bytes, owned); // Reuses vectors and existing child objects.
const copy:Inventory = Inventory.clone(owned); // Independent vectors and objects.
Inventory.reset(copy); // Clears vector lengths, retaining flexible vectors.
```

Owned fields use `Vector.<T>` and start empty. Keep them non-null and resizable (`fixed = false`).
Absent and empty wire vectors both decode to empty vectors. All scalar types, strings, structs, and tables are
supported as elements; exact 64-bit integers use `Int64` / `UInt64` objects.
Object, string, and 64-bit elements must be non-null when packing.

Each borrowed vector exposes `fieldLength` and `field(index)`.
Indexing an absent vector or reading past its length throws `RangeError`.
Helper names receive suffixes if they collide with schema field names.

Struct and table accessors return one cached child view per vector field. The
next access rebinds that same view, so use an owned value or a separately bound
view to retain an independent element. String access decodes on every call;
64-bit access creates a word object. Other scalar access does not allocate.

Unpacking resizes flexible destination vectors and reuses surviving elements
by index. Resizing assigns `length` directly. Absent input and reset both set
`length = 0`, retaining the vector. Shrinking a vector drops
its removed objects; a later growth allocates replacements. Cloning copies
vectors and mutable elements deeply. As with other table fields, source graphs
must be acyclic.
