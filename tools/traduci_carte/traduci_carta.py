#!/usr/bin/env python3
"""Prova: ricompone una carta di ISS Vanguard in italiano sopra la grafica originale.

1. trova sull'immagine le righe di testo inglese (OCR su più versioni dell'immagine);
2. le abbina ai campi dei dati della carta (titolo, testo di colore, esiti...);
3. cancella il testo inglese ricostruendo lo sfondo;
4. scrive il testo italiano nello stesso spazio, con le icone del gioco nel testo.

uso: traduci_carta.py <id o file della carta> <uscita.png>
"""
import json, re, sys, os, difflib
import numpy as np, cv2, pytesseract
from PIL import Image, ImageDraw, ImageFont

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../.."))
QUI = os.path.dirname(os.path.abspath(__file__))
DB = json.load(open(REPO + "/data/carte_db.json"))
ICONE = json.load(open(REPO + "/data/logbook/icone.json"))
SCALA = 3          # ingrandimento per l'OCR e per scrivere il testo (poi si riduce: bordi morbidi)

F = {
    "titolo": QUI + "/font/orbitron-latin-700-normal.ttf",
    "testo": QUI + "/font/exo-2-latin-400-normal.ttf",
    "grassetto": QUI + "/font/exo-2-latin-700-normal.ttf",
    "corsivo": QUI + "/font/exo-2-latin-400-italic.ttf",
}
# riquadri fissi per categoria (frazioni della carta), usati quando l'OCR non riesce a leggere
MODELLI = {"reparto": {"titolo": (0.47, 0.25, 0.52, 0.22, "d")},
           "pdi": {"titolo": (0.01, 0.015, 0.63, 0.075, "s")},
           "minacce": {"titolo": (0.01, 0.0, 0.6, 0.045, "s")}}
# riquadri misurati a mano (frazioni della carta) dove l'OCR sbaglia; la chiave è il file o la cartella,
# poi "titolo" o l'inizio del testo inglese: (x, y, w, h, allineamento s/c/d, righe, chiaro)
CORREZIONI = json.load(open(QUI + "/correzioni.json")) if os.path.exists(QUI + "/correzioni.json") else {}
ETICHETTE = {"OBJECTIVE:": "OBIETTIVO:", "HINT:": "SUGGERIMENTO:", "COMPLETION:": "COMPLETAMENTO:"}


def carta(chiave):
    if chiave in DB["per_file"]:
        return DB["per_file"][chiave]
    return DB["per_file"][DB["per_id"][chiave][0]]


def norm(w):
    return re.sub(r"[^a-z0-9]", "", w.lower().replace("’", "'"))


# ------------------------------------------------------------------ campi da tradurre

