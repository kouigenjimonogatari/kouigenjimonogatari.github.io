#!/usr/bin/env python3
"""
Phase 4: prebuild スクリプト
xml/master/ をマスターとして以下を生成:
  4-1. docs/tei/        表示・解析用TEI（処理命令付き）
  4-2. docs/data/waka.json  和歌一覧データ
  4-4. docs/output/     PDF (xslt3 + lualatex)
  4-5. docs/bibi-bookshelf/ EPUB
"""

import json
import os
import re
import shutil
import subprocess
import sys
from xml.etree import ElementTree as ET

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
XML_LW_DIR = os.path.join(BASE_DIR, 'xml', 'master')
DOCS_DIR = os.path.join(BASE_DIR, 'docs')

DEFAULT_SITE_URL = 'https://kouigenjimonogatari.github.io'
SITE_URL = os.environ.get('SITE_URL', DEFAULT_SITE_URL).rstrip('/')

CHAPTERS = [f'{i:02d}' for i in range(1, 55)]


def xslt_cmd(xsl, src, dst):
    """Return command list for XSLT transformation, preferring Saxon-HE over npx xslt3."""
    saxon_jar = os.environ.get('SAXON_JAR')
    if saxon_jar:
        return ['java', '-jar', saxon_jar, f'-xsl:{xsl}', f'-s:{src}', f'-o:{dst}']
    if shutil.which('saxon'):
        return ['saxon', f'-xsl:{xsl}', f'-s:{src}', f'-o:{dst}']
    return ['npx', 'xslt3', f'-xsl:{xsl}', f'-s:{src}', f'-o:{dst}']

# Chapter names (巻名)
CHAPTER_NAMES = {
    '01': 'きりつぼ', '02': '帚木', '03': '空蝉', '04': '夕顔', '05': '若紫',
    '06': '末摘花', '07': '紅葉賀', '08': '花宴', '09': 'あふひ', '10': '賢木',
    '11': '花散里', '12': '須磨', '13': '明石', '14': 'みをつくし', '15': '蓬生',
    '16': '関屋', '17': '絵合', '18': '松風', '19': '薄雲', '20': '朝顔',
    '21': '少女', '22': '玉鬘', '23': '初音', '24': '胡蝶', '25': '蛍',
    '26': '常夏', '27': '篝火', '28': '野分', '29': '行幸', '30': '藤袴',
    '31': '真木柱', '32': '梅枝', '33': '藤裏葉', '34': '若菜上', '35': '若菜下',
    '36': '柏木', '37': '横笛', '38': '鈴虫', '39': '夕霧', '40': '御法',
    '41': '幻', '42': '匂宮', '43': '紅梅', '44': '竹河', '45': '橋姫',
    '46': '椎本', '47': '総角', '48': '早蕨', '49': '宿木', '50': '東屋',
    '51': '浮舟', '52': '蜻蛉', '53': '手習', '54': '夢浮橋',
}


