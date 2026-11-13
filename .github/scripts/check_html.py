#!/usr/bin/env python3
"""DIP（組み立てたサイト）の HTML と CSS を Nu Html Checker（vnu）で検証する（標準ライブラリだけで動く）。

  python3 check_html.py <DIP のフォルダ> --vnu <vnu.jar>

対象: DIP の中の *.html と *.css すべて。ただし次は除く。
  bibi/  第三者の EPUB 閲覧の道具をそのまま同梱したもの（直すのは上流）
  lib/   第三者のライブラリ
  epub/  EPUB を展開したもの。EPUB 3 の決まり（html の prefix 属性など）は HTML の決まりと違うので、
         vnu では誤って誤りになる。EPUB は epubcheck で確かめるべきもの
  google42e5d8b9a7f8c8d9.html  Google の所有確認用のファイル（頁ではない）

誤り（error）が 1 件でもあれば、終了コード 1 で終わる。
警告（warning）は数えて要約に書くが、止めない。vnu の版を上げたときに新しく増える
「推奨」の類で公開が止まらないようにするため。情報（info）は数えるだけ。
GITHUB_STEP_SUMMARY があれば、要約を書き足す。
"""

import argparse
import collections
import json
import os
import re
import subprocess
import sys

SKIP_DIRS = ('bibi/', 'lib/', 'epub/')
SKIP_FILES = {'google42e5d8b9a7f8c8d9.html'}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('root')
    ap.add_argument('--vnu', required=True, help='vnu.jar のパス')
    ap.add_argument('--java', default='java')
    args = ap.parse_args()
    root = os.path.abspath(args.root)

    targets = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames.sort()
        for fn in sorted(filenames):
            rel = os.path.relpath(os.path.join(dirpath, fn), root).replace(os.sep, '/')
            if rel in SKIP_FILES or rel.startswith(SKIP_DIRS):
                continue
            if fn.endswith(('.html', '.css')):
                targets.append(rel)
    if not targets:
        sys.exit('検証する HTML が 1 つも無い')

    r = subprocess.run([args.java, '-Xss8m', '-jar', os.path.abspath(args.vnu), '--also-check-css', '--format', 'json',
                        '--exit-zero-always', *targets], cwd=root, capture_output=True, text=True)
    try:
        messages = json.loads(r.stderr)['messages']
    except (ValueError, KeyError):
        print(r.stderr[-2000:], file=sys.stderr)
        sys.exit('vnu の出力を読めなかった')

    def kind(m):
        return 'warning' if m.get('subType') == 'warning' else m['type']   # error / warning / info / non-document-error

    counts = collections.Counter(kind(m) for m in messages)
    by_msg = collections.Counter((kind(m), re.sub(r'“[^”]*”', '“…”', m.get('message', ''))) for m in messages)
    errors = [m for m in messages if kind(m) in ('error', 'non-document-error', 'fatal')]

    def where(m):
        u = m.get('url', '')
        u = u.split(root + '/', 1)[-1] if root in u else u.replace('file:', '')
        return f"{u}:{m.get('lastLine', '?')}"

    n_html = sum(t.endswith('.html') for t in targets)
    print(f'vnu {json.loads(r.stderr).get("version", "?")}: HTML {n_html}・CSS {len(targets) - n_html} files')
    print('counts: ' + ', '.join(f'{k} {v}' for k, v in sorted(counts.items())))
    for (k, msg), n in by_msg.most_common():
        print(f'  {n:6d}  {k:8s}  {msg[:150]}')
    for m in errors:
        print(f"ERROR: {where(m)}: {m.get('message', '')}")
    for m in messages:
        if kind(m) == 'warning':
            print(f"WARNING: {where(m)}: {m.get('message', '')}")

    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as out:
            print(f'### DIP の HTML 検証（vnu）: {"誤りなし" if not errors else f"**誤り {len(errors)} 件**"}', file=out)
            print(f'- HTML {n_html}・CSS {len(targets) - n_html} ファイル。誤り {len(errors)}・'
                  f'警告 {counts["warning"]}（止めない）・情報 {counts["info"]}', file=out)
            for m in (errors + [m for m in messages if kind(m) == 'warning'])[:20]:
                print(f"- {kind(m)}: `{where(m)}` {m.get('message', '')}", file=out)
    sys.exit(1 if errors else 0)


if __name__ == '__main__':
    main()
