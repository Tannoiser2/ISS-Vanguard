#!/usr/bin/env python3
"""Traduce in blocco le carte e le salva in web/img/it/ con lo stesso percorso dell'originale,
poi aggiorna data/carte_it.json (l'elenco che il gioco legge).

uso: python3 -I tools/traduci_carte/batch_it.py <cartella o file> [<cartella o file> ...]
     es.: ... batch_it.py tutorial_events m01 carte/g01/g01_9900.webp
"""
import glob, json, os, sys

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
scelte = sys.argv[1:]
sys.argv = [sys.argv[0]]
import traduci_carta as T
from PIL import Image

for rel in sorted(T.DB["per_file"]):
    if rel.split("/")[1] not in scelte and rel not in scelte:
        continue
    out = T.REPO + "/web/img/it/" + rel
    os.makedirs(os.path.dirname(out), exist_ok=True)
    try:
        T.traduci(rel, "/tmp/carta_it.png")
        Image.open("/tmp/carta_it.png").convert("RGB").save(out, "WEBP", quality=86, method=6)
        print("ok", rel, flush=True)
    except Exception as e:
        print("ERRORE", rel, e, flush=True)

os.chdir(T.REPO + "/web/img/it")
elenco = sorted(glob.glob("carte/**/*.webp", recursive=True))
json.dump(elenco, open(T.REPO + "/data/carte_it.json", "w"), indent=0)
print(len(elenco), "carte italiane in elenco")
