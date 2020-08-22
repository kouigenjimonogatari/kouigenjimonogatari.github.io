import bs4
import requests
from urllib.parse import urljoin
import uuid
import json
import pandas as pd
import openpyxl

df = pd.read_excel('../data/metadata.xlsx', index_col=None, sheet_name=None)

map = {}

itaiji = []

import csv

with open('data2/itaiji.csv', 'r') as f:
    reader = csv.reader(f)
    header = next(reader)

    for row in reader:
        key = row[1]
        text = row[2]
        elements = text.split("　")
        for e in elements:
            itaiji.append(e)

rows = []

rows.append(["巻", "ID", "check", "テキスト"])

for sheet_name in df:
    print(sheet_name)

    table = df[sheet_name]

    for i in range(4, len(table.index)):
        line = table.loc[i, "title"]
        # print(page)

        if pd.isnull(line):
            continue

        print(i, line)

        line = str(line)

        arr = []

        if "(" in line:
            arr.append("(")

        if ")" in line:
            arr.append(")")

        if "々" in line:
            arr.append("々")

        for e in itaiji:
            if e in line:
                arr.append(e)

        if len(arr) > 0:

            vol = table.loc[i, "冊数名"]

            row = [
                vol,
                table.iloc[i, 0], arr, line
            ]
        

            rows.append(row)


df = pd.DataFrame(rows)

# convert from pandas data to excel
writer = pd.ExcelWriter('data2/check.xlsx', options={'strings_to_urls':False})
df.to_excel(writer,index=False, header=False)
writer.close()
