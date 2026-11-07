# サイト（docs/）を Endings Principles に合わせる

## 2026-11-06

方針は論文 46（OAIS と源氏の公開）の査読への回答で決めた「アプリの改修の案」。
作業ブランチは `endings`。

### やったこと

- snorql（SPARQL の画面、`docs/snorql/`、598 ファイル・6.3 MB）を外した。
  各巻の「LOD」は、JSON-LD（`https://w3id.org/kouigenjimonogatari/api/item_sets/NN.json`）を
  外部の Musubi（`https://musubi.ldas.jp/?u=<URL エンコードした URI>`）で開くリンクにした。
  w3id の 302 と github.io の両方に `Access-Control-Allow-Origin: *` があり、Musubi で開けることを確かめた
- CDN からの読み込みをやめた。外していたのは Bootstrap 5.3.2（CSS・JS）、jQuery 3.7.1、
  Font Awesome 6.4.0、Google Fonts、Chart.js 4.4.4（jsDelivr）、Mirador（unpkg の `mirador@latest`）、
  ロゴ画像 2 つ（tei-c.org・json-ld.org）
  - Mirador 4.3.0 と Chart.js 4.4.4 は `docs/lib/` に同梱した（版・SHA-256 は `docs/lib/README.md`）
  - Bootstrap は、使っていたクラスだけを `docs/css/base.css` に書き直した（約 170 行）
  - 上部の帯は、スクリプトなしで動く形にした（折りたたみをやめ、言語はもう一方の頁へのリンク）
  - アイコンは、使っていた 19 個を SVG で埋め込んだ
  - 書体は端末の書体（ヒラギノ・游）にした
- トップページの巻の一覧は、組み立て時に HTML へ書き出すようにした（`prebuild.py index`）。
  以前はブラウザが jQuery で `genji.lib.u-tokyo.ac.jp/data/info.json` を読んで作っていた。
  巻名の表記は info.json の値を `VOLUME_LABELS` に写した（`CHAPTER_NAMES` とは 6 巻で表記が違う。
  例: 桐壺 と きりつぼ）
- トップページの、ブラウザの言語で英語版に飛ばすスクリプト（`seo-redirect.js`）を外した

### 実測

- 改修後、手元（`python3 -m http.server`）で各頁が読み込む先を調べた。
  トップ・統計・和歌は自サイトだけになった。本文の頁（`html/01.html`）は、自サイトのほかは NDL の IIIF の画像だけだった
- トップページは 28 KB から 138 KB になった（54 巻分を HTML に書き出したため）。
  アイコンを頁の中で 1 回だけ定義して参照する形にする前は 323 KB だった

### 途中で分かったこと

- 本文の頁の Mirador は `mirador@latest` で読んでいた。版がいつ変わってもおかしくない状態だった
  （2026-11-06 時点の latest は 4.3.0、10/12 公開）
- トップページから `js/clear-lang-redirect.js` を読んでいたが、ファイルは無く 404 だった

### 残り（同じブランチで続ける）

- 4.4: `?canvas=`・`?lang=` をやめる（本文の頁の英語版は今も `html/NN.html?lang=en`）
- 4.7: 和歌の一覧を組み立て時に HTML にする
- 5.3・5.4: 各頁に版・ビルド日・引用の方法を出す
- `release.yml` の prebuild に `index` を足すか（いまは index.html をコミットしているので無くても動く）。
  release.yml は dip-checks の worktree で直しているので、そちらで扱う
