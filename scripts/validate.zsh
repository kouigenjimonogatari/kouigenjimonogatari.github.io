#!/usr/bin/env zsh
#
# TEI ファイルを RELAX NG と Schematron の両方で検証する。
#
# 前提: ./scripts/setup-tools.zsh と ./scripts/build-schema.zsh を実行済みであること。
#
# 使い方:
#   ./scripts/validate.zsh                    xml/master/*.xml を全部
#   ./scripts/validate.zsh xml/master/01.xml  ファイルを指定
#
# 出力は 1行1件、jing と同じ形式に揃えてある:
#   /絶対パス/01.xml:253:1: error: 和歌は5句です (waka-001 は 4 句) / A waka must have 5 lines ...
#
# 終了コード: error が1件でもあれば 1。warning だけなら 0。

set -euo pipefail

REPO_ROOT=${0:A:h:h}
source $REPO_ROOT/scripts/lib/tools.zsh
require_tools

RNG=$REPO_ROOT/docs/schema/tei_kouigenji.rng
SCH_XSL=$BUILD_DIR/tei_kouigenji.sch.xsl

[[ -f $RNG ]]     || die "$RNG がありません。./scripts/build-schema.zsh を実行してください"
[[ -f $SCH_XSL ]] || die "$SCH_XSL がありません。./scripts/build-schema.zsh を実行してください"

if (( $# > 0 )); then
  files=()
  for f in "$@"; do files+=(${f:A}); done
else
  files=($REPO_ROOT/xml/master/*.xml(N))
fi
(( ${#files} > 0 )) || die "検証対象のファイルがありません"

mkdir -p $BUILD_DIR/svrl

errors=0
warnings=0

count_matches() {  # count_matches <文字列> <パターン>
  print -r -- $1 | grep -c -- $2 || true
}

print "=== RELAX NG (${#files} ファイル) ==="
rng_out=$(jing $RNG $files 2>&1) || true
if [[ -n $rng_out ]]; then
  print -r -- $rng_out
  errors=$(( errors + $(count_matches $rng_out ': error: ') ))
fi

print "=== Schematron (${#files} ファイル) ==="
for f in $files; do
  svrl=$BUILD_DIR/svrl/${f:t:r}.svrl
  saxon -s:$f -xsl:$SCH_XSL -o:$svrl >/dev/null
  out=$(python3 $REPO_ROOT/scripts/svrl_report.py $f $svrl) || true
  if [[ -n $out ]]; then
    print -r -- $out
    errors=$((   errors   + $(count_matches $out ': error: ') ))
    warnings=$(( warnings + $(count_matches $out ': warning: ') ))
  fi
done

print
if (( errors == 0 && warnings == 0 )); then
  print "指摘 0 件。${#files} ファイルすべてが RELAX NG と Schematron を通過しました。"
  exit 0
fi

print "error ${errors} 件 / warning ${warnings} 件"
(( errors > 0 )) && exit 1
exit 0
