#!/usr/bin/env python3
"""release.yml から呼ぶ、Zenodo とのやり取り（標準ライブラリだけで動く）。

  lookup    その版（version == タグ）の正の記録を探す（あれば ID と AIP の MD5 を出す）
  publish   AIP を Zenodo に上げて公開する（--src を渡せばソースの zip も。ワークフローでは渡さない）（新しい版として足すか、新規に作る）
  download  正の記録から AIP を取り出す（リリースへの添付が途中で失敗したときの取り直し）
  verify    手元の AIP の MD5 を、Zenodo の記録の AIP の MD5 と突き合わせる
  check-file  手元のファイル（AIP の中の SIP など）の MD5 を、記録の同名のファイルと突き合わせる

正の記録の決まり: 同じ概念（concept）の全版のうち、metadata.version がタグと同じものが複数あれば、
created が最も早いもの（同時刻なら ID の小さいもの）だけを正とする。
書き込める者が後から同じ版名の記録を足しても、AIP を作った直後の値が勝つようにするため。

環境変数:
  ZENODO_API                API の基点（https://zenodo.org/api か https://sandbox.zenodo.org/api）
  ZENODO_TOKEN              本番用の個人用トークン（deposit:write・deposit:actions）
  ZENODO_SANDBOX_TOKEN      sandbox 用のトークン。API の基点が sandbox のときはこちらだけを使う
  ZENODO_DEPOSITION_ID      本番で新しい版を足す元の記録（どの版の ID でもよい）。空なら新規に作る
  ZENODO_SANDBOX_DEPOSITION_ID  sandbox での同じもの
  GITHUB_OUTPUT / GITHUB_STEP_SUMMARY  あれば、出力と要約を書き足す

トークンは Authorization ヘッダにだけ入れる。ログ・例外の文面には出さない。
"""

import argparse
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

SANDBOX_HOST = 'sandbox.zenodo.org'
PAGE_SIZE = 25          # 匿名の検索で許される件数の上限。ページを送って全部取る
INDEX_WAIT = (5, 10, 20, 30, 60, 60, 60, 60)  # 公開直後は検索の索引に載るまで少しかかる


class ZenodoError(SystemExit):
    pass


def die(msg):
    raise ZenodoError(f'::error::{msg}')


def api_base():
    api = os.environ.get('ZENODO_API') or 'https://zenodo.org/api'
    return api.rstrip('/')


def is_sandbox(api):
    return urllib.parse.urlparse(api).hostname == SANDBOX_HOST


def token_for(api, required=True):
    # 本番のトークンを sandbox に送らない（逆も）。どちらを使うかは API の基点で決める
    name = 'ZENODO_SANDBOX_TOKEN' if is_sandbox(api) else 'ZENODO_TOKEN'
    tok = os.environ.get(name, '').strip()
    if required and not tok:
        die(f'{name} が設定されていません（API: {api}）')
    return tok or None


def deposition_id_for(api):
    name = 'ZENODO_SANDBOX_DEPOSITION_ID' if is_sandbox(api) else 'ZENODO_DEPOSITION_ID'
    v = os.environ.get(name, '').strip()
    if v and not v.isdigit():
        die(f'{name} は数字の記録 ID にしてください（今の値: {v!r}）')
    return v or None


def http(method, url, token=None, body=None, data=None, length=None, ctype=None, raw=False):
    """JSON を返す（raw=True なら応答そのもの）。失敗は状態コードと本文の先頭で止める"""
    headers = {'Accept': 'application/json'}
    if token:
        headers['Authorization'] = f'Bearer {token}'
    if body is not None:
        data = json.dumps(body).encode()
        headers['Content-Type'] = 'application/json'
    elif data is not None:
        headers['Content-Type'] = ctype or 'application/octet-stream'
        if length is not None:
            headers['Content-Length'] = str(length)
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        resp = urllib.request.urlopen(req, timeout=600)
    except urllib.error.HTTPError as e:
        detail = e.read()[:800].decode('utf-8', 'replace')
        die(f'{method} {url} → {e.code}: {detail}')
    if raw:
        return resp
    with resp:
        text = resp.read()
    return json.loads(text) if text.strip() else None


