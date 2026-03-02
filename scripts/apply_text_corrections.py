#!/usr/bin/env python3
"""
Phase 1-2: 文字符号修正
添付3のExcelから115件の修正ペア（テキストDB / 修正私案本文）を読み取り、
xml/master/ の該当seg行のテキストを置換する。

注意: 和歌行修正（column B = ［和歌行修正］）の場合、修正私案本文に全角空白2文字が
含まれている。Phase 1-1で和歌2字下げが既に適用済みのため、この空白を考慮して照合する。
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


def parse_chapter(g_val):
    """Extract chapter number from e.g. ［B01-桐壺※］ → '01'"""
    m = re.search(r'B(\d{2})', g_val)
    if m:
        return m.group(1)
    raise ValueError(f'Cannot parse chapter from: {g_val}')


def parse_page_line(h_val):
    """Extract page-line from e.g. ［P0009-L08］ → ('0009', '08')"""
    m = re.search(r'P(\d+)-L(\d+)', h_val)
    if m:
        return m.group(1), m.group(2)
    raise ValueError(f'Cannot parse page-line from: {h_val}')


def load_corrections(excel_path):
    """Load correction pairs from Attachment 3."""
    wb = openpyxl.load_workbook(excel_path, read_only=True)
    ws = wb.active

    rows_data = []
    for row in ws.iter_rows(min_row=2, values_only=True):
        rows_data.append(row)
    wb.close()

    corrections = []
    i = 0
    while i < len(rows_data):
        row = rows_data[i]
        i_val = row[8]  # column I: 対象項目
        if i_val == '《テキストＤＢ》':
            # Next row should be 修正私案本文
            if i + 1 < len(rows_data) and rows_data[i + 1][8] == '《修正私案本文》':
                fix_row = rows_data[i + 1]
                g_val = row[6]  # column G: chapter
                h_val = row[7]  # column H: page-line
                j_db = row[9]   # column J: current text
                j_fix = fix_row[9]  # column J: corrected text
                is_waka = row[1] and '和歌行修正' in str(row[1])

                ch = parse_chapter(g_val)
                page, line = parse_page_line(h_val)

                corrections.append({
                    'chapter': ch,
                    'page': page,
                    'line': line,
                    'corresp_key': f'{page}-{line}',
                    'current_text': j_db,
                    'fix_text': j_fix,
                    'is_waka': is_waka,
                    'seq': row[0],  # H-number
                })
        i += 1

    return corrections


def extract_seg_text(line):
    """Extract text content from a <seg> line, excluding XML tags."""
    m = re.search(r'<seg\s+corresp="[^"]*">(.*?)</seg>', line)
    if m:
        # Remove any inline XML tags to get plain text
        text = m.group(1)
        # For now, the text should not have sub-elements (Phase 2 adds them later)
        return text
    return None


def apply_corrections_to_file(xml_path, corrections):
    """Apply text corrections to matching seg lines in the XML file."""
    with open(xml_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    lookup = {}
    for c in corrections:
        key = c['corresp_key']
        lookup[key] = c

    modified_count = 0
    warnings = []
    new_lines = []

    for line in lines:
        m = re.search(r'<seg\s+corresp="([^"]*?/(\d{4}-\d{2})\.json)">(.*?)</seg>', line)
        if m:
            corresp_key = m.group(2)
            if corresp_key in lookup:
                corr = lookup[corresp_key]
                current_seg_text = m.group(3)
                expected_current = corr['current_text']
                fix_text = corr['fix_text']

                # Phase 1-1 may have already added indent, so current seg text
                # may start with \u3000\u3000 while Excel's テキストDB doesn't
                current_for_compare = current_seg_text
                if current_seg_text.startswith('\u3000\u3000') and not expected_current.startswith('\u3000\u3000'):
                    current_for_compare = current_seg_text[2:]

                if current_for_compare == expected_current:
                    # Apply the fix
                    # If the fix text has indent and current already has it, don't double
                    if current_seg_text.startswith('\u3000\u3000') and fix_text.startswith('\u3000\u3000'):
                        new_text = fix_text
                    elif current_seg_text.startswith('\u3000\u3000') and not fix_text.startswith('\u3000\u3000'):
                        # Keep the indent from Phase 1-1
                        new_text = '\u3000\u3000' + fix_text
                    else:
                        new_text = fix_text

                    old_part = f'>{current_seg_text}</seg>'
                    new_part = f'>{new_text}</seg>'
                    line = line.replace(old_part, new_part, 1)
                    modified_count += 1
                else:
                    warnings.append(
                        f'  MISMATCH {corr["seq"]} ({corresp_key}): '
                        f'expected={repr(expected_current)}, '
                        f'found={repr(current_for_compare)}'
                    )
                del lookup[corresp_key]
        new_lines.append(line)

    for key in lookup:
        warnings.append(f'  UNMATCHED: {key} ({lookup[key]["seq"]})')

    if warnings:
        for w in warnings:
            print(w, file=sys.stderr)

    with open(xml_path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

    return modified_count, len(warnings)


def main():
    excel_path = find_excel('添付３')
    print(f'Loading Attachment 3: {excel_path}')
    corrections = load_corrections(excel_path)
    print(f'Loaded {len(corrections)} correction entries')

    # Group by chapter
    by_chapter = {}
    for c in corrections:
        ch = c['chapter']
        by_chapter.setdefault(ch, []).append(c)

    total_modified = 0
    total_warnings = 0
    for ch in sorted(by_chapter.keys()):
        xml_path = os.path.join(XML_DIR, f'{ch}.xml')
        if not os.path.exists(xml_path):
            print(f'  ERROR: {xml_path} not found', file=sys.stderr)
            continue
        count, warns = apply_corrections_to_file(xml_path, by_chapter[ch])
        if count > 0 or warns > 0:
            print(f'  {ch}.xml: {count} corrected, {warns} warnings')
        total_modified += count
        total_warnings += warns

    print(f'\nTotal: {total_modified} corrections applied (expected 115)')
    if total_warnings > 0:
        print(f'Warnings: {total_warnings}', file=sys.stderr)
    if total_modified != 115:
        print(f'WARNING: count mismatch! Expected 115, got {total_modified}', file=sys.stderr)


if __name__ == '__main__':
    main()
