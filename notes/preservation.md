# 保存と公開の流れ（OAIS の情報パッケージ）

リリースを起点に SIP → AIP → DIP → 公開を機械的に通す取り組みの実験ノート。
日付の見出しの下に書き足し、前の記述は書き換えない。docs/ はサイトそのもの（DIP に入る）なので、ノートは notes/ に置く。

## 2026-11-06

### 考え方

- Git のリリースは「版を区切って中身を固定して出す」行為で、OAIS の提出（SIP）とほぼ同じ形になっている。
  これを起点に、AIP と DIP を機械的に導く。
- 対応づけ

  | OAIS | この仕組み |
  |---|---|
  | SIP | リリースのタグのソース zip（`gh api repos/<repo>/zipball/<tag>`） |
  | 受け入れ（Ingest） | GitHub Actions と a3m |
  | AIP | a3m の出力（BagIt + METS/PREMIS、.7z） |
  | 保存（Archival Storage） | 東大のリポジトリ（AIP）、Zenodo（SIP）、GitHub のリリース（作業の場・控え） |
  | DIP の生成 | AIP の中のソースから組み立てたサイト一式（zip + SHA-256、リリースに添付） |
  | アクセスシステム | GitHub Pages（DIP をそのまま置く） |
  | 保存の計画・管理 | 扱わない（人が担う） |

- GitHub Pages は DIP ではなく、DIP を届けるアクセスシステムとして扱う。
  当初は「Pages = DIP」としていたが、それだと DIP がパッケージとして残らず
  （Pages 用の一時的な入れ物は期限で消える）、どの版で何を公開したかをチェックサムで示せない。
  Archivematica も AIP から閲覧用の DIP を作り、別の閲覧システム（AtoM など）に渡すので、同じ分け方にした。
- 設計の原則
  - (a) 下流は上流の「保存先」から作る。ジョブ間で直接受け渡さず、リリースに置いたものを取り直して検証してから使う
  - (b) 各段の成果物を固定し、チェックサムでつなぐ。DIP の `build-info.json` に AIP の SHA-256・コミット・道具の版を書く
  - (c) 一度添付した AIP・DIP は作り直さない（`--clobber` を外し、添付済みなら飛ばす）

主張の候補: Git と静的サイトの組み合わせなら、SIP・AIP・DIP を 1 回のリリースで機械的に通せる（根拠: release.yml、下の実測）。
主張の候補: リリースのたびに AIP から DIP を組み立て直すことが、AIP の内容が足りていることの継続的な検証になる。

### 実測（手元、Apple Silicon で amd64 を変換して実行）

- SIP（v1.0.0 の zipball）は Zenodo の zip と MD5（97f1c7670bb9bf9d97d1049a0efb9b11）・SHA-256 とも一致
- a3m の 1 回目は PREMIS に zip 1 件しか載らなかった。`extract_packages=yes` と
  `delete_packages_after_extraction=no` で作り直すと、展開した中身の 793 件が載った
  （TEI P5 55、PDF 54、JS 334、HTML 194 ほか）。元の zip も残る
- AIP は 57MB、作成に約 2 分。`python -m bagit --validate` で検証が通り、中の zip の MD5 も SIP と一致
- a3m のイメージは amd64 のみ（arm64 では `--platform linux/amd64` が要る）。版のリリースが無いのでダイジェストで固定

### 途中で分かったこと

- a3m は実行のたびに UUID と日時を書き込むので、同じ版でも AIP のチェックサムが変わる。
  作り直しを許すと、東大に置いた AIP とリリース上の AIP が食い違う → 原則 (c)
- サイトの組み立て（scripts/prebuild.py）が使う Python のライブラリは lxml だけで、ネットワークから資料は取らない。
  外への依存は道具（Saxon・Java・Python）だけ。requirements.txt は版を固定していなかったので固定した。
  ただし v1.0.0 のタグの中の requirements.txt は固定前のまま（v1.0.0 の DIP は組み立てた時点の版で作られ、
  その版は `build-info.json` に残る）
- 古いタグで手で流すとサイトが戻るので、公開は最新のリリースのときだけにした

### 却下した案

- AIP に組み立て済みのサイトを同梱する: AIP からサイトを作る段が要らなくなり、AIP の十分性を確かめる機会が消える
- master への push ごとに公開する（以前の deploy.yml）: 版と公開物が対応しなくなる
- 東大のリポジトリへの登録を Actions から自動化する: UTokyo Self Archive（Esploro）の API の鍵は機関が管理するもので、
  個人では取れない（未確認の点あり）。統合認証を Actions に通すのも不可。当面は手作業で登録する

### 限界（確かめていない・言えないこと）

- OAIS に準拠しているとは言えない。6 つの機能のうち、受け入れ・保存・提供の一部だけ
- 作る人と保存する人が同じ
- 道具は AIP の外にある（版の固定で補う）
- 写本の画像は国立国会図書館の IIIF を参照しており、DIP の中に無い
- a3m の保守が続くかは分からない（AIP の形式は BagIt・METS・PREMIS なので、a3m が無くても読める）
- Actions の上での a3m の実行は未確認（試験用ワークフロー test-release.yml で確かめる）

### 関連

- OAIS: ISO 14721:2012 / CCSDS 650.0-M-2（Reference Model for an Open Archival Information System, 2012）
- a3m: https://github.com/artefactual-labs/a3m
- Archivematica（AIP・DIP と AtoM への受け渡し）: https://www.archivematica.org/
- Endings Project, Endings Principles for Digital Longevity v2.2: https://endings.uvic.ca/principles.html

### 追記（同日）: Actions の上での試験

- 試験用ワークフロー（PR #18 の test-release.yml、run 42268730245）で、Actions の ubuntu-latest の上で通しで成功した
  （SIP → a3m で AIP → BagIt 検証 → AIP の中のソースから DIP の組み立て）
- 所要時間: ジョブ全体 2 分 10 秒。うち a3m 64 秒（イメージの取得込み）、DIP の組み立て 51 秒
- a3m はコンテナ内の別ユーザーで動くが、作業フォルダの書き込み権限を広げておけば問題なかった
- a3m の終了時に gRPC の GOAWAY の記録が 1 行出るが、処理は「completed successfully」で終わっており無害
- AIP・DIP の大きさは、試験では記録し損ねた（step summary を API から読めなかった）。v1.0.0 の本番の実行で測る
- 試験用ワークフローは、確認後に削除した
