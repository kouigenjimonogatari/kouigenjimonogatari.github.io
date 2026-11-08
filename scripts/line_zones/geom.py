#!/usr/bin/env python3
"""align.py の結果を、行の並び（位置）で確かめ直す。

使い方:
    python3 -I geom.py --tsv lines.tsv --out lines_geom.tsv

考え方:
  - 縦書きなので、行は右から左へ並ぶ。行の番号が 1 つ進むと、x が約 1 行分（間隔）だけ減る
  - 確かな行（印が無く、類似度 0.9 以上、10 文字以上）を「手がかり」にする
  - どの行も、前後の手がかりから x を内挿して「予想の枠」を作る
      x: 前後の手がかりの x を、行番号の比で内挿（片側しか無いときは頁の間隔で外挿）
      幅: 頁の手がかりの幅の中央値
      上端: 頁の手がかりの上端の中央値
      高さ: 文字数 × 1 字の高さ（頁の手がかりの 高さ / 文字数 の中央値）
  - OCR の枠の x が予想から半行分以内なら、位置が合う（geom_ok）

method 列:
  string    印が無く、位置も合う（文字列だけで確定）
  neighbor  印はあるが、位置が合う（前後から確定）
  interp    対応する OCR の行が無い、または位置が合わない。予想の枠に置き換え、確認に回す
  conflict  印が無いのに位置が合わない（文字列と位置が食い違う。確認に回す）

あわせて、手がかりの行を 1 行ずつ隠して予想し、実際の枠との重なり（IoU）を測る（標準エラーに出す）。
"""
import argparse
import csv
import json
import statistics as st
import sys
from collections import defaultdict
from pathlib import Path


def is_anchor(r):
    return r["x"] and not r["flags"] and float(r["sim"]) >= 0.9 and int(r["len"]) >= 10


def iou(a, b):
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    ix = max(0, min(ax + aw, bx + bw) - max(ax, bx))
    iy = max(0, min(ay + ah, by + bh) - max(ay, by))
    inter = ix * iy
    u = aw * ah + bw * bh - inter
    return inter / u if u else 0.0


def page_model(rows, anchors):
    """頁の規則: 間隔（1 行あたりの x の変化）、幅、上端、1 字の高さ"""
    xs = [(i, int(rows[i]["x"])) for i in anchors]
    steps = [(x2 - x1) / (i2 - i1) for (i1, x1), (i2, x2) in zip(xs, xs[1:])]
    return {
        "pitch": st.median(steps) if steps else None,
        "w": st.median(int(rows[i]["w"]) for i in anchors),
        "y": st.median(int(rows[i]["y"]) for i in anchors),
        "ch": st.median(int(rows[i]["h"]) / int(rows[i]["len"]) for i in anchors),
    }


def predict(i, rows, anchors, m):
    """i 行目の予想の枠。anchors に i 自身は含めない"""
    before = [a for a in anchors if a < i]
    after = [a for a in anchors if a > i]
    if before and after:
        a, b = before[-1], after[0]
        xa, xb = int(rows[a]["x"]), int(rows[b]["x"])
        x = xa + (xb - xa) * (i - a) / (b - a)
    elif m["pitch"] is not None and (before or after):
        a = before[-1] if before else after[0]
        x = int(rows[a]["x"]) + m["pitch"] * (i - a)
    else:
        return None
    h = max(1, int(rows[i]["len"])) * m["ch"]
    return (round(x), round(m["y"]), round(m["w"]), round(h))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tsv", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    a = ap.parse_args()

    pages = defaultdict(list)
    with a.tsv.open(encoding="utf-8") as f:
        rd = csv.DictReader(f, delimiter="\t")
        fields = rd.fieldnames
        for r in rd:
            pages[r["page"]].append(r)

    loo_iou, loo_dx_ok = [], []
    count = defaultdict(int)
    out_rows = []
    for page, rows in pages.items():
        anchors = [i for i, r in enumerate(rows) if is_anchor(r)]
        if len(anchors) < 2:
            for r in rows:
                r["method"] = "string" if r["x"] and not r["flags"] else "check"
                r["dx"] = ""
                count[r["method"]] += 1
                out_rows.append(r)
            continue
        m = page_model(rows, anchors)
        half = abs(m["pitch"]) / 2 if m["pitch"] else 50

        # 1 行ずつ隠して予想する（手がかりの行だけ）
        for i in anchors:
            others = [k for k in anchors if k != i]
            p = predict(i, rows, others, m)
            if p is None:
                continue
            act = tuple(int(rows[i][k]) for k in ("x", "y", "w", "h"))
            loo_iou.append(iou(p, act))
            loo_dx_ok.append(abs(p[0] - act[0]) < half)

        for i, r in enumerate(rows):
            p = predict(i, rows, [k for k in anchors if k != i], m)
            if r["x"] and p:
                dx = int(r["x"]) - p[0]
                ok = abs(dx) < half
            else:
                dx, ok = "", False
            r["dx"] = dx
            if r["x"] and ok:
                r["method"] = "neighbor" if r["flags"] else "string"
            elif not r["flags"] and r["x"]:
                r["method"] = "conflict"
            else:
                r["method"] = "interp"
            if r["method"] in ("interp", "conflict") and p:
                r["ocr_x"], r["ocr_y"], r["ocr_w"], r["ocr_h"] = r["x"], r["y"], r["w"], r["h"]
                if r["method"] == "interp":
                    r["x"], r["y"], r["w"], r["h"] = map(str, p)
            count[r["method"]] += 1
            out_rows.append(r)

    cols = fields + ["method", "dx"]
    with a.out.open("w", encoding="utf-8") as w:
        w.write("\t".join(cols) + "\n")
        for r in out_rows:
            w.write("\t".join(str(r.get(c, "")) for c in cols) + "\n")

    loo = {
        "n": len(loo_iou),
        "iou_median": round(st.median(loo_iou), 3) if loo_iou else None,
        "iou>=0.5": round(sum(v >= 0.5 for v in loo_iou) / len(loo_iou), 4) if loo_iou else None,
        "x_within_half_pitch": round(sum(loo_dx_ok) / len(loo_dx_ok), 4) if loo_dx_ok else None,
    }
    print(json.dumps({"method": dict(count), "leave_one_out": loo}, ensure_ascii=False), file=sys.stderr)


if __name__ == "__main__":
    main()
