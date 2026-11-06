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

先行研究（agy で探し、書誌は Crossref・J-STAGE・各誌のページで確かめた。括弧内はこの取り組みとの違い）:

OAIS を個別のプロジェクト・研究データに当てはめたもの
- Oltmanns, E., Hasler, T., Peters-Kottig, W., Kuper, H.-G. Different Preservation Levels: The Case of Scholarly Digital Editions. Data Science Journal, 18, 2019. https://doi.org/10.5334/dsj-2019-051 （保存機関が移管時にパッケージを作る前提。リリースごとの自動生成ではない）
- Roberts, J. Archival Information Packages: A Data-Centric Approach to Preservation. International Journal of Digital Curation, 20(1), 2026. https://doi.org/10.2218/ijdc.v20i1.1154 （AIP を自己完結した正本とする設計原則。原則の提示で、AIP から DIP を作り直して確かめる実装はない）
- Bouras, A., Naseem, H., Belhi, A. Preserving Research Grant Data: Building an OAIS-Compliant Open Archive. EPiC Series in Computing, 107, pp. 272–281（EUNIS 2025）. https://doi.org/10.29007/q3wz （受け入れ側の基盤の設計）
- Lavoie, B. The Open Archival Information System (OAIS) Reference Model: Introductory Guide (2nd Edition). DPC Technology Watch Report 14-02, 2014. https://doi.org/10.7207/twr14-02
- Archaeology Data Service / Digital Antiquity. Guides to Good Practice: Digital Archiving and the Project Lifecycle. https://doi.org/10.5284/h0p2-5584 （OAIS の節の著者名は確かめていない）

Git・GitHub・CI と保存
- Di Cosmo, R., Zacchiroli, S. Software Heritage: Why and How to Preserve Software Source Code. iPRES 2017, pp. 1–10. https://hal.science/hal-01590958 （ソースの収集・保存。DIP は扱わない）
- Escamilla, E., Klein, M., Cooper, T., Rampin, V., Weigle, M. C., Nelson, M. L. The Rise of GitHub in Scholarly Publications. TPDL 2022, LNCS 13541, pp. 187–200. https://doi.org/10.1007/978-3-031-16802-4_15
- Almas, B., Clérice, T. Continuous Integration and Unit Testing of Digital Editions. Digital Humanities Quarterly, 11(4), 2017. http://www.digitalhumanities.org/dhq/vol/11/4/000350/000350.html （TEI 版に CI を当てた例。目的は品質の検査で、保存パッケージは作らない）
- Houillon, M., Klar, J., Boutanios, Z., Stary, T., Cojean, T., Anzt, H., Loewe, A. FACILE-RS: archiving and long-term preservation of research software repositories made easy. Journal of Open Source Software, 10(114), 7330, 2025. https://doi.org/10.21105/joss.07330 （Git のリリースから CI でアーカイブ用の包みを作る。いちばん近い。DIP の作り直しによる確認はない）
- GitHub Archive Program: https://archiveprogram.github.com/

静的サイトによる長期の公開
- Holmes, M., Takeda, J. From Tamagotchis to Pet Rocks: On Learning to Love Simplicity through the Endings Principles. Digital Humanities Quarterly, 17(1), 2023. https://doi.org/10.63744/dr2uaqdau4tz
- Carlin, C. Endings: Concluding, Archiving, and Preserving Digital Projects for Long-Term Usability. KULA, 2(1), 19, 2018. https://doi.org/10.5334/kula.35
- Risam, R., Gil, A. Introduction: The Questions of Minimal Computing. Digital Humanities Quarterly, 16(2), 2022. https://doi.org/10.63744/b49fzhuz9hhz
- Becker, D., Williamson, E., Wikle, O. CollectionBuilder-CONTENTdm: Developing a Static Web 'Skin' for CONTENTdm-based Digital Collections. Code4Lib Journal, 49, 2020. https://journal.code4lib.org/articles/15326
- Wikle, O. M., Williamson, E. P. Static Web Methodology as a Sustainable Approach to Digital Humanities Projects. Code4Lib Journal, 60, 2025. https://journal.code4lib.org/articles/18372

