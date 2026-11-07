#!/usr/bin/env zsh
# Zenodo の個人用トークンを、GitHub Actions の secret に入れる（release.yml が AIP を Zenodo に上げるため）。
#
# 使い方:
#   zsh scripts/setup/zenodo-token.zsh sandbox      # 試験用（secret: ZENODO_SANDBOX_TOKEN）
#   zsh scripts/setup/zenodo-token.zsh production   # 本番用（secret: ZENODO_TOKEN）
#
# 前提:
#   - gh にログイン済みで、このリポジトリの secret を書ける（管理者）
#   - 先にブラウザでトークンを作っておく（sandbox と本番は別のアカウント・別のトークン）
#       sandbox: https://sandbox.zenodo.org/account/settings/applications/tokens/new/
#       本番:     https://zenodo.org/account/settings/applications/tokens/new/
#     （右上のアカウントのメニュー → Applications → Personal access tokens の「New token」）
#     Scopes は deposit:write と deposit:actions の 2 つだけに印を付ける（user:email は要らない）。
#       deposit:write   … 下書きの作成・ファイルの追加（公開はできない）
#       deposit:actions … 公開・編集・新しい版（publish / edit / newversion）
#     出典: https://developers.zenodo.org/ の Quickstart と Scopes の節
#   - 本番のトークンは、記録の所有者のアカウント（今の GitHub 連携の記録を持つアカウント）で作る。
#     newversion は所有者でないと使えないため
#
# 何をするか:
#   1. トークンを画面に出さずに入力してもらう（read -s）
#   2. Zenodo の API に 1 回だけ問い合わせて、トークンが効くか確かめる（読み取りだけ）
#   3. gh secret set に標準入力で渡す（コマンドラインの引数・履歴・ファイルに値を残さない）
#
# トークンは 1Password にも保存しておくとよい（項目名にパレンを使わない。例: "Zenodo token kouigenji production"）。
# 1Password から直接入れるなら、この台本を使わずに次の 1 行でもよい:
#   op read 'op://Personal/Zenodo token kouigenji production/credential' | gh secret set ZENODO_TOKEN --env zenodo -R kouigenjimonogatari/kouigenjimonogatari.github.io

set -euo pipefail

REPO=kouigenjimonogatari/kouigenjimonogatari.github.io
ENV_NAME=zenodo

case "${1:-}" in
  sandbox)    NAME=ZENODO_SANDBOX_TOKEN; API=https://sandbox.zenodo.org/api ;;
  production) NAME=ZENODO_TOKEN;         API=https://zenodo.org/api ;;
  *) print -u2 "使い方: zsh $0 sandbox|production"; exit 2 ;;
esac

read -s "TOKEN?${NAME} の値を貼り付けて Enter（画面には出ません）: "
print
if [[ -z "$TOKEN" ]]; then
  print -u2 "空でした。やめます"; exit 1
fi
print "長さ: ${#TOKEN} 文字"

# ヘッダは標準入力で渡す（引数に入れると ps で見えるため）
code=$(print -r -- "Authorization: Bearer $TOKEN" | curl -s -o /dev/null -w '%{http_code}' -H @- "$API/deposit/depositions?size=1")
if [[ "$code" != 200 ]]; then
  unset TOKEN
  print -u2 "トークンが効きません（$API/deposit/depositions → HTTP $code）。scope に deposit:write があるか、sandbox と本番を取り違えていないか確かめてください"
  exit 1
fi
print "Zenodo で確かめました（HTTP 200）"

# release.yml の aip の段は environment "zenodo" で動く。secret はリポジトリ全体ではなく、そこに置く
gh api -X PUT "repos/$REPO/environments/$ENV_NAME" > /dev/null
print -rn -- "$TOKEN" | gh secret set "$NAME" --env "$ENV_NAME" -R "$REPO"
unset TOKEN

print "\n入れた secret（environment: $ENV_NAME）:"
gh secret list --env "$ENV_NAME" -R "$REPO" | grep -E '^ZENODO' || true
print "\nenvironment の保護（承認者・タグだけ）は画面で付ける: https://github.com/$REPO/settings/environments"
print "\n変数（vars）の今の値:"
gh variable list -R "$REPO" | grep -E '^ZENODO' || print "  （ZENODO_* の変数はまだありません）"
