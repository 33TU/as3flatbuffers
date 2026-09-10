"""Required-field interoperability with official flatc binary/JSON conversion."""
import json
from union_interop import ROOT, flatc

CASES = []
for i in range(5):
    populated = i in (1, 3)
    case = dict(name='player' if populated else '', position=dict(x=1.25,y=-2.5),
        child=dict(label='child' if populated else ''), numbers=[-7,0,42] if populated else [],
        names=['','hello ää'] if populated else [], positions=[dict(x=3,y=4)] if populated else [],
        children=[dict(label='nested')] if populated else [],
        payload_type=['Text','Child','Position','Child','Text'][i],
        payload=['',dict(label='union'),dict(x=9,y=-9),dict(label='again'),''][i],
        payloads_type=['Text','Child'] if populated else [],
        payloads=['',dict(label='vector')] if populated else [])
    CASES.append(case)


def create(work):
    for i,case in enumerate(CASES):
        path=work/f'required-flatc-{i}.json'
        path.write_text(json.dumps(case))
        flatc('-b','--strict-json','-o',work,ROOT/'internal/testdata/required.fbs',path)


def verify(work):
    for i in range(len(CASES)):
        results=[]
        for side in ('flatc','as3'):
            directory=work/('required-json-'+side)
            directory.mkdir(exist_ok=True)
            flatc('-t','--strict-json','--defaults-json','--raw-binary','-o',directory,
                ROOT/'internal/testdata/required.fbs','--',work/f'required-{side}-{i}.bin')
            results.append(json.loads((directory/f'required-{side}-{i}.json').read_text()))
        assert results[0]==results[1],(i,results)
    print(f'Passed {len(CASES)} required-field fixtures, including empty strings/vectors and required unions.')
