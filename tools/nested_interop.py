"""Recursive table interoperability through official flatc-generated Python code."""
import json
import struct
import sys
from pathlib import Path

import flatbuffers

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "runtime/bin/python"))
from fixtures.nested import Scene, Node, Position, Left, Right


def node(value, next=None, branch=None):
    return dict(value=value, next=next, branch=branch, position=[value + 0.25, -value - 0.5])


def cases():
    chain = None
    for i in reversed(range(32)):
        chain = node(i, chain)
    return [
        dict(head=None, alternate=None, pair=None, serial=0),
        dict(head=node(7), alternate=None, pair=None, serial=1),
        dict(head=node(1, node(2, node(3)), node(4)), alternate=node(-9),
             pair=dict(code=12, right=dict(weight=1.5, left=dict(code=34, right=None))), serial=2),
        dict(head=chain, alternate=node(99, branch=node(100)), pair=None, serial=3),
        dict(head=None, alternate=None, pair=dict(code=0, right=None), serial=4),
    ]


def pack_node(builder, value):
    if value is None:
        return 0
    next_offset = pack_node(builder, value["next"])
    branch_offset = pack_node(builder, value["branch"])
    Node.Start(builder)
    Node.AddValue(builder, value["value"])
    Node.AddNext(builder, next_offset)
    Node.AddBranch(builder, branch_offset)
    Node.AddPosition(builder, Position.CreatePosition(builder, *value["position"]))
    return Node.End(builder)


def pack_left(builder, value):
    if value is None:
        return 0
    right = value["right"]
    offset = 0
    if right is not None:
        left_offset = pack_left(builder, right["left"])
        Right.Start(builder)
        Right.AddWeight(builder, right["weight"])
        Right.AddLeft(builder, left_offset)
        offset = Right.End(builder)
    Left.Start(builder)
    Left.AddCode(builder, value["code"])
    Left.AddRight(builder, offset)
    return Left.End(builder)


def create(work):
    values = cases()
    for index, value in enumerate(values):
        builder = flatbuffers.Builder(16)
        head = pack_node(builder, value["head"])
        alternate = pack_node(builder, value["alternate"])
        pair = pack_left(builder, value["pair"])
        Scene.Start(builder)
        Scene.AddHead(builder, head)
        Scene.AddAlternate(builder, alternate)
        Scene.AddPair(builder, pair)
        Scene.AddSerial(builder, value["serial"])
        builder.Finish(Scene.End(builder))
        (work / f"nested-python-{index}.bin").write_bytes(builder.Output())
    (work / "nested.json").write_text(json.dumps(values))


def verify_reference(parent, slot, child):
    offset = parent._tab.Offset(slot)
    if child is None:
        assert offset == 0
        return
    location = parent._tab.Pos + offset
    assert location % 4 == 0
    relative = struct.unpack_from("<I", parent._tab.Bytes, location)[0]
    assert relative >= 4 and location + relative == child._tab.Pos
    vtable = parent._tab.Pos - struct.unpack_from("<i", parent._tab.Bytes, parent._tab.Pos)[0]
    size = struct.unpack_from("<H", parent._tab.Bytes, vtable + 2)[0]
    assert child._tab.Pos >= parent._tab.Pos + size  # Child is outside the inline object.


def verify_node(actual, expected):
    assert (actual is None) == (expected is None)
    if actual is None:
        return
    assert actual.Value() == expected["value"]
    position = actual.Position()
    assert [position.X(), position.Y()] == expected["position"]
    assert position._tab.Pos % 16 == 0
    next_value, branch = actual.Next(), actual.Branch()
    verify_reference(actual, 6, next_value)
    verify_reference(actual, 10, branch)
    verify_node(next_value, expected["next"])
    verify_node(branch, expected["branch"])


def verify_left(actual, expected):
    assert (actual is None) == (expected is None)
    if actual is None:
        return
    assert actual.Code() == expected["code"]
    right = actual.Right()
    verify_reference(actual, 6, right)
    assert (right is None) == (expected["right"] is None)
    if right is not None:
        assert right.Weight() == expected["right"]["weight"]
        left = right.Left()
        verify_reference(right, 6, left)
        verify_left(left, expected["right"]["left"])


def verify(work):
    values = cases()
    for index, value in enumerate(values):
        data = bytearray((work / f"nested-as3-{index}.bin").read_bytes())
        root = Scene.Scene.GetRootAs(data)
        assert root.Serial() == value["serial"]
        head, alternate, pair = root.Head(), root.Alternate(), root.Pair()
        verify_reference(root, 4, head)
        verify_reference(root, 6, alternate)
        verify_reference(root, 8, pair)
        verify_node(head, value["head"])
        verify_node(alternate, value["alternate"])
        verify_left(pair, value["pair"])
    print(f"Passed {len(values)} bidirectional nested-table fixtures, including recursive and mutually recursive types.")
