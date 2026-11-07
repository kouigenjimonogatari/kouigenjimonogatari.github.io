#!/usr/bin/env python3
"""odd2html.xsl が作ったカスタマイズの解説（docs/schema/tei_kouigenji.html）のリンクを直す。

    python3 scripts/fix_schema_links.py docs/schema/tei_kouigenji.html

TEI Stylesheets は、TEI の要素・クラスごとに ref-<名前>.html という頁が並んでいる前提で
リンクを作る。このサイトでは解説を 1 頁にしているので、その頁が無く、
カスタマイズで使っていないクラス（model.global など）への #<名前> も頁の中に無い。
そのまま公開すると 239 本のリンクが切れていた（scripts/check_links.py で実測）。

- 頁の中に無い相手は、使っている TEI P5 の版（P5_VERSION）の公式の解説へ向ける
- index.html（このサイトには docs/schema/index.html が無い）はサイトのトップへ向ける
- サイト自身の絶対 URL は相対にする（Endings Principles: 内部リンクはすべて相対）

あわせて、HTML として検証を通らない部分を直す（W3C の Nu HTML Checker で 1,354 件出ていた）。
- xml:lang だけが付いた要素に、同じ値の lang を足す（HTML では lang が要る）
- xml:space="preserve" を外す（HTML には無い属性。表示は class="pre" の CSS が受け持つ）
- 生成器の消し忘れの処理命令 <?DEBUG ...?> を外す

何度かけても同じ結果になる（build-schema.zsh の再生成と、CI の一致の検査のため）。
"""

import pathlib
import re
import sys

P5_VERSION = '4.12.0'  # scripts/lib/tools.zsh と揃える
TEI_REF = f'https://www.tei-c.org/Vault/P5/{P5_VERSION}/doc/tei-p5-doc/en/html/ref-{{}}.html'
SITE = 'https://kouigenjimonogatari.github.io/'


def fix(text):
    ids = set(re.findall(r'\bid="([^"]+)"', text))

    def repl(m):
        href = m.group(1)
        r = re.fullmatch(r'ref-(.+)\.html', href)
        if r:
            name = r.group(1)
            return f'href="#{name}"' if name in ids else f'href="{TEI_REF.format(name)}"'
        if href.startswith("#") and len(href) > 1 and href[1:] not in ids:
            return f'href="{TEI_REF.format(href[1:])}"'
        if href in ('index.html', SITE):
            return 'href="../index.html"'
        return m.group(0)

    text = re.sub(r'href="([^"]*)"', repl, text)
    text = re.sub(r'<\?DEBUG[^>]*\?>', '', text)
    text = text.replace(' xml:space="preserve"', '')

    def add_lang(m):
        tag = m.group(0)
        if re.search(r'\slang="', tag):
            return tag
        return tag.replace(f'xml:lang="{m.group(1)}"', f'xml:lang="{m.group(1)}" lang="{m.group(1)}"', 1)

    return re.sub(r'<[a-zA-Z][^<>]*\sxml:lang="([^"]*)"[^<>]*>', add_lang, text)


def main():
    for p in sys.argv[1:]:
        path = pathlib.Path(p)
        old = path.read_text(encoding='utf-8')
        new = fix(old)
        if new != old:
            path.write_text(new, encoding='utf-8')


if __name__ == '__main__':
    main()
