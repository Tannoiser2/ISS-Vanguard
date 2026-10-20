#!/usr/bin/env python3
"""Unisce le trascrizioni delle carte (data/carte/*.json, una per lotto) in un unico archivio
data/carte_db.json letto dal gioco.

- per_file: percorso relativo dell'immagine (come in data/componenti.json, es. "carte/missioni/m102_18700.webp")
  -> voce della carta, con "categoria" (pdi, eventi, condizioni, missioni, minacce, reparto, equipaggio,
  attrezzatura, ferite_gradi, lander, scoperte, atterraggio, componenti)
- per_id: codice stampato (P107, G23, M02…) -> elenco di percorsi
- pianeti: nome dello stato nel modulo TTS (p.18-19…) -> plancia

Normalizza anche le azioni speciali: liste sempre presenti, requisiti come stringhe.
"""
import json, os, glob, re, sys

PRJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEB = os.path.join(PRJ, "web", "img") + "/"

def testo(x):
    if isinstance(x, dict):
        return {"en": str(x.get("en", "") or ""), "it": str(x.get("it", "") or x.get("en", "") or "")}
    if isinstance(x, str):
        return {"en": x, "it": x}
    return {"en": "", "it": ""}

def norm_req(r):
    if r is None:
        return ""
    if isinstance(r, list):
        return " / ".join("+".join(a) if isinstance(a, list) else str(a) for a in r)
    return str(r).replace("[", "").replace("]", "").strip()

COL = {"gialla": "yellow", "giallo": "yellow", "rossa": "red", "rosso": "red", "verde": "green"}
_COLRX = r"(gialla|giallo|rossa|rosso|verde)"
_RX_FRECCE = [
    re.compile(r"(?:dalla|dal|dall')\s*(?:riga |traccia |risultato |esito )?" + _COLRX + r".{0,25}?(?:verso|alla|al|a quello|collega alla)\s+(?:la |il |quello )?(?:riga |traccia |risultato )?(?:sottostante )?" + _COLRX),
    re.compile(r"(?:riga|traccia|risultato) " + _COLRX + r" (?:ha una freccia verso|è collegat\w+ al|la collega alla) (?:la |il )?(?:riga |traccia )?" + _COLRX),
    re.compile(r"riga " + _COLRX + r" la collega alla riga " + _COLRX),
]
_RX_FRA = re.compile(r"fra la riga " + _COLRX + r" e la riga " + _COLRX + r", che punta verso la " + _COLRX)

def frecce(f):
    """Collegamenti fra Risultati descritti nel campo 'frecce': [(da, a)]. Regola: risolto il Risultato
    da cui parte la freccia, si risolve anche quello a cui punta (Regolamento pag. 17)."""
    f = str(f or "")
    out = []
    m = _RX_FRA.search(f)
    if m:
        a, b, dove = COL[m.group(1)], COL[m.group(2)], COL[m.group(3)]
        out.append((a if dove == b else b, dove))
    for rx in _RX_FRECCE:
        for m in rx.finditer(f):
            c = (COL[m.group(1)], COL[m.group(2)])
            if c[0] != c[1] and c not in out:
                out.append(c)
    return out

def norm_azione(a):
    if not isinstance(a, dict):
        return None
    out = dict(a)
    out["nome"] = testo(a.get("nome", ""))
    out["pericolo"] = [str(p).strip("[]") for p in (a.get("pericolo") or [])]
    out["prova"] = bool(a.get("prova", bool(a.get("esiti") or a.get("tracce") or a.get("speciali"))))
    sp = []
    for r in a.get("speciali") or []:
        if not isinstance(r, dict):
            continue
        e = r.get("effetto", "")
        if isinstance(e, str):
            e = e.strip("[] ")
        sp.append({"req": norm_req(r.get("req", "")), "effetto": e})
    out["speciali"] = sp
    es = []
    for r in a.get("esiti") or []:
        if not isinstance(r, dict):
            continue
        t = testo(r)
        es.append({"colore": str(r.get("colore", "") or ""), "req": norm_req(r.get("req", "")),
                   "en": t["en"], "it": t["it"], "segue": str(r.get("segue", "") or "")})
    out["esiti"] = es
    tr = []
    for r in a.get("tracce") or []:
        if not isinstance(r, dict):
            continue
        t = testo(r)
        tr.append({"colore": str(r.get("colore", "") or ""), "caselle": int(r.get("caselle", 1) or 1),
                   "en": t["en"], "it": t["it"]})
    out["tracce"] = tr
    # frecce fra i Risultati: completano i "segue" mancanti
    for da, verso in frecce(a.get("frecce", "")):
        for r in es:
            if r["colore"] == da and not r["segue"]:
                r["segue"] = verso
        for r in tr:
            if r["colore"] == da and not r.get("segue"):
                r["segue"] = verso
    return out

