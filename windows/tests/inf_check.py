"""Checks that the driver's INF and its C++ tables describe the same cables.

Splitter.inx names every endpoint, registers its interfaces and gives each
name a GUID; Inc/endpoints.h, Inc/common.h, Filters/minipairs.h and
Filters/cabletoptable.h make the same endpoints in C++. Nothing at build
time checks that the two agree, and a mismatch only shows on Windows as a
missing or unnamed device. Runs anywhere with Python 3:

    python3 windows/tests/inf_check.py [path to windows/driver/Source]

Copyright (c) the BananaSplit authors. MIT licence (see LICENSE).
"""
import os
import re
import sys
import uuid

src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'driver', 'Source')
inx_raw = open(f'{src}/Main/Splitter.inx', newline='').read()
problems = []


def bad(msg):
    problems.append(msg)


if inx_raw.count('\r\n') != inx_raw.count('\n'):
    bad('Splitter.inx: mixed line endings')
inx = inx_raw.replace('\r\n', '\n')
endpoints = open(f'{src}/Inc/endpoints.h').read()
minipairs = open(f'{src}/Filters/minipairs.h').read()
common = open(f'{src}/Inc/common.h').read()
toptable = open(f'{src}/Filters/cabletoptable.h').read()
rule = open(f'{src}/Utilities/cablerule.h').read()

count = int(re.search(r'#define SPLITTER_CABLE_COUNT\s+(\d+)', common).group(1))
if int(re.search(r'#define CABLE_RING_COUNT\s+(\d+)', rule).group(1)) != count:
    bad('CABLE_RING_COUNT != SPLITTER_CABLE_COUNT')

# ---- INF structure ----------------------------------------------------------------
sections = {}
order = []
cur = None
for line in inx.split('\n'):
    t = line.strip()
    if not t or t.startswith(';'):
        continue
    m = re.fullmatch(r'\[([^\]]+)\]', t)
    if m:
        cur = m.group(1)
        if cur.lower() in (k.lower() for k in sections):
            bad(f'duplicate section [{cur}]')
        sections[cur] = []
        order.append(cur)
        continue
    if cur is None:
        bad(f'line outside a section: {t}')
        continue
    sections[cur].append(t)

strings = {}
for t in sections.get('Strings', []):
    m = re.fullmatch(r'([A-Za-z0-9_.]+)\s*=\s*(.*)', t)
    if not m:
        bad(f'[Strings] line not key = value: {t}')
        continue
    k, v = m.group(1), m.group(2).strip()
    if k.lower() in (x.lower() for x in strings):
        bad(f'duplicate string {k}')
    strings[k] = v.strip('"')

# every %token% is defined (stampinf fills $ARCH$ and $KMDFVERSION$)
for name, lines in sections.items():
    if name == 'Strings':
        continue
    for t in lines:
        for tok in re.findall(r'%([^%]+)%', t):
            if tok.isdigit():
                continue
            if tok not in strings:
                bad(f'[{name}] uses undefined %{tok}%')

# every AddReg / Include target exists
for name, lines in sections.items():
    for t in lines:
        m = re.fullmatch(r'AddReg\s*=\s*(.+)', t)
        if m:
            for target in [x.strip() for x in m.group(1).split(',')]:
                if target not in sections:
                    bad(f'[{name}] AddReg {target}: no such section')

ifaces = [t for t in sections['SPLITTER_SA.NT.Interfaces']]
iface_set = set()
for t in ifaces:
    m = re.fullmatch(r'AddInterface\s*=\s*%([^%]+)%,\s*%([^%]+)%,\s*(\S+)', t)
    if not m:
        bad(f'odd AddInterface line: {t}')
        continue
    cat, ref, sect = m.groups()
    if (cat, ref, sect) in iface_set:
        bad(f'duplicate AddInterface {t}')
    iface_set.add((cat, ref, sect))
    if sect not in sections:
        bad(f'AddInterface to missing section {sect}')

