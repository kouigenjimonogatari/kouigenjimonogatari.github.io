"""zenodo.py を、Zenodo の応答を模したローカルの HTTP サーバに対して動かす。"""
import contextlib, hashlib, io, json, os, re, sys, tempfile, threading, urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

sys.path.insert(0, sys.argv[1])
import zenodo  # noqa: E402

zenodo.INDEX_WAIT = (0, 0, 0)
TOKEN = 'SECRET-TOKEN-XYZ'
S = {'rec': {}, 'dep': {}, 'blob': {}, 'next': 1000, 'clock': 0, 'hidden': set(), 'search_calls': 0, 'writes': []}


def nid():
    S['next'] += 1
    return S['next']


def now():
    S['clock'] += 1
    return f'2026-11-07T00:00:{S["clock"]:02d}+00:00' if S['clock'] < 60 else f'2026-11-07T00:{S["clock"]//60:02d}:{S["clock"]%60:02d}+00:00'


def add_record(concept, version, files, created=None):
    rid = nid()
    S['rec'][rid] = {'id': rid, 'conceptrecid': str(concept), 'created': created or now(), 'status': 'published',
                     'doi': f'10.5072/zenodo.{rid}', 'metadata': {'version': version},
                     'files': [{'key': k, 'checksum': 'md5:' + hashlib.md5(v).hexdigest(), 'size': len(v)} for k, v in files.items()],
                     'links': {}}
    for k, v in files.items():
        S['blob'][(rid, k)] = v
    return rid


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def send(self, code, obj=None, raw=None, headers=()):
        self.send_response(code)
        for k, v in headers:
            self.send_header(k, v)
        body = raw if raw is not None else (json.dumps(obj).encode() if obj is not None else b'')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def base(self):
        return f'http://{self.headers["Host"]}/api'

    def rec_out(self, r):
        r = json.loads(json.dumps(r))
        for f in r['files']:
            f['links'] = {'self': f'{self.base()}/records/{r["id"]}/files/{f["key"]}'}
        r['links'] = {'latest': f'{self.base()}/records/{r["id"]}/latest'}
        return r

    def authed(self):
        ok = self.headers.get('Authorization') == f'Bearer {TOKEN}'
        if not ok:
            self.send(401, {'message': 'unauthorized'})
        return ok

    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        p, q = u.path, urllib.parse.parse_qs(u.query)
        if p == '/api/records':
            S['search_calls'] += 1
            concept = re.match(r'conceptrecid:(\d+)', q['q'][0]).group(1)
            size, page = int(q['size'][0]), int(q['page'][0])
            assert size <= 25, size
            hits = sorted((r for r in S['rec'].values() if r['conceptrecid'] == concept and r['id'] not in S['hidden']),
                          key=lambda r: r['created'])
            chunk = hits[(page - 1) * size: page * size]
            links = {'self': self.path}
            if page * size < len(hits):
                nq = dict((k, v[0]) for k, v in q.items()); nq['page'] = page + 1
                links['next'] = f'{self.base()}/records?{urllib.parse.urlencode(nq)}'
            # 索引の遅れ: 1 回目の検索では出てこない記録を、その後は出す
            S['hidden'].clear()
            return self.send(200, {'hits': {'hits': [self.rec_out(r) for r in chunk], 'total': len(hits)}, 'links': links})
        m = re.fullmatch(r'/api/records/(\d+)/latest', p)
        if m:
            c = S['rec'][int(m.group(1))]['conceptrecid']
            lat = max((r for r in S['rec'].values() if r['conceptrecid'] == c), key=lambda r: r['created'])
            return self.send(302, headers=[('Location', f'{self.base()}/records/{lat["id"]}')])
        m = re.fullmatch(r'/api/records/(\d+)/files/(.+?)/content', p)
        if m:
            return self.send(200, raw=S['blob'][(int(m.group(1)), urllib.parse.unquote(m.group(2)))])
        m = re.fullmatch(r'/api/records/(\d+)', p)
        if m:
            r = S['rec'].get(int(m.group(1)))
            return self.send(200, self.rec_out(r)) if r else self.send(404, {'message': 'not found'})
        m = re.fullmatch(r'/api/deposit/depositions/(\d+)', p)
        if m and self.authed():
            return self.send(200, self.dep_out(S['dep'][int(m.group(1))]))
        if not m:
            self.send(404, {'message': p})

    def dep_out(self, d):
        return {'id': d['id'], 'files': [{'id': f'f-{k}', 'filename': k} for k in d['files']],
                'links': {'bucket': f'{self.base()}/files/b{d["id"]}'}}

    def body(self):
        n = int(self.headers.get('Content-Length') or 0)
        return self.rfile.read(n)

    def do_POST(self):
        if not self.authed():
            return
        p = self.path
        self.body()
        S['writes'].append(('POST', p))
        if p == '/api/deposit/depositions':
            did = nid()
            S['dep'][did] = {'id': did, 'concept': str(nid()), 'files': {}, 'meta': None}
            return self.send(201, self.dep_out(S['dep'][did]))
        m = re.fullmatch(r'/api/deposit/depositions/(\d+)/actions/newversion', p)
        if m:
            src = S['rec'][int(m.group(1))]
            lat = max((r for r in S['rec'].values() if r['conceptrecid'] == src['conceptrecid']), key=lambda r: r['created'])
            if lat['id'] != src['id']:
                return self.send(400, {'message': 'not latest'})
            did = nid()
            S['dep'][did] = {'id': did, 'concept': src['conceptrecid'],
                             'files': {f['key']: S['blob'][(src['id'], f['key'])] for f in src['files']}, 'meta': None}
            return self.send(201, {'id': src['id'], 'links': {'latest_draft': f'{self.base()}/deposit/depositions/{did}'}})
        m = re.fullmatch(r'/api/deposit/depositions/(\d+)/actions/publish', p)
        if m:
            d = S['dep'].pop(int(m.group(1)))
            assert d['meta'] and d['meta']['version'], d
            rid = add_record(d['concept'], d['meta']['version'], d['files'])
            S['hidden'].add(rid)
            return self.send(202, {'id': rid, 'record_id': rid})
        self.send(404, {'message': p})

    def do_PUT(self):
        if not self.authed():
            return
        p, data = self.path, self.body()
        S['writes'].append(('PUT', p))
        m = re.fullmatch(r'/api/deposit/depositions/(\d+)', p)
        if m:
            S['dep'][int(m.group(1))]['meta'] = json.loads(data)['metadata']
            return self.send(200, {})
        m = re.fullmatch(r'/api/files/b(\d+)/(.+)', p)
        if m:
            S['dep'][int(m.group(1))]['files'][urllib.parse.unquote(m.group(2))] = data
            return self.send(201, {})
        self.send(404, {'message': p})

    def do_DELETE(self):
        if not self.authed():
            return
        m = re.fullmatch(r'/api/deposit/depositions/(\d+)/files/f-(.+)', self.path)
        S['writes'].append(('DELETE', self.path))
        del S['dep'][int(m.group(1))]['files'][m.group(2)]
        self.send(204)


