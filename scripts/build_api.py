#!/usr/bin/env python3
"""xml/master/*.xml から item / item_set の JSON-LD を生成する。

    python3 scripts/build_api.py            docs/api/ 以下に出力
    python3 scripts/build_api.py --check    出力せず、TEI との整合だけ検査

生成物:
    docs/api/items/<ページ4桁>-<行2桁>.json   本文1行につき1件
    docs/api/item_sets/<帖2桁>.json           帖につき1件

これらは seg/@corresp と pb が指す URI の実体で、w3id.org 経由で解決される。

    https://w3id.org/kouigenjimonogatari/api/items/0005-01.json
      → https://kouigenjimonogatari.github.io/api/items/0005-01.json

## なぜ TEI から作るのか

以前は scripts/001_convert_xlsx_to_rdf.py が data/metadata.xlsx から生成していた。
しかしその xlsx は本文修正・異体字正規化より前の状態で止まっており、
現行の TEI と比べると 25,065 行中 24,747 行で本文が違う（後凉殿/後涼殿、御覽/御覧、
いと〱しく/いとゝしく など）。そのまま配信すると、公開中の TEI と食い違う本文を
API として出すことになる。

xml/master/ がマスターである以上、API もそこから作る。副次的な効果として
pandas / numpy / rdflib / openpyxl が不要になり、依存は lxml だけで済む。

## 語彙

旧実装（001_convert_xlsx_to_rdf.py / 011_create_collection.py）が RDF に出していた
プロパティをそのまま踏襲する。canvas / manifest は旧実装では列はあったものの
プロパティ URI が与えられておらず RDF に出ていなかったが、TEI から確実に導出でき
利用価値が高いので、既存の property 名前空間に追加している。
"""

import argparse
import glob
import json
import os
import re
import sys

from lxml import etree

TEI = 'http://www.tei-c.org/ns/1.0'
T = '{%s}' % TEI

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
XML_DIR = os.path.join(BASE_DIR, 'xml', 'master')
DOCS_DIR = os.path.join(BASE_DIR, 'docs')

DEFAULT_SITE_URL = 'https://w3id.org/kouigenjimonogatari'
BASE = os.environ.get('API_BASE_URL', DEFAULT_SITE_URL).rstrip('/')

PROP = BASE + '/api/property/'
ITEMS = BASE + '/api/items/'
ITEM_SETS = BASE + '/api/item_sets/'
TEI_URI = BASE + '/tei/'

TYPE_LINE = 'https://jpsearch.go.jp/term/type/文章要素'
TYPE_WORK = 'https://jpsearch.go.jp/term/type/作品'
CC0 = 'http://creativecommons.org/publicdomain/zero/1.0/'
CURATION = 'http://codh.rois.ac.jp/software/iiif-curation-viewer/demo/'

CONTEXT_URI = BASE + '/api/context.json'

# 25,065 件すべてに埋め込むと 100MB 近くになるので、外部コンテキストとして
# docs/api/context.json に1つだけ置き、各ファイルからは URI で参照する。
CONTEXT = {
    'rdfs': 'http://www.w3.org/2000/01/rdf-schema#',
    'dcterms': 'http://purl.org/dc/terms/',
    'kg': PROP,
    'label': 'rdfs:label',
    'seeAlso': {'@id': 'rdfs:seeAlso', '@type': '@id'},
    'rights': {'@id': 'dcterms:rights', '@type': '@id'},
    'relation': {'@id': 'dcterms:relation', '@type': '@id'},
    'isPartOf': {'@id': 'dcterms:isPartOf', '@type': '@id'},
    'page': 'kg:page',
    'row': 'kg:row',
    'vol': 'kg:vol',
    'canvas': {'@id': 'kg:canvas', '@type': '@id'},
    'manifest': {'@id': 'kg:manifest', '@type': '@id'},
}


def chapter_of(path):
    return os.path.splitext(os.path.basename(path))[0]


def parse_chapter(path):
    """1帖分の TEI から、item の材料と item_set の材料を取り出す。"""
    tree = etree.parse(path)
    root = tree.getroot()
    ch = chapter_of(path)

    # facsimile: zone の xml:id → その zone を含む surface の canvas URI
    manifest = None
    facs = root.find(T + 'facsimile')
    if facs is not None:
        manifest = facs.get('sameAs')
    canvas_of_zone = {}
    for surface in root.iter(T + 'surface'):
        canvas = surface.get('sameAs')
        for zone in surface.iter(T + 'zone'):
            zid = zone.get('{http://www.w3.org/XML/1998/namespace}id')
            if zid:
                canvas_of_zone[zid] = canvas

    # 巻名: <title>校異源氏物語・きりつぼ</title>
    title_el = root.find('.//' + T + 'titleStmt/' + T + 'title')
    title = (title_el.text or '').strip() if title_el is not None else ''
    volume_name = title.split('・')[-1] if '・' in title else title

    items = []
    page = None
    canvas = None
    row = 0
    # 本文は <p> の中を文書順に見る。pb が現れたらページが変わる。
    body = root.find('.//' + T + 'body')
    for el in body.iter():
        tag = etree.QName(el).localname if isinstance(el.tag, str) else None
        if tag == 'pb':
            page = el.get('n')
            corresp = el.get('corresp') or ''
            canvas = canvas_of_zone.get(corresp[1:]) if corresp.startswith('#') else None
            row = 0
        elif tag == 'seg':
            row += 1
            items.append({
                'id': el.get('corresp'),
                'page': page,
                'row': row,
                'label': ''.join(el.itertext()).strip(),
                'canvas': canvas,
            })

    return {
        'chapter': ch,
        'volume_name': volume_name,
        'manifest': manifest,
        'items': items,
    }