# ---- per cable ---------------------------------------------------------------------
want_render = {'KSCATEGORY_AUDIO', 'KSCATEGORY_RENDER', 'KSCATEGORY_REALTIME'}
want_capture = {'KSCATEGORY_AUDIO', 'KSCATEGORY_CAPTURE', 'KSCATEGORY_REALTIME'}
want_topo = {'KSCATEGORY_AUDIO', 'KSCATEGORY_TOPOLOGY'}
names = []
for n in range(1, count + 1):
    for kind, cap, wave_cats in (('RENDER', 'Render', want_render), ('CAPTURE', 'Capture', want_capture)):
        # GUID: endpoints.h struct, its STATIC bytes and the INF string agree
        m = re.search(rf'#define STATIC_NAME_SPLITTER_{kind}{n} \\\n\s*(0x[0-9a-f]+), (0x[0-9a-f]+), (0x[0-9a-f]+), ((?:0x[0-9a-f]{{2}}, ){{7}}0x[0-9a-f]{{2}})\n'
                      rf'DEFINE_GUIDSTRUCT\("([0-9A-F-]+)", NAME_SPLITTER_{kind}{n}\);\n'
                      rf'#define NAME_SPLITTER_{kind}{n} DEFINE_GUIDNAMED\(NAME_SPLITTER_{kind}{n}\)', endpoints)
        if not m:
            bad(f'endpoints.h: NAME_SPLITTER_{kind}{n} missing or malformed')
            continue
        d1, d2, d3, rest, text = m.groups()
        g = uuid.UUID(text)
        b = g.bytes
        if (int(d1, 16), int(d2, 16), int(d3, 16)) != (int.from_bytes(b[0:4], 'big'), int.from_bytes(b[4:6], 'big'), int.from_bytes(b[6:8], 'big')) \
                or [int(x, 16) for x in rest.split(', ')] != list(b[8:]):
            bad(f'endpoints.h: STATIC bytes of {kind}{n} do not match its string')
        inf_guid = strings.get(f'{cap}{n}NameGUID')
        if inf_guid != '{' + text + '}':
            bad(f'INF {cap}{n}NameGUID {inf_guid} != endpoints.h {text}')
        # topology pin names the GUID
        if f'&NAME_SPLITTER_{kind}##N' not in toptable:
            bad('cabletoptable.h does not name pins by GUID')
        # INF: endpoint name in MediaCategories
        for line in (f'HKR,MediaCategories\\%{cap}{n}NameGUID%,Name,,%{cap}{n}Name%',
                     f'HKR,MediaCategories\\%{cap}{n}NameGUID%,Display,1,00,00,00,00'):
            if line not in sections['SPLITTER_SA.AddReg']:
                bad(f'missing in SPLITTER_SA.AddReg: {line}')
        if f'{cap}{n}Name' not in strings:
            bad(f'no string {cap}{n}Name')
        names.append(strings.get(f'{cap}{n}Name'))
        # interface sections
        for filt in ('Wave', 'Topology'):
            ref = f'KSNAME_{filt}{cap}{n}'
            if strings.get(ref) != f'{filt}{cap}{n}':
                bad(f'{ref} = {strings.get(ref)}')
            if f'L"{filt}{cap}" #N' not in minipairs:
                bad(f'minipairs.h does not name {filt}{cap} filters by number')
            sect = f'SPLITTER.I.{filt}{cap}{n}'
            if sections.get(sect) != [f'AddReg = {sect}.AddReg']:
                bad(f'[{sect}] wrong: {sections.get(sect)}')
            body = sections.get(f'{sect}.AddReg', [])
            want = ['HKR,,CLSID,,%Proxy.CLSID%', f'HKR,,FriendlyName,,%{cap}{n}Name%']
            if filt == 'Topology':
                want += ['HKR,EP\\0,%PKEY_AudioEndpoint_Association%,,%KSNODETYPE_ANY%',
                         'HKR,EP\\0,%PKEY_AudioEndpoint_Supports_EventDriven_Mode%,0x00010001,0x1']
            if body != want:
                bad(f'[{sect}.AddReg] = {body}')
            cats = {c for c, r, s in iface_set if r == ref and s == sect}
            if cats != (wave_cats if filt == 'Wave' else want_topo):
                bad(f'AddInterface categories of {ref}: {sorted(cats)}')
    # C++ tables list every cable
    for pat in (rf'\beCableRender{n}\b', rf'\beCableCapture{n}\b', rf'SPLITTER_RENDER_MINIPAIR\({n}\)', rf'SPLITTER_CAPTURE_MINIPAIR\({n}\)',
                rf'&CableRender{n}Miniports,', rf'&CableCapture{n}Miniports,'):
        if not re.search(pat, common + minipairs):
            bad(f'missing {pat}')
    if not re.search(rf'SPLITTER_RENDER_TOPO\({n}\)', toptable) or not re.search(rf'SPLITTER_CAPTURE_TOPO\({n}, KSNODETYPE_\w+\)', toptable):
        bad(f'cabletoptable.h: cable {n} not instantiated')

if len(set(n.lower() for n in names if n)) != len(names):
    bad('endpoint names are not unique')
all_guids = re.findall(r'DEFINE_GUIDSTRUCT\("([0-9A-F-]+)"', endpoints)
if len(set(all_guids)) != len(all_guids):
    bad('duplicate GUID in endpoints.h')
if len(ifaces) != count * 10:
    bad(f'{len(ifaces)} AddInterface lines, expected {count * 10}')

print(f'{count} cables, {len(names)} endpoint names, {len(ifaces)} AddInterface lines')
for n in names:
    print('  ', n)
if problems:
    print('PROBLEMS:')
    for p in problems:
        print('  ', p)
    sys.exit(1)
print('INF and C++ tables agree')