Archivematica・BagIt をワークフローに組み込んだもの
- Eckard, M., Pillen, D., Shallcross, M. Bridging Technologies to Efficiently Arrange and Describe Digital Archives: the Bentley Historical Library's ArchivesSpace-Archivematica-DSpace Workflow Integration Project. Code4Lib Journal, 35, 2017. https://journal.code4lib.org/articles/12105
- Hutchinson, T. Archidora: Integrating Archivematica and Islandora. Code4Lib Journal, 39, 2018. https://journal.code4lib.org/articles/13150
- Kunze, J., Littman, J., Madden, E., Scancella, J., Adams, C. The BagIt File Packaging Format (V1.0). RFC 8493, 2018. https://doi.org/10.17487/RFC8493

TEI 版の持続性
- Creamer, A., Lembi, G., Mylonas, E., Satlow, M. Archiving a TEI Project FAIRly. Journal of the Text Encoding Initiative, 14, 2021. https://doi.org/10.4000/jtei.4324
- Stadler, P., Ferger, A., Röwenstrunk, D. From OxGarage to TEIGarage and MEIGarage: Toward a More Sustainable Software Solution in the Digital Humanities. Journal of the Text Encoding Initiative, 17, 2024. https://doi.org/10.4000/15bou
- Turska, M., Cummings, J., Rahtz, S. Challenging the Myth of Presentation in Digital Editions. Journal of the Text Encoding Initiative, 9, 2016. https://doi.org/10.4000/jtei.1453
- Holmes, M. Whatever happened to interchange? Digital Scholarship in the Humanities, 32(suppl_1), 2017（オンライン 2016）. https://doi.org/10.1093/llc/fqw048
- Drucker, J. Sustainability and complexity: Knowledge and authority in the digital humanities. Digital Scholarship in the Humanities, 36(suppl_2), pp. ii86–ii94, 2021. https://doi.org/10.1093/llc/fqab025
- Cayless, H., Viglianti, R. CETEIcean: TEI in the Browser. Balisage Series on Markup Technologies, 21, 2018. https://doi.org/10.4242/BalisageVol21.Cayless01

日本
- 金 甫榮, 中村 覚, 山田 太造, 渡邉 英徳. デジタル資料の長期保存のためのOAIS参照モデルによる情報パッケージの作成：東京大学史料編纂所を事例に. デジタルアーカイブ学会誌, 9(3), pp. e15–e24, 2025. https://doi.org/10.24506/jsda.9.3_e15
- 川嶌 健一, 高久 雅生. OAIS参照モデルに関するこれまでの議論と第3版改訂における現在地. デジタルアーカイブ学会誌, 10(s2), pp. s87–s90, 2026. https://doi.org/10.24506/jsda.10.s2_s87
- 中村 覚, 金 甫榮, 南山 泰之. Archivematicaを活用したデジタルデータの長期保存を支援する簡易操作アプリケーションの開発. デジタルアーカイブ学会誌, 7(s2), pp. s107–s110, 2023. https://doi.org/10.24506/jsda.7.s2_s107
- 金 甫榮, 中村 覚, 渡邉 英徳. 真正なデジタル化資料の長期保存と公開：ArchivematicaとOmeka Sを用いた事例. デジタルアーカイブ学会誌, 6(s3), pp. s147–s150, 2022. https://doi.org/10.24506/jsda.6.s3_s147
- 金 甫榮, 渡邉 英徳. 組織アーカイブズにおける真正なデジタル記録の長期保存の要件：Archivematicaを用いた検討. アーカイブズ学研究, 38, pp. 4–35, 2023. https://doi.org/10.32239/archivalscience.38.0_4
- 五島 敏芳, 戸田 健太郎. 教育研究のアーカイブ資料の情報への永続識別子の付与：京都大学デジタルアーカイブシステムPeekにおけるARKの利用. 情報知識学会誌, 31(4), pp. 478–481, 2021. https://doi.org/10.2964/jsik_2021_063
- 永崎 研宣. 国際的な情報技術標準化における日本文化資料. 情報知識学会誌, 33(3), 2023. https://doi.org/10.2964/jsik_2023_026

