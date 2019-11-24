import pandas as pd
from rdflib import URIRef, BNode, Literal, Graph
from rdflib.namespace import RDF, RDFS, FOAF, XSD
from rdflib import Namespace
import numpy as np
import math
import sys
import argparse
import json

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

for j in range(3, r_count):

    g = Graph()

    subject = df.iloc[j,0]

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
                g.add((subject, p, URIRef(value)))
            else:
                g.add((subject, p, Literal(value)))


    g.serialize(destination="../docs/data/"+id, format='json-ld')