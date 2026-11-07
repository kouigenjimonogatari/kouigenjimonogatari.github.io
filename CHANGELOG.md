# Changelog / 変更履歴

版ごとの主な変更を記します。新しい版を上に書きます。
Notable changes for each version, newest first.

## [1.1.0] - 2026-11-06

サイトを Endings Principles（長く使い続けられるデジタル資料のための指針）に沿って作り直した版です。TEI 本文（`xml/master/`）は変えていません。
The website was rebuilt following the Endings Principles for digital longevity. The TEI text (`xml/master/`) is unchanged.

- 外部の CDN をやめ、Mirador 4.3.0 と Chart.js 4.4.4 を `docs/lib/` に同梱。Bootstrap と jQuery は使わない / No CDN: Mirador and Chart.js are bundled; Bootstrap and jQuery removed
- 巻の一覧と和歌の一覧（795 首）を組み立て時に HTML に書き込む。スクリプトが動かなくても読める / The volume list and the waka list are written into the HTML at build time
- URL のクエリをやめた。頁は `html/01.html#p13`、和歌は `#waka-001`。英語版は `en/` の下（`en/html/01.html`）。古い URL（`?lang=en`・`?canvas=`・`*-en.html`）は転送する / No query strings: `#p13`, `#waka-001`, English pages under `en/`; old URLs redirect
- 各頁に版・公開日・DOI を表示し、トップに「引用の仕方」を置いた。値は `CITATION.cff` から / Every page shows version, release date and DOI from `CITATION.cff`; a How to Cite section on the top page
- JSON-LD: 帖から行へ `hasPart`、漢字の巻名（`alternative`）、行から本文の頁へのリンク / JSON-LD: `hasPart` from volume to lines, kanji volume names, links to the text pages
- 検証: 公開する HTML を W3C の Nu HTML Checker で、内部リンクを `scripts/check_links.py` で CI で確かめる（`scripts/check-html.zsh`）。頁の版の表示と `CITATION.cff` の一致も確かめる / CI validates the published HTML and internal links, and checks that the pages show the version in `CITATION.cff`
- SPARQL の画面（snorql）を外し、Musubi へのリンクに / snorql removed in favour of links to Musubi
- ODD の作成者の所属を「東京大学」に / ODD: affiliation given as The University of Tokyo

## [1.0.0] - 2026-11-06

最初の版番号つきの公開。Zenodo に保存し、DOI を付ける最初の版です。
First versioned release, archived on Zenodo with a DOI.

- TEI 本文 54 帖（`xml/master/`）
- TEI のカスタマイズ（`odd/tei_kouigenji.odd`）と、そこから作るスキーマ（`docs/schema/`）
- item API（Linked Open Data）を TEI 本文から生成
- 削除: 本文修正より前で止まっていた `scripts/data/metadata.xlsx` と、それを読む旧スクリプト（#13）