def norm_azioni(lista):
    return [x for x in (norm_azione(a) for a in (lista or [])) if x]

def rel(f):
    f = str(f or "")
    if f.startswith(WEB):
        return f[len(WEB):]
    return f

db = {"per_file": {}, "per_id": {}, "pianeti": {}}
# nomi degli stati del Planetopedia dai lotti (le trascrizioni hanno solo il file)
nomi_pianeti = {}
for lp in glob.glob(os.path.join(PRJ, "tools", "trascrizione", "lotti", "pianeta_*.json")):
    for it in json.load(open(lp))["immagini"]:
        nomi_pianeti[it["file"]] = it["nomi"]
for p in sorted(glob.glob(os.path.join(PRJ, "data", "carte", "*.json"))):
    cat = re.sub(r"_\d+$", "", os.path.splitext(os.path.basename(p))[0])
    try:
        dati = json.load(open(p, encoding="utf-8"))
    except Exception as e:
        print("JSON NON VALIDO", p, e)
        continue
    carte = dati.get("carte", dati if isinstance(dati, list) else [])
    for c in carte:
        if not isinstance(c, dict):
            continue
        c["categoria"] = cat
        for k in ("azioni",):
            if k in c:
                c[k] = norm_azioni(c[k])
        if isinstance(c.get("viaggio"), dict):
            c["viaggio"] = norm_azione(c["viaggio"])
        if cat == "pianeta":
            for st in c.get("settori", []) or []:
                if isinstance(st.get("stampato"), dict):
                    st["stampato"]["azioni"] = norm_azioni(st["stampato"].get("azioni"))
                    if isinstance(st["stampato"].get("viaggio"), dict):
                        st["stampato"]["viaggio"] = norm_azione(st["stampato"]["viaggio"])
                for k in ("condizione_stampata",):
                    if isinstance(st.get(k), dict):
                        st[k]["azioni"] = norm_azioni(st[k].get("azioni"))
                        if isinstance(st[k].get("viaggio"), dict):
                            st[k]["viaggio"] = norm_azione(st[k]["viaggio"])
            cd = c.get("colonna_destra") or {}
            if isinstance(cd.get("condizione"), dict):
                cd["condizione"]["azioni"] = norm_azioni(cd["condizione"].get("azioni"))
                if isinstance(cd["condizione"].get("viaggio"), dict):
                    cd["condizione"]["viaggio"] = norm_azione(cd["condizione"]["viaggio"])
            nomi = c.get("nomi") or nomi_pianeti.get(c.get("file", ""), [])
            for n in nomi:
                db["pianeti"][n] = c
            continue
        r = rel(c.get("file", ""))
        c["file"] = r
        db["per_file"][r] = c
        cid = str(c.get("id", "") or (c.get("campi") or {}).get("id", "") or "").upper()
        if cid:
            db["per_id"].setdefault(cid, []).append(r)
        for n in c.get("nomi", []) or []:
            if re.match(r"^[A-Z]\d{2,3}$", str(n)):
                if r not in db["per_id"].setdefault(str(n).upper(), []):
                    db["per_id"][str(n).upper()].append(r)

# copie di ogni carta nei mazzi del modulo (le carte Reparto hanno doppioni)
from collections import Counter as _C
copie = _C()
def _giro(o):
    for c in o.get("carte", []) or []:
        if c.get("fronte"): copie[c["fronte"]] += 1
    if o.get("fronte") and o.get("tipo") in ("Card", "CardCustom"): copie[o["fronte"]] += 1
    for k in ("contenuto", "stati"):
        for x in o.get(k, []) or []: _giro(x)
for o in json.load(open(os.path.join(PRJ, "data", "componenti.json")))["oggetti"]:
    _giro(o)
for r, c in db["per_file"].items():
    c["copie"] = copie.get(r, 1)

out = os.path.join(PRJ, "data", "carte_db.json")
json.dump(db, open(out, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
from collections import Counter
print(out, os.path.getsize(out) // 1024, "KB")
print(Counter(c["categoria"] for c in db["per_file"].values()), "pianeti:", len(db["pianeti"]))
