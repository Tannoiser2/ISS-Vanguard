#!/usr/bin/env python3
"""Controlla che ogni carattere usato nelle stringhe del gioco (script, carte, Logbook) esista in uno dei
font in assets/font: quelli che mancano nel browser e su iPad compaiono come quadratini.
Uso: python3 tools/controlla_glifi.py   (serve fonttools e brotli)"""
import glob, json, re, sys
from fontTools.ttLib import TTFont

coperti = set()
for f in glob.glob("assets/font/*.woff2") + glob.glob("assets/font/*.ttf"):
    coperti |= set(TTFont(f).getBestCmap().keys())
mancanti = {}
for f in glob.glob("scripts/**/*.gd", recursive=True):
    for n, riga in enumerate(open(f, encoding="utf8"), 1):
        if riga.lstrip().startswith("#"):
            continue
        for stringa in re.findall(r'"((?:[^"\\]|\\.)*)"', riga):
            for c in stringa:
                if ord(c) > 127 and ord(c) not in coperti:
                    mancanti.setdefault(c, []).append("%s:%d" % (f, n))
for f in ["data/carte_db.json"] + glob.glob("data/logbook/c*.json"):
    testo = json.dumps(json.load(open(f, encoding="utf8")), ensure_ascii=False)
    for c in set(testo):
        if ord(c) > 127 and ord(c) not in coperti and c not in "​﻿":
            mancanti.setdefault(c, []).append(f)
for c, dove in sorted(mancanti.items()):
    print("MANCA %r U+%04X  %s" % (c, ord(c), ", ".join(dove[:4])))
print("glifi mancanti: %d" % len(mancanti))
sys.exit(1 if mancanti else 0)