srv = ThreadingHTTPServer(('127.0.0.1', 0), H)
threading.Thread(target=srv.serve_forever, daemon=True).start()
API = f'http://127.0.0.1:{srv.server_port}/api'
tmp = tempfile.mkdtemp()
results = []


def run(*argv, env=None, expect_ok=True):
    os.environ.clear(); os.environ.update({'ZENODO_API': API, 'ZENODO_TOKEN': TOKEN, 'GITHUB_REPOSITORY': 'o/r',
                                           'GITHUB_OUTPUT': f'{tmp}/out', 'GITHUB_STEP_SUMMARY': f'{tmp}/sum'})
    os.environ.update(env or {})
    open(f'{tmp}/out', 'w').close()
    buf_o, buf_e = io.StringIO(), io.StringIO()
    code = 0
    with contextlib.redirect_stdout(buf_o), contextlib.redirect_stderr(buf_e):
        try:
            zenodo.main(list(argv))
        except SystemExit as e:
            code = e.code if isinstance(e.code, int) else 1
            print(e.code, file=sys.stderr)
    outs = dict(l.split('=', 1) for l in open(f'{tmp}/out').read().splitlines() if '=' in l)
    alltext = buf_o.getvalue() + buf_e.getvalue() + open(f'{tmp}/sum').read() if os.path.exists(f'{tmp}/sum') else ''
    assert TOKEN not in alltext, 'token leaked'
    return code, outs, buf_e.getvalue()


