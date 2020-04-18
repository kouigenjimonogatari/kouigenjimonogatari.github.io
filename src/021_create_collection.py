import pandas as pd
from rdflib import URIRef, BNode, Literal, Graph
from rdflib.namespace import RDF, RDFS, FOAF, XSD
from rdflib import Namespace
import numpy as np
import math
import sys
import argparse
import json
import glob

files = glob.glob("../data/*.json")

files = sorted(files)

result = {}

for file in files:
    with open(file) as f:
        df = json.load(f)
        data = df[0]
        vol = data["http://example.org/冊数名"][0]["@value"]

        if vol not in result:
            result[vol] = {
                "@id" : "https://w3id.org/kouigenjimonogatari/vols/"+str(vol).zfill(2)+".json",
                "http://example.org/作品名" : data["http://example.org/作品名"],
                "http://example.org/巻名" : data["http://example.org/巻名"],
                "http://purl.org/dc/terms/isPartOf" : data["http://purl.org/dc/terms/isPartOf"],
                "http://purl.org/dc/terms/relation" : data["http://purl.org/dc/terms/relation"],
                "http://purl.org/dc/terms/rights" : data["http://purl.org/dc/terms/rights"],
                "http://example.org/data" : []
            }

        result[vol]["http://example.org/data"].append(data)

for vol in result:
    data = result[vol]

    f2 = open("../vols/"+str(vol).zfill(2)+".json", 'w')
    json.dump([data], f2, ensure_ascii=False, indent=4,
        sort_keys=True, separators=(',', ': '))