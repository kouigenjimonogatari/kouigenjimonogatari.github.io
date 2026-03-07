#!/usr/bin/env python3
"""
Phase 2-1: 和歌 <lg>/<l> マークアップ追加
添付2のExcelから全795首の位置情報を取得し、Phase 1完了後の xml/master/ に
<lg type="waka" rhyme="tanka"><l n="1">...</l>...<l n="5">...</l></lg> を追加する。

和歌/散文の分割:
  - 各和歌行は「　　{歌テキスト}{散文}」の形式
  - 1文字 = 1モーラ（計画通り）
  - 　　の後の31文字が和歌、残りが散文
  - 31文字未満の行は、全体を和歌として扱う（短い和歌や行末和歌）

5句分割: [0:5], [5:12], [12:17], [17:24], [24:31]
"""

import os
import re
import sys
import openpyxl

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXCEL_DIR = os.path.join(BASE_DIR, 'tmp', 'fw')
XML_DIR = os.path.join(BASE_DIR, 'xml', 'master')

# 5-7-5-7-7 split positions (cumulative)
WAKA_SPLITS = [5, 12, 17, 24, 31]


def find_excel(keyword):
    for f in os.listdir(EXCEL_DIR):
        if keyword in f and f.endswith('.xlsx'):
            return os.path.join(EXCEL_DIR, f)
    raise FileNotFoundError(f'Excel file with "{keyword}" not found in {EXCEL_DIR}')


def parse_chapter(f_val):
    m = re.search(r'B(\d{2})', f_val)
    if m:
        return m.group(1)
    raise ValueError(f'Cannot parse chapter from: {f_val}')


def parse_page_line(g_val):
    m = re.search(r'P(\d+)-L(\d+)', g_val)
    if m:
        return m.group(1), m.group(2)
    raise ValueError(f'Cannot parse page-line from: {g_val}')


def load_all_waka_entries(excel_path):
    """Load ALL 795 waka entries from Attachment 2."""
    wb = openpyxl.load_workbook(excel_path, read_only=True)
    ws = wb.active
    entries = []
    for row in ws.iter_rows(min_row=2, values_only=True):
        if row[1] is None:  # column B: waka serial
            continue
        f_val = row[5]  # column F: chapter
        g_val = row[6]  # column G: page-line
        ch = parse_chapter(f_val)
        page, line = parse_page_line(g_val)
        entries.append({
            'chapter': ch,
            'page': page,
            'line': line,
            'corresp_key': f'{page}-{line}',
            'serial': row[1],
        })
    wb.close()
    return entries


def make_waka_markup(waka_text):
    """Create <lg>/<l> markup for waka text.

    The waka text is split into 5 lines of 5-7-5-7-7 characters.
    If the text has fewer than 31 characters, the last line gets whatever remains.
    """
    lines = []
    prev = 0
    for i, end in enumerate(WAKA_SPLITS):
        if prev >= len(waka_text):
            break
        actual_end = min(end, len(waka_text))
        line_text = waka_text[prev:actual_end]
        lines.append(f'<l n="{i+1}">{line_text}</l>')
        prev = actual_end

    return f'<lg type="waka" rhyme="tanka">{"".join(lines)}</lg>'


def apply_waka_markup_to_file(xml_path, entries):
    """Apply waka markup to seg lines in the XML file."""
    with open(xml_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    lookup = {}
    for e in entries:
        lookup[e['corresp_key']] = e

    modified_count = 0
    new_lines = []

    for line in lines:
        m = re.search(r'(<seg\s+corresp="[^"]*?/(\d{4}-\d{2})\.json">)(.*?)(</seg>)', line)
        if m:
            corresp_key = m.group(2)
            if corresp_key in lookup:
                seg_open = m.group(1)
                seg_text = m.group(3)
                seg_close = m.group(4)

                # The text should start with 2 full-width spaces (from Phase 1)
                if seg_text.startswith('\u3000\u3000'):
                    indent = '\u3000\u3000'
                    text_after_indent = seg_text[2:]
                else:
                    # Some lines may have had [既存] indent but the text might not start with spaces
                    # In practice after Phase 1, all waka lines should have the indent
                    indent = ''
                    text_after_indent = seg_text
                    print(f"  WARNING: No indent found for {corresp_key}", file=sys.stderr)

                # Split waka from prose at position 31
                waka_len = min(31, len(text_after_indent))
                waka_text = text_after_indent[:waka_len]
                prose_text = text_after_indent[waka_len:]

                # Generate markup
                markup = make_waka_markup(waka_text)

                # Reconstruct the seg content
                new_content = f'{indent}{markup}{prose_text}'
                new_seg = f'{seg_open}{new_content}{seg_close}'

                # Replace in the line
                old_seg = m.group(0)
                line = line.replace(old_seg, new_seg, 1)
                modified_count += 1
                del lookup[corresp_key]

        new_lines.append(line)

    if lookup:
        for key in lookup:
            print(f"  WARNING: unmatched waka entry {key}", file=sys.stderr)

    with open(xml_path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

    return modified_count


def main():
    excel_path = find_excel('添付２')
    print(f'Loading Attachment 2: {excel_path}')
    entries = load_all_waka_entries(excel_path)
    print(f'Loaded {len(entries)} waka entries (all 795)')

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
        count = apply_waka_markup_to_file(xml_path, by_chapter[ch])
        print(f'  {ch}.xml: {count} waka marked up')
        total_modified += count

    print(f'\nTotal: {total_modified} waka marked up (expected 795)')
    if total_modified != 795:
        print(f'WARNING: count mismatch! Expected 795, got {total_modified}', file=sys.stderr)


if __name__ == '__main__':
    main()
