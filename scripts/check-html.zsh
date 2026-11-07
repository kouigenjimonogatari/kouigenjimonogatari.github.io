#!/usr/bin/env zsh
#
# 公開する HTML を検証する（Endings Principles の準拠の条件のうち 2 つ）。
#   1. すべてのコードを検証してある → W3C の Nu HTML Checker（vnu.jar）でエラーが 0 件
#   2. 内部リンクはすべて確かめてある → scripts/check_links.py で問題が 0 件（相対リンクかどうかも見る）
#
# 前提: ./scripts/setup-tools.zsh を実行済みで、docs/html・docs/en/html・docs/epub を組み立て済みであること
#       （python3 scripts/prebuild.py tei xsl epub）。
#
# 使い方: ./scripts/check-html.zsh     終了コード: 問題が 1 件でもあれば 1
#
# 対象外: docs/lib（同梱した Mirador・Chart.js）・docs/bibi（同梱した EPUB の閲覧ソフト）・
#         docs/api（JSON-LD）・Google の所有確認用のファイル。

set -euo pipefail

REPO_ROOT=${0:A:h:h}
source $REPO_ROOT/scripts/lib/tools.zsh
[[ -f $VNU_JAR ]] || die "tools/vnu がありません。./scripts/setup-tools.zsh を実行してください"
[[ -f $REPO_ROOT/docs/html/01.html ]] || die "docs/html がありません。python3 scripts/prebuild.py tei xsl を実行してください"

cd $REPO_ROOT
files=( ${(f)"$(find docs -name '*.html' -not -path 'docs/lib/*' -not -path 'docs/bibi/*' -not -path 'docs/bibi-bookshelf/*' -not -path 'docs/api/*' -not -name 'google*.html' | sort)"} )

print "1/2 HTML の検証（Nu HTML Checker $VNU_VERSION、${#files} 頁）"
rc=0
vnu --errors-only --format gnu $files || rc=1

print "2/2 内部リンクの確認"
python3 scripts/check_links.py docs || rc=1

(( rc == 0 )) && print "問題はありません。"
exit $rc
