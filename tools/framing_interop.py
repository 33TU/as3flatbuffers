"""Identifiers and size-prefixed frames against generated Python readers/builders."""
import struct
import sys
from pathlib import Path

import flatbuffers

sys.path.insert(0,str(Path(__file__).resolve().parent.parent/'runtime/bin/python'))
from fixtures.framing import Record, PlainFrame, Child, Aligned

TITLES=['','hello ää 日本語 😀','x'*70000,'last']


def make_record(builder,title,index):
    text=builder.CreateString(title)
    name=builder.CreateString('child-'+str(index))
    Child.Start(builder);Child.AddName(builder,name);child=Child.End(builder)
    nested_text=builder.CreateString('next-'+str(index))
    Record.Start(builder);Record.AddTitle(builder,nested_text);nested=Record.End(builder)
    Record.StartValuesVector(builder,3)
    for value in reversed([0,2**32-1,index]):builder.PrependUint32(value)
    values=builder.EndVector()
    Record.Start(builder)
    Record.AddTitle(builder,text);Record.AddChild(builder,child);Record.AddNext(builder,nested);Record.AddValues(builder,values)
    Record.AddAligned(builder,Aligned.CreateAligned(builder,index+0.25,index+7))
    return Record.End(builder)


def create(work):
    for i,title in enumerate(TITLES):
        for prefixed in (False,True):
            builder=flatbuffers.Builder(1)
            root=make_record(builder,title,i)
            if prefixed:builder.FinishSizePrefixed(root,file_identifier=b'FRM1')
            else:builder.Finish(root,file_identifier=b'FRM1')
            suffix='size' if prefixed else 'plain'
            (work/f'frame-python-{suffix}-{i}.bin').write_bytes(builder.Output())
            builder=flatbuffers.Builder(1)
            text=builder.CreateString(title)
            PlainFrame.Start(builder);PlainFrame.AddText(builder,text);PlainFrame.AddValue(builder,i)
            root=PlainFrame.End(builder)
            if prefixed:builder.FinishSizePrefixed(root)
            else:builder.Finish(root)
            (work/f'noid-python-{suffix}-{i}.bin').write_bytes(builder.Output())


def verify(work):
    for i,title in enumerate(TITLES):
        for prefixed in (False,True):
            suffix='size' if prefixed else 'plain'
            data=bytearray((work/f'frame-as3-{suffix}-{i}.bin').read_bytes())
            if prefixed:assert struct.unpack_from('<I',data)[0]==len(data)-4
            assert Record.Record.RecordBufferHasIdentifier(data,0,prefixed)
            root=Record.Record.GetRootAs(data,4 if prefixed else 0)
            assert root.Title().decode('utf-8')==title
            assert root.Child().Name().decode('utf-8')=='child-'+str(i)
            assert root.Next().Title().decode('utf-8')=='next-'+str(i)
            assert root.Aligned().Value()==i+0.25 and root.Aligned().Tag()==i+7
            assert root.Aligned()._tab.Pos%16==0
            assert [root.Values(j) for j in range(root.ValuesLength())]==[0,2**32-1,i]
            data=bytearray((work/f'noid-as3-{suffix}-{i}.bin').read_bytes())
            if prefixed:assert struct.unpack_from('<I',data)[0]==len(data)-4
            plain=PlainFrame.PlainFrame.GetRootAs(data,4 if prefixed else 0)
            assert plain.Text().decode('utf-8')==title and plain.Value()==i
    print('Passed 16 identifier/size-prefix combinations, including nested roots, alignment and 70KB strings.')
