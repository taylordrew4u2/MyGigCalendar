#!/usr/bin/env python3
"""Check icon and required screenshot PNG dimensions and absence of alpha, without dependencies."""
from pathlib import Path
import json, struct
root = Path(__file__).resolve().parent
repo = root.parent

def png_size(path):
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', f'Not a PNG: {path}'
    w, h, depth, kind = struct.unpack('>IIBB', data[16:26])
    assert depth == 8 and kind == 2, f'Expected opaque 8-bit RGB PNG: {path}'
    offset = 8
    while offset < len(data):
        length = struct.unpack('>I', data[offset:offset+4])[0]
        assert data[offset+4:offset+8] != b'tRNS', f'Transparency chunk: {path}'
        offset += length + 12
    return w, h

catalog = repo / 'SEE ME LIVE/Assets.xcassets/AppIcon.appiconset'
entries = json.loads((catalog / 'Contents.json').read_text())['images']
assert len(entries) == 3
for entry in entries:
    assert png_size(catalog / entry['filename']) == (1024, 1024)
for group, size in [('iphone-6.9', (1320, 2868)), ('ipad-13', (2064, 2752))]:
    images = list((root / 'screenshots/en-US' / group).glob('*.png'))
    assert 1 <= len(images) <= 10, f'Missing or excessive screenshots: {group}'
    for path in images:
        assert png_size(path) == size, f'Wrong screenshot size: {path}'
    print(f'{group}: {len(images)} valid screenshots')
print('App Store assets passed: three icons and both device screenshot sets.')