def item_doc(it, ch, manifest):
    """1行分の JSON-LD。"""
    doc = {
        '@context': CONTEXT_URI,
        '@id': it['id'],
        '@type': TYPE_LINE,
        'label': it['label'],
        'page': it['page'],
        'row': str(it['row']),
        'rights': CC0,
        'isPartOf': ITEM_SETS + ch + '.json',
    }
    if manifest:
        doc['manifest'] = manifest
    if it['canvas']:
        doc['canvas'] = it['canvas']
    if manifest and it['canvas']:
        doc['relation'] = '%s?manifest=%s&canvas=%s' % (CURATION, manifest, it['canvas'])
    return doc


def item_set_doc(ch, volume_name, manifest, vol):
    doc = {
        '@context': CONTEXT_URI,
        '@id': ITEM_SETS + ch + '.json',
        '@type': TYPE_WORK,
        'label': volume_name,
        'rights': CC0,
        'relation': TEI_URI + ch + '.xml',
    }
    if vol is not None:
        doc['vol'] = str(vol)
    if manifest:
        doc['seeAlso'] = manifest
    return doc


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--check', action='store_true',
                    help='出力せず、TEI との整合だけ検査する')
    args = ap.parse_args(argv)

    paths = sorted(glob.glob(os.path.join(XML_DIR, '*.xml')))
    if not paths:
        print('xml/master/*.xml が見つかりません', file=sys.stderr)
        return 1

    chapters = [parse_chapter(p) for p in paths]

    # 冊番号: manifest の初出順に 1 から振る（底本は全5冊）
    vol_of_manifest = {}
    for c in chapters:
        if c['manifest'] and c['manifest'] not in vol_of_manifest:
            vol_of_manifest[c['manifest']] = len(vol_of_manifest) + 1

    problems = []
    n_items = 0
    seen_ids = set()
    uri_re = re.compile(r'^%s(\d{4})-(\d{2})\.json$' % re.escape(ITEMS))

    items_dir = os.path.join(DOCS_DIR, 'api', 'items')
    sets_dir = os.path.join(DOCS_DIR, 'api', 'item_sets')
    if not args.check:
        os.makedirs(items_dir, exist_ok=True)
        os.makedirs(sets_dir, exist_ok=True)
        with open(os.path.join(DOCS_DIR, 'api', 'context.json'), 'w', encoding='utf-8') as f:
            json.dump({'@context': CONTEXT}, f, ensure_ascii=False, indent=2)

    for c in chapters:
        ch = c['chapter']
        vol = vol_of_manifest.get(c['manifest'])
        for it in c['items']:
            n_items += 1
            uri = it['id']
            m = uri_re.match(uri or '')
            if not m:
                problems.append('%s: seg/@corresp が規定の形式ではありません: %r' % (ch, uri))
                continue
            if uri in seen_ids:
                problems.append('%s: seg/@corresp が重複しています: %s' % (ch, uri))
            seen_ids.add(uri)
            # URI のページ・行が、TEI から導いた位置と一致するか
            if m.group(1) != (it['page'] or '').zfill(4):
                problems.append('%s: URI のページが pb/@n と一致しません: %s (pb=%s)'
                                % (ch, uri, it['page']))
            if int(m.group(2)) != it['row']:
                problems.append('%s: URI の行が文書順と一致しません: %s (実際は %d 行目)'
                                % (ch, uri, it['row']))
            if not it['label']:
                problems.append('%s: 本文が空です: %s' % (ch, uri))
            if not args.check:
                name = uri.rsplit('/', 1)[-1]
                with open(os.path.join(items_dir, name), 'w', encoding='utf-8') as f:
                    json.dump(item_doc(it, ch, c['manifest']), f, ensure_ascii=False, indent=2)

        if not args.check:
            with open(os.path.join(sets_dir, ch + '.json'), 'w', encoding='utf-8') as f:
                json.dump(item_set_doc(ch, c['volume_name'], c['manifest'], vol),
                          f, ensure_ascii=False, indent=2)

    if problems:
        for p in problems[:20]:
            print('  ' + p, file=sys.stderr)
        if len(problems) > 20:
            print('  ... 他 %d 件' % (len(problems) - 20), file=sys.stderr)
        print('整合しない項目が %d 件あります' % len(problems), file=sys.stderr)
        return 1

    if args.check:
        print('item %d 件 / item_set %d 件。TEI と整合しています。'
              % (n_items, len(chapters)))
    else:
        print('  context → docs/api/context.json')
        print('  item %d 件 → docs/api/items/' % n_items)
        print('  item_set %d 件 → docs/api/item_sets/ (底本 %d 冊)'
              % (len(chapters), len(vol_of_manifest)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
