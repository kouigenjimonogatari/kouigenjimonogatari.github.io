#!/usr/bin/env zsh
#
# odd/tei_kouigenji.odd を正本として、検証に使うスキーマ一式を生成する。
#
# 前提: ./scripts/setup-tools.zsh を先に実行しておくこと。
#
# 使い方:
#   ./scripts/build-schema.zsh
#
# 生成物:
#   docs/schema/tei_kouigenji.rng         RELAX NG        （コミットする。公開もされる）
#   docs/schema/tei_kouigenji.sch         ISO Schematron  （コミットする。公開もされる）
#   docs/schema/tei_kouigenji.html        カスタマイズの解説  （コミットする。公開もされる）
#   build/tei_kouigenji.compiled.odd  ODD を P5 と合成したもの（中間物）
#   build/tei_kouigenji.sch.xsl       Schematron を XSLT 3.0 にしたもの（検証実行用）
#
# 公開先（docs/ が GitHub Pages のルート）:
#   https://kouigenjimonogatari.github.io/schema/tei_kouigenji.rng
#   https://kouigenjimonogatari.github.io/schema/tei_kouigenji.sch
#   https://kouigenjimonogatari.github.io/schema/tei_kouigenji.html
#
# 変換はすべて TEI 公式の Stylesheets と SchXslt2 で、自前の変換は無い。
# odd2odd（合成）を挟まないと、moduleRef で参照しただけの要素が解決されない。
#
# なお odd2relax は Schematron を RNG の中にも埋め込むが、jing はそれを実行しない
# （jing が持つのは旧 Schematron 1.5）。コマンドライン・CI の経路で Schematron を
# 走らせるには、独立した .sch と SchXslt2 が要る。

set -euo pipefail

REPO_ROOT=${0:A:h:h}
source $REPO_ROOT/scripts/lib/tools.zsh
require_tools

ODD=$REPO_ROOT/odd/tei_kouigenji.odd
RNG=$REPO_ROOT/docs/schema/tei_kouigenji.rng
SCH=$REPO_ROOT/docs/schema/tei_kouigenji.sch
DOC=$REPO_ROOT/docs/schema/tei_kouigenji.html

[[ -f $ODD ]] || die "$ODD がありません"

mkdir -p $BUILD_DIR

print "1/5 ODD 自体を検証 (jing + TEI の ODD 用スキーマ)"
jing $ODDS_RNG $ODD || die "ODD が TEI の ODD スキーマに違反しています"

print "2/5 ODD を P5 と合成 (odd2odd.xsl)"
saxon -s:$ODD -xsl:$ODDS_XSL_DIR/odd2odd.xsl -o:$BUILD_DIR/tei_kouigenji.compiled.odd defaultSource=$P5SUBSET

print "3/5 RELAX NG を生成 (odd2relax.xsl)"
saxon -s:$BUILD_DIR/tei_kouigenji.compiled.odd -xsl:$ODDS_XSL_DIR/odd2relax.xsl -o:$RNG

print "4/5 ISO Schematron を抽出 (extract-isosch.xsl) して XSLT に変換 (SchXslt2)"
saxon -s:$BUILD_DIR/tei_kouigenji.compiled.odd -xsl:$ODDS_XSL_DIR/extract-isosch.xsl -o:$SCH
saxon -s:$SCH -xsl:$SCHXSLT2_DIR/transpile.xsl -o:$BUILD_DIR/tei_kouigenji.sch.xsl

print "5/5 カスタマイズの解説を生成 (odd2html.xsl)"
saxon -s:$BUILD_DIR/tei_kouigenji.compiled.odd -xsl:$ODDS_XSL_DIR/odd2html.xsl -o:$DOC

print
print "生成しました:"
print "  docs/schema/tei_kouigenji.rng    $(grep -c '<element name=' $RNG) 要素"
print "  docs/schema/tei_kouigenji.sch    $(grep -c '<pattern ' $SCH) パターン"
print "  docs/schema/tei_kouigenji.html   $(( $(wc -c < $DOC) / 1024 )) KB"
print "  build/tei_kouigenji.sch.xsl"
print
print "次: ./scripts/validate.zsh で xml/master/*.xml を検証します。"
