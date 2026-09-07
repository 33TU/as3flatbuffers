"""UTF-8 string interoperability with official flatc-generated Python readers."""
import json
import struct
import sys
from pathlib import Path

import flatbuffers

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "runtime/bin/python"))
from fixtures.text import Strings, Text


VALUES = [None, "", "hello", "ää öö 日本語", "😀𝄞🚀", "a\0b\0", "\ufeffBOM", "e\u0301",
          "\x7f\x80\u07ff\u0800\ud7ff\ue000\uffff\U00010000\U0010ffff", "x" * 70000, "", None]


def create(work):
    (work / "strings.json").write_text(json.dumps(VALUES))
    for i, value in enumerate(VALUES):
        b = flatbuffers.Builder(16)
        text = b.CreateString(value) if value is not None else 0
        label = b.CreateString("label")
        empty = b.CreateString("")
        Text.Start(b)
        Text.AddValue(b, text)
        child = Text.End(b)
        Strings.Start(b)
        Strings.AddText(b, text)
        next_value = Strings.End(b)
        Strings.Start(b)
        Strings.AddText(b, text)
        Strings.AddLabel(b, label)
        Strings.AddStringValue(b, empty)
        Strings.AddChild(b, child)
        Strings.AddNext(b, next_value)
        b.Finish(Strings.End(b))
        (work / f"string-python-{i}.bin").write_bytes(b.Output())


def verify(work):
    for i, value in enumerate(VALUES):
        data = (work / f"string-as3-{i}.bin").read_bytes()
        root = Strings.Strings.GetRootAs(data)
        expected = None if value is None else value.encode("utf-8")
        assert root.Text() == expected, i
        assert root.Label() == b"label" and root.StringValue() == b"", i
        assert root.Child().Value() == expected and root.Next().Text() == expected, i
        for obj, slot in [(root, 4), (root.Child(), 4), (root.Next(), 4)]:
            relative = obj._tab.Offset(slot)
            if value is None:
                assert relative == 0
                continue
            field = obj._tab.Pos + relative
            start = field + struct.unpack_from("<I", data, field)[0]
            length = struct.unpack_from("<I", data, start)[0]
            assert start % 4 == 0 and length == len(expected)
            assert data[start + 4 + length] == 0
    print(f"Passed {len(VALUES)} string interoperability fixtures: native AIR decoding and Python verification of UTF-8 output, including NUL, BOM and 70KB strings.")
