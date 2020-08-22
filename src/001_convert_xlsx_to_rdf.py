import pandas as pd
from rdflib import URIRef, BNode, Literal, Graph
from rdflib.namespace import RDF, RDFS, FOAF, XSD
from rdflib import Namespace
import numpy as np
import math
import sys
import argparse
import json
import urllib.parse

path = "data/metadata.xlsx"



df = pd.read_excel(path, sheet_name=0, header=None, index_col=None)

r_count = len(df.index)
c_count = len(df.columns)

map = {}

for i in range(1, c_count):
    label = df.iloc[0, i]
    uri = df.iloc[1, i]
    type = df.iloc[2, i]

    if not pd.isnull(type):
        obj = {}
        map[i] = obj
        obj["label"] = label
        obj["uri"] = uri
        obj["type"] = type

vols = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
11, 12 ,13, 14, 15, 16, 17, 18, 19, 20,
21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 
41, 42, 43, 44, 45,  46, 47, 48, 49, 50, 
51, 52, 53, 54]

import csv

itaiji = {}

all = Graph()

with open('check/data2/itaiji.csv', 'r') as f:
    reader = csv.reader(f)
    header = next(reader)

    for row in reader:
        key = row[1]
        text = row[2]
        elements = text.split("　")
        for e in elements:
            itaiji[e] = key

for j in range(3, r_count):

    g = Graph()

    subject = df.iloc[j,0]

    vol = df.iloc[j, 6]

    if pd.isnull(vol):
        continue
    
    vol = int(vol)

    if vol not in vols:
        continue

    print(subject)

    if pd.isnull(subject) or subject == "":
        continue

    id = subject.split("/")[-1]

    subject = URIRef(subject)
    for i in map:
        value = df.iloc[j,i]

        if not pd.isnull(value) and value != 0:

            obj = map[i]

            if pd.isnull(obj["uri"]):
                continue

            p = URIRef(obj["uri"])

            if obj["type"].upper() == "RESOURCE":
                g.add((subject, p, URIRef(value)))
                all.add((subject, p, URIRef(value)))
            else:

                if isinstance(value, str):
                    for key in itaiji:
                        value = value.replace(key, itaiji[key])

                g.add((subject, p, Literal(value)))
                all.add((subject, p, Literal(value)))


    g.serialize(destination="../api/items/"+id, format='json-ld')

all.serialize(destination="data/items.rdf", format='pretty-xml')