def build_tei(ch, src_path, dst_path):
    """4-1: Generate TEI with processing instructions for display and analysis."""
    with open(src_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Remove old XML declaration and processing instructions
    content = re.sub(r'<\?xml[^?]*\?>\s*', '', content)
    content = re.sub(r'<\?xml-model[^?]*\?>\s*', '', content)
    content = re.sub(r'<\?xml-stylesheet[^?]*\?>\s*', '', content)
    # Remove xmlns:rdf attribute
    content = re.sub(r'\s*xmlns:rdf="[^"]*"', '', content)
    # Tab → 2 spaces
    content = content.replace('\t', '  ')

    # Add processing instructions at the beginning
    pis = (
        '<?xml version="1.0" ?>\n'
        f'<?xml-model href="{SITE_URL}/lw/tei_genji.rng" '
        'type="application/xml" schematypens="http://relaxng.org/ns/structure/1.0"?>\n'
    )
    content = pis + content

    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    with open(dst_path, 'w', encoding='utf-8') as f:
        f.write(content)





def build_html():
    """4-1b: Transform TEI XML to HTML using mirador.xsl via xslt3 (Saxon-JS)."""
    xsl_path = os.path.join(DOCS_DIR, 'xsl', 'mirador.xsl')
    html_dir = os.path.join(DOCS_DIR, 'html')
    os.makedirs(html_dir, exist_ok=True)
    for ch in CHAPTERS:
        src = os.path.join(DOCS_DIR, 'tei', f'{ch}.xml')
        dst = os.path.join(html_dir, f'{ch}.html')
        if not os.path.exists(src):
            continue
        result = subprocess.run(
            xslt_cmd(xsl_path, src, dst),
            capture_output=True, text=True, cwd=BASE_DIR
        )
        if result.returncode != 0:
            print(f'  {ch}.html FAILED: {result.stderr}', file=sys.stderr)
        else:
            print(f'  {ch}.html')


def build_waka_json():
    """4-3: Extract all <lg type="waka"> from xml/master/ and generate waka.json."""
    TEI_NS = 'http://www.tei-c.org/ns/1.0'
    all_waka = []
    global_seq = 0

    for ch in CHAPTERS:
        src_path = os.path.join(XML_LW_DIR, f'{ch}.xml')
        if not os.path.exists(src_path):
            continue

        with open(src_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Use regex to extract waka from seg elements (faster than XML parsing
        # and avoids issues with namespace/PI handling)
        pattern = r'<seg\s+corresp="([^"]+)">[^<]*<lg\s+xml:id="([^"]+)"\s+type="waka"[^>]*>(.*?)</lg>'
        for m in re.finditer(pattern, content):
            global_seq += 1
            corresp = m.group(1)
            waka_id = m.group(2)
            lg_content = m.group(3)

            # Extract l elements
            l_parts = re.findall(r'<l[^>]*>(.*?)</l>', lg_content)

            all_waka.append({
                'seq': global_seq,
                'chapter': ch,
                'chapter_name': CHAPTER_NAMES.get(ch, ch),
                'lines': l_parts,
                'corresp': corresp,
                'waka_id': waka_id,
            })

    dst_path = os.path.join(DOCS_DIR, 'data', 'waka.json')
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    with open(dst_path, 'w', encoding='utf-8') as f:
        json.dump(all_waka, f, ensure_ascii=False, indent=2)

    return len(all_waka)


def build_chapters_json():
    """Extract per-chapter statistics (pages, lines, chars, waka) and generate chapters.json."""
    chapters = []

    for ch in CHAPTERS:
        src_path = os.path.join(XML_LW_DIR, f'{ch}.xml')
        if not os.path.exists(src_path):
            continue

        with open(src_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Count <pb> elements (pages)
        pages = len(re.findall(r'<pb\s', content))

        # Count <seg> elements (lines) and sum their text characters
        seg_texts = re.findall(r'<seg[^>]*>(.*?)</seg>', content)
        lines = len(seg_texts)
        chars = 0
        for seg_text in seg_texts:
            # Strip XML tags to get plain text, then count characters
            plain = re.sub(r'<[^>]+>', '', seg_text)
            # Remove leading whitespace (e.g. ideographic spaces used for indentation)
            plain = plain.strip()
            chars += len(plain)

        # Count <lg type="waka"> elements
        waka = len(re.findall(r'<lg\s+type="waka"', content))

        chapters.append({
            'chapter': ch,
            'chapter_name': CHAPTER_NAMES.get(ch, ch),
            'pages': pages,
            'lines': lines,
            'chars': chars,
            'waka': waka,
        })

    dst_path = os.path.join(DOCS_DIR, 'data', 'chapters.json')
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    with open(dst_path, 'w', encoding='utf-8') as f:
        json.dump(chapters, f, ensure_ascii=False, indent=2)

    return len(chapters)


def detect_jfont():
    """Auto-detect an available Japanese serif font via fc-list."""
    preferred = [
        'Noto Serif CJK JP',
        'Hiragino Mincho ProN',
        'YuMincho',
        'BIZ UDMincho',
        'IPAexMincho',
    ]
    try:
        result = subprocess.run(
            ['fc-list', ':lang=ja', 'family'],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            return None
        available = set()
        for line in result.stdout.splitlines():
            for name in line.split(','):
                available.add(name.strip())
        for font in preferred:
            if font in available:
                return font
    except FileNotFoundError:
        pass
    return None


def _detect_fallback_font():
    """Detect a fallback font that covers U+3031 (くの字点)."""
    try:
        result = subprocess.run(
            ['fc-list', ':charset=3031', 'family'],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                for name in line.split(','):
                    name = name.strip()
                    if name and not name.startswith('.'):
                        return name
    except FileNotFoundError:
        pass
    return None


def _patch_tex(tex_path, jfont):
    """Patch generated .tex: replace font, add fallback for rare chars."""
    with open(tex_path, 'r', encoding='utf-8') as f:
        tex = f.read()

    # Replace main font
    if jfont != 'Noto Serif CJK JP':
        tex = tex.replace('Noto Serif CJK JP', jfont)

    # Add fallback font for rare characters (e.g. U+3031 くの字点)
    if '〱' in tex:
        fallback = _detect_fallback_font()
        if fallback:
            # Replace in body first, then insert preamble with literal char
            body_marker = '\\begin{document}'
            preamble, body = tex.split(body_marker, 1)
            body = body.replace('〱', '\\kuno{}')
            fallback_defs = (
                f'\\newjfontfamily\\fallbackjfont{{{fallback}}}\n'
                '\\newcommand{\\kuno}{{\\fallbackjfont 〱}}\n'
            )
            tex = preamble + fallback_defs + body_marker + body

    with open(tex_path, 'w', encoding='utf-8') as f:
        f.write(tex)


BUILD_DIR = os.path.join(BASE_DIR, 'build')


def build_pdf(ch):
    """4-4: Generate PDF via XSLT + lualatex. Intermediate files go to build/."""
    xsl_src = os.path.join(DOCS_DIR, 'tei', f'{ch}.xml')
    tex_xsl = os.path.join(DOCS_DIR, 'xsl', 'tex.xsl')
    work_dir = os.path.join(BUILD_DIR, 'pdf', ch)
    tex_path = os.path.join(work_dir, 'main.tex')

    os.makedirs(work_dir, exist_ok=True)

    # XSLT XML → TeX
    result = subprocess.run(
        xslt_cmd(tex_xsl, xsl_src, tex_path),
        capture_output=True, text=True, cwd=BASE_DIR
    )
    if result.returncode != 0:
        print(f'    xslt3 error: {result.stderr}', file=sys.stderr)
        return False

    # Auto-detect Japanese font and patch .tex
    jfont = detect_jfont()
    if jfont is None:
        print('    WARNING: no Japanese serif font found; skipping PDF', file=sys.stderr)
        return False
    _patch_tex(tex_path, jfont)

    # lualatex TeX → PDF
    result = subprocess.run(
        ['lualatex', f'-output-directory={work_dir}', tex_path],
        capture_output=True, text=True, cwd=BASE_DIR
    )
    if result.returncode != 0:
        print(f'    lualatex error: {result.stderr[:200]}', file=sys.stderr)
        return False

    # Copy final PDF to docs/pdf/
    pdf_src = os.path.join(work_dir, 'main.pdf')
    pdf_dir = os.path.join(DOCS_DIR, 'pdf')
    os.makedirs(pdf_dir, exist_ok=True)
    shutil.copy2(pdf_src, os.path.join(pdf_dir, f'{ch}.pdf'))

    return True


def build_epub(ch):
    """4-5: Generate EPUB 3.0 as .epub file for Bibi reader."""
    import zipfile

    src_path = os.path.join(XML_LW_DIR, f'{ch}.xml')
    if not os.path.exists(src_path):
        return False

    work_dir = os.path.join(BUILD_DIR, 'epub', ch)

    with open(src_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Extract title
    title_m = re.search(r'<title>(.*?)</title>', content)
    title = title_m.group(1) if title_m else f'巻{ch}'

    # Extract seg text grouped by page (pb elements)
    pages = {}
    current_page = None
    for line in content.split('\n'):
        pb_m = re.search(r'<pb\s+[^>]*n="(\d+)"', line)
        if pb_m:
            current_page = pb_m.group(1)
            if current_page not in pages:
                pages[current_page] = []

        seg_m = re.search(r'<seg[^>]*>(.*?)</seg>', line)
        if seg_m and current_page:
            text = re.sub(r'<[^>]+>', '', seg_m.group(1))
            pages[current_page].append(text)

    if not pages:
        return False

    # Create intermediate directory structure
    epub_dir = os.path.join(work_dir, 'EPUB')
    meta_dir = os.path.join(work_dir, 'META-INF')
    os.makedirs(epub_dir, exist_ok=True)
    os.makedirs(meta_dir, exist_ok=True)

    # mimetype
    with open(os.path.join(work_dir, 'mimetype'), 'w') as f:
        f.write('application/epub+zip')

    # META-INF/container.xml
    with open(os.path.join(meta_dir, 'container.xml'), 'w', encoding='utf-8') as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n')
        f.write('<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">\n')
        f.write('  <rootfiles>\n')
        f.write('    <rootfile full-path="EPUB/content.opf" media-type="application/oebps-package+xml"/>\n')
        f.write('  </rootfiles>\n')
        f.write('</container>\n')

    # style.css
    with open(os.path.join(epub_dir, 'style.css'), 'w', encoding='utf-8') as f:
        f.write('body { writing-mode: vertical-rl; font-family: serif; line-height: 1.8; }\n')

    # Generate XHTML pages
    sorted_pages = sorted(pages.keys(), key=int)
    for page_num in sorted_pages:
        lines = pages[page_num]
        text_content = '<br/>'.join(lines)
        xhtml = (
            "<?xml version='1.0' encoding='utf-8'?>\n"
            "<!DOCTYPE html>\n"
            '<html xmlns="http://www.w3.org/1999/xhtml" '
            'xmlns:epub="http://www.idpf.org/2007/ops" '
            'epub:prefix="z3998: http://www.daisy.org/z3998/2012/vocab/structure/#" '
            'lang="ja" xml:lang="ja">\n'
            "  <head>\n"
            f"    <title>{page_num}</title>\n"
            "  </head>\n"
            f'  <body><link rel="stylesheet" href="style.css" type="text/css"/>'
            f'{text_content}</body>\n'
            "</html>\n"
        )
        with open(os.path.join(epub_dir, f'{page_num}.xhtml'), 'w', encoding='utf-8') as f:
            f.write(xhtml)

    # content.opf
    manifest_items = ['    <item href="style.css" id="_style.css" media-type="text/css"/>']
    spine_items = []
    for page_num in sorted_pages:
        manifest_items.append(
            f'    <item href="{page_num}.xhtml" id="page_{page_num}" '
            f'media-type="application/xhtml+xml"/>'
        )
        spine_items.append(f'    <itemref idref="page_{page_num}"/>')

    manifest_items.append(
        '    <item href="toc.ncx" id="ncx" media-type="application/x-dtbncx+xml"/>'
    )

    opf = (
        "<?xml version='1.0' encoding='utf-8'?>\n"
        '<package xmlns="http://www.idpf.org/2007/opf" '
        'unique-identifier="id" version="3.0" '
        'prefix="rendition: http://www.idpf.org/vocab/rendition/#">\n'
        '  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:opf="http://www.idpf.org/2007/opf">\n'
        '    <meta property="dcterms:modified">2024-01-01T00:00:00Z</meta>\n'
        f'    <dc:identifier id="id">{ch}</dc:identifier>\n'
        f'    <dc:title>{title}</dc:title>\n'
        '    <dc:language>ja</dc:language>\n'
        '    <dc:creator id="creator">池田亀鑑</dc:creator>\n'
        '  </metadata>\n'
        '  <manifest>\n'
        + '\n'.join(manifest_items) + '\n'
        '  </manifest>\n'
        '  <spine toc="ncx" page-progression-direction="rtl">\n'
        + '\n'.join(spine_items) + '\n'
        '  </spine>\n'
        '</package>\n'
    )
    with open(os.path.join(epub_dir, 'content.opf'), 'w', encoding='utf-8') as f:
        f.write(opf)

    # toc.ncx
    nav_points = []
    for i, page_num in enumerate(sorted_pages, 1):
        nav_points.append(
            f'    <navPoint id="navpoint-{i}" playOrder="{i}">\n'
            f'      <navLabel><text>Page {page_num}</text></navLabel>\n'
            f'      <content src="{page_num}.xhtml"/>\n'
            f'    </navPoint>'
        )

    ncx = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">\n'
        '  <head>\n'
        f'    <meta name="dtb:uid" content="{ch}"/>\n'
        '  </head>\n'
        '  <docTitle>\n'
        f'    <text>{title}</text>\n'
        '  </docTitle>\n'
        '  <navMap>\n'
        + '\n'.join(nav_points) + '\n'
        '  </navMap>\n'
        '</ncx>\n'
    )
    with open(os.path.join(epub_dir, 'toc.ncx'), 'w', encoding='utf-8') as f:
        f.write(ncx)

    # Copy expanded folder to docs/epub/{ch}/ (for Bibi folder-mode)
    epub_out_dir = os.path.join(DOCS_DIR, 'epub')
    folder_dst = os.path.join(epub_out_dir, ch)
    if os.path.exists(folder_dst):
        shutil.rmtree(folder_dst)
    shutil.copytree(work_dir, folder_dst)

    # Also package as .epub file (for download)
    epub_path = os.path.join(epub_out_dir, f'{ch}.epub')
    with zipfile.ZipFile(epub_path, 'w') as zf:
        zf.write(os.path.join(work_dir, 'mimetype'), 'mimetype',
                 compress_type=zipfile.ZIP_STORED)
        for dirpath, _dirs, files in os.walk(work_dir):
            for fname in files:
                if fname == 'mimetype':
                    continue
                full = os.path.join(dirpath, fname)
                arcname = os.path.relpath(full, work_dir)
                zf.write(full, arcname, compress_type=zipfile.ZIP_DEFLATED)

    return True


def build_api():
    """4-6: Generate docs/api/ and docs/files/rdf/ by calling existing scripts."""
    scripts_dir = os.path.join(BASE_DIR, 'scripts')
    api_items_dir = os.path.join(DOCS_DIR, 'api', 'items')
    api_sets_dir = os.path.join(DOCS_DIR, 'api', 'item_sets')
    rdf_dir = os.path.join(DOCS_DIR, 'files', 'rdf')

    os.makedirs(api_items_dir, exist_ok=True)
    os.makedirs(api_sets_dir, exist_ok=True)
    os.makedirs(rdf_dir, exist_ok=True)

    # Run 001_convert_xlsx_to_rdf.py (generates api/items/ and files/rdf/items.rdf)
    # This script uses relative paths from scripts/ dir
    print('  Running 001_convert_xlsx_to_rdf.py...')
    result = subprocess.run(
        [sys.executable, '001_convert_xlsx_to_rdf.py'],
        capture_output=True, text=True, cwd=scripts_dir
    )
    if result.returncode != 0:
        print(f'    Error: {result.stderr[:500]}', file=sys.stderr)
        return False

    # Run 011_create_collection.py (generates api/item_sets/ and files/rdf/item_sets.rdf)
    print('  Running 011_create_collection.py...')
    result = subprocess.run(
        [sys.executable, '011_create_collection.py'],
        capture_output=True, text=True, cwd=scripts_dir
    )
    if result.returncode != 0:
        print(f'    Error: {result.stderr[:500]}', file=sys.stderr)
        return False

    items_count = len(os.listdir(api_items_dir))
    sets_count = len(os.listdir(api_sets_dir))
    print(f'  Generated {items_count} items, {sets_count} item_sets')
    return True


def replace_site_url():
    """Replace DEFAULT_SITE_URL with SITE_URL in docs/ static files."""
    if SITE_URL == DEFAULT_SITE_URL:
        return
    targets = [
        os.path.join(DOCS_DIR, 'index.html'),
        os.path.join(DOCS_DIR, 'index-en.html'),
        os.path.join(DOCS_DIR, 'waka.html'),
        os.path.join(DOCS_DIR, 'viz.html'),
        os.path.join(DOCS_DIR, 'stats.html'),
        os.path.join(DOCS_DIR, 'sitemap.xml'),
        os.path.join(DOCS_DIR, 'snorql', 'snorql_def.js'),
    ]
    for path in targets:
        if not os.path.exists(path):
            continue
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
        new_content = content.replace(DEFAULT_SITE_URL, SITE_URL)
        if new_content != content:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f'  {os.path.relpath(path, BASE_DIR)}')


def main():
    tasks = sys.argv[1:] if len(sys.argv) > 1 else ['tei', 'xsl', 'waka', 'stats', 'api', 'pdf', 'epub']

    print(f'=== SITE_URL: {SITE_URL} ===')

    if SITE_URL != DEFAULT_SITE_URL:
        print('=== Replacing site URL in static files ===')
        replace_site_url()

    if 'tei' in tasks:
        print('=== Building docs/tei/ ===')
        for ch in CHAPTERS:
            src = os.path.join(XML_LW_DIR, f'{ch}.xml')
            dst = os.path.join(DOCS_DIR, 'tei', f'{ch}.xml')
            if os.path.exists(src):
                build_tei(ch, src, dst)
                print(f'  {ch}.xml')



    if 'xsl' in tasks:
        print('=== Building docs/html/ (XSLT) ===')
        build_html()

    if 'waka' in tasks:
        print('=== Building docs/data/waka.json ===')
        count = build_waka_json()
        print(f'  {count} waka extracted')

    if 'stats' in tasks:
        print('=== Building docs/data/chapters.json ===')
        count = build_chapters_json()
        print(f'  {count} chapters extracted')

    if 'api' in tasks:
        print('=== Building docs/api/ ===')
        build_api()

    if 'pdf' in tasks:
        print('=== Building docs/pdf/ ===')
        for ch in CHAPTERS:
            ok = build_pdf(ch)
            status = 'ok' if ok else 'FAILED'
            print(f'  {ch}: {status}')

    if 'epub' in tasks:
        print('=== Building docs/epub/ ===')
        for ch in CHAPTERS:
            ok = build_epub(ch)
            status = 'ok' if ok else 'FAILED'
            print(f'  {ch}: {status}')

    print('\nDone.')


if __name__ == '__main__':
    main()
