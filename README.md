# 校異源氏物語・本文テキストデータリポジトリ

校異源氏物語の本文テキストを公開するリポジトリです。

This is the master repository for Koui Genji Monogatari Linked Open Data (LOD)

* https://w3id.org/kouigenjimonogatari/

## リポジトリの構成

| パス | 内容 |
|---|---|
| `xml/master/*.xml` | TEI 本文。全54帖。**手で編集するのはここ** |
| `odd/tei_kouigenji.odd` | TEI カスタマイズの**正本**。スキーマと制約はすべてここに書く |
| `docs/schema/` | ODD から生成したスキーマ（公開される） |
| `docs/` | GitHub Pages のルート。`prebuild.py` の生成物を含む |
| `xsl/` | ビルド専用の XSLT（公開しない） |
| `scripts/` | ビルド・検証スクリプト |
| `tools/` | 検証ツール（`setup-tools.zsh` が取得。コミットしない） |

## スキーマと検証

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

### 準備（初回のみ）

Java が要ります（macOS なら `brew install openjdk`）。Saxon と Jing は下のスクリプトが取得します。

```
./scripts/setup-tools.zsh
```

### 使い方

```
./scripts/build-schema.zsh              odd/ からスキーマを生成する
./scripts/validate.zsh                  xml/master/*.xml を全部検証する
./scripts/validate.zsh xml/master/01.xml  ファイルを指定して検証する
```

ODD を編集したら `build-schema.zsh` を実行し、**生成物もあわせてコミット**してください。
忘れた場合は CI（`.github/workflows/validate.yml`）が検出します。

検証は公開の門番になっています。`deploy.yml` が `validate.yml` を呼び出し、
**検証を通らなければサイトは公開されません**。Pull Request でも同じ検証が走ります。

### 何をどちらで検査しているか

RELAX NG は文法（閉じた世界）、Schematron は規則（開いた世界）です。
**文法で書けるものは文法に置く**方針で、PureODD で表せるものは `<attDef>` として、
表せないものだけを `<constraintSpec>` として書いています。

RELAX NG（PureODD で宣言）:

| 規則 | 対象 |
|---|---|
| 和歌に `xml:id` が必須 | `lg` 795首 |
| 和歌の `@rhyme` が `tanka`（閉じた値リスト） | `lg` 795首 |
| 句に `@n` が必須 | `l` 3975句 |
| `seg/@corresp` が API の URI 形式（正規表現） | `seg` 25065件 |
| `xml:id` が重複しない（`xsd:ID` の性質） | 全体 |

Schematron（RELAX NG では原理的に書けないもの）:

| 規則 | 対象 |
|---|---|
| 句の `@n` が位置と一致する | `l` 3975句 |
| `pb/@corresp` が `zone` に解決する | `pb` 1812件 |
| `pb/@n` が帖の中で単調増加する | `pb` 1812件 |
| `change/@who` が文書中の `xml:id` に解決する | `change` 54件 |
| 和歌は5句である | `lg[@type='waka']` 795首 |

最後の「5句」だけは RELAX NG でも書けますが、content model を `l` 5個に固定すると
`lg` の中に `<pb/>` や `<lb/>` を置けなくなり、丁の変わり目が和歌の途中に来る場合に
対応できなくなるため、あえて Schematron に置いています。

なお TEI P5 自身が持つ制約（19パターン）も ODD 経由で一緒に取り込まれます。

## エディタ

`xml/master/*.xml` の `<?xml-model?>` は公開 URL を指しています。そのまま編集すると
**デプロイ済みのスキーマ**で検証されるため、作業コピーの `docs/schema/` に読み替える
`catalog.xml` を用意しています。

* **VS Code** — `.vscode/` に設定済み。`redhat.vscode-xml` を入れてください。
  Schematron は拡張が非対応なので、タスク「TEI: 開いているファイルを検証」で結果を見ます。
* **oXygen** — Preferences > XML > XML Catalog にリポジトリ直下の `catalog.xml` を追加してください。

## ライセンス

* TEI データ: CC0 1.0（各ファイルの `<availability>` を参照）
* リポジトリ: `LICENSE` を参照
