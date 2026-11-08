# 同梱しているライブラリ

外部の CDN に頼らずに動くよう、版を固定してここに置いている（Endings Principles 4.3）。
入れ替えるときは、フォルダ名の版番号も変える。

| フォルダ | 元 | 使っている頁 | ライセンス |
| --- | --- | --- | --- |
| `openseadragon-6.1.1/` | npm `openseadragon@6.1.1` の `build/openseadragon/openseadragon.min.js` | `html/*.html`・`en/html/*.html`（`xsl/page.xsl` が出力） | BSD-3-Clause（`LICENSE.txt`） |
| `chart.js-4.4.4/` | npm `chart.js@4.4.4` の `dist/chart.umd.js` | `stats*.html`・`waka*.html` | MIT（`LICENSE.md`） |

アイコンは Font Awesome Free 6.4.0 の SVG（CC BY 4.0）から、使う 19 個だけを各頁に埋め込んでいる
（トップページの一覧の分は `scripts/site_icons.py`）。

SHA-256（npm の配布物から写したとき。Chart.js は 2026-11-06、OpenSeadragon は 2026-11-07。
OpenSeadragon の tgz は npm の integrity sha512-g4iKe2q8… と一致を確かめた）:

```
fed6a739f8d0f0687174de6cd14745fc0fc7809144ab113d22908a26bf0d7fea  chart.js-4.4.4/chart.umd.js
14d587cd3ee7c4861f1a41077ce642029364a21029956ba635bd8fb1202cf9ad  openseadragon-6.1.1/openseadragon.min.js
```

本文の頁の画像は、2026-11-07 に Mirador 4.3.0 から OpenSeadragon に替えた（本文の行を押すとその行の枠を画像に描くため）。
