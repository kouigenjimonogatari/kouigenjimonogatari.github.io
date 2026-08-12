#!/usr/bin/env zsh
#
# スキーマの生成・検証に使う外部ツールを tools/ に取得する。
#
# 前提: Java だけ（macOS なら brew install openjdk）。
#       saxon / jing はここで取得した jar を使うので、別途インストールしなくてよい。
#
# 使い方:
#   ./scripts/setup-tools.zsh          取得（既にあるものは飛ばす）
#   ./scripts/setup-tools.zsh --force  取り直す
#
# 取得するもの（すべてバージョン固定・SHA-256 照合つき。版は scripts/lib/tools.zsh）:
#   tools/tei-xsl/       TEI Stylesheets   ODD → RELAX NG / ISO Schematron
#   tools/schxslt2/      SchXslt2          Schematron → XSLT 3.0
#   tools/saxon/         Saxon-HE          XSLT 実行
#   tools/jing/          Jing              RELAX NG 検証
#   tools/p5subset.xml   TEI P5 の仕様本体（ODD の合成に必要）
#   tools/tei_odds.rng   ODD 自身を検証するためのスキーマ
#
# tools/ は .gitignore 済み。CI でも同じスクリプトを使う。

set -euo pipefail

REPO_ROOT=${0:A:h:h}
source $REPO_ROOT/scripts/lib/tools.zsh

FORCE=no
[[ ${1:-} == --force ]] && FORCE=yes

for cmd in curl shasum unzip; do
  command -v $cmd >/dev/null || die "$cmd が見つかりません"
done

mkdir -p $TOOLS_DIR

# fetch <url> <出力先> [期待するsha256]
fetch() {
  local url=$1 dest=$2 want=${3:-}
  local tmp
  tmp=$(mktemp)
  print "取得中: ${url:t}"
  curl -fsSL -o $tmp $url || { rm -f $tmp; die "ダウンロードに失敗: $url" }
  if [[ -n $want ]]; then
    local got
    got=$(shasum -a 256 $tmp | cut -d' ' -f1)
    if [[ $got != $want ]]; then
      rm -f $tmp
      die "SHA-256 が一致しません: ${url:t}
  期待 $want
  実際 $got
  改ざんかバージョン変更の可能性があります。scripts/lib/tools.zsh を確認してください。"
    fi
  fi
  mkdir -p ${dest:h}
  mv $tmp $dest
  chmod 644 $dest
}

# --- TEI Stylesheets ---
if [[ $FORCE == yes || ! -d $TEI_XSL_DIR ]]; then
  rm -rf $TEI_XSL_DIR
  fetch $TEI_XSL_URL $TOOLS_DIR/tei-xsl.zip $TEI_XSL_SHA256
  unzip -q -o $TOOLS_DIR/tei-xsl.zip -d $TEI_XSL_DIR
  rm -f $TOOLS_DIR/tei-xsl.zip
  [[ -d $ODDS_XSL_DIR ]] || die "TEI Stylesheets の展開結果が想定と違います"
else
  print "skip: tools/tei-xsl"
fi

# --- SchXslt2 ---
if [[ $FORCE == yes || ! -d $SCHXSLT2_DIR ]]; then
  rm -rf $SCHXSLT2_DIR $TOOLS_DIR/.schxslt2-tmp
  fetch $SCHXSLT2_URL $TOOLS_DIR/schxslt2.zip $SCHXSLT2_SHA256
  unzip -q -o $TOOLS_DIR/schxslt2.zip -d $TOOLS_DIR/.schxslt2-tmp
  mv $TOOLS_DIR/.schxslt2-tmp/schxslt2-${SCHXSLT2_VERSION} $SCHXSLT2_DIR
  rm -rf $TOOLS_DIR/.schxslt2-tmp $TOOLS_DIR/schxslt2.zip
  [[ -f $SCHXSLT2_DIR/transpile.xsl ]] || die "SchXslt2 の展開結果が想定と違います"
else
  print "skip: tools/schxslt2"
fi

# --- Saxon-HE ---
if [[ $FORCE == yes || ! -f $SAXON_JAR ]]; then
  fetch $SAXON_URL $SAXON_JAR $SAXON_SHA256
  fetch $XMLRESOLVER_URL $XMLRESOLVER_JAR $XMLRESOLVER_SHA256
  fetch $XMLRESOLVER_DATA_URL $XMLRESOLVER_DATA_JAR $XMLRESOLVER_DATA_SHA256
else
  print "skip: tools/saxon"
fi

# --- Jing ---
if [[ $FORCE == yes || ! -f $JING_JAR ]]; then
  rm -rf $TOOLS_DIR/jing $TOOLS_DIR/.jing-tmp
  fetch $JING_URL $TOOLS_DIR/jing.zip $JING_SHA256
  unzip -q -o $TOOLS_DIR/jing.zip -d $TOOLS_DIR/.jing-tmp
  mkdir -p $TOOLS_DIR/jing
  cp $TOOLS_DIR/.jing-tmp/jing-${JING_VERSION}/bin/*.jar $TOOLS_DIR/jing/
  rm -rf $TOOLS_DIR/.jing-tmp $TOOLS_DIR/jing.zip
  [[ -f $JING_JAR ]] || die "Jing の展開結果が想定と違います"
else
  print "skip: tools/jing"
fi

# --- TEI P5 ---
if [[ $FORCE == yes || ! -f $P5SUBSET ]]; then
  fetch $P5_URL $P5SUBSET $P5_SHA256
else
  print "skip: tools/p5subset.xml"
fi

# tei_odds.rng は P5 のリリースごとに中身が変わりうるので SHA 照合はしない
if [[ $FORCE == yes || ! -f $ODDS_RNG ]]; then
  fetch $ODDS_RNG_URL $ODDS_RNG
else
  print "skip: tools/tei_odds.rng"
fi

print
print "準備できました:"
print "  TEI Stylesheets $TEI_XSL_VERSION"
print "  SchXslt2        $SCHXSLT2_VERSION"
print "  TEI P5          $P5_VERSION"
print "  Saxon-HE        $SAXON_VERSION"
print "  Jing            $JING_VERSION"
print "  Java            $JAVA"
print
print "次: ./scripts/build-schema.zsh でスキーマを生成します。"