def check(name, cond, extra=''):
    results.append((name, bool(cond)))
    print(('ok  ' if cond else 'FAIL'), name, extra)


def write(name, data):
    path = os.path.join(tmp, name); open(path, 'wb').write(data); return path


meta = os.path.join(tmp, 'meta'); os.mkdir(meta)
json.dump({'upload_type': 'dataset', 'title': 't', 'creators': [{'name': 'N'}]}, open(f'{meta}/.zenodo.json', 'w'))
open(f'{meta}/CITATION.cff', 'w').write('cff-version: 1.2.0\nversion: 1.2.0\ndate-released: 2026-11-08\n')
aip = write('r-v1.2.0-aip.7z', b'AIP-1' * 1000)
src = write('r-v1.2.0.zip', b'ZIP-1' * 100)

# 1. 新規に作って公開 → 検証が通る
c, o, e = run('publish', '--tag', 'v1.2.0', '--aip', aip, '--src', src, '--meta-dir', meta)
check('publish (new) succeeds', c == 0 and o.get('record_id'), e)
rid1 = o.get('record_id')
check('aip_md5 output equals local md5', o.get('aip_md5') == hashlib.md5(open(aip, 'rb').read()).hexdigest())
S['hidden'].add(int(rid1))  # 索引の遅れ
c, o, e = run('verify', '--tag', 'v1.2.0', '--record-id', rid1, '--aip', aip)
check('verify ok (with index lag)', c == 0 and o.get('verified') == 'true', e)

# 2. 差し替えた AIP は止まる
bad = write('bad/r-v1.2.0-aip.7z'.replace('/', '_'), b'TAMPERED')
c, o, e = run('verify', '--tag', 'v1.2.0', '--record-id', rid1, '--aip', bad)
check('verify fails on tampered AIP', c != 0 and '合いません' in e)

# 3. 版の違うタグ・空の ID
c, o, e = run('verify', '--tag', 'v9.9.9', '--record-id', rid1, '--aip', aip)
check('verify fails on version mismatch', c != 0)
c, o, e = run('verify', '--tag', 'v1.2.0', '--record-id', '', '--aip', aip)
check('verify fails on empty record id', c != 0)

# 4. 既存の概念に newversion（前の版のファイルを外してから入れる）
concept = S['rec'][int(rid1)]['conceptrecid']
aip3 = write('r-v1.3.0-aip.7z', b'AIP-3' * 999)
open(f'{meta}/CITATION.cff', 'w').write('version: 1.3.0\ndate-released: 2026-11-09\n')
c, o, e = run('publish', '--tag', 'v1.3.0', '--aip', aip3, '--meta-dir', meta, env={'ZENODO_DEPOSITION_ID': rid1})
rid3 = o.get('record_id')
check('newversion publish succeeds', c == 0 and rid3, e)
check('newversion stays in the same concept', S['rec'][int(rid3)]['conceptrecid'] == concept)
check('inherited files were removed', [f['key'] for f in S['rec'][int(rid3)]['files']] == ['r-v1.3.0-aip.7z'])

# 5. 同じ版を二度公開しない（索引に載った後）
S['hidden'].clear()
c, o, e = run('publish', '--tag', 'v1.3.0', '--aip', aip3, '--meta-dir', meta, env={'ZENODO_DEPOSITION_ID': rid1})
check('refuses to republish same version', c != 0 and '既に' in e)

# 6. CITATION.cff の版がタグと合わない
c, o, e = run('publish', '--tag', 'v1.4.0', '--aip', aip3, '--meta-dir', meta, env={'ZENODO_DEPOSITION_ID': rid1})
check('refuses CITATION/tag mismatch', c != 0 and 'CITATION' in e)

