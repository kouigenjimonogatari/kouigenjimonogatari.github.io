# Koui Genji Monogatari Text Data Repository / 校異源氏物語・本文テキストデータリポジトリ

[English](#english) | [日本語](#日本語)

<a id="english"></a>

## English

This is the master repository for the Koui Genji Monogatari (校異源氏物語) Linked Open Data (LOD).
It publishes the full text of the *Koui Genji Monogatari*, encoded in TEI.

* https://w3id.org/kouigenjimonogatari/

### Repository layout

| Path | Contents |
|---|---|
| `xml/master/*.xml` | TEI text of all 54 chapters. **This is the only place to edit by hand** |
| `odd/tei_kouigenji.odd` | The **source of truth** for the TEI customization. All schema rules and constraints are written here |
| `docs/schema/` | Schemas generated from the ODD (published) |
| `docs/` | Root of GitHub Pages. Includes the output of `prebuild.py` |
| `xsl/` | XSLT used only at build time (not published) |
| `scripts/` | Build and validation scripts |
| `tools/` | Validation tools (fetched by `setup-tools.zsh`; not committed) |

### Schema and validation

`odd/tei_kouigenji.odd` is the single source of truth. Both the RELAX NG and the Schematron schemas are generated from it.
Everything under `docs/schema/` is generated output, so **please do not edit it by hand**.

```
odd/tei_kouigenji.odd
  ├─ odd2relax.xsl      → docs/schema/tei_kouigenji.rng    structural validation
  ├─ extract-isosch.xsl → docs/schema/tei_kouigenji.sch    rules that a grammar cannot express
  └─ odd2html.xsl       → docs/schema/tei_kouigenji.html   documentation of the customization
```

All transformations use the official TEI [Stylesheets](https://github.com/TEIC/Stylesheets) and
[SchXslt2](https://codeberg.org/SchXslt/schxslt2). There are no home-grown conversions.

#### Setup (first time only)

Java is required (on macOS: `brew install openjdk`). Saxon and Jing are fetched by the script below.

```
./scripts/setup-tools.zsh
```

#### Usage

```
./scripts/build-schema.zsh                generate schemas from odd/
./scripts/validate.zsh                    validate all of xml/master/*.xml
./scripts/validate.zsh xml/master/01.xml  validate a specific file
```

After editing the ODD, run `build-schema.zsh` and **commit the generated files as well**.
If you forget, CI (`.github/workflows/validate.yml`) will catch it.

Validation acts as the gatekeeper for publication. `deploy.yml` calls `validate.yml`,
and **the site is not deployed unless validation passes**. The same validation also runs on pull requests.

#### What is checked where

RELAX NG is a grammar (closed world); Schematron is a set of rules (open world).
Our policy is **to put everything a grammar can express into the grammar**: whatever PureODD can express is declared as `<attDef>`,
and only what it cannot is written as `<constraintSpec>`.

RELAX NG (declared in PureODD):

| Rule | Target |
|---|---|
| `xml:id` is required on each waka poem | `lg`, 795 poems |
| Waka `@type` is `waka` and `@rhyme` is `tanka` (both required, closed value lists) | `lg`, 795 poems |
| `@n` is required on each line of verse | `l`, 3,975 lines |
| `seg/@corresp` is required and matches the API URI pattern (regular expression) | `seg`, 25,065 |
| `pb/@n`, `@corresp`, and `@facs` are required | `pb`, 1,812 |
| `xml:id` values are unique (a property of `xsd:ID`) | whole document |

Schematron (rules that RELAX NG cannot express in principle):

| Rule | Target |
|---|---|
| A line's `@n` matches its position | `l`, 3,975 lines |
| `pb/@corresp` resolves to a `zone` | `pb`, 1,812 |
| `pb/@n` (page number) increases monotonically within a chapter | `pb`, 1,812 |
| `change/@who` resolves to a `respStmt` in the teiHeader | `change`, 54 |
| A waka has five lines | `lg[@type='waka']`, 795 poems |

Only the last rule, "five lines", could also be written in RELAX NG (by interleaving `model.global` between lines,
`<pb/>` and `<lb/>` can still appear inside `lg`). It stays in Schematron anyway because, as a grammar,
a violation only yields `element "lg" incomplete` and **does not tell you which poem has how many lines**.
Schematron can name it: "waka-001 has 4 lines".

The constraints built into TEI P5 itself (19 patterns) are also brought in through the ODD.

### Item API (Linked Open Data)

Each line of the text is given a URI, and its resource is served as JSON-LD.

```
https://w3id.org/kouigenjimonogatari/api/items/<4-digit page number>-<2-digit line number>.json
https://w3id.org/kouigenjimonogatari/api/item_sets/<2-digit chapter number>.json
https://w3id.org/kouigenjimonogatari/api/context.json
```

These are the resources that `seg/@corresp` in `xml/master/*.xml` points to (25,065 items / 54 item sets).

```
python3 scripts/build_api.py            generate into docs/api/
python3 scripts/build_api.py --check    check consistency with the TEI only, without writing output
```

The API is generated **from the TEI text**. It used to be built by `scripts/001_convert_xlsx_to_rdf.py`
from `scripts/data/metadata.xlsx`, but that spreadsheet was frozen before text corrections and variant-character normalization,
and its text differs from the current TEI in 24,747 of 25,065 lines
(e.g. 後凉殿/後涼殿, 御覽/御覧, いと〱しく/いとゝしく). Since `xml/master/` is the master,
the API is built from it as well. As a side effect, `pandas` / `numpy` / `rdflib` / `openpyxl` are no longer needed,
and the only dependency is `lxml`.

The SPARQL endpoint (Dydra, referenced from `docs/snorql/`) is managed separately.
Because JSON-LD is RDF, the generated files can be loaded into it as they are.

### Editors

The `<?xml-model?>` processing instructions in `xml/master/*.xml` point to public URLs. Editing the files as they are
would validate them against **the deployed schema**, so a `catalog.xml` is provided that redirects them to the working copy in `docs/schema/`.

* **VS Code** — preconfigured in `.vscode/`. Install `redhat.vscode-xml`.
  The extension does not support Schematron, so run the task "TEI: 開いているファイルを検証" (validate the open file) to see the results.
* **oXygen** — add `catalog.xml` at the repository root under Preferences > XML > XML Catalog.

### License

* TEI data (`xml/master/*.xml`): **CC0 1.0** (see `<availability>` in each file)
* The repository as a whole: **CC BY 4.0** (`LICENSE`)
* `odd/tei_kouigenji.odd`: because it starts from the minimal customization (tei_minimal) in the TEI distribution,
  it inherits the **dual license of CC BY-SA 3.0 / BSD-2** (see `<availability>` in the file).
  These terms differ from the CC BY 4.0 of the repository as a whole, so please take care when reusing it.

---

<a id="日本語"></a>

## 日本語

校異源氏物語の本文テキストを公開するリポジトリです。
校異源氏物語 Linked Open Data（LOD）のマスターリポジトリです。

* https://w3id.org/kouigenjimonogatari/

### リポジトリの構成

| パス | 内容 |
|---|---|
| `xml/master/*.xml` | TEI 本文。全54帖。**手で編集するのはここ** |
| `odd/tei_kouigenji.odd` | TEI カスタマイズの**正本**。スキーマと制約はすべてここに書く |
| `docs/schema/` | ODD から生成したスキーマ（公開される） |
| `docs/` | GitHub Pages のルート。`prebuild.py` の生成物を含む |
| `xsl/` | ビルド専用の XSLT（公開しない） |
| `scripts/` | ビルド・検証スクリプト |
| `tools/` | 検証ツール（`setup-tools.zsh` が取得。コミットしない） |

### スキーマと検証

`odd/tei_kouigenji.odd` が唯一の正本です。RELAX NG も Schematron も、そこから生成します。
`docs/schema/` 以下は生成物なので、**手で編集しないでください**。

```
odd/tei_kouigenji.odd
  ├─ odd2relax.xsl      → docs/schema/tei_kouigenji.rng    構造の検証
  ├─ extract-isosch.xsl → docs/schema/tei_kouigenji.sch    構造では書けない規則の検証
  └─ odd2html.xsl       → docs/schema/tei_kouigenji.html   カスタマイズの解説
```

変換はすべて TEI 公式の [Stylesheets](https://github.com/TEIC/Stylesheets) と
[SchXslt2](https://codeberg.org/SchXslt/schxslt2) を使っており、自前の変換はありません。

#### 準備（初回のみ）

Java が要ります（macOS なら `brew install openjdk`）。Saxon と Jing は下のスクリプトが取得します。

```
./scripts/setup-tools.zsh
```

#### 使い方

```
./scripts/build-schema.zsh              odd/ からスキーマを生成する
./scripts/validate.zsh                  xml/master/*.xml を全部検証する
./scripts/validate.zsh xml/master/01.xml  ファイルを指定して検証する
```

ODD を編集したら `build-schema.zsh` を実行し、**生成物もあわせてコミット**してください。
忘れた場合は CI（`.github/workflows/validate.yml`）が検出します。

検証は公開の門番になっています。`deploy.yml` が `validate.yml` を呼び出し、
**検証を通らなければサイトは公開されません**。Pull Request でも同じ検証が走ります。

#### 何をどちらで検査しているか

RELAX NG は文法（閉じた世界）、Schematron は規則（開いた世界）です。
**文法で書けるものは文法に置く**方針で、PureODD で表せるものは `<attDef>` として、
表せないものだけを `<constraintSpec>` として書いています。

RELAX NG（PureODD で宣言）:

| 規則 | 対象 |
|---|---|
| 和歌に `xml:id` が必須 | `lg` 795首 |
| 和歌の `@type` が `waka`、`@rhyme` が `tanka`（いずれも必須・閉じた値リスト） | `lg` 795首 |
| 句に `@n` が必須 | `l` 3975句 |
| `seg/@corresp` が必須で API の URI 形式（正規表現） | `seg` 25065件 |
| `pb/@n`・`@corresp`・`@facs` が必須 | `pb` 1812件 |
| `xml:id` が重複しない（`xsd:ID` の性質） | 全体 |

Schematron（RELAX NG では原理的に書けないもの）:

| 規則 | 対象 |
|---|---|
| 句の `@n` が位置と一致する | `l` 3975句 |
| `pb/@corresp` が `zone` に解決する | `pb` 1812件 |
| `pb/@n`（ページ番号）が帖の中で単調増加する | `pb` 1812件 |
| `change/@who` が teiHeader の `respStmt` に解決する | `change` 54件 |
| 和歌は5句である | `lg[@type='waka']` 795首 |

最後の「5句」だけは RELAX NG でも書けます（句の間に `model.global` を挟めば
`lg` の中に `<pb/>` や `<lb/>` も置けます）。それでも Schematron に置いているのは、
文法だと違反時のメッセージが `element "lg" incomplete` 止まりで、
**どの和歌が何句なのかを言ってくれない**からです。
Schematron なら「waka-001 は 4 句」と名指しできます。

なお TEI P5 自身が持つ制約（19パターン）も ODD 経由で一緒に取り込まれます。

### item API（Linked Open Data）

本文1行ごとに URI を与え、その実体を JSON-LD として配信しています。

```
https://w3id.org/kouigenjimonogatari/api/items/<ページ番号4桁>-<行番号2桁>.json
https://w3id.org/kouigenjimonogatari/api/item_sets/<帖2桁>.json
https://w3id.org/kouigenjimonogatari/api/context.json
```

これは `xml/master/*.xml` の `seg/@corresp` が指す URI の実体です（item 25,065 件 / item_set 54 件）。

```
python3 scripts/build_api.py            docs/api/ に生成する
python3 scripts/build_api.py --check    出力せず TEI との整合だけ検査する
```

生成元は **TEI 本文です**。以前は `scripts/001_convert_xlsx_to_rdf.py` が
`scripts/data/metadata.xlsx` から作っていましたが、その xlsx は本文修正・異体字正規化
より前の状態で止まっており、現行の TEI と比べて 25,065 行中 24,747 行で本文が違います
（後凉殿/後涼殿、御覽/御覧、いと〱しく/いとゝしく など）。`xml/master/` がマスターである以上、
API もそこから作ります。副次的に `pandas` / `numpy` / `rdflib` / `openpyxl` が不要になり、
依存は `lxml` だけになりました。

なお SPARQL エンドポイント（`docs/snorql/` から参照している Dydra）は別管理です。
JSON-LD は RDF なので、生成物をそのまま投入できます。

### エディタ

`xml/master/*.xml` の `<?xml-model?>` は公開 URL を指しています。そのまま編集すると
**デプロイ済みのスキーマ**で検証されるため、作業コピーの `docs/schema/` に読み替える
`catalog.xml` を用意しています。

* **VS Code** — `.vscode/` に設定済み。`redhat.vscode-xml` を入れてください。
  Schematron は拡張が非対応なので、タスク「TEI: 開いているファイルを検証」で結果を見ます。
* **oXygen** — Preferences > XML > XML Catalog にリポジトリ直下の `catalog.xml` を追加してください。

### ライセンス

* TEI データ（`xml/master/*.xml`）: **CC0 1.0**（各ファイルの `<availability>` を参照）
* リポジトリ全体: **CC BY 4.0**（`LICENSE`）
* `odd/tei_kouigenji.odd`: TEI 配布物の最小カスタマイズ（tei_minimal）を出発点としているため、
  **CC BY-SA 3.0 / BSD-2 のデュアルライセンス**を引き継ぎます（ファイル内の `<availability>` を参照）。
  リポジトリ全体の CC BY 4.0 とは条件が異なるため、再利用の際はご注意ください。
