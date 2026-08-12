#!/usr/bin/env python3
"""SVRL (Schematron の検証結果) を、行番号つきの1行1件の形式で出力する。

    python3 scripts/svrl_report.py <検証した XML> <SVRL>

出力は jing と同じ形式に揃えてある:

    /絶対パス/01.xml:253:1: error: 和歌は5句です (waka-001 は 4 句)

SVRL の @location は EQName 形式 (/Q{名前空間}要素名[n]/...) の XPath なので、
これを元の XML に対して評価し直し、当たったノードの行番号を取る。
Saxon-HE には saxon:line-number() が無いため、行番号はこちら側で解決している。
桁は取れないので常に 1 を出す。

終了コード: role="error" が1件でもあれば 1、なければ 0
（role="warning" / "info" は報告するが、終了コードには影響しない）
"""

import re
import sys

from lxml import etree

SVRL_NS = "http://purl.oclc.org/dsdl/svrl"
EQNAME = re.compile(r"Q\{([^}]*)\}([^/\[\]]+)")


def eqname_to_xpath(location, nsmap):
    """/Q{uri}local[1]/... を lxml で評価できる XPath に直す。"""

    def repl(m):
        uri, local = m.group(1), m.group(2)
        prefix = nsmap.get(uri)
        if prefix is None:
            prefix = "ns%d" % len(nsmap)
            nsmap[uri] = prefix
        return "%s:%s" % (prefix, local)

    return EQNAME.sub(repl, location)


def line_of(tree, location):
    """@location が指すノードの行番号。解決できなければ 1。"""
    if not location:
        return 1
    uri_to_prefix = {}
    xpath = eqname_to_xpath(location, uri_to_prefix)
    namespaces = {p: u for u, p in uri_to_prefix.items()}
    try:
        hits = tree.xpath(xpath, namespaces=namespaces)
    except etree.XPathError:
        return 1
    if not hits:
        return 1
    node = hits[0]
    # 属性が当たった場合は、その属性を持つ要素の行を使う
    line = getattr(node, "sourceline", None)
    return line if line else 1


def main(argv):
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2

    xml_path, svrl_path = argv[1], argv[2]
    parser = etree.XMLParser(resolve_entities=False, no_network=True)
    tree = etree.parse(xml_path, parser)
    svrl = etree.parse(svrl_path, parser)

    findings = svrl.findall(".//{%s}failed-assert" % SVRL_NS)
    findings += svrl.findall(".//{%s}successful-report" % SVRL_NS)

    # 出力順が安定するよう、行番号で並べ替える
    rows = []
    for f in findings:
        role = (f.get("role") or "error").lower()
        if role not in ("error", "warning", "info"):
            role = "error"
        text_el = f.find("{%s}text" % SVRL_NS)
        message = " ".join((text_el.text or "").split()) if text_el is not None else ""
        rows.append((line_of(tree, f.get("location")), role, message))

    errors = 0
    for line, role, message in sorted(rows, key=lambda r: r[0]):
        print("%s:%d:1: %s: %s" % (xml_path, line, role, message))
        if role == "error":
            errors += 1

    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
