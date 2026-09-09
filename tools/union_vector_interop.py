"""Mixed union vectors: flatc interoperability plus raw NONE-slot verification."""
import copy
import json
import struct

from union_interop import ROOT, flatc

KINDS = ['NONE', 'Value', 'Point', 'Text', 'Tiny', 'Alternate']
MIXED = [
    ('Value', dict(x=42, next=dict(id=77, items_type=['Text'], items=['nested']))),
    ('Point', dict(x=1.25, y=-2.5)), ('Text', 'hello ää 日本語 😀'),
    ('Tiny', dict(value=255)), ('Alternate', dict(x=-123)), ('Text', ''),
]
SEQUENCES = [[], MIXED, [('Point', dict(x=3.5, y=4.5)), *MIXED[1:]],
             MIXED, [('NONE', None), *MIXED[1:]], MIXED[:2], [],
             [('NONE', None), ('Text', ''), ('Tiny', dict(value=231))], MIXED]
CASES = []
for i, items in enumerate(SEQUENCES):
    item = dict(id=i, tail=bool(i % 2))
    if i != 0:
        for name, values in [('items', items), ('mirror', list(reversed(items)))]:
            item[name + '_type'] = [kind for kind, value in values]
            item[name] = [value for kind, value in values]
    if i % 2:
        item.update(single_type='Text', single='single')
    CASES.append(item)


def u32(data, pos):
    return struct.unpack_from('<I', data, pos)[0]


def field(data, table, slot):
    vt = table - struct.unpack_from('<i', data, table)[0]
    if slot >= struct.unpack_from('<H', data, vt)[0]:
        return 0
    relative = struct.unpack_from('<H', data, vt + slot)[0]
    return table + relative if relative else 0


def reference(data, position):
    return position + u32(data, position) if position else 0


def create(work):
    for i, case in enumerate(CASES):
        # flatc 25.12.19 cannot parse NONE in union-vector JSON. Start with a
        # placeholder table, then replace its tag/reference with NONE/zero.
        source = copy.deepcopy(case)
        for name in ('items', 'mirror'):
            for index, kind in enumerate(source.get(name + '_type', [])):
                if kind == 'NONE':
                    source[name + '_type'][index] = 'Value'
                    source[name][index] = {}
        path = work / f'union-vector-flatc-{i}.json'
        path.write_text(json.dumps(source, ensure_ascii=False))
        flatc('-b', '--strict-json', '-o', work, ROOT/'internal/testdata/union_vectors.fbs', path)
        binary = path.with_suffix('.bin')
        data = bytearray(binary.read_bytes())
        table = u32(data, 0)
        for name, slot in [('items', 6), ('mirror', 10)]:
            tags = reference(data, field(data, table, slot))
            values = reference(data, field(data, table, slot + 2))
            for index, kind in enumerate(case.get(name + '_type', [])):
                if kind == 'NONE':
                    data[tags + 4 + index] = 0
                    struct.pack_into('<I', data, values + 4 + index * 4, 0)
        binary.write_bytes(data)


def canonical(case):
    def member(kind, value):
        if kind in ('Value', 'Alternate'):
            value = dict(x=value.get('x', 0), next=canonical(value['next']) if 'next' in value else None)
        return [kind, value]
    return dict(id=case.get('id', 0), tail=case.get('tail', False),
        items=[member(k,v) for k,v in zip(case.get('items_type', []), case.get('items', []))],
        mirror=[member(k,v) for k,v in zip(case.get('mirror_type', []), case.get('mirror', []))],
        single=member(case.get('single_type','NONE'), case.get('single')))


def decode(data, table):
    def member(tag, offset):
        kind = KINDS[tag]
        if tag == 0:
            assert not offset or u32(data, offset) == 0
            return [kind, None]
        assert offset and u32(data, offset) >= 4
        pos = reference(data, offset)
        if kind in ('Value', 'Alternate'):
            x = field(data, pos, 4)
            child = reference(data, field(data, pos, 6))
            value = dict(x=struct.unpack_from('<i', data, x)[0] if x else 0, next=decode(data,child) if child else None)
        elif kind == 'Point':
            x,y = struct.unpack_from('<ff', data, pos)
            value = dict(x=x,y=y)
        elif kind == 'Tiny':
            value = dict(value=data[pos])
        else:
            length = u32(data,pos)
            assert data[pos + 4 + length] == 0
            value = data[pos + 4:pos + 4 + length].decode('utf-8')
        return [kind,value]
    result = {}
    for name,slot in [('items',6),('mirror',10)]:
        tags = reference(data,field(data,table,slot))
        values = reference(data,field(data,table,slot+2))
        assert bool(tags) == bool(values)
        count = u32(data,tags) if tags else 0
        assert count == (u32(data,values) if values else 0)
        result[name] = [member(data[tags+4+i], values+4+i*4) for i in range(count)]
    tag = field(data,table,14)
    result['single'] = member(data[tag] if tag else 0,field(data,table,16))
    id_pos,tail = field(data,table,4),field(data,table,18)
    result.update(id=u32(data,id_pos) if id_pos else 0,tail=bool(data[tail]) if tail else False)
    return result


def verify(work):
    for i,case in enumerate(CASES):
        expected = canonical(case)
        for side in ('flatc','as3'):
            path = work/f'union-vector-{side}-{i}.bin'
            data = path.read_bytes()
            assert decode(data,u32(data,0)) == expected, (i,side)
        if 'NONE' in case.get('items_type', []):
            continue
        decoded = []
        for side in ('flatc','as3'):
            directory = work/('union-vector-json-'+side)
            directory.mkdir(exist_ok=True)
            flatc('-t','--strict-json','--defaults-json','--raw-binary','-o',directory,
                ROOT/'internal/testdata/union_vectors.fbs','--',work/f'union-vector-{side}-{i}.bin')
            decoded.append(canonical(json.loads((directory/f'union-vector-{side}-{i}.json').read_text())))
        assert decoded[0] == decoded[1] == expected
    print(f'Passed {len(CASES)} mixed union-vector fixtures, including raw NONE slots, nested vectors and resizing.')
