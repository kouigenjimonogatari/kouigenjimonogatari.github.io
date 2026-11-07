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

- 4.7: 和歌の一覧を組み立て時に HTML にする
- 5.3・5.4: 各頁に版・ビルド日・引用の方法を出す
- `release.yml` の prebuild に `index` を足すか（いまは index.html をコミットしているので無くても動く）。
  release.yml は dip-checks の worktree で直しているので、そちらで扱う

## 2026-11-06（続き）4.4 クエリ文字列をやめる

- 本文の頁の英語版を、`html/NN.html?lang=en` から静的な `html/NN-en.html` に分けた。
  `xsl/mirador.xsl` に `lang` の引数を足し、`prebuild.py xsl` が 54 巻 × 2 言語 = 108 頁を書き出す（約 48 秒）。
  画面の文言の差し替えはスクリプトでなく XSLT で行う。英語版にあった「JS で文言を書き換える」部分は削った
- 頁の位置は `?canvas=<IIIF の Canvas URI>` をやめ、`#p<原本の頁>`（例 `#p13`）にした。和歌は `#waka-001`。
  頁をめくると `#p…` が書き換わる。`#` を手で変えても動く
- 古い URL（`?canvas=` `?n=` `?waka=` `?corresp=` `?lang=en`）は、開いたときに `#` の形へ読み替え、
  `?lang=en` は `NN-en.html` へ移す。論文や他のサイト（genji-api・awase）から張られた古いリンクを切らないため
- 落とし穴: 1 枚の画像（Canvas）に見開きの 2 頁が入っている。画像から頁を逆に引くと後ろの頁になり、
  `#p12` で開いても `#p13` に書き換わっていた。前の頁を引き、いまの `#p` がその画像の頁なら書き換えないようにした
- 確かめたこと（Chrome、手元）: `01.html?waka=waka-002&lang=en` → `01-en.html#waka-002` で英語の画面・和歌の強調。
  `?canvas=…/24` → `#p9`、`?n=13` → `#p13`、`[Page 16]` を押す → `#p16`、`#p20` に書き換え → その画像へ
- 残る `?`: 外部の Musubi へのリンク（`?u=`）は相手のサイトの URL なので、このサイトの URL の安定性とは別

## 2026-11-06（続き）英語の頁を en/ の下に

- 本人の判断で、英語の頁を `index-en.html` などから `en/index.html`・`en/stats.html`・`en/viz.html`・`en/waka.html`・
  `en/html/NN.html` に移した（Claude は当初、公開済みの URL を変えないため `-en` のままを勧めたが、
  古い URL から転送する形にして移すことになった）
- 古い 4 つの URL には転送用の小さな頁を置いた（`meta refresh` と、`#` を保つ 1 行のスクリプト、`rel="canonical"`、
  `noindex`）。GitHub Pages ではサーバでの転送ができないため。`html/NN.html?lang=en` も `en/html/NN.html` へ移る
- サイトの中のリンクは `en/` ではなく `en/index.html` と書いた。ディスクから開いた写し（file://）では
  フォルダへのリンクが index.html を開かないため（EP の「どこに置いても動く」）
- 確かめたこと（Chrome、手元）: `index-en.html#12` → `en/index.html#12`、`waka-en.html` → `en/waka.html`（795 首、
  リンクは `en/html/01.html#waka-001`）、`stats-en.html` → `en/stats.html`（図 4 つ）、`html/03.html?lang=en` → `en/html/03.html`
- 残る `?`: EPUB の読み手 `bibi/index.html?book=NN` は同梱の外部の道具の作り。Musubi への `?u=` は相手のサイトの URL

## 2026-11-06（続き）JSON-LD で帖から行へたどれるように

- 本人の指摘: Musubi で帖（`api/item_sets/NN.json`）を開いても情報が少なく、行の RDF にたどれない。
  行には `isPartOf`（帖へ）があったが、帖から行への向きが無かった
- 帖に足したもの: `dcterms:hasPart`（その帖の行の URI、全 25,065 件を帖ごとに）、`dcterms:alternative`（漢字の巻名。
  `label` と同じなら付けない）、`relation` に本文の頁（`/html/NN.html`）。帖の JSON は 54 件で 216KB → 1.9MB
- 行の `relation` を、外部の IIIF Curation Viewer から、このサイトの本文の頁のその位置（`/html/NN.html#p5`）に替えた。
  Curation Viewer は `seeAlso` に移した（消してはいない）
- 巻名の表は `scripts/volumes.py` に移し、トップページの一覧と JSON-LD で共用する
- 確かめたこと: 手元の別のサーバ（別サイトからの読み込みを許す設定）で帖 02 を Musubi に開かせ、`hasPart` 617 件・
  漢字の「帚木」・本文の頁へのリンクが出ることを見た。`hasPart` を順序付きの列（`@list`）にするのはやめた。
  行ごとに `page`・`row` を持っているので順序は復元でき、LOD の閲覧の道具では単純な集合のほうが読みやすいため
- 公開中の `context.json` は v1.0.1 で配るまで古いまま。それまでは公開版の Musubi では `hasPart` は出ない
- 別件で分かったこと: NDL の IIIF マニフェストが Musubi で開けない。マニフェストの `@context` が
  `http://iiif.io/...`（https でない）で、https の頁からはブラウザが取りに行かないため。Musubi の側で直す話

## 2026-11-06（続き）4.7 和歌の一覧を組み立て時に HTML に

- 以前は waka.html を開いてから data/waka.json と data/chapters.json を fetch し、ブラウザで 795 首を組み立てていた。スクリプトが動かない環境や file:// では「読み込み中」のまま何も出なかった
- prebuild.py に build_waka_page を足した。waka・stats のタスクの後に、全首のカード・巻の選択肢・件数・グラフの数値（chapters.json の 4 項目を `<script type="application/json">` で）を、印（`<!-- waka-list:start -->` など）の間に書き込む。日英の 2 頁
- スクリプトは絞り込み（カードの hidden を切り替える）とグラフだけにした。fetch は無くなった
- 各カードに id="waka-001" を付けたので、一覧の中の 1 首にも直接リンクできる
- 実測: waka.html は約 30KB → 698KB（gzip で 55KB）。2 回組み立てて同じ内容になることを確かめた（release.yml の再ビルド一致の検査に響かない）
- 確認: 795 首・巻の選択肢 54・検索「いのち」で 6 首・空蝉で 2 首・該当なしの表示・グラフ 2 つ、日英とも