def md5_of(path):
    h = hashlib.md5()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def plain_md5(checksum):
    # 記録の API は "md5:<hex>"、古い deposit の API は "<hex>" で返す
    return (checksum or '').removeprefix('md5:').lower()


def record_files(rec):
    files = rec.get('files') or []
    if isinstance(files, dict):           # InvenioRDM の形（{"entries": {...}}）にも備える
        files = list((files.get('entries') or {}).values())
    return [{'key': f.get('key') or f.get('filename'), 'checksum': plain_md5(f.get('checksum')),
             'size': f.get('size') or f.get('filesize'), 'links': f.get('links') or {}} for f in files]


def file_with_suffix(rec, suffix):
    hits = [f for f in record_files(rec) if (f['key'] or '').endswith(suffix)]
    if len(hits) > 1:
        die(f'記録 {rec.get("id")} に {suffix} で終わるファイルが {len(hits)} 個あります')
    return hits[0] if hits else None


def get_record(api, rid, token=None):
    return http('GET', f'{api}/records/{rid}', token)


def all_versions(api, concept, token=None):
    """概念の全版を、ページを送って取る（25 件で黙って切らない）"""
    q = urllib.parse.urlencode({'q': f'conceptrecid:{concept}', 'all_versions': 'true',
                                'sort': 'oldest', 'size': PAGE_SIZE, 'page': 1})
    url, out, total = f'{api}/records?{q}', [], None
    for _ in range(1000):
        page = http('GET', url, token)
        hits = page['hits']
        total = hits['total'] if isinstance(hits['total'], int) else hits['total'].get('value')
        out.extend(hits['hits'])
        nxt = (page.get('links') or {}).get('next')
        if not nxt or not hits['hits']:
            break
        url = nxt
    ids = {h['id'] for h in out}
    if total is not None and len(ids) != total:
        die(f'概念 {concept} の版を取りきれません（{len(ids)} / {total} 件）')
    # 念のため、概念の違うものは捨てる
    return [h for h in out if str(h.get('conceptrecid')) == str(concept)]


def canonical(versions, tag):
    same = [h for h in versions if (h.get('metadata') or {}).get('version') == tag]
    same.sort(key=lambda h: (h['created'], int(h['id'])))
    return (same[0] if same else None), same


def concept_of(api, rid, token=None):
    rec = get_record(api, rid, token)
    c = rec.get('conceptrecid')
    if not c:
        die(f'記録 {rid} に conceptrecid がありません')
    return str(c), rec


def out(**kv):
    path = os.environ.get('GITHUB_OUTPUT')
    for k, v in kv.items():
        print(f'{k}={v}')
        if path:
            with open(path, 'a') as f:
                print(f'{k}={v}', file=f)


def summary(lines):
    path = os.environ.get('GITHUB_STEP_SUMMARY')
    if path:
        with open(path, 'a') as f:
            print('\n'.join(lines), file=f)


# ---------- メタデータ ----------

def read_cff(path):
    text = open(path, encoding='utf-8').read()

    def top(key):
        m = re.search(rf'^{re.escape(key)}:\s*"?(.*?)"?\s*$', text, flags=re.M)
        return m.group(1) if m else None
    return {'version': top('version'), 'date': top('date-released'), 'doi': top('doi')}


def build_metadata(src_dir, tag, repo):
    """.zenodo.json を土台に、版（タグ）と公開日（CITATION.cff）を入れる。どちらもタグの版のもの"""
    meta = json.load(open(os.path.join(src_dir, '.zenodo.json'), encoding='utf-8'))
    cff = read_cff(os.path.join(src_dir, 'CITATION.cff'))
    if cff['version'] != tag.removeprefix('v'):
        die(f'CITATION.cff の version（{cff["version"]}）がタグ {tag} と合いません')
    meta['version'] = tag
    if cff['date']:
        meta['publication_date'] = cff['date']
    rel = list(meta.get('related_identifiers') or [])
    if repo:
        rel.append({'identifier': f'https://github.com/{repo}/tree/{tag}',
                    'relation': 'isSupplementTo', 'resource_type': 'software'})
    meta['related_identifiers'] = rel
    meta.setdefault('notes', (
        f'File: *-aip.7z is the Archival Information Package (BagIt with METS/PREMIS, made by a3m) '
        f'of the source of {tag}. The source files are in data/objects/ of the package; '
        f'the commit they come from is recorded in the METS file (Dublin Core). '
        f'ファイル: *-aip.7z は {tag} のソースを a3m で包んだ AIP（BagIt・METS/PREMIS）。'
        f'ソースのファイルは AIP の data/objects/ に、元の commit は METS（Dublin Core）にあります。'))
    return meta


