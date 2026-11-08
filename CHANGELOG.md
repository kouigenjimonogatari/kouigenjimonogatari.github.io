# Changelog / 変更履歴

版ごとの主な変更を記します。新しい版を上に書きます。
Notable changes for each version, newest first.

## [1.4.0] - 2026-11-07

本文の頁の画像の表示を替えた版です。TEI 本文（`xml/master/`）は変えていません。
The image viewer on text pages was replaced. The TEI text (`xml/master/`) is unchanged.

- 本文の頁の画像を Mirador から OpenSeadragon 6.1.1 に替えた。本文の行を押すと、その行の範囲（`<zone type="line">`）を画像の上で薄い赤に塗り、行が収まるように拡大する。もう一度押すか Esc で消える。和歌への `#waka-NNN` で開いたときも、その行に色を付ける / The image viewer on text pages is now OpenSeadragon 6.1.1 instead of Mirador. Clicking a line of the text highlights its line zone on the image and zooms to it (click again or press Esc to clear); links to a waka (`#waka-NNN`) do the same
- 画像はその巻の画像だけをめくる（以前は Mirador がマニフェスト全体を読んでいた）。マニフェストは読まず、頁の `@facs` から IIIF Image API の URL を取る / Only the images of the volume are shown; the manifest is no longer fetched, and the IIIF Image API URL is taken from each page's `@facs`
- トップのお知らせに 1 件（日英）。1.3.0 で付けた行の位置と、この版の表示をあわせて知らせる / Added a news item (ja/en) on the line positions (1.3.0) and the new viewer
- `xsl/mirador.xsl` を `xsl/page.xsl` に改名。`docs/lib/mirador-4.3.0` を外した / Renamed `xsl/mirador.xsl` to `xsl/page.xsl`; removed `docs/lib/mirador-4.3.0`

## [1.3.0] - 2026-11-07

TEI 本文の各行に、画像上の位置（行の枠）を付けた版です。本文の文字は変えていません。
Each line of the TEI text now has its position on the page image. The characters of the text are unchanged.

- 全 25,065 行に `<zone type="line" xml:id="line_<頁>-<行>" ulx uly lrx lry/>` を足し（その頁の `<surface>` の中）、行頭の `<lb/>` を `<lb facs="#line_<頁>-<行>"/>` にした / Added a line zone for each of the 25,065 lines inside the page's `<surface>`, and pointed each line's `<lb/>` to it with `@facs`
- 座標は NDLOCR-Lite の行と本文の行を対応づけ（行の順を崩さない動的計画法）、行の横の位置で確かめて付けた。OCR が行を検出し落とした 7 行は、前後の行から推定した枠を付けた。道具は `scripts/line_zones/`、経過と実測は `notes/line-zones.md` / The coordinates come from aligning NDLOCR-Lite lines with the text lines (order-preserving dynamic programming) and checking the horizontal position; 7 lines missed by the OCR were given boxes estimated from their neighbours. Tools in `scripts/line_zones/`, notes in `notes/line-zones.md`
- 画像での判定: 抽出した 109 行で行の取り違えは 0 行 / Image check: no wrong line among 109 sampled lines
- 狭い画面（375px 前後）での表示を直した。トップの 3 枚のカードを外し、本文の頁の上部の帯を低くし、和歌のグラフは横に送れるようにした（#28） / Layout fixes for narrow screens: the three cards on the top page removed, a lower header on text pages, the waka chart scrolls sideways (#28)
- README は全版共通の DOI だけを載せる（#29） / README cites the concept DOI only (#29)

## [1.2.0] - 2026-11-07

保存の流れを変えた版です。TEI 本文（`xml/master/`）とサイトの中身は変えていません。
The preservation workflow was changed. The TEI text (`xml/master/`) and the website content are unchanged.

- リリースのたびに、a3m で作った AIP（BagIt・METS・PREMIS、7z）を GitHub Actions が Zenodo の API で公開する。Zenodo の GitHub 連携（ソースの zip の自動登録）はやめた / On each release, GitHub Actions publishes the AIP built with a3m (BagIt, METS, PREMIS; 7z) to Zenodo through its API; the Zenodo GitHub integration is no longer used
- サイト（DIP）を組み立てる前に、リリースに添付した AIP 全体の MD5 を、Zenodo のその版の記録と突き合わせる。サイトは AIP の中のソースから組み立てる / Before building the site (DIP), the MD5 of the whole attached AIP is checked against the Zenodo record of that version; the site is built from the source inside the AIP
- 組み立ての失敗と、54 帖の日英の頁が揃っていることを確かめる / The build fails on errors, and all 54 volumes are checked in Japanese and English

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
