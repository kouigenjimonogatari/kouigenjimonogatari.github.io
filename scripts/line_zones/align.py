#!/usr/bin/env python3
"""TEI の行（座標なし）と NDLOCR-Lite の行（座標あり）を、頁ごとに対応づける。

使い方:
    python3 -I align.py --xml-dir xml/master --ocr-dir <ocr の JSON のフォルダ> --out lines.tsv

頁ごとに次を行う。
  1. TEI の <pb> から次の <pb> までの <seg> を、その頁の行として並べる（1 行 = 1 <seg>）
  2. OCR の行（JSON の contents[0]、読み順）を並べる
  3. 文字を揃えてから、1 - 編集距離 / 長い方の長さ を類似度とする
  4. 順番を崩さない対応づけ（動的計画法）。OCR の行は飛ばしてよい（校異欄・柱・行番号）。
     TEI の行も飛ばせるが、飛ばすと「未対応」として印を付ける
  5. 座標は切り出し画像の中の値なので、pb の facs の切り出し位置を足してキャンバスの座標に直す

出力 (TSV) の列:
  page line_id sim len canvas x y w h ocr_text tei_text flags
flags: low（類似度が低い）, short（文字が少ない）, unmatched（対応する OCR の行が無い）,
       margin（2 番目に似た OCR の行との差が小さい）
"""
import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

T = "{http://www.tei-c.org/ns/1.0}"
XMLID = "{http://www.w3.org/XML/1998/namespace}id"

LOW = 0.8      # これ未満は low
SHORT = 10     # 揃えた後の文字数がこれ未満は short
MARGIN = 0.1   # 1 位と 2 位の類似度の差がこれ未満は margin
SKIP_TEI = -0.5  # TEI の行を飛ばすときの点（類似度がこれを下回る対応より、飛ばす方を選ぶ）


def norm(s: str) -> str:
    """比べる前に揃える。踊り字の書き方、空白、数字（行番号）、記号を消す。"""
    s = s.replace("〳〵", "〱").replace("／＼", "〱")
    return re.sub(r"[\s　\d０-９\-―ー・、。「」『』（）()]", "", s)


def lev(a: str, b: str) -> int:
    prev = list(range(len(b) + 1))
    for i, x in enumerate(a, 1):
        cur = [i]
        for j, y in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (x != y)))
        prev = cur
    return prev[-1]


def sim(a: str, b: str) -> float:
    a, b = norm(a), norm(b)
    if not a and not b:
        return 0.0
    return 1 - lev(a, b) / max(len(a), len(b))


def read_tei(path: Path):
    """頁番号 → (キャンバス URI, 切り出しの x, y, [(line_id, text)])"""
    root = ET.parse(path).getroot()
    zone2canvas = {}
    for surface in root.iter(T + "surface"):
        for zone in surface.iter(T + "zone"):
            zone2canvas[zone.get(XMLID)] = surface.get("sameAs")
    pages = {}
    cur = None
    for el in root.iter():
        if el.tag == T + "pb":
            n = el.get("n")
            m = re.search(r"/(\d+),(\d+),\d+,\d+/full/", el.get("facs", ""))
            ox, oy = (int(m.group(1)), int(m.group(2))) if m else (0, 0)
            canvas = zone2canvas.get((el.get("corresp") or "").lstrip("#"))
            cur = pages.setdefault(n, {"canvas": canvas, "ox": ox, "oy": oy, "lines": []})
        elif el.tag == T + "seg" and cur is not None:
            lid = (el.get("corresp") or "").rsplit("/", 1)[-1].removesuffix(".json")
            cur["lines"].append((lid, "".join(el.itertext())))
    return pages


def box(o):
    xs = [p[0] for p in o["boundingBox"]]
    ys = [p[1] for p in o["boundingBox"]]
    return min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)


def align(tei_lines, ocr_lines):
    """順番を保つ対応づけ。戻り値は TEI の各行について (OCR の番号 or None, 類似度, 2 位との差)"""
    n, m = len(tei_lines), len(ocr_lines)
    S = [[sim(t, o["text"]) for o in ocr_lines] for _, t in tei_lines]
    NEG = float("-inf")
    dp = [[NEG] * (m + 1) for _ in range(n + 1)]
    bk = {}
    for j in range(m + 1):
        dp[0][j] = 0.0
    for i in range(1, n + 1):
        dp[i][0] = dp[i - 1][0] + SKIP_TEI
        bk[i, 0] = "t"
        for j in range(1, m + 1):
            cands = [
                (dp[i - 1][j - 1] + S[i - 1][j - 1], "d"),  # 対応
                (dp[i][j - 1], "o"),                         # OCR の行を飛ばす
                (dp[i - 1][j] + SKIP_TEI, "t"),              # TEI の行を飛ばす
            ]
            dp[i][j], bk[i, j] = max(cands)
    res = [None] * n
    i, j = n, m
    while i > 0:
        step = bk[i, j]
        if step == "d":
            res[i - 1] = j - 1
            i, j = i - 1, j - 1
        elif step == "o":
            j -= 1
        else:
            i -= 1
    out = []
    for i, j in enumerate(res):
        row = sorted(S[i], reverse=True) if S[i] else [0.0]
        if j is None:
            out.append((None, row[0], 0.0))
        else:
            others = [s for k, s in enumerate(S[i]) if k != j]
            second = max(others) if others else 0.0
            out.append((j, S[i][j], S[i][j] - second))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--xml-dir", required=True, type=Path)
    ap.add_argument("--ocr-dir", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    a = ap.parse_args()

    stats = {"pages": 0, "no_ocr": 0, "lines": 0, "low": 0, "short": 0, "unmatched": 0, "margin": 0, "flagged": 0}
    with a.out.open("w", encoding="utf-8") as w:
        w.write("page\tline_id\tsim\tlen\tcanvas\tx\ty\tw\th\tocr_text\ttei_text\tflags\n")
        for xml in sorted(a.xml_dir.glob("*.xml")):
            for n, pg in read_tei(xml).items():
                stats["pages"] += 1
                f = a.ocr_dir / f"{n}.json"
                if not f.exists():
                    stats["no_ocr"] += 1
                    continue
                ocr = json.loads(f.read_text(encoding="utf-8"))["contents"][0]
                for (lid, text), (j, s, mg) in zip(pg["lines"], align(pg["lines"], ocr)):
                    stats["lines"] += 1
                    L = len(norm(text))
                    flags = []
                    if j is None:
                        flags.append("unmatched")
                        x = y = bw = bh = ""
                        otext = ""
                    else:
                        bx, by, bw, bh = box(ocr[j])
                        x, y = bx + pg["ox"], by + pg["oy"]
                        otext = ocr[j]["text"]
                        if s < LOW:
                            flags.append("low")
                        if mg < MARGIN:
                            flags.append("margin")
                    if L < SHORT:
                        flags.append("short")
                    for fl in flags:
                        stats[fl] += 1
                    stats["flagged"] += bool(flags)
                    w.write("\t".join(map(str, [n, lid, f"{s:.3f}", L, pg["canvas"], x, y, bw, bh,
                                                otext, text, ",".join(flags)])) + "\n")
    print(json.dumps(stats, ensure_ascii=False), file=sys.stderr)


if __name__ == "__main__":
    main()