# ---------- 各コマンド ----------

def cmd_lookup(a):
    api = api_base()
    dep = deposition_id_for(api)
    if not dep:
        out(found='false')
        summary([f'- Zenodo: 新規に作る設定のため、既存の版は探さない（{api}）'])
        return
    concept, _ = concept_of(api, dep)
    rec, same = canonical(all_versions(api, concept), a.tag)
    if not rec:
        out(found='false', concept=concept)
        return
    aip = file_with_suffix(rec, '-aip.7z')
    if not aip:
        die(f'版 {a.tag} の正の記録 {rec["id"]}（{rec["created"]}）に AIP がありません。'
            f'GitHub 連携で作られた版は、この流れでは守れません')
    out(found='true', concept=concept, record_id=rec['id'], aip_md5=aip['checksum'],
        doi=rec.get('doi', ''), others=' '.join(str(h['id']) for h in same[1:]))


def cmd_publish(a):
    api = api_base()
    tok = token_for(api)
    dep = deposition_id_for(api)
    meta = build_metadata(a.meta_dir, a.tag, os.environ.get('GITHUB_REPOSITORY', ''))
    files = [a.aip] + ([a.src] if a.src else [])

    if dep:
        concept, _ = concept_of(api, dep, tok)
        rec, _ = canonical(all_versions(api, concept, tok), a.tag)
        if rec:
            die(f'版 {a.tag} は既に記録 {rec["id"]} として公開されています（作り直さない）')
        # 新しい版は、概念の最新版から足す
        latest = http('GET', f'{api}/records/{dep}', tok)['links']['latest']
        latest_id = http('GET', latest, tok)['id']
        r = http('POST', f'{api}/deposit/depositions/{latest_id}/actions/newversion', tok)
        draft = http('GET', r['links']['latest_draft'], tok)
        # 新しい版の下書きは前の版のファイルを引き継ぐので、全部外してから入れる
        for f in draft.get('files') or []:
            http('DELETE', f'{api}/deposit/depositions/{draft["id"]}/files/{f["id"]}', tok)
        mode = f'newversion（概念 {concept}、元 {latest_id}）'
    else:
        draft = http('POST', f'{api}/deposit/depositions', tok, body={})
        mode = '新規'

    did = draft['id']
    http('PUT', f'{api}/deposit/depositions/{did}', tok, body={'metadata': meta})
    bucket = draft['links']['bucket']
    for p in files:
        name = os.path.basename(p)
        with open(p, 'rb') as fh:
            http('PUT', f'{bucket}/{urllib.parse.quote(name)}', tok, data=fh, length=os.path.getsize(p))
    pub = http('POST', f'{api}/deposit/depositions/{did}/actions/publish', tok)
    rid = pub.get('record_id') or pub['id']

    # 公開された記録の値を、手元の値と突き合わせてから出す
    rec = get_record(api, rid, tok)
    for p in files:
        f = file_with_suffix(rec, os.path.basename(p))
        if not f or f['checksum'] != md5_of(p):
            die(f'公開した記録 {rid} の {os.path.basename(p)} の MD5 が手元と合いません')
    aip_md5 = file_with_suffix(rec, '-aip.7z')['checksum']
    out(record_id=rid, aip_md5=aip_md5, doi=rec.get('doi', ''), concept=rec.get('conceptrecid', ''))
    summary(['### Zenodo に公開', f'- API: `{api}`（{mode}）', f'- 記録: `{rid}` / DOI: `{rec.get("doi", "")}`',
             f'- AIP の MD5（Zenodo）: `{aip_md5}`'])


