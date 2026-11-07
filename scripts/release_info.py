"""版・公開日・DOI を CITATION.cff から読む（Endings Principles 5.3・5.4）。

頁に出す版の情報は、この 1 か所だけを元にする。値を頁に手で書かない。
組み立てた時刻は使わない（同じ版を組み立て直したときに中身が変わり、
release.yml の再ビルド一致の検査が通らなくなるため）。

CITATION.cff は単純な YAML なので、外部のライブラリを使わずに上の階層のキーだけを読む。
"""

import os
import re

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read(path=os.path.join(BASE_DIR, 'CITATION.cff')):
    with open(path, encoding='utf-8') as f:
        text = f.read()

    def top(key):
        m = re.search(rf'^{re.escape(key)}:\s*"?(.*?)"?\s*$', text, flags=re.M)
        if not m:
            raise SystemExit(f'CITATION.cff: {key} not found')
        return m.group(1)

    authors = re.findall(r'^\s+- family-names:\s*(.+?)\s*\n\s+given-names:\s*(.+?)\s*$', text, flags=re.M)
    return {
        'version': top('version'),
        'date': top('date-released'),
        'doi': top('doi'),          # Zenodo の concept DOI（常に最新版の記録を指す）
        'title': top('title'),
        'url': top('url'),
        'authors': [f'{fam}, {giv}' for fam, giv in authors],
    }


if __name__ == '__main__':
    print(read())
