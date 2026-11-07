#!/usr/bin/env python3
"""docs/ の中の HTML の内部リンクを確かめる（Endings Principles の「内部リンクはすべて確かめてある」）。

- href・src が指すファイルが docs/ の中にあるか
- #id の付いたリンクは、相手の頁にその id があるか
- 内部リンクが相対であるか（/ で始まる絶対パスや、自分のサイトの https:// を使っていないか）

外部のサイト（http・https・mailto など）へのリンクは確かめない。
projectEndings/html_diagnostics と同じことをするが、あちらは XHTML しか読めないので、
標準ライブラリの html.parser で書き直した。

使い方: python3 scripts/check_links.py [docs のパス]   問題が無ければ終了コード 0
"""

import os
import sys
from html.parser import HTMLParser
from urllib.parse import urlsplit, unquote

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = 'https://kouigenjimonogatari.github.io'
# 本文の頁がスクリプトで後から付ける id（#p13 は pb の span に、#waka-001 は lg に付いている）は
# HTML にそのまま書かれているので、特別扱いは要らない。
SKIP_DIRS = {'bibi', 'lib', 'bibi-bookshelf', 'api'}  # 外から持ち込んだ部品と JSON-LD は対象外


class Collect(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.ids, self.links, self.base = set(), [], None

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        for k in ('id', 'name') if tag == 'a' else ('id',):
            if a.get(k):
                self.ids.add(a[k])
        if tag == 'base' and a.get('href'):
            self.base = a['href']
        for k in ('href', 'src'):
            v = a.get(k)
            if v is None or (tag == 'link' and k == 'href' and a.get('rel') in ('canonical', 'alternate')):
                continue  # canonical・hreflang は公開先の絶対 URL を書くのが決まり
            if tag == 'meta':
                continue
            self.links.append((self.getpos()[0], tag, v))


def parse(path, cache={}):
    if path not in cache:
        p = Collect()
        with open(path, encoding='utf-8', errors='replace') as f:
            p.feed(f.read())
        cache[path] = p
    return cache[path]


def main():
    docs = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(BASE_DIR, 'docs'))
    pages = []
    for root, dirs, files in os.walk(docs):
        dirs[:] = [d for d in dirs if os.path.relpath(os.path.join(root, d), docs).split(os.sep)[0] not in SKIP_DIRS]
        pages += [os.path.join(root, f) for f in files if f.endswith('.html')]
    problems, nlinks = [], 0
    for page in sorted(pages):
        rel = os.path.relpath(page, docs)
        for line, tag, v in parse(page).links:
            if '${' in v:
                continue  # スクリプトの中のテンプレート
            u = urlsplit(v)
            if u.scheme in ('mailto', 'tel', 'data', 'javascript'):
                continue
            if v.startswith(SITE):
                problems.append(f'{rel}:{line}: 自分のサイトを絶対 URL で指している: {v}')
                continue
            if u.scheme or u.netloc:
                continue  # 外部
            nlinks += 1
            if u.path.startswith('/') and rel == '404.html':
                continue  # 404.html は GitHub Pages がどの階層の URL にも返すので、/ から書くしかない
            if u.path.startswith('/'):
                problems.append(f'{rel}:{line}: / で始まるリンク（相対にする）: {v}')
                continue
            target = os.path.normpath(os.path.join(os.path.dirname(page), unquote(u.path))) if u.path else page
            if os.path.isdir(target):
                target = os.path.join(target, 'index.html')
            if not os.path.exists(target):
                problems.append(f'{rel}:{line}: 相手のファイルが無い: {v}')
                continue
            if u.fragment and target.endswith('.html') and u.fragment not in parse(target).ids:
                problems.append(f'{rel}:{line}: 相手の頁に id が無い: {v}')
    for p in problems:
        print(p)
    print(f'{len(pages)} 頁・内部リンク {nlinks} 本を確かめた。問題 {len(problems)} 件', file=sys.stderr)
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