def cmd_download(a):
    api = api_base()
    rec = get_record(api, a.record_id)
    f = file_with_suffix(rec, '-aip.7z')
    if not f:
        die(f'記録 {a.record_id} に AIP がありません')
    url = f['links'].get('self') or f'{api}/records/{a.record_id}/files/{urllib.parse.quote(f["key"])}/content'
    if not url.endswith('/content') and '/files/' in url:
        url += '/content'
    dst = os.path.join(a.out_dir, os.path.basename(f['key']))
    with http('GET', url, raw=True) as resp, open(dst, 'wb') as fh:
        while chunk := resp.read(1 << 20):
            fh.write(chunk)
    if md5_of(dst) != f['checksum']:
        die('取り出した AIP の MD5 が記録と合いません')
    print(dst)


def wait_for_versions(api, concept, rid):
    for i, wait in enumerate((0,) + INDEX_WAIT):
        time.sleep(wait)
        vs = all_versions(api, concept)
        if any(str(h['id']) == str(rid) for h in vs):
            return vs
        print(f'記録 {rid} がまだ検索に出ません（{i + 1} 回目）', file=sys.stderr)
    die(f'記録 {rid} が概念 {concept} の版の検索に出てきません')


def cmd_verify(a):
    api = api_base()
    rid = str(a.record_id or '').strip()
    if not rid:
        die('照合する Zenodo の記録 ID がありません（aip の段の出力が空）')
    concept, rec = concept_of(api, rid)
    if rec.get('status') not in (None, 'published') or (rec.get('metadata') or {}).get('version') != a.tag:
        die(f'記録 {rid} は版 {a.tag} の公開済みの記録ではありません')
    dep = deposition_id_for(api)
    if dep:
        c2, _ = concept_of(api, dep)
        if c2 != concept:
            die(f'記録 {rid} の概念 {concept} が、設定の記録 {dep} の概念 {c2} と違います')
    first, same = canonical(wait_for_versions(api, concept, rid), a.tag)
    lines = ['### AIP の照合（リリースの添付と Zenodo の記録、MD5）',
             f'- 版 {a.tag} の記録: ' + ', '.join(f'`{h["id"]}`（{h["created"]}）' for h in same)]
    if str(first['id']) != rid:
        summary(lines + [f'- **止める: 正（最古）の記録は `{first["id"]}` で、aip の段の `{rid}` と違う**'])
        die(f'版 {a.tag} の正の記録は {first["id"]}（最古）で、{rid} ではありません')
    z = file_with_suffix(rec, '-aip.7z')
    ours = md5_of(a.aip)
    ok = bool(z) and z['checksum'] == ours
    summary(lines + [f'- 正の記録: `{rid}`', f'- リリースの AIP: `{ours}`',
                     f'- Zenodo の AIP: `{z["checksum"] if z else "なし"}`',
                     f'- 結果: {"一致" if ok else "**不一致（リリースの AIP が Zenodo の保存版と違う）**"}'])
    if not ok:
        die('リリースに添付された AIP が、Zenodo の記録の AIP と合いません')
    out(verified='true', doi=rec.get('doi', ''))


def cmd_check_file(a):
    api = api_base()
    rec = get_record(api, a.record_id)
    z = file_with_suffix(rec, a.suffix)
    ours = md5_of(a.file)
    ok = bool(z) and z['checksum'] == ours
    summary([f'- 記録の `*{a.suffix}` と AIP の中のファイル: {"一致" if ok else "**不一致**"}（`{ours}`）'])
    if not ok:
        die(f'{a.file} が記録 {a.record_id} の {a.suffix} と合いません')


def main(argv=None):
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest='cmd', required=True)
    s = sub.add_parser('lookup'); s.add_argument('--tag', required=True)
    s = sub.add_parser('publish'); s.add_argument('--tag', required=True); s.add_argument('--aip', required=True)
    s.add_argument('--src'); s.add_argument('--meta-dir', required=True)
    s = sub.add_parser('download'); s.add_argument('--record-id', required=True); s.add_argument('--out-dir', default='.')
    s = sub.add_parser('verify'); s.add_argument('--tag', required=True); s.add_argument('--record-id', default='')
    s.add_argument('--aip', required=True)
    s = sub.add_parser('check-file'); s.add_argument('--record-id', required=True)
    s.add_argument('--suffix', required=True); s.add_argument('--file', required=True)
    a = p.parse_args(argv)
    {'lookup': cmd_lookup, 'publish': cmd_publish, 'download': cmd_download,
     'verify': cmd_verify, 'check-file': cmd_check_file}[a.cmd](a)


if __name__ == '__main__':
    main()
