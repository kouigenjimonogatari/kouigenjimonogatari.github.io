#!/usr/bin/env python3
"""
Phase 1-1: 和歌2字下げ修正
添付2のExcelから [補入] の649行を読み取り、xml/master/ の該当seg行に全角空白2文字を追加する。
"""

import os
import re
import sys
import openpyxl

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXCEL_DIR = os.path.join(BASE_DIR, 'tmp', 'fw')
XML_DIR = os.path.join(BASE_DIR, 'xml', 'master')


def find_excel(keyword):
    for f in os.listdir(EXCEL_DIR):
        if keyword in f and f.endswith('.xlsx'):
            return os.path.join(EXCEL_DIR, f)
    raise FileNotFoundError(f'Excel file with "{keyword}" not found in {EXCEL_DIR}')


def parse_chapter(f_val):
    """Extract chapter number from e.g. ［B01-桐壺※］ → '01'"""
    m = re.search(r'B(\d{2})', f_val)
    if m:
        return m.group(1)
    raise ValueError(f'Cannot parse chapter from: {f_val}')


def parse_page_line(g_val):
    """Extract page-line from e.g. ［P0009-L03］ → ('0009', '03')"""
    m = re.search(r'P(\d+)-L(\d+)', g_val)
    if m:
        return m.group(1), m.group(2)
    raise ValueError(f'Cannot parse page-line from: {g_val}')


def load_waka_indent_entries(excel_path):
    """Load entries from Attachment 2 that need indent insertion ([補入])."""
    wb = openpyxl.load_workbook(excel_path, read_only=True)
    ws = wb.active
    entries = []
    for row in ws.iter_rows(min_row=2, values_only=True):
        d_val = row[3]  # column D: 和歌２字下げ
        if d_val != '［補入］':
            continue
        f_val = row[5]  # column F: 巻数-巻表示
        g_val = row[6]  # column G: 頁数-行数
        h_val = row[7]  # column H: テキストDB (current)
        ch = parse_chapter(f_val)
        page, line = parse_page_line(g_val)
        entries.append({
            'chapter': ch,
            'page': page,
            'line': line,
            'current_text': h_val,
            'corresp_key': f'{page}-{line}',
        })
    wb.close()
    return entries


def apply_indent_to_file(xml_path, entries):
    """Apply 2-char full-width space indent to matching seg lines."""
    with open(xml_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # Build lookup: corresp_key → entry
    lookup = {}
    for e in entries:
        key = e['corresp_key']
        if key in lookup:
            print(f"  WARNING: duplicate key {key}", file=sys.stderr)
        lookup[key] = e

    modified_count = 0
    new_lines = []
    for line in lines:
        # Match seg lines with corresp attribute
        m = re.search(r'<seg\s+corresp="[^"]*?/(\d{4}-\d{2})\.json">(.*?)</seg>', line)
        if m:
            corresp_key = m.group(1)
            if corresp_key in lookup:
                entry = lookup[corresp_key]
                seg_text = m.group(2)
                # Verify the text doesn't already start with full-width spaces
                if seg_text.startswith('\u3000\u3000'):
                    print(f"  SKIP (already indented): {corresp_key}", file=sys.stderr)
                else:
                    # Insert 2 full-width spaces after <seg corresp="...">
                    old_part = f'>{seg_text}</seg>'
                    new_part = f'>\u3000\u3000{seg_text}</seg>'
                    line = line.replace(old_part, new_part, 1)
                    modified_count += 1
                del lookup[corresp_key]
        new_lines.append(line)

    if lookup:
        for key in lookup:
            print(f"  WARNING: unmatched entry {key}", file=sys.stderr)

    with open(xml_path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

    return modified_count


def main():
    excel_path = find_excel('添付２')
    print(f'Loading Attachment 2: {excel_path}')
    entries = load_waka_indent_entries(excel_path)
    print(f'Loaded {len(entries)} indent entries')

    # Group by chapter
    by_chapter = {}
    for e in entries:
        ch = e['chapter']
        by_chapter.setdefault(ch, []).append(e)

    total_modified = 0
    for ch in sorted(by_chapter.keys()):
        xml_path = os.path.join(XML_DIR, f'{ch}.xml')
        if not os.path.exists(xml_path):
            print(f'  ERROR: {xml_path} not found', file=sys.stderr)
            continue
        count = apply_indent_to_file(xml_path, by_chapter[ch])
        print(f'  {ch}.xml: {count} lines modified')
        total_modified += count

    print(f'\nTotal: {total_modified} lines modified (expected 649)')
    if total_modified != 649:
        print(f'WARNING: count mismatch! Expected 649, got {total_modified}', file=sys.stderr)


if __name__ == '__main__':
    main()
