# Strings

Generate the owned `Chat` and borrowed `ChatView` classes with `just generate`.
Include `runtime/src` and `examples/string/src` on your compiler's source path.

```as3
import example.chat.Chat;
import example.chat.ChatView;
import flash.utils.ByteArray;
import flash.utils.Endian;

const chat:Chat = new Chat();
chat.sender = "Eetu";
chat.message = "Hello, 世界 👋";
const bytes:ByteArray = new ByteArray();
bytes.endian = Endian.LITTLE_ENDIAN;
Chat.pack(chat, bytes);

const view:ChatView = new ChatView();
view.bind(bytes, bytes.readUnsignedInt());
trace(view.sender, view.message);
const owned:Chat = Chat.unpack(bytes);
Chat.unpack(bytes, owned); // Reuses the message; strings are immutable values.
```

`null` omits a string field; `""` writes a present empty string. Strings use a
32-bit UTF-8 byte count followed by the bytes and a zero terminator. Encoding and
decoding use `ByteArray.writeUTFBytes()` and `readUTFBytes()` directly, with native
NUL/BOM and malformed-Unicode behavior. Offsets, lengths, and terminators are
checked; UTF-8 is not separately validated. Getters decode on every call, so
unpack once to retain the string.
