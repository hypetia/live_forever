#!/usr/bin/env python3
"""Rebuild the UI subset from a user-supplied Noto CJK source (fontTools)."""
from pathlib import Path
import argparse


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('font', type=Path)
    parser.add_argument('--face', type=int, default=2, help='Simplified Chinese face in Noto CJK TTC')
    args = parser.parse_args()
    from fontTools import subset
    from fontTools.ttLib import TTFont
    root = Path(__file__).resolve().parents[1]
    text = ''.join(path.read_text() for path in root.glob('scripts/*.gd'))
    points = {ord(char) for char in text} | set(range(0x20, 0x7f))
    font = TTFont(args.font, fontNumber=args.face)
    original = set(font.getBestCmap())
    options = subset.Options()
    options.layout_features = ['*']
    sub = subset.Subsetter(options=options)
    sub.populate(unicodes=points & original)
    sub.subset(font)
    destination = root / 'assets/fonts/interface.otf'
    font.save(destination)
    missing = [chr(point) for point in points if 0x3400 <= point <= 0x9fff and point not in font.getBestCmap()]
    assert not missing, missing
    print(f'Rebuilt {destination.name}; all runtime Chinese glyphs present.')


if __name__ == '__main__':
    main()