確かめられなかったもの:
- 金 甫榮ほか「デジタル資料の保存用メタデータの検討：Archivematicaが出力するAIPの内容分析」じんもんこん2024（http://id.nii.ac.jp/1001/00241398/）。情報学広場が 503 で開けなかった
- 見つからなかったこと（agy の検索の範囲で）: a3m を CI の上で動かした査読論文。AIP を取り直して DIP を作り直し、AIP の十分性を確かめる手法の報告

agy の書誌の誤りで直したもの: Bouras ほかの頁（agy は 122–131、正しくは 272–281）。Bentley の記事の URL（agy は 12115 で、開くと Not Found。正しくは 12105）。

### 追記（同日）: Actions の上での試験

- 試験用ワークフロー（PR #18 の test-release.yml、run 42268730245）で、Actions の ubuntu-latest の上で通しで成功した
  （SIP → a3m で AIP → BagIt 検証 → AIP の中のソースから DIP の組み立て）
- 所要時間: ジョブ全体 2 分 10 秒。うち a3m 64 秒（イメージの取得込み）、DIP の組み立て 51 秒
- a3m はコンテナ内の別ユーザーで動くが、作業フォルダの書き込み権限を広げておけば問題なかった
- a3m の終了時に gRPC の GOAWAY の記録が 1 行出るが、処理は「completed successfully」で終わっており無害
- AIP・DIP の大きさは、試験では記録し損ねた（step summary を API から読めなかった）。v1.0.0 の本番の実行で測る
- 試験用ワークフローは、確認後に削除した

### 追記（同日）: v1.0.0 の本番の実行

- release.yml を tag=v1.0.0 で手動実行（run 42270635512）。4 段とも成功、全体 4 分 43 秒
  （validate 1 分 36 秒、aip 1 分 21 秒、dip 1 分 17 秒、deploy 17 秒）。画面: img/run-42270635512-v1.0.0.jpg
  （Actions の実行記録は既定で 90 日で消えるので、画面と値をここに残す）
- SIP: MD5 97f1c7670bb9bf9d97d1049a0efb9b11（Zenodo の zip と一致）、SHA-256 ccdd7831364be1ffee327dc133555d9f8e8b4c0e62718921184c2bcf615ce939
- AIP: 57,039,803 バイト、UUID 97968d8b-0572-4baf-9161-319e875163d9、
  SHA-256 182149432e381fd5a4cdf3ec0b67d536349776fa3406c835f78b0685e046bdec、MD5 8fc551a9955e2bb7b52686ea7aee7e83
- DIP: 35,547,043 バイト、28,065 ファイル、SHA-256 576162abd0e6700a4ff3863dabcaeaedf0fd5c73f0737113fda38c63c6b239cf
- v1.0.0 のタグのコミットは 864328b9ec8eaf05f93b6ed01a2e52905fdeb76d（DIP の build-info.json にも記録）
- AIP→DIP の変換は scripts/prebuild.py（Python 3.12・Saxon-HE 12.5・lxml）。AIP の中の元の zip だけを使い、
  METS/PREMIS は DIP に引き継いでいない。PDF は Actions では作らず、コミット済みの 54 件をそのまま写す

### 追記（同日）: 東京大学のリポジトリへの登録

- UTokyo Repository Self Archive（Esploro）に v1.0.0 の AIP を登録し、送信した。状態は「送信済み」（担当者の確認後に公開）
- 資料タイプはデータセット。AIP 自身の DOI は付けない（引用に使う DOI は Zenodo の 1 本にする）。
  Zenodo の v1.0.0（10.5281/zenodo.24015762）を関連アセット「派生元」（DataCite の IsDerivedFrom）として付けた
- ライセンス欄は CC BY 4.0。著作権表示の欄にライセンスの内訳（TEI データは CC0 1.0、ODD は CC BY-SA 3.0 / BSD-2）を書いた
- 抄録に AIP の SHA-256・MD5・UUID、元のコミット、作成したワークフローの実行の URL を書いた
- 自明でなかったこと: Chrome の拡張から上げられるファイルは 10MB までで、57MB の AIP は手でドロップした。
  フォームの「DOI から補完」は Zenodo の DOI を見つけられず、しかも入力した DOI がこの資料自身の DOI 欄に入ってしまった（消した）
- 自動化について: 登録の API（Esploro の Research Assets API）は機関が管理する鍵が要るので、当面は手作業