def campi(c):
    """[(en, it, stile)] di tutti i testi stampati sulla carta: ogni oggetto {en, it} dei dati, ovunque sia;
    lo stile dipende dal nome del campo."""
    out = []
    etich = {"obiettivo": "OBJECTIVE:", "suggerimento": "HINT:", "completamento": "COMPLETION:"}

    def giro(o, chiave, in_azione):
        if isinstance(o, list):
            for v in o:
                giro(v, chiave, in_azione)
            return
        if not isinstance(o, dict):
            return
        en, it = o.get("en"), o.get("it", "")
        if isinstance(en, str) and en.strip() and isinstance(it, str) and it.strip():
            if chiave == "obiettivo" and c.get("veterano"):
                pass   # l'obiettivo dei Veterani è stampato sul retro
            elif chiave in etich:
                out.append((etich[chiave] + " " + en, ETICHETTE[etich[chiave]] + " " + it, "etichetta"))
            elif chiave == "regole":
                for e1, i1 in zip(en.split("\n"), it.split("\n")):
                    out.append((e1, i1, "prefisso"))
            elif chiave == "titolo" or (chiave == "nome" and in_azione):
                out.append((en, it, "titolo"))
            elif chiave == "testo_colore":
                out.append((en, it, "corsivo"))
            elif chiave == "tempo" and in_azione == "lista_tempo":
                out.append((en, it, "piccolo"))
            elif chiave == "obiettivo" and c.get("veterano"):
                pass   # l'obiettivo dei Veterani è stampato sul retro
            elif chiave in ("effetto", "testo", "abilita"):
                en = re.split(r"\s*Rank requirement:", en)[0]
                it = re.split(r"\s*Requisito di grado:", it)[0]
                out.append((en, it, "prefisso"))
            else:
                out.append((en, it, "testo"))
        for k, v in o.items():
            if k in ("en", "it", "campi"):
                continue
            giro(v, k, in_azione or k in ("azioni", "viaggio"))
    for k, v in c.items():
        if k == "tempo" and isinstance(v, list):
            giro(v, "tempo", "lista_tempo")
        elif k not in ("campi",):
            giro(v, k, k in ("azioni", "viaggio"))
    # etichette stampate che nei dati non hanno un testo {en, it}
    CONCEDE = {"Equipment": "Attrezzatura", "Lander Mod": "Modifica del Lander", "Lander Mods": "Modifiche del Lander",
               "Bridge Upgrade": "Potenziamento del Ponte", "Production Project": "Progetto di Produzione",
               "Production Projects": "Progetti di Produzione", "Facility Upgrade": "Potenziamento della Struttura",
               "Research Project": "Progetto di Ricerca", "Research Projects": "Progetti di Ricerca", "Lander": "Lander",
               "Story Log": "Annotazione della Storia", "Lander Upgrade": "Potenziamento del Lander", "[success]": "[success]"}
    if c.get("concede"):
        out.append(("GRANTS:", "CONCEDE:", "etichetta"))
        out.append((", ".join(c["concede"]), ", ".join(CONCEDE.get(x, x) for x in c["concede"]), "testo"))
    ABILITA = {"ADAPTIVE": "ADATTABILE", "ADVISOR": "CONSIGLIERE", "ALERTNESS": "ALLERTA", "ALPHA": "ALFA",
               "BRUTE FORCE": "FORZA BRUTA", "CAREFUL": "PRUDENTE", "COMPETENT": "COMPETENTE", "DISCIPLINED": "DISCIPLINATO",
               "EFFICIENT": "EFFICIENTE", "ENDURANCE": "RESISTENZA", "ENERGETIC": "ENERGICO", "FOLLOWER": "GREGARIO",
               "FORECAST": "PREVISIONE", "FORTITUDE": "TEMPRA", "GRIT": "GRINTA", "HERMIT": "EREMITA",
               "HIDDEN RESERVES": "RISERVE NASCOSTE", "INSIGHT": "INTUITO", "LOADER": "CARICATORE", "METHODICAL": "METODICO",
               "PROTECTOR": "PROTETTORE", "RECKLESS": "SPERICOLATO", "RECORD KEEPER": "ARCHIVISTA", "SEARCHER": "CERCATORE",
               "SELFLESS": "ALTRUISTA", "SOLDIER": "SOLDATO", "STORYTELLER": "NARRATORE", "SYSTEMATIC": "SISTEMATICO",
               "TEAM PLAYER": "GIOCO DI SQUADRA", "TRUMP CARD": "ASSO NELLA MANICA", "UNBREAKABLE": "INDISTRUTTIBILE",
               "WELL-TRAINED": "BEN ADDESTRATO", "WILD CARD": "JOLLY"}
    abil = c.get("abilita")
    for a_ in (abil if isinstance(abil, list) else [abil]):
        if isinstance(a_, dict) and isinstance(a_.get("nome"), str) and a_["nome"] in ABILITA:
            out.append((a_["nome"], ABILITA[a_["nome"]], "grassetto"))
    tipo = c.get("tipo", "")
    # codice della Missione stampato dopo il titolo: "MISSION: X (M32)"
    if c.get("categoria") == "missioni" and c.get("id") and isinstance(c.get("titolo"), dict):
        for k_, x in enumerate(out):
            if x[0] == c["titolo"]["en"]:
                out[k_] = (x[0] + " (%s)" % c["id"], x[1] + " (%s)" % c["id"], x[2])
    TIPI = {"lander_mod": ("LANDER MOD", "MODIFICA DEL LANDER"), "medbay_upgrade": ("MEDBAY UPGRADE", "POTENZIAMENTO DELL'INFERMERIA"),
            "production_upgrade": ("PRODUCTION UPGRADE", "POTENZIAMENTO DELLA PRODUZIONE"),
            "bridge_upgrade": ("BRIDGE UPGRADE", "POTENZIAMENTO DEL PONTE"), "bridge_upgrade_travel": ("BRIDGE UPGRADE", "POTENZIAMENTO DEL PONTE")}
    if tipo in TIPI:
        out.append(TIPI[tipo] + ("etichetta",))
    camp = c.get("campi") if isinstance(c.get("campi"), dict) else {}
    MODIF = {"structural": ("STRUCTURAL", "STRUTTURALE"), "utility": ("UTILITY", "UTILITÀ")}
    if tipo == "lander_mod" and camp.get("modifica") in MODIF:
        out.append(MODIF[camp["modifica"]] + ("etichetta",))
    if tipo == "production_project":
        out += [("BOOST:", "POTENZIAMENTO:", "etichetta"), ("PRODUCTION PROJECT", "PROGETTO DI PRODUZIONE", "etichetta"),
                ("ANY ICON", "QUALSIASI ICONA", "etichetta")]
        if c.get("stadio_iniziale") not in (None, ""):
            out.append(("STARTING STAGE: %s" % c["stadio_iniziale"], "FASE INIZIALE: %s" % c["stadio_iniziale"], "etichetta"))
    if tipo == "research_project":
        out.append(("RESEARCH PROJECT", "PROGETTO DI RICERCA", "etichetta"))
        if isinstance(c.get("costo"), dict):
            out.append(("COST: " + c["costo"]["en"], "COSTO: " + c["costo"].get("it", ""), "etichetta"))
    cat_scoperta = (c.get("campi") or {}).get("categoria") if isinstance(c.get("campi"), dict) else None
    ETIC_SCOP = {"alien_tech": ("ALIEN TECH", "TECNOLOGIA ALIENA"), "strange_flora": ("STRANGE FLORA", "STRANA VEGETAZIONE"),
                 "live_specimen": ("LIVE SPECIMEN", "ESEMPLARE VIVO"), "mineral": ("MINERAL", "MINERALE"),
                 "microorganism": ("MICROORGANISM", "MICRORGANISMO")}
    if tipo == "discovery" and cat_scoperta in ETIC_SCOP:
        out.append(ETIC_SCOP[cat_scoperta] + ("titolo",))
    # etichette stampate comuni, se nessun altro testo le contiene già
    GENERICHE = [("OPTIONAL MISSION", "MISSIONE OPZIONALE"), ("OBJECTIVE", "OBIETTIVO"), ("EFFECT", "EFFETTO"),
                 ("SOLVED", "RISOLTA"), ("UTILITY", "UTILITÀ"), ("STRUCTURAL", "STRUTTURALE")]
    gia = " ".join(x[0].upper() for x in out)
    for en_, it_ in GENERICHE:
        if en_ not in gia:
            out.append((en_, it_, "etichetta"))
    visti, finali = set(), []
    for x in out:
        if x[0].strip() and x[1].strip() and x[0] not in visti:
            visti.add(x[0])
            finali.append(x)
    # i pezzi già contenuti in un testo più lungo (es. le due scelte di "A - OPPURE - B") si scrivono con quello
    def nudo(t):
        return re.sub(r"\W+", " ", re.sub(r"\[\w+\]", " ", t)).strip().lower()
    return [x for x in finali if x[2] in ("titolo", "etichetta") or not any(y is not x and len(nudo(y[0])) > len(nudo(x[0])) and nudo(x[0]) and nudo(x[0]) in nudo(y[0]) for y in finali)]


# ------------------------------------------------------------------ OCR

