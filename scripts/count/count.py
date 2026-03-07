import sys
import urllib
import json
import argparse
import urllib.request
import unicodedata
import collections
import os
import xml.etree.ElementTree as ET
import csv
import glob
import urllib.parse

files = glob.glob("../../api/items/*.json")

pages = []
total = 0

for file in sorted(files):

    with open(file, 'r') as f:
        data = json.load(f)[0]
        
        # print(data)

        id = data["@id"]

        page = int(id.split("/")[-1].split("-")[0])

        text = data["http://www.w3.org/2000/01/rdf-schema#label"][0]["@value"]

        size = len(text)

        total += size

        if page not in pages:
            pages.append(page)

print("pages", len(pages))
print("total words", total)