# 7. 後から同じ版名の記録が足された: 最古だけが正
forged_aip = write('forged-aip.7z', b'FORGED')
forged = add_record(concept, 'v1.3.0', {'r-v1.3.0-aip.7z': b'FORGED'})
c, o, e = run('verify', '--tag', 'v1.3.0', '--record-id', str(forged), '--aip', forged_aip)
check('later duplicate record is rejected', c != 0 and '最古' in e)
c, o, e = run('verify', '--tag', 'v1.3.0', '--record-id', rid3, '--aip', aip3)
check('oldest record still verifies', c == 0, e)
c, o, e = run('lookup', '--tag', 'v1.3.0', env={'ZENODO_DEPOSITION_ID': rid1})
check('lookup returns the oldest', o.get('found') == 'true' and o.get('record_id') == rid3 and o.get('others') == str(forged), str(o))

# 8. 30 版を超える（ページ送り）: 2 頁目にある版も見つかる
for i in range(30):
    add_record(concept, f'v0.{i}', {f'x-{i}-aip.7z': b'x%d' % i})
target = add_record(concept, 'v2.0.0', {'r-v2.0.0-aip.7z': b'AIP-20'})
calls = S['search_calls']
c, o, e = run('verify', '--tag', 'v2.0.0', '--record-id', str(target), '--aip', write('a20', b'AIP-20'))
check('pagination: version on page 2 verifies', c == 0 and S['search_calls'] - calls >= 2, e)
early = add_record(concept, 'v2.0.0', {'r-v2.0.0-aip.7z': b'EARLY'}, created='2000-01-01T00:00:00+00:00')
c, o, e = run('verify', '--tag', 'v2.0.0', '--record-id', str(target), '--aip', write('a20', b'AIP-20'))
check('pagination: older duplicate on page 1 is the canonical one', c != 0 and str(early) in e)

# 9. 記録の中の zip と AIP の中の SIP
c, o, e = run('check-file', '--record-id', rid1, '--suffix', 'r-v1.2.0.zip', '--file', src)
check('check-file ok', c == 0, e)
c, o, e = run('check-file', '--record-id', rid1, '--suffix', 'r-v1.2.0.zip', '--file', bad)
check('check-file mismatch fails', c != 0)

# 10. download で取り直す
d = tempfile.mkdtemp()
c, o, e = run('download', '--record-id', rid1, '--out-dir', d)
check('download restores the AIP', c == 0 and open(f'{d}/r-v1.2.0-aip.7z', 'rb').read() == open(aip, 'rb').read(), e)

# 11. GitHub 連携の記録（AIP なし）が正のとき、lookup は止まる
gh = add_record(concept, 'v3.0.0', {'o/r-v3.0.0.zip': b'z'})
c, o, e = run('lookup', '--tag', 'v3.0.0', env={'ZENODO_DEPOSITION_ID': rid1})
check('lookup stops on a record without AIP', c != 0 and 'AIP' in e)

# 12. トークンの選び方（API の基点で決める）
os.environ.clear(); os.environ.update({'ZENODO_TOKEN': 'P', 'ZENODO_SANDBOX_TOKEN': ''})
try:
    zenodo.token_for('https://sandbox.zenodo.org/api'); ok = False
except SystemExit:
    ok = True
check('sandbox never falls back to production token', ok)
os.environ['ZENODO_SANDBOX_TOKEN'] = 'S'
check('sandbox token chosen for sandbox host', zenodo.token_for('https://sandbox.zenodo.org/api') == 'S')
check('production token chosen for zenodo.org', zenodo.token_for('https://zenodo.org/api') == 'P')
os.environ.update({'ZENODO_DEPOSITION_ID': '24015762', 'ZENODO_SANDBOX_DEPOSITION_ID': ''})
check('sandbox never uses production deposition id', zenodo.deposition_id_for('https://sandbox.zenodo.org/api') is None)

# 13. 書き込みはすべてトークン付きだった（401 が出ていない）
check('no write without token', all(w for w in S['writes']))

srv.shutdown()
print(f'\n{sum(r for _, r in results)}/{len(results)} passed')
sys.exit(0 if all(r for _, r in results) else 1)