def parole(img):
    """Parole riconosciute (su più versioni dell'immagine), coordinate nell'immagine ingrandita."""
    big = img.resize((img.width * SCALA, img.height * SCALA), Image.LANCZOS)
    g = np.array(big.convert("L"))
    versioni = [big, Image.fromarray(255 - g)]
    _, th = cv2.threshold(g, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    versioni += [Image.fromarray(255 - th), Image.fromarray(th)]
    tutte = []
    for v in versioni:
        for psm in ("11", "6"):
            d = pytesseract.image_to_data(v, lang="eng", output_type=pytesseract.Output.DICT, config="--psm " + psm)
            for i, w in enumerate(d["text"]):
                if w.strip() and float(d["conf"][i]) > 35 and norm(w):
                    box = (d["left"][i], d["top"][i], d["width"][i], d["height"][i])
                    if box[3] > 0.25 * big.height:
                        continue
                    tutte.append({"t": w, "n": norm(w), "b": box, "c": float(d["conf"][i])})
    # via i doppioni (stessa parola nello stesso posto)
    uniche = []
    for p in sorted(tutte, key=lambda p: -p["c"]):
        if not any(_sovrap(p["b"], q["b"]) > 0.5 for q in uniche):
            uniche.append(p)
    return uniche


def _sovrap(a, b):
    x1, y1 = max(a[0], b[0]), max(a[1], b[1])
    x2, y2 = min(a[0] + a[2], b[0] + b[2]), min(a[1] + a[3], b[1] + b[3])
    if x2 <= x1 or y2 <= y1:
        return 0.0
    return (x2 - x1) * (y2 - y1) / min(a[2] * a[3], b[2] * b[3])


def ordine_lettura(ps):
    """Indici delle parole in ordine di lettura (righe dall'alto, poi da sinistra)."""
    idx = sorted(range(len(ps)), key=lambda i: ps[i]["b"][1] + ps[i]["b"][3] / 2)
    righe = []
    for i in idx:
        b = ps[i]["b"]
        cy = b[1] + b[3] / 2
        if righe and abs(cy - righe[-1][0]) < 0.6 * max(b[3], righe[-1][1]):
            righe[-1][2].append(i)
        else:
            righe.append([cy, b[3], [i]])
    out = []
    for r in righe:
        out += sorted(r[2], key=lambda i: ps[i]["b"][0])
    return out


def trova_blocco(en, ps, usate):
    """Parole dell'immagine che formano il testo inglese 'en': il tratto (in ordine di lettura) che
    corrisponde meglio alla sequenza delle sue parole."""
    toks = [norm(w) for w in re.sub(r"\[\w+\]", " ", en).split() if norm(w)]
    if not toks:
        return None
    seq = [i for i in ordine_lettura(ps) if i not in usate]
    parole_seq = [ps[i]["n"] for i in seq]
    migliore, punti = None, 0
    n = len(toks)
    for a in range(len(seq)):
        if not (parole_seq[a] == toks[0] or difflib.SequenceMatcher(None, parole_seq[a], toks[0]).ratio() > 0.75
                or parole_seq[a] in toks[:3]):
            continue
        for lung in (n - 2, n - 1, n, n + 1, n + 2, n + 4):
            if lung < 1 or a + lung > len(seq):
                continue
            sm = difflib.SequenceMatcher(None, parole_seq[a:a + lung], toks, autojunk=False)
            r = sum(bl.size for bl in sm.get_matching_blocks()) / max(n, lung)
            if r > punti:
                punti, migliore = r, seq[a:a + lung]
    if migliore is None or punti < 0.5:
        return None
    # restano solo le parole che corrispondono davvero (non i segni letti nelle icone)...
    tset = set(toks)
    buone = [i for i in migliore if ps[i]["n"] in tset or (len(ps[i]["n"]) > 3 and any(difflib.SequenceMatcher(None, ps[i]["n"], t).ratio() > 0.8 for t in tset))]
    # ...e non isolate: lontane da tutte le altre della stessa riga
    tenute = []
    for i in buone:
        b = ps[i]["b"]
        vicine = [j for j in buone if j != i and abs((ps[j]["b"][1] + ps[j]["b"][3] / 2) - (b[1] + b[3] / 2)) < b[3]]
        if len(buone) <= 2 or not vicine or min(max(0, max(b[0], ps[j]["b"][0]) - min(b[0] + b[2], ps[j]["b"][0] + ps[j]["b"][2])) for j in vicine) < 3 * b[3]:
            tenute.append(i)
    return tenute or None


def trova_sfumato(en, ps, usate):
    """Ripiego quando la sequenza non si trova: le parole lette che somigliano alle parole del testo,
    raggruppate per vicinanza; si prende il gruppo che ne copre di più."""
    toks = [norm(w) for w in re.sub(r"\[\w+\]", " ", en).split() if len(norm(w)) >= 3]
    if not toks:
        return None
    cand = []
    for i, p in enumerate(ps):
        if i in usate or p["c"] < 50 or len(p["n"]) < 2:
            continue
        for t in toks:
            if p["n"] == t or (len(p["n"]) >= 3 and difflib.SequenceMatcher(None, p["n"], t).ratio() >= 0.75) or (len(p["n"]) >= 4 and p["n"] in t):
                cand.append((i, t))
                break
    if not cand:
        return None
    # gruppi: parole a meno di due righe una dall'altra
    gruppi = []
    for i, t in cand:
        b = ps[i]["b"]
        messo = None
        for gr in gruppi:
            for j, _ in gr:
                bb = ps[j]["b"]
                h = max(b[3], bb[3])
                vic_v = abs((b[1] + b[3] / 2) - (bb[1] + bb[3] / 2)) < 2.2 * h
                vic_o = b[0] < bb[0] + bb[2] + 6 * h and bb[0] < b[0] + b[2] + 6 * h
                if vic_v and vic_o:
                    messo = gr
                    break
            if messo:
                break
        if messo:
            messo.append((i, t))
        else:
            gruppi.append([(i, t)])
    migliore = max(gruppi, key=lambda gr: len({t for _, t in gr}))
    coperti = len({t for _, t in migliore})
    if coperti < max(1 if len(toks) <= 2 else 2, int(0.4 * len(toks) + 0.5)):
        return None
    return [i for i, _ in migliore]


# ------------------------------------------------------------------ cancellazione e scrittura

def colori(arr, box):
    """Colore del testo e dello sfondo dentro un riquadro."""
    x, y, w, h = box
    reg = arr[y:y + h, x:x + w].reshape(-1, 3).astype(float)
    bordo = np.concatenate([arr[y:y + h, max(0, x - 3)], arr[y:y + h, min(arr.shape[1] - 1, x + w + 2)],
                            arr[max(0, y - 3), x:x + w], arr[min(arr.shape[0] - 1, y + h + 2), x:x + w]]).astype(float)
    fondo = np.median(bordo, axis=0)
    dist = np.linalg.norm(reg - fondo, axis=1)
    sel = reg[dist >= np.percentile(dist, 85)]
    testo = np.median(sel, axis=0) if len(sel) else reg.mean(axis=0)
    return testo, fondo, float(np.std(bordo))


def cancella(arr, box, testo, fondo, tutto, icone=False, oltre=0, limite=None):
    x, y, w, h = box
    if icone and oltre:
        # un'icona alla fine di una riga può sporgere oltre il riquadro trovato
        x1 = min(arr.shape[1], x + w + oltre, limite if limite else arr.shape[1])
        reg2 = arr[y:y + h, x + w:x1].astype(float)
        if reg2.size:
            sat2 = (reg2.max(axis=2) - reg2.min(axis=2) > 70) & (reg2.max(axis=2) > 100)
            cols = np.where(sat2.sum(axis=0) > 2)[0]
            if len(cols):
                w = int(cols.max()) + 1 + w + 4
    box = (x, y, w, h)
    reg = arr[y:y + h, x:x + w].astype(float)
    colorati = None
    if icone:
        # le icone dei dadi e dei simboli colorati nel testo: si tolgono anche quelle (si riscrivono)
        sat = reg.max(axis=2) - reg.min(axis=2)
        colorati = (sat > 70) & (reg.max(axis=2) > 100)
    contrasto = max(30.0, float(np.linalg.norm(testo - fondo)))
    if tutto:
        # fondo uniforme: si toglie tutto quello che non è fondo (anche le icone, che si riscrivono)
        m = np.linalg.norm(reg - fondo, axis=2) > 22
    else:
        # anche i bordi sfumati delle lettere: tutto ciò che va dal fondo verso il colore del testo
        verso = (reg - fondo) @ ((testo - fondo) / contrasto)
        m = verso > 0.2 * contrasto
    mask = np.zeros(arr.shape[:2], np.uint8)
    if colorati is not None and np.linalg.norm(fondo - np.array([fondo.mean()] * 3)) < 40:
        m = m | colorati
    mask[y:y + h, x:x + w] = (m * 255).astype(np.uint8)
    mask = cv2.dilate(mask, np.ones((3, 3), np.uint8), iterations=5)
    out = cv2.inpaint(arr, mask, 7, cv2.INPAINT_TELEA)
    if tutto:
        # sul fondo uniforme una leggera sfocatura della zona ricostruita toglie le ultime tracce
        sf = cv2.GaussianBlur(out, (0, 0), 6)
        m3 = cv2.GaussianBlur(mask, (0, 0), 4)[..., None] / 255.0
        out = (out * (1 - m3) + sf * m3).astype(np.uint8)
    return out


def icona(nome, h, chiara):
    if nome not in ICONE:
        return None
    p = REPO + "/assets/app/%s/%d.webp" % ("icone_chiare" if chiara and os.path.exists(REPO + "/assets/app/icone_chiare/%d.webp" % int(ICONE[nome])) else "icone", int(ICONE[nome]))
    im = Image.open(p).convert("RGBA")
    return im.resize((max(1, int(im.width * h / im.height)), h), Image.LANCZOS)


def pezzi(testo, stile):
    """Il testo diviso in parole [(testo, font_chiave)] e icone [("[icona]", None)]; il prefisso prima dei
    due punti va in grassetto."""
    out = []
    grassetto_fino = -1
    if stile in ("etichetta", "prefisso"):
        m = re.match(r"^([^:]{2,40}:)", testo)
        if m:
            grassetto_fino = len(m.group(1))
    pos = 0
    for tok in re.findall(r"\[\w+\]|[^\s\[]+", testo):
        i = testo.find(tok, pos)
        pos = i + len(tok)
        if tok.startswith("[") and tok.endswith("]"):
            out.append((tok, None))
        else:
            k = {"titolo": "titolo", "corsivo": "corsivo", "grassetto": "grassetto"}.get(stile, "testo")
            if i < grassetto_fino or (re.match(r"^Annotazion[ei]$", tok) or re.match(r"^\d+[.,]?$", tok) and re.search(r"Annotazion[ei]\s+$", testo[:i])):
                k = "grassetto"
            out.append((tok, k))
    return out


def impagina(pz, size, larg):
    righe, riga, x = [], [], 0
    fonts = {k: ImageFont.truetype(v, size) for k, v in F.items()}
    sp = fonts["testo"].getlength(" ")
    for tok, k in pz:
        w = (size * 1.15 if k is None else fonts[k].getlength(tok))
        if riga and x + sp + w > larg:
            righe.append(riga)
            riga, x = [], 0
        riga.append((tok, k, w))
        x += (sp if len(riga) > 1 else 0) + w
    if riga:
        righe.append(riga)
    if len(righe) > 1 and len(righe[-1]) == 1 and len(righe[-1][0][0]) <= 4 and len(righe[-2]) > 2:
        righe[-1].insert(0, righe[-2].pop())
    return righe, fonts, sp


# il carattere del corpo dell'originale è più stretto di Exo 2: si stringe un poco in orizzontale
STRETTO = {"titolo": 1.0}
def stretto(stile):
    return STRETTO.get(stile, 0.9)


def adatta(it, stile, w, h, n_righe_orig, corpo, passo, extra_x=0, extra_y=0):
    """Corpo e impaginazione: si parte dal corpo dell'originale; prima si stringe l'interlinea, poi si
    usa lo spazio libero intorno, e solo alla fine si riduce il corpo."""
    pz = pezzi(it, stile)
    il0 = max(1.08, passo / corpo) if n_righe_orig > 1 else 1.22
    size = int(corpo)
    while size > 8:
        for il in (il0, min(il0, 1.12), min(il0, 1.05)):
            prove = [(w, h), (w + extra_x, h)]
            if stile == "corsivo" and size > corpo * 0.85:
                prove.append((w + extra_x, h + extra_y))
            for ww, hh in prove:
                righe, fonts, sp = impagina(pz, size, ww / stretto(stile))
                alto = (len(righe) - 1) * size * il + size * 1.1
                if alto <= hh * 0.97 and (stile != "titolo" or len(righe) <= max(1, n_righe_orig)) and all(sum(t[2] for t in r) + sp * (len(r) - 1) <= ww / stretto(stile) * 1.01 for r in righe):
                    return size, il, righe, fonts, sp, ww, hh
        size -= 1
    return size, 1.12, righe, fonts, sp, w, h


def scrivi(img, box, it, stile, col, centrato, n_righe_orig, alto_riga, destra=False, corpo=None, passo=None, extra_x=0, extra_y=0, adattato=None):
    x, y, w, h = box
    if corpo is None:
        corpo, passo = alto_riga * 1.2, alto_riga * 1.5
    if stile != "titolo" and not adattato:
        m_ = alto_riga * 0.25
        x, w = x + m_, w - 2 * m_
    size, il, righe, fonts, sp, w, h = adattato or adatta(it, stile, w, h, n_righe_orig, corpo, passo, extra_x, extra_y)
    cx = stretto(stile)
    dest = img
    if cx < 1:
        img = Image.new("RGBA", (int(dest.width / cx), dest.height), (0, 0, 0, 0))
        x, w = x / cx, w / cx
    d = ImageDraw.Draw(img)
    alto = (len(righe) - 1) * size * il + size * 1.1
    yy = y + (h - alto) / 2 if alto <= h or n_righe_orig <= 1 else box[1] + size * 0.05
    chiara = sum(col) / 3 > 128
    y_ini = yy
    for r in righe:
        lw = sum(t[2] for t in r) + sp * (len(r) - 1)
        xx = x + (w - lw) / 2 if centrato else (x + w - lw if destra else x)
        for tok, k, tw in r:
            if k is None:
                ic = icona(tok[1:-1], int(size * 1.1), chiara)
                if ic:
                    img.paste(ic, (int(xx), int(yy + size * 0.1)), ic)
            else:
                bordo = max(1, size // 14) if stile == "titolo" and sum(col) / 3 > 160 else 0
                d.text((xx, yy + size * 0.05), tok, font=fonts[k], fill=tuple(int(c) for c in col), stroke_width=bordo, stroke_fill=(20, 22, 30))
            xx += tw + sp
        yy += size * il
    if cx < 1:
        livello = img.resize(dest.size, Image.LANCZOS)
        dest.paste(livello, (0, 0), livello)
    larghe = max((sum(t[2] for t in r) + sp * (len(r) - 1)) for r in righe) * cx
    xa_ = (x * cx + (w * cx - larghe) / 2) if centrato else ((x + w) * cx - larghe if destra else x * cx)
    return (xa_, y_ini, xa_ + larghe, y_ini + alto)


MANCANTI = []      # campi dell'ultima carta non trovati sull'immagine
PROBLEMI = []      # altri segnali di qualità dell'ultima carta


def traduci(chiave, uscita, debug=False):
    MANCANTI.clear()
    PROBLEMI.clear()
    c = carta(chiave)
    src = Image.open(REPO + "/web/img/" + c["file"]).convert("RGB")
    ps = parole(src)
    big = np.array(src.resize((src.width * SCALA, src.height * SCALA), Image.LANCZOS))
    usate = set()
    blocchi = []
    maiuscole = {norm(p["t"]) for p in ps if re.sub(r"[^A-Za-z]", "", p["t"]).isupper() and p["c"] >= 60}
    gen = {"OPTIONAL MISSION", "OBJECTIVE", "EFFECT", "SOLVED", "UTILITY", "STRUCTURAL"}
    for en, it, stile in sorted(campi(c), key=lambda x: -len(x[0])):
        if en in gen and norm(en.split()[-1]) not in maiuscole:
            continue
        corr = None
        for chiave in (c["file"], c["file"].split("/")[1]):
            for k_, v_ in CORREZIONI.get(chiave, {}).items():
                if (k_ == "titolo" and en == (c.get("titolo") or {}).get("en")) or (k_ != "titolo" and en.startswith(k_)):
                    corr = v_
            if corr:
                break
        if corr:
            H, W = big.shape[:2]
            fx, fy, fw, fh, all_, nr, chiaro = corr[:7]
            if len(corr) > 7:
                it = corr[7]
            box = (int(fx * W), int(fy * H), int(fw * W), int(fh * H))
            passo = box[3] / nr
            corpo = passo * (0.78 if stile == "titolo" else 0.74)
            azione = stile == "titolo" and en != (c.get("titolo") or {}).get("en")
            blocchi.append({"en": en, "it": it, "stile": stile, "box": box, "alto": passo * 0.62, "righe": nr,
                            "centrato": all_ == "c", "destra": all_ == "d", "chiaro": bool(chiaro), "corpo": corpo, "passo": passo,
                            "extra_x": 0, "extra_y": 0, "azione": azione, "fisso": True})
            # le parole OCR dentro il riquadro non servono più ad altri blocchi
            for i, p in enumerate(ps):
                b = p["b"]
                if box[0] <= b[0] + b[2] / 2 <= box[0] + box[2] and box[1] <= b[1] + b[3] / 2 <= box[1] + box[3]:
                    usate.add(i)
            continue
        g = trova_blocco(en, ps, usate)
        if g is None:
            g = trova_sfumato(en, ps, usate)
        if g is None and stile == "titolo" and en == c["titolo"]["en"] and c.get("categoria") in MODELLI:
            fx, fy, fw, fh, all_ = MODELLI[c["categoria"]]["titolo"]
            H, W = big.shape[:2]
            box = (int(fx * W), int(fy * H), int(fw * W), int(fh * H))
            nr = 2 if fh > 0.15 else 1
            blocchi.append({"en": en, "it": it, "stile": stile, "box": box, "alto": box[3] / (2.2 if nr == 2 else 1.3), "righe": nr,
                            "centrato": all_ == "c", "destra": all_ == "d", "chiaro": True, "corpo": box[3] / nr * 0.8, "passo": box[3] / nr,
                            "extra_x": 0, "extra_y": 0, "fisso": True})
            continue
        if g is None:
            print("  non trovato:", en[:60])
            # conta solo se il testo è davvero stampato su questo lato della carta (le sue parole si leggono)
            parole_en = [norm(w) for w in re.sub(r"\[\w+\]", " ", en).split() if len(norm(w)) >= 4]
            lette = [p["n"] for p in ps if p["c"] >= 60 and len(p["n"]) >= 3]
            presenti = sum(1 for w in parole_en if any(difflib.SequenceMatcher(None, w, l).ratio() >= 0.75 or (len(l) >= 4 and l in w) for l in lette))
            if parole_en and presenti >= min(2, len(parole_en)):
                MANCANTI.append(en)
            continue
        usate |= set(g)
        xs = [ps[i]["b"] for i in g]
        x0, y0 = min(b[0] for b in xs), min(b[1] for b in xs)
        x1, y1 = max(b[0] + b[2] for b in xs), max(b[1] + b[3] for b in xs)
        # le parole della stessa riga che l'OCR non ha abbinato (icone, parole storpiate) stanno nel blocco
        for i, p in sorted(enumerate(ps), key=lambda ip: ip[1]["b"][0]) * 2:
            b = p["b"]
            if i in usate or b[1] + b[3] / 2 < y0 or b[1] + b[3] / 2 > y1:
                continue
            if any(b[0] < bb[0] + bb[2] and bb[0] < b[0] + b[2] and b[1] < bb[1] + bb[3] and bb[1] < b[1] + b[3] for bb in xs):
                continue
            simile = len(p["n"]) >= 4 and any(difflib.SequenceMatcher(None, p["n"], t).ratio() > 0.7 for t in [norm(w) for w in en.split()])
            if (p["c"] >= 70 or simile) and len(p["n"]) >= 2 and re.match(r"^[A-Za-z]", p["t"]) and b[0] < x1 + 1.2 * b[3] and b[0] + b[2] > x0 - 1.2 * b[3] and b[3] < 1.6 * max(bb[3] for bb in xs):
                x0, x1 = min(x0, b[0]), max(x1, b[0] + b[2])
                usate.add(i)
                g = g + [i]
        alto_riga = float(np.median([b[3] for b in xs]))
        coda = re.search(r"((?:\s*\+?\s*\[\w+\])+)\W*$", en)
        if coda:
            n_ic = coda.group(1).count("[")
            ult = max(xs, key=lambda b: b[0] + b[2])
            x1 = min(big.shape[1], int(x1 + n_ic * 1.45 * ult[3] + 0.3 * ult[3]))
        # parole che l'OCR non ha letto affatto (es. il primo di due parole di un titolo): si allarga il
        # riquadro di quanto mancano, dal lato dove mancano
        toks = [norm(w) for w in re.sub(r"\[\w+\]", " ", en).split() if norm(w)]
        lette = [ps[i]["n"] for i in g]
        xs = [ps[i]["b"] for i in g]
        if len(set(lette)) < len(toks) and (y1 - y0) < alto_riga * 1.6:
            fnt = ImageFont.truetype(F["titolo" if stile == "titolo" else "testo"], 40)
            parole_en = re.sub(r"\[\w+\]", " ", en).split()
            idx = [k for k, w in enumerate(parole_en) if norm(w) in lette]
            if idx:
                letto = fnt.getlength(" ".join(parole_en[idx[0]:idx[-1] + 1]))
                k = 0.85 * (x1 - x0) / max(1.0, letto)
                x0 = max(0, int(x0 - k * fnt.getlength(" ".join(parole_en[:idx[0]]) + " ") * (1 if idx[0] > 0 else 0)))
                x1 = min(big.shape[1], int(x1 + k * fnt.getlength(" " + " ".join(parole_en[idx[-1] + 1:])) * (1 if idx[-1] < len(parole_en) - 1 else 0)))
        righe_y = sorted(set(round((b[1] + b[3] / 2) / (alto_riga * 0.8)) for b in xs))
        # resti di parole che l'OCR ha letto a metà: si segue l'inchiostro a destra e a sinistra
        gr = big[y0:y1].mean(axis=2)
        fb = float(np.median(gr[:, x0:x1]))
        fascia = big[y0:y1].astype(int)
        neutro = (fascia.max(axis=2) - fascia.min(axis=2)) < 60
        ink = ((np.abs(gr - fb) > 90) & neutro).sum(axis=0) >= 2
        # una cornice colorata ferma la ricerca
        med = np.median(fascia[:, x0:x1].reshape(-1, 3), axis=0)
        muro = ((~neutro) & (np.abs(fascia - med).sum(axis=2) > 160)).sum(axis=0) > (y1 - y0) * 0.3
        muro |= ((np.abs(gr - fb) > 90).sum(axis=0) > (y1 - y0) * 0.55)
        n_tok = len([w for w in re.sub(r"\[\w+\]", " ", en).split() if norm(w)])
        manca_parola = len(set(ps[i]["n"] for i in g)) < n_tok
        lim_vuoto = alto_riga * (0.7 if manca_parola or stile == "titolo" else 0.4)
        vuoto = 0
        xx = x1
        v0 = vuoto
        while xx < big.shape[1] - 1 and vuoto < lim_vuoto and not muro[xx + 1]:
            xx += 1
            if ink[xx]:
                x1, vuoto = xx + 1, 0
            else:
                vuoto += 1
        vuoto, xx = v0, x0
        while xx > 0 and vuoto < (lim_vuoto if (manca_parola or stile == "titolo") else 0) and not muro[xx - 1]:
            xx -= 1
            if ink[xx]:
                x0, vuoto = xx, 0
            else:
                vuoto += 1
        pad = int(alto_riga * 0.25)
        box = (max(0, x0 - pad), max(0, y0 - pad), min(big.shape[1], x1 + pad) - max(0, x0 - pad), min(big.shape[0], y1 + pad) - max(0, y0 - pad))
        # centrato se i centri delle righe sono allineati più dei bordi sinistri
        righe_b = []
        for b in sorted(xs, key=lambda b: b[1] + b[3] / 2):
            cy = b[1] + b[3] / 2
            if righe_b and abs(cy - righe_b[-1][0]) < alto_riga * 0.6:
                righe_b[-1][1].append(b)
            else:
                righe_b.append([cy, [b]])
        per_riga = {k: r[1] for k, r in enumerate(righe_b)}
        sx = [min(b[0] for b in r) for r in per_riga.values()]
        cx = [(min(b[0] for b in r) + max(b[0] + b[2] for b in r)) / 2 for r in per_riga.values()]
        if len(per_riga) > 1:
            rientrate = sum(1 for v in sx if v - min(sx) > alto_riga * 0.5)
            centrato = np.std(sx) > alto_riga * 0.4 and np.std(cx) < np.std(sx) * 0.6 and rientrate >= len(sx) / 2
        else:
            centrato = abs((x0 + x1) / 2 - big.shape[1] / 2) < big.shape[1] * 0.06
        fk = {"titolo": "titolo", "corsivo": "corsivo"}.get(stile, "testo")
        f100 = ImageFont.truetype(F[fk], 100)
        rapp = []
        for i in g:
            t = re.sub(r"[^A-Za-z]", "", ps[i]["t"])
            if len(t) >= 2:
                bb = f100.getbbox(t)
                if stile == "titolo":
                    rapp.append((ps[i]["b"][2] * 100.0 / max(1.0, f100.getlength(t)) * ps[i]["b"][3] * 100.0 / max(1, bb[3] - bb[1])) ** 0.5)
                else:
                    rapp.append(ps[i]["b"][3] * 100.0 / max(1, bb[3] - bb[1]))
        corpo = (float(np.median(rapp)) if rapp else alto_riga * 1.2) * (1.0 if stile == "titolo" else 0.94)
        passo = float(np.median(np.diff([r[0] for r in righe_b]))) if len(righe_b) > 1 else corpo * 1.22
        # spazio libero intorno (fondo uniforme) in cui il testo italiano, più lungo, può allargarsi
        grigio = big.mean(axis=2)
        def unif(y_a, y_b, x_a, x_b):
            y_a, y_b, x_a, x_b = max(0, y_a), min(big.shape[0], y_b), max(0, x_a), min(big.shape[1], x_b)
            if not (y_b > y_a and x_b > x_a):
                return False
            z = grigio[y_a:y_b, x_a:x_b]
            return z.std() < 24 and abs(float(np.median(z)) - fondo_box) < 22 and z.max() < fondo_box + 70
        bx, by, bw, bh = box
        fondo_box = float(np.median(grigio[by:by + bh, bx:bx + bw]))
        dx = 0
        passo_x = max(4, int(alto_riga * 0.3))
        while not (stile == "titolo" and centrato) and dx < bw * 0.9 and unif(by, by + bh, bx + bw + dx, bx + bw + dx + passo_x):
            dx += passo_x
        dy = 0
        while dy < bh * 0.4 and unif(by + bh + dy, by + bh + dy + passo_x, bx, bx + bw) and (centrato or True):
            dy += passo_x
        blocchi.append({"en": en, "it": it, "stile": stile, "box": box, "alto": alto_riga, "righe": len(per_riga), "centrato": centrato,
                        "corpo": corpo, "passo": passo, "extra_x": dx, "extra_y": dy, "azione": stile == "titolo" and en != (c.get("titolo") or {}).get("en")})
    for _giro in range(3):
        for i, p in enumerate(ps):
            if i in usate or p["c"] < 70 or not re.match(r"^[A-Za-z0-9]", p["t"]) or len(re.sub(r"\W", "", p["t"])) < 2:
                continue
            b = p["b"]
            maiusc = re.sub(r"\W", "", p["t"]).isalpha() and re.sub(r"\W", "", p["t"]).isupper() and len(re.sub(r"\W", "", p["t"])) >= 3
            if any(b[0] < o["box"][0] + o["box"][2] and o["box"][0] < b[0] + b[2] and b[1] < o["box"][1] + o["box"][3] and o["box"][1] < b[1] + b[3] for o in blocchi):
                continue
            for bl in blocchi:
                if bl.get("chiaro") or bl.get("azione") or bl.get("fisso") or bl["stile"] == "titolo":
                    continue
                if maiusc and not (bl["en"].isupper() and norm(p["t"]) in [norm(w) for w in bl["en"].split()]):
                    continue
                x, y, w, h = bl["box"]
                al = bl["alto"]
                if not (0.6 * al < b[3] < 1.5 * al):
                    continue
                vicino_v = (y - 1.3 * al < b[1] + b[3] < y + 0.2 * al) or (y + h - 0.2 * al < b[1] < y + h + 1.0 * al)
                dentro_o = b[0] > x - 2 * al and b[0] + b[2] < x + w + 2 * al
                if vicino_v and dentro_o:
                    nx0, ny0 = min(x, b[0] - int(al * 0.25)), min(y, b[1] - int(al * 0.25))
                    nx1, ny1 = max(x + w, b[0] + b[2] + int(al * 0.25)), max(y + h, b[1] + b[3] + int(al * 0.25))
                    bl["box"] = (nx0, ny0, nx1 - nx0, ny1 - ny0)
                    bl["righe"] = max(bl["righe"], int(round((ny1 - ny0) / max(1.0, bl["passo"]))))
                    usate.add(i)
                    break
    # Equipaggio e Veterani: il testo in basso non deve coprire il riquadro delle Cariche a destra
    if c.get("categoria") in ("equipaggio", "veterani"):
        H_, W_ = big.shape[:2]
        for b_ in blocchi:
            x_, y_, w_, h_ = b_["box"]
            if y_ + h_ > H_ * 0.82 and x_ + w_ > W_ * 0.71:
                b_["box"] = (x_, y_, int(W_ * 0.71) - x_, h_)
                b_["extra_x"] = 0
    # riquadri che si sovrappongono in verticale: si dividono a metà della sovrapposizione
    for a_ in blocchi:
        for b_ in blocchi:
            if a_ is b_ or a_.get("chiaro") or b_.get("chiaro"):
                continue
            ax, ay, aw, ah = a_["box"]
            bx_, by_, bw_, bh_ = b_["box"]
            if ay < by_ < ay + ah < by_ + bh_ and ax < bx_ + bw_ and bx_ < ax + aw:
                m_ = (by_ + ay + ah) // 2
                a_["box"] = (ax, ay, aw, m_ - ay)
                b_["box"] = (bx_, m_, bw_, by_ + bh_ - m_)
    # prima si cancella tutto, poi si scrive
    for b in blocchi:
        if b.get("chiaro"):
            # lettere chiare con il bordo scuro: si tolgono i pixel chiari e il loro contorno
            x, y, w, h = b["box"]
            reg = big[y:y + h, x:x + w].astype(float)
            m = (reg.mean(axis=2) > 185).astype(np.uint8) * 255
            mask = np.zeros(big.shape[:2], np.uint8)
            mask[y:y + h, x:x + w] = m
            mask = cv2.dilate(mask, np.ones((3, 3), np.uint8), iterations=7)
            big = cv2.inpaint(big, mask, 9, cv2.INPAINT_TELEA)
            b["col"] = np.array([240.0, 240.0, 240.0])
            continue
        testo, fondo, var = colori(big, b["box"])
        b["col"] = testo
        lim = int(big.shape[1] * 0.71) if c.get("categoria") in ("equipaggio", "veterani") else None
        big = cancella(big, b["box"], testo, fondo, tutto=var < 18, icone="[" in b["en"], oltre=int(b["alto"] * 1.6), limite=lim)
    orig = np.array(src.resize((src.width * SCALA, src.height * SCALA), Image.LANCZOS))
    sposta = []
    for b in blocchi:
        if not b.get("azione"):
            continue
        x, y, w, h = b["box"]
        b["centrato"], b["destra"] = False, True
        size, il, righe, fonts, sp, _, _ = adatta(b["it"], "titolo", 10 ** 5, h, 1, b["corpo"], b["passo"])
        lw = sum(t[2] for t in righe[0]) + sp * (len(righe[0]) - 1)
        manca = int(lw - (w - b["alto"] * 0.25))
        if manca <= 0:
            continue
        if manca > min(w * 0.35, x - big.shape[1] * 0.02):
            manca = int(max(0, min(w * 0.35, x - big.shape[1] * 0.02)))
            size, il, righe, fonts, sp, _, _ = adatta(b["it"], "titolo", w + manca - b["alto"] * 0.25, h, 1, b["corpo"], b["passo"])
        # la striscia di icone a sinistra del titolo: colonne con pixel chiari o colorati, fino a un vuoto
        band = orig[y:y + h].astype(int)
        acceso = (band.min(axis=2) > 175) | ((band[..., 0] > 170) & (band[..., 1] > 125) & (band[..., 2] < 110))
        col_on = acceso.sum(axis=0) > h * 0.12
        xa, vuoto = x, 0
        while xa > 0 and vuoto < b["alto"] * 0.9:
            xa -= 1
            vuoto = 0 if col_on[xa] else vuoto + 1
        xa += vuoto
        manca = min(manca, xa)
        if x - xa > b["alto"] * 0.5 and manca > 0:
            sposta.append((xa, y, x - xa, h, manca))
        b["box"] = (x - manca, y, w + manca, h)
        b["adattato"] = (size, il, righe, fonts, sp, w + manca, h)
    for xa, y, ws, h, manca in sposta:
        reg = orig[y:y + h, xa:xa + ws]
        r_ = reg.astype(int)
        m = ((r_.min(axis=2) > 125) | ((r_.min(axis=2) > 95) & (r_.max(axis=2) - r_.min(axis=2) < 45)) | ((r_[..., 0] > 150) & (r_[..., 1] > 105) & (r_[..., 2] < 130))).astype(np.uint8) * 255
        m[:int(h * 0.1)] = 0
        m[int(h * 0.86):] = 0
        # solo le macchie grandi (le icone), non i puntini chiari dello sfondo
        n_, lab, st, _ = cv2.connectedComponentsWithStats(m)
        for k in range(1, n_):
            if st[k, cv2.CC_STAT_AREA] < 40 or st[k, cv2.CC_STAT_WIDTH] > h * 1.5:
                m[lab == k] = 0
        m = cv2.dilate(m, np.ones((3, 3), np.uint8), iterations=4)
        m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
        mask = np.zeros(big.shape[:2], np.uint8)
        mask[y:y + h, xa:xa + ws] = cv2.dilate(m, np.ones((3, 3), np.uint8), iterations=3)
        big = cv2.inpaint(big, mask, 7, cv2.INPAINT_TELEA)
        dst = big[y:y + h, xa - manca:xa - manca + ws]
        mm = cv2.GaussianBlur(m, (5, 5), 0)[..., None] / 255.0
        big[y:y + h, xa - manca:xa - manca + ws] = (reg * mm + dst * (1 - mm)).astype(np.uint8)
    img = Image.fromarray(big)
    for b in blocchi:
        b["rect"] = scrivi(img, b["box"], b["it"], b["stile"], b["col"], b["centrato"], b["righe"], b["alto"], b.get("destra", False),
               b.get("corpo"), b.get("passo"), b.get("extra_x", 0), b.get("extra_y", 0), b.get("adattato"))
        if debug:
            ImageDraw.Draw(img).rectangle([b["box"][0], b["box"][1], b["box"][0] + b["box"][2], b["box"][1] + b["box"][3]], outline=(255, 0, 255), width=3)
    # testi che finiscono uno sopra l'altro, o fuori dalla carta
    W_, H_ = img.size
    for i_, a_ in enumerate(blocchi):
        ra = a_.get("rect")
        if not ra:
            continue
        if ra[0] < -5 or ra[2] > W_ + 5 or ra[1] < -5 or ra[3] > H_ + 5:
            PROBLEMI.append("fuori dalla carta: " + a_["it"][:30])
        for b_ in blocchi[i_ + 1:]:
            rb = b_.get("rect")
            if not rb:
                continue
            ix = min(ra[2], rb[2]) - max(ra[0], rb[0])
            iy = min(ra[3], rb[3]) - max(ra[1], rb[1])
            if ix > 0 and iy > 0 and ix * iy > 0.08 * min((ra[2] - ra[0]) * (ra[3] - ra[1]), (rb[2] - rb[0]) * (rb[3] - rb[1])):
                PROBLEMI.append("sovrapposti: %s / %s" % (a_["it"][:20], b_["it"][:20]))
    img = img.resize((src.width * 2, src.height * 2), Image.LANCZOS)
    img.save(uscita)
    return blocchi


if __name__ == "__main__":
    traduci(sys.argv[1], sys.argv[2], "debug" in sys.argv)
