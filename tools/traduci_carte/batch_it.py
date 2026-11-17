#!/usr/bin/env python3
"""Traduce in blocco le carte e le salva in web/img/it/ con lo stesso percorso dell'originale,
poi aggiorna data/carte_it.json (l'elenco che il gioco legge).

uso: python3 -I tools/traduci_carte/batch_it.py <cartella o file> [<cartella o file> ...]
     es.: ... batch_it.py tutorial_events m01 carte/g01/g01_9900.webp
"""
import glob, json, os, re, sys

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
opz = [a for a in sys.argv[1:] if a.startswith("--")]
scelte = [a for a in sys.argv[1:] if not a.startswith("--")]
salta = "--salta" in opz          # non rifà le carte già tradotte
parte = [a for a in opz if a.startswith("--parte=")]   # --parte=k/n: solo una fetta (lavori in parallelo)
k_parte, n_parte = (int(x) for x in parte[0].split("=")[1].split("/")) if parte else (0, 1)
tutte = "--tutte" in opz
dopo = [float(a.split("=")[1]) for a in opz if a.startswith("--dopo=")]   # salta i file rifatti dopo quest'ora
sys.argv = [sys.argv[0]]
import traduci_carta as T
from PIL import Image

def controllo(rel, png):
    """Parole inglesi della carta (che non compaiono nel testo italiano) ancora leggibili nel risultato."""
    c = T.carta(rel)
    en_p, it_p = set(), set()
    for en, it, _ in T.campi(c):
        en_p |= {T.norm(w) for w in re.sub(r"\[\w+\]", " ", en).split() if len(T.norm(w)) >= 4 and T.norm(w).isalpha()}
        it_p |= {T.norm(w) for w in re.sub(r"\[\w+\]", " ", it).split()}
    sospette = en_p - it_p
    img = Image.open(png).convert("RGB")
    img = img.resize((img.width // 2, img.height // 2), Image.LANCZOS)
    lette = T.parole(img)
    forti = {p["n"] for p in lette if p["c"] >= 80 and p["n"] in sospette}
    # pezzi di parole inglesi rimasti (es. "SHIP" di TOWNSHIP): presenti nel testo inglese, assenti dall'italiano
    tutto_en = " ".join(T.norm(w) for e, _, _ in T.campi(c) for w in e.split())
    tutto_it = " ".join(T.norm(w) for _, i, _ in T.campi(c) for w in i.split())
    import difflib
    nomi = " ".join(str(c.get("nome", "")).split() + [str(n) for n in c.get("nomi", [])] +
                    [w for e, i, _ in T.campi(c) if T.norm(e) == T.norm(i) for w in e.split()]).lower()
    tutto_it = tutto_it + " " + re.sub(r"[^a-z ]", "", nomi) + " ultrararo ultrarara"
    it_unito = re.sub(r"[^a-z]", "", tutto_it)
    parole_it = set(tutto_it.split())
    for p in T.parole(Image.open(png).convert("RGB")):
        t = re.sub(r"[^A-Za-z]", "", p["t"]).lower()
        if p["c"] >= 85 and len(t) >= 6 and t == T.norm(p["t"]) and t not in it_unito and t[:6] not in it_unito and \
                not any(difflib.SequenceMatcher(None, t, w).ratio() >= 0.7 for w in parole_it):
            forti.add(t)
            forti.add("·")
    for p in lette:
        t = re.sub(r"[^A-Za-z]", "", p["t"])
        if p["c"] >= 75 and len(t) >= 3 and t.isupper() and p["n"] in tutto_en and p["n"] not in tutto_it:
            forti.add(p["n"])
            forti.add("·")
    # anche un solo resto ben leggibile di 5+ lettere basta a scartare la carta
    if any(len(w) >= 5 for w in forti):
        forti.add("·")
    return sorted(forti)


lista = [r for r in sorted(T.DB["per_file"]) if tutte or r.split("/")[1] in scelte or r in scelte]
for n_, rel in enumerate(lista):
    if n_ % n_parte != k_parte:
        continue
    out = T.REPO + "/web/img/it/" + rel
    if salta and os.path.exists(out):
        continue
    if dopo and os.path.exists(out) and os.path.getmtime(out) > dopo[0]:
        continue
    rv = T.REPO + "/tools/traduci_carte/da_rivedere/" + rel.replace("/", "__")
    if dopo and os.path.exists(rv) and os.path.getmtime(rv) > dopo[0]:
        continue
    os.makedirs(os.path.dirname(out), exist_ok=True)
    try:
        tmp = "/tmp/carta_it_%d.png" % os.getpid()
        T.traduci(rel, tmp)
        resti = controllo(rel, tmp)
        motivi = (["parole inglesi: " + " ".join(resti[:6])] if len(resti) >= 2 else []) + \
                 (["non trovati: " + " | ".join(m[:25] for m in T.MANCANTI)] if T.MANCANTI else []) + T.PROBLEMI
        if motivi:
            # restano parole inglesi leggibili: la carta va rivista, intanto il gioco usa l'originale
            dest = T.REPO + "/tools/traduci_carte/da_rivedere/" + rel.replace("/", "__")
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            Image.open(tmp).convert("RGB").save(dest, "WEBP", quality=80)
            if os.path.exists(out):
                os.remove(out)
            print("RIVEDERE", rel, "·", " · ".join(motivi), flush=True)
            continue
        Image.open(tmp).convert("RGB").save(out, "WEBP", quality=86, method=6)
        print("ok", rel, flush=True)
    except Exception as e:
        print("ERRORE", rel, e, flush=True)

import ritocchi
ritocchi.main(solo=set(lista))
os.chdir(T.REPO + "/web/img/it")
elenco = sorted(glob.glob("carte/**/*.webp", recursive=True))
json.dump(elenco, open(T.REPO + "/data/carte_it.json", "w"), indent=0)
print(len(elenco), "carte italiane in elenco")
