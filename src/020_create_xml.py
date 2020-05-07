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

def get_mdata(manifest):
    print(manifest)
    res = urllib.request.urlopen(manifest)
    # json_loads() でPythonオブジェクトに変換
    data = json.loads(res.read().decode('utf-8'))

    canvases = data["sequences"][0]["canvases"]
    
    map = {}

    for i in range(len(canvases)):
        canvas = canvases[i]
        canvas_id = canvas["@id"]
        width = canvas["width"]
        height = canvas["height"]
        url = canvas["images"][0]["resource"]["@id"]

        map[canvas_id] = {
            "width": width,
            "height": height,
            "url": url
        }


    return map

vols = [
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
    11, 12 ,13, 14, 15, 16, 17, 18, 19, 20,
    21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
    31, 32, 33, 
    # 34, 35, 36, 
    37, 38, 
    # 39, 
    40, 41, 42, 43, 
    # 44, 45, 46, 47, 48, 49, 50,
    # 51, 52, 53, 
    54
    ]

m_map = {}

for vol in vols:

    prefix = ".//{http://www.tei-c.org/ns/1.0}"
    xml = ".//{http://www.w3.org/XML/1998/namespace}"

    tmp_path = "data/template.xml"

    tree = ET.parse(tmp_path)
    ET.register_namespace('', "http://www.tei-c.org/ns/1.0")
    ET.register_namespace('xml', "http://www.w3.org/XML/1998/namespace")
    root = tree.getroot()

    para = root.find(prefix + "body").find(prefix + "p")

    files = glob.glob("../data/*.json")

    surfaceGrp = root.find(prefix+"surfaceGrp")
    

    with open("../vols/"+str(vol).zfill(2)+".json", 'r') as f:
        rdf_collection = json.load(f)
    
    manifest = rdf_collection[0]["http://purl.org/dc/terms/isPartOf"][0]["@id"]

    surfaceGrp.set("facs", manifest)

    if manifest not in m_map:
        m_map[manifest] = get_mdata(manifest)

    canvas_data = m_map[manifest]

    prev_page = -1

    canvas_map = {}

    for file in sorted(files):

        with open(file, 'r') as f:
            data = json.load(f)

            value = data[0]["http://www.w3.org/2000/01/rdf-schema#label"][0]["@value"]

            if "http://example.org/冊数名" not in data[0]:
                continue

            vol_ = data[0]["http://example.org/冊数名"][0]["@value"]

            if vol != vol_:
                continue

            title = data[0]["http://example.org/巻名"][0]["@value"]
            root.find(prefix + "title").text = "校異源氏物語・"+ title

            id = data[0]["@id"]

            page = data[0]["http://example.org/頁数"][0]["@value"]

            # 新しい頁
            if page != prev_page:
                prev_page = page

                lb = ET.Element(
                    "{http://www.tei-c.org/ns/1.0}lb")
                para.append(lb)

                pb = ET.Element(
                    "{http://www.tei-c.org/ns/1.0}pb")
                pb.set("n", str(page))
                pb.set("facs", "#zone_"+str(page).zfill(4))
                para.append(pb)

                relation = data[0]["http://purl.org/dc/terms/relation"][0]["@id"]
                relation = urllib.parse.unquote(relation)

                canvas_id = relation.split("%22canvas%22:%22")[1].split("%22}]")[0]

                obj = canvas_data[canvas_id]

                if canvas_id not in canvas_map:
                    canvas_map[canvas_id] = {
                        "url": obj["url"],
                        "zones": []
                    }

                if page % 2 == 0:
                    lrx = obj["width"]
                    ulx = int(lrx / 2)
                else:
                    lrx = int(obj["width"] / 2)
                    ulx = 0

                zone = ET.Element(
                    "{http://www.tei-c.org/ns/1.0}zone")
                zone.set("xml:id", "zone_"+str(page).zfill(4))
                zone.set("lrx", str(lrx))
                zone.set("lry", str(obj["height"]))
                zone.set("ulx", str(ulx))
                zone.set("uly", str(0))

                canvas_map[canvas_id]["zones"].append(zone)


            lb = ET.Element(
                    "{http://www.tei-c.org/ns/1.0}lb")
            para.append(lb)

            line = ET.Element(
                    "{http://www.tei-c.org/ns/1.0}seg")
            line.set("corresp", id)
            line.text = value
            # para.append(line)
            para.append(line)

    for canvas_id in canvas_map:

        obj = canvas_map[canvas_id]

        surface = ET.Element(
                    "{http://www.tei-c.org/ns/1.0}surface")
        surfaceGrp.append(surface)

        graphic = ET.Element(
                    "{http://www.tei-c.org/ns/1.0}graphic")
        graphic.set("n", canvas_id)
        graphic.set("url", obj["url"])
        surface.append(graphic)

        for zone in obj["zones"]:
            surface.append(zone)


    tree.write("../tei/"+str(vol).zfill(2)+".xml", encoding="utf-8")
