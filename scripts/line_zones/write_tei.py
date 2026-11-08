#!/usr/bin/env python3
"""geom.py の結果（lines_geom.tsv）を TEI に書き込む。

使い方:
    python3 -I write_tei.py --tsv lines_geom.tsv --xml-dir xml/master [--accept accepted.tsv] [--dry]

- 各行の枠を <zone type="line" xml:id="line_<頁>-<行>" ulx uly lrx lry/> として、
  その頁の <zone xml:id="zone_<頁>"/> の直後（同じ <surface> の中）に足す
- その行の <seg> の直前の <lb/> を <lb facs="#line_<頁>-<行>"/> にする
- method が string（文字列だけで確定）と neighbor（前後から確定）の行を書く。
  interp（予想の枠で補った行）・check・conflict は確認に回す行なので書かない。
  --accept に line_id の一覧（確認で正しいとした行）を渡すと、それも書く（interp は予想の枠を書く）
- 既に facs の付いた <lb> は触らない（何度流しても同じ結果になる）

ファイルの書式（タブの字下げ）を崩さないよう、XML として読み直さず、文字列で置き換える。
"""
import argparse
import csv
import re
from collections import defaultdict
from pathlib import Path

SEG = 'https://w3id.org/kouigenjimonogatari/api/items/{}.json'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tsv", required=True, type=Path)
    ap.add_argument("--xml-dir", required=True, type=Path)
    ap.add_argument("--accept", type=Path)
    ap.add_argument("--dry", action="store_true")
    a = ap.parse_args()

    accepted = set()
    if a.accept:
        accepted = {l.split("\t")[0].strip() for l in a.accept.read_text().splitlines() if l.strip()}

    by_page = defaultdict(list)
    skipped = 0
    with a.tsv.open(encoding="utf-8") as f:
        for r in csv.DictReader(f, delimiter="\t"):
            if not r["x"] or (r["method"] not in ("string", "neighbor") and r["line_id"] not in accepted):
                skipped += 1
                continue
            by_page[r["page"]].append(r)

    total = 0
    for xml in sorted(a.xml_dir.glob("*.xml")):
        s = xml.read_text(encoding="utf-8")
        orig = s
        for pb in re.findall(r'<pb [^>]*>', s):
            mn = re.search(r'\bn="(\d+)"', pb)
            mz = re.search(r'corresp="#(zone_[^"]+)"', pb)
            if not (mn and mz):
                continue
            page, zone_id = mn.group(1), mz.group(1)
            rows = by_page.get(page)
            if not rows:
                continue
            zones = []
            for r in rows:
                lid = r["line_id"]
                zid = f"line_{lid}"
                x, y, w, h = (int(r[k]) for k in ("x", "y", "w", "h"))
                pat = re.compile(r'<lb/>(\s*<seg corresp="' + re.escape(SEG.format(lid)) + '")')
                s, k = pat.subn(f'<lb facs="#{zid}"/>\\1', s, count=1)
                if k:
                    zones.append(f'<zone type="line" lrx="{x + w}" lry="{y + h}" ulx="{x}" uly="{y}" xml:id="{zid}"/>')
                    total += 1
            if zones:
                m = re.search(r'(\n(\t*)<zone [^>]*xml:id="' + re.escape(zone_id) + r'"/>)', s)
                if not m:
                    raise SystemExit(f"{xml.name}: {zone_id} が見つかりません")
                indent = m.group(2)
                s = s[:m.end()] + "".join(f"\n{indent}{z}" for z in zones) + s[m.end():]
        if s != orig and not a.dry:
            xml.write_text(s, encoding="utf-8")
    print(f"書き込み {total} 行、保留 {skipped} 行" + ("（--dry のため書いていません）" if a.dry else ""))


if __name__ == "__main__":
    main()
