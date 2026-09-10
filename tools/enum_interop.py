"""Enum values use the official scalar wire types, including unknown values."""
import sys
from pathlib import Path

import flatbuffers

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "runtime/bin/python"))
from fixtures.enums import Enums, EnumStruct

KINDS = ["Int8", "Uint8", "Int16", "Uint16", "Int32", "Uint32", "Int64", "Uint64"]
DEFAULTS = [-128, 0, -32768, 0, -2**31, 0, 2**53+1, 0]
KNOWN = [127, 255, 32767, 65535, 2**31-1, 2**32-1, -2**63, 2**64-1]
UNKNOWN = [37, 38, 300, 301, -999, 999, -2**53-7, 2**63+9]
CASES = [DEFAULTS, KNOWN, UNKNOWN, DEFAULTS]


def create(work):
    for case, values in enumerate(CASES):
        b = flatbuffers.Builder(16)
        vectors = []
        if case in (1, 2):
            for letter, kind, known, unknown in zip("ABCDEFGH", KINDS, KNOWN, UNKNOWN):
                getattr(Enums, "Start" + letter + "vVector")(b, 3)
                for value in reversed([0, known, unknown]):
                    getattr(b, "Prepend" + kind)(value)
                vectors.append(getattr(b, "EndVector")())
        Enums.Start(b)
        for letter, value in zip("ABCDEFGH", values):
            getattr(Enums, "Add" + letter)(b, value)
        for letter, vector in zip("ABCDEFGH", vectors):
            getattr(Enums, "Add" + letter + "v")(b, vector)
        if case in (1, 2):
            Enums.AddOptionalMode(b, 0 if case == 1 else 37)
            Enums.AddOptionalWide(b, 0 if case == 1 else 2**64-1)
            Enums.AddFlags(b, 3 if case == 1 else 135)
            Enums.AddState(b, EnumStruct.CreateEnumStruct(b, *values))
        b.Finish(Enums.End(b))
        (work / f"enum-python-{case}.bin").write_bytes(b.Output())


def verify(work):
    for case, values in enumerate(CASES):
        data = (work / f"enum-as3-{case}.bin").read_bytes()
        root = Enums.Enums.GetRootAs(data)
        for letter, expected in zip("ABCDEFGH", values):
            assert getattr(root, letter)() == expected, (case, letter)
        for letter, known, unknown in zip("ABCDEFGH", KNOWN, UNKNOWN):
            assert getattr(root, letter + "vLength")() == (3 if case in (1, 2) else 0)
            if case in (1, 2):
                assert [getattr(root, letter + "v")(i) for i in range(3)] == [0, known, unknown]
        if case in (1, 2):
            assert root.OptionalMode() == (0 if case == 1 else 37)
            assert root.OptionalWide() == (0 if case == 1 else 2**64-1)
            assert root.Flags() == (3 if case == 1 else 135)
            state = root.State()
            for letter, expected in zip("ABCDEFGH", values):
                assert getattr(state, letter)() == expected
        else:
            assert root.OptionalMode() is None and root.OptionalWide() is None
            assert root.State() is None and root.Flags() == 0
    print("Passed 4 bidirectional enum fixtures: all 8 integer widths, defaults, unknown values, vectors, structs, nullable fields and bit flags.")
