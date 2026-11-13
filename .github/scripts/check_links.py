#!/usr/bin/env python3
"""DIP（組み立てたサイト）の中のリンクを確かめる（標準ライブラリだけで動く）。

  python3 check_links.py <DIP のフォルダ> [--site-url https://kouigenjimonogatari.github.io/]

確かめること（Endings の原則の「内部リンクは相対で、すべて確かめてある」）:
  1. 相対リンク（href・src・srcset・poster・data、CSS の url()）が、DIP の中のファイルを指しているか。
     「#」の付いたリンクは、指す先の HTML にその id（または name）があるかも確かめる
  2. 内部リンクが絶対の形で書かれていないか（「/」で始まるもの、サイトの URL で始まるもの）。
     ただし rel="canonical" と rel="alternate" の link 要素は、検索エンジン向けに絶対 URL が決まりなので除く。
     404.html も除く（GitHub Pages は、無い URL のどこででもこの頁を返すので、相対リンクでは戻り先がずれる）

どちらかが 1 件でもあれば、終了コード 1 で終わる。外部（他のサイト）へのリンクは数えるだけで、止めない。
GITHUB_STEP_SUMMARY があれば、要約を書き足す。
"""

import argparse
import collections
import html.parser
import os
import re
import sys
import urllib.parse

# 第三者の道具をそのまま同梱したもの。中のリンクは道具が JavaScript で組み立てるので、ここでは見ない
SKIP_DIRS = ('bibi/', 'lib/', 'epub/')
SKIP_FILES = {'google42e5d8b9a7f8c8d9.html'}   # Google の所有確認用のファイル（頁ではない）
ROOT_RELATIVE_OK = {'404.html'}                 # 「/」で始まるリンクを許す頁（上の 2 の但し書き）
URL_ATTRS = {'href', 'src', 'poster', 'data', 'action', 'formaction'}
SKIP_SCHEMES = ('mailto:', 'tel:', 'javascript:', 'data:', 'blob:')
CSS_URL = re.compile(r'url\(\s*([\'"]?)([^\'")]+)\1\s*\)')


class Page(html.parser.HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.links = []      # (要素, 属性, 値, rel)
        self.ids = set()
        self.in_style = False

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        for k in ('id', 'name'):
            if a.get(k):
                self.ids.add(a[k])
        rel = (a.get('rel') or '').lower().split()
        for k, v in attrs:
            if v is None:
                continue
            if k in URL_ATTRS:
                self.links.append((tag, k, v.strip(), rel))
            elif k in ('srcset', 'imagesrcset'):
                for part in v.split(','):
                    u = part.strip().split(' ')[0]
                    if u:
                        self.links.append((tag, k, u, rel))
            elif k == 'style':
                for m in CSS_URL.finditer(v):
                    self.links.append((tag, 'style', m.group(2).strip(), rel))
        self.in_style = tag == 'style'

    def handle_endtag(self, tag):
        if tag == 'style':
            self.in_style = False

    def handle_data(self, data):
        if self.in_style:
            for m in CSS_URL.finditer(data):
                self.links.append(('style', 'url()', m.group(2).strip(), []))


def skipped(rel):
    return rel in SKIP_FILES or rel.startswith(SKIP_DIRS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('root')
    ap.add_argument('--site-url', default='https://kouigenjimonogatari.github.io/')
    args = ap.parse_args()
    root = os.path.abspath(args.root)
    site = args.site_url.rstrip('/') + '/'
    site_host = urllib.parse.urlsplit(site).netloc

    pages, sources = {}, []   # sources: (DIP の中のパス, 要素, 属性, 値, rel)
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames.sort()
        for fn in sorted(filenames):
            path = os.path.join(dirpath, fn)
            rel = os.path.relpath(path, root).replace(os.sep, '/')
            if skipped(rel):
                continue
            if fn.endswith(('.html', '.htm', '.xhtml')):
                p = Page()
                p.feed(open(path, encoding='utf-8', errors='replace').read())
                p.close()
                pages[rel] = p
                sources += [(rel, *l) for l in p.links]
            elif fn.endswith('.css'):
                text = open(path, encoding='utf-8', errors='replace').read()
                sources += [(rel, 'css', 'url()', m.group(2).strip(), []) for m in CSS_URL.finditer(text)]

    ids_cache = {}

    def ids_of(target):
        if target in pages:
            return pages[target].ids
        if target not in ids_cache:
            p = Page()
            p.feed(open(os.path.join(root, target), encoding='utf-8', errors='replace').read())
            ids_cache[target] = p.ids
        return ids_cache[target]

    broken, absolute, missing_anchor = [], [], []
    external = collections.Counter()
    checked = 0
    for rel, tag, attr, val, relattr in sources:
        if not val or val.lower().startswith(SKIP_SCHEMES) or '{' in val:
            continue
        sp = urllib.parse.urlsplit(val)
        is_link_meta = tag == 'link' and ({'canonical', 'alternate'} & set(relattr))
        if sp.scheme in ('http', 'https') or val.startswith('//'):
            if sp.netloc == site_host:
                if not is_link_meta:
                    absolute.append((rel, tag, attr, val))
            else:
                external[sp.netloc] += 1
            continue
        if sp.scheme:
            continue
        if val.startswith('/'):
            if rel in ROOT_RELATIVE_OK:
                continue
            absolute.append((rel, tag, attr, val))
            continue
        checked += 1
        base = os.path.dirname(rel)
        if sp.path == '':
            target = rel                     # 「#x」だけのリンク: 同じ頁の中
        else:
            target = os.path.normpath(os.path.join(base, urllib.parse.unquote(sp.path))).replace(os.sep, '/')
            if target.startswith('..'):
                broken.append((rel, tag, attr, val, 'DIP の外を指す'))
                continue
            full = os.path.join(root, target)
            if os.path.isdir(full) or sp.path.endswith('/'):
                target = (target.rstrip('/') + '/index.html').lstrip('./') if target != '.' else 'index.html'
                full = os.path.join(root, target)
            if not os.path.isfile(full):
                broken.append((rel, tag, attr, val, 'ファイルが無い'))
                continue
        frag = urllib.parse.unquote(sp.fragment)
        if frag and target.endswith(('.html', '.htm', '.xhtml')) and not skipped(target):
            if frag not in ids_of(target):
                missing_anchor.append((rel, tag, attr, val, f'{target} に id="{frag}" が無い'))

    print(f'pages: {len(pages)}  links: {len(sources)}  relative checked: {checked}')
    print(f'broken: {len(broken)}  missing anchors: {len(missing_anchor)}  absolute internal: {len(absolute)}')
    print('external hosts: ' + ', '.join(f'{h} {n}' for h, n in external.most_common()))
    for r in broken + missing_anchor:
        print('BROKEN:', *r)
    for r in absolute:
        print('ABSOLUTE:', *r)

    bad = len(broken) + len(missing_anchor) + len(absolute)
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as out:
            print(f'### DIP のリンク: {"問題なし" if not bad else f"**{bad} 件の問題**"}', file=out)
            print(f'- 頁 {len(pages)}・相対リンク {checked} 件を確かめた。切れ {len(broken)}・'
                  f'頁内の位置が無い {len(missing_anchor)}・絶対の形の内部リンク {len(absolute)}', file=out)
            print(f'- 外部へのリンク（止めない）: ' + ', '.join(f'{h} {n}' for h, n in external.most_common(10)), file=out)
            for r in (broken + missing_anchor + absolute)[:20]:
                print(f'- `{r[0]}`: `{r[3]}`', file=out)
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
