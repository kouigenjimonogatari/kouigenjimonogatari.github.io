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
31, 32, 33, 
34, 35, 36, 
37, 38, 
# 39, 
40, 41, 42, 43, 
44, 45,  
# 46, 47, 48, 49, 50, 51, 52, 53, 
54]

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
            p = URIRef(obj["uri"])

            if obj["type"].upper() == "RESOURCE":

                if "http://purl.org/dc/terms/relation" == obj["uri"]:
                    tmp = value.split("?params=")
                    value = tmp[0] + "?params=" + urllib.parse.quote(tmp[1])

                g.add((subject, p, URIRef(value)))
            else:
                g.add((subject, p, Literal(value)))


    g.serialize(destination="../data/"+id, format='json-ld')