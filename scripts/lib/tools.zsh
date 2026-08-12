#!/usr/bin/env zsh
#
# スキーマ関連スクリプトの共通設定。単体では実行せず、source して使う。
#
#   REPO_ROOT=${0:A:h:h}
#   source $REPO_ROOT/scripts/lib/tools.zsh
#
# saxon / jing は tools/ 以下の jar を叩く関数として定義する。
# Homebrew や PATH の状態に依存せず、ローカルと CI で同じものが動く。
# 必要なのは Java だけ。

TOOLS_DIR=$REPO_ROOT/tools
BUILD_DIR=$REPO_ROOT/build

# --- バージョン固定（変える時は SHA-256 も一緒に更新すること） ---
TEI_XSL_VERSION=7.61.0
TEI_XSL_URL=https://github.com/TEIC/Stylesheets/releases/download/v${TEI_XSL_VERSION}/tei-xsl-${TEI_XSL_VERSION}.zip
TEI_XSL_SHA256=1a6cd1043af5adb3c5a8c1b2ec0b6abb7d0f241cd8725e233d691b3ca2f312bf

SCHXSLT2_VERSION=1.11.2
SCHXSLT2_URL=https://codeberg.org/SchXslt/schxslt2/releases/download/v${SCHXSLT2_VERSION}/schxslt2-${SCHXSLT2_VERSION}.zip
SCHXSLT2_SHA256=a0f5be3173113eb5ff4b5cf246fd9d1af0497a90df37023d3c0ccf60422af37c

P5_VERSION=4.12.0
P5_URL=https://www.tei-c.org/Vault/P5/${P5_VERSION}/xml/tei/odd/p5subset.xml
P5_SHA256=5b89720edc6f3821ab3d0aa242aa5dc922bfbafabfb103d2de9d211001c33e26
ODDS_RNG_URL=https://www.tei-c.org/Vault/P5/${P5_VERSION}/xml/tei/custom/schema/relaxng/tei_odds.rng

SAXON_VERSION=12.9
SAXON_URL=https://repo1.maven.org/maven2/net/sf/saxon/Saxon-HE/${SAXON_VERSION}/Saxon-HE-${SAXON_VERSION}.jar
SAXON_SHA256=8f3a9216a537367132293eacbba9df062eace8f8b16a184af59e2e4839d4cd41

# xmlresolver は Saxon 12 の必須依存。ただし 6.x は Apache HttpClient5 を要求し、
# odd2odd.xsl の doc-available() で ClassNotFoundException になる。
# 5.3.3 は java.net で完結するので、Homebrew の saxon が同梱しているのと同じ 5.3.3 に揃える。
XMLRESOLVER_VERSION=5.3.3
XMLRESOLVER_URL=https://repo1.maven.org/maven2/org/xmlresolver/xmlresolver/${XMLRESOLVER_VERSION}/xmlresolver-${XMLRESOLVER_VERSION}.jar
XMLRESOLVER_SHA256=1fe4d5b92f708dcdb82dbce12919e0171e6b5ca62c6dca6220483625098feb5f
XMLRESOLVER_DATA_URL=https://repo1.maven.org/maven2/org/xmlresolver/xmlresolver/${XMLRESOLVER_VERSION}/xmlresolver-${XMLRESOLVER_VERSION}-data.jar
XMLRESOLVER_DATA_SHA256=b0c487ad2f3e558be8d829c916d2458d10aca6a5bafa7a4d0524b70845e48a5c

JING_VERSION=20241231
JING_URL=https://github.com/relaxng/jing-trang/releases/download/V${JING_VERSION}/jing-${JING_VERSION}.zip
JING_SHA256=d11a765f9106e398e01d66aaffb629beb1da21f8a716299e2930a751130bfad2

# --- 配置 ---
TEI_XSL_DIR=$TOOLS_DIR/tei-xsl
ODDS_XSL_DIR=$TEI_XSL_DIR/xml/tei/stylesheet/odds
SCHXSLT2_DIR=$TOOLS_DIR/schxslt2
P5SUBSET=$TOOLS_DIR/p5subset.xml
ODDS_RNG=$TOOLS_DIR/tei_odds.rng
SAXON_JAR=$TOOLS_DIR/saxon/Saxon-HE.jar
XMLRESOLVER_JAR=$TOOLS_DIR/saxon/xmlresolver.jar
XMLRESOLVER_DATA_JAR=$TOOLS_DIR/saxon/xmlresolver-data.jar
JING_JAR=$TOOLS_DIR/jing/jing.jar

die() { print -u2 "エラー: $*"; exit 1 }

# macOS では Homebrew の openjdk が PATH に出ていないことが多いので、順に探す
find_java() {
  if [[ -n ${JAVA_HOME:-} && -x $JAVA_HOME/bin/java ]]; then
    print -r -- $JAVA_HOME/bin/java
    return 0
  fi
  if command -v java >/dev/null 2>&1 && java -version >/dev/null 2>&1; then
    command -v java
    return 0
  fi
  if [[ -x /usr/libexec/java_home ]]; then
    local home
    home=$(/usr/libexec/java_home 2>/dev/null) || home=
    if [[ -n $home && -x $home/bin/java ]]; then
      print -r -- $home/bin/java
      return 0
    fi
  fi
  local candidate
  for candidate in /opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
                   /usr/local/opt/openjdk/libexec/openjdk.jdk/Contents/Home; do
    if [[ -x $candidate/bin/java ]]; then
      print -r -- $candidate/bin/java
      return 0
    fi
  done
  return 1
}

JAVA=$(find_java) || die "Java が見つかりません（brew install openjdk、または JAVA_HOME を設定してください）"

saxon() { $JAVA -cp $SAXON_JAR:$XMLRESOLVER_JAR:$XMLRESOLVER_DATA_JAR net.sf.saxon.Transform "$@" }
jing()  { $JAVA -jar $JING_JAR "$@" }

require_tools() {
  [[ -d $ODDS_XSL_DIR ]]            || die "tools/ が未整備です。./scripts/setup-tools.zsh を実行してください"
  [[ -f $SCHXSLT2_DIR/transpile.xsl ]] || die "tools/schxslt2 がありません。./scripts/setup-tools.zsh を実行してください"
  [[ -f $P5SUBSET ]]                || die "tools/p5subset.xml がありません。./scripts/setup-tools.zsh を実行してください"
  [[ -f $SAXON_JAR ]]               || die "tools/saxon がありません。./scripts/setup-tools.zsh を実行してください"
  [[ -f $JING_JAR ]]                || die "tools/jing がありません。./scripts/setup-tools.zsh を実行してください"
}
