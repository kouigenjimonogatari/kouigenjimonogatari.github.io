# 同梱しているライブラリ

外部の CDN に頼らずに動くよう、版を固定してここに置いている（Endings Principles 4.3）。
入れ替えるときは、フォルダ名の版番号も変える。

| フォルダ | 元 | 使っている頁 | ライセンス |
| --- | --- | --- | --- |
| `mirador-4.3.0/` | npm `mirador@4.3.0` の `dist/mirador.min.js` | `html/*.html`（`xsl/mirador.xsl` が出力） | Apache-2.0（`LICENSE`） |
| `chart.js-4.4.4/` | npm `chart.js@4.4.4` の `dist/chart.umd.js` | `stats*.html`・`waka*.html` | MIT（`LICENSE.md`） |

アイコンは Font Awesome Free 6.4.0 の SVG（CC BY 4.0）から、使う 19 個だけを各頁に埋め込んでいる
（トップページの一覧の分は `scripts/site_icons.py`）。

SHA-256（2026-11-06 に npm の配布物から写したとき）:

```
fed6a739f8d0f0687174de6cd14745fc0fc7809144ab113d22908a26bf0d7fea  chart.js-4.4.4/chart.umd.js
38e6aefcf445ce7348838a954f5b76220b5ef03e6772a5998f77c32e541ddd84  mirador-4.3.0/mirador.min.js
```
