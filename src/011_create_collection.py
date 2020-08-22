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

all = Graph()

checks = []

for j in range(3, r_count):

    g = Graph()

    subject = df.iloc[j,15]

    if subject in checks:
        continue

    if pd.isnull(subject):
        continue

    id = subject.split("/")[-1]

    subject = URIRef(subject)
    

    checks.append(subject)

    label = df.iloc[j,5]

    if pd.isnull(label):
        continue

    if len(label.split(" ")) == 2:
        label = label.split(" ")[1]

    label = Literal(label)

    g.add((subject, URIRef("http://www.w3.org/2000/01/rdf-schema#label"), label))

    vol = df.iloc[j, 6]
    vol = Literal(vol)
    g.add((subject, URIRef("https://w3id.org/kouigenjimonogatari/api/property/vol"), vol))

    manifest = df.iloc[j, 13]
    manifest = URIRef(manifest)
    g.add((subject, URIRef("http://www.w3.org/2000/01/rdf-schema#seeAlso"), manifest))

    g.add((subject, URIRef("http://purl.org/dc/terms/rights"), URIRef("http://creativecommons.org/publicdomain/zero/1.0/")))

    g.add((subject, URIRef("http://purl.org/dc/terms/relation"), Literal("https://w3id.org/kouigenjimonogatari/tei/"+id.replace("json", "xml"))))

    opath = "../api/item-sets/"+id

    g.serialize(destination=opath, format='json-ld')

    checks.append(subject)

    all.parse(opath, format='json-ld')

    print("vol", vol)

all.serialize(destination="data/item-sets.rdf", format='pretty-xml')