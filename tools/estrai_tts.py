#!/usr/bin/env python3
"""Estrae dal modulo Tabletop Simulator di ISS Vanguard tutti i componenti:
carte (tagliate dai fogli), segnalini, tessere, standee, plance con più stati, modelli 3D.

Uso: python3 tools/estrai_tts.py <cartella_ttsmod_estratta> <cartella_progetto>

Scrive:
  web/img/...            immagini (webp) caricate dal gioco a richiesta (non entrano nel .pck)
  data/componenti.json   catalogo di tutti gli oggetti con posizione sul tavolo TTS
"""
import json, re, os, sys, hashlib, collections
from PIL import Image
Image.MAX_IMAGE_PIXELS = None

SRC, PRJ = sys.argv[1], sys.argv[2]
OUT_IMG = os.path.join(PRJ, "web", "img")
mod = json.load(open(os.path.join(SRC, "Mods/Workshop/3427368430.json")))

# indice dei file in cache: nome = URL senza caratteri non alfanumerici
cache = {}
for sub in ("Images", "Models", "PDF", "Assetbundles"):
    for f in os.listdir(os.path.join(SRC, "Mods", sub)):
        cache[os.path.splitext(f)[0]] = os.path.join(SRC, "Mods", sub, f)

def local(url):
    if not url:
        return None
    return cache.get(re.sub(r"[^A-Za-z0-9]", "", url))

def slug(s):
    s = re.sub(r"^[/\s\d]*", "", s or "").strip() or "x"
    s = re.sub(r"[^A-Za-z0-9]+", "_", s).strip("_").lower()
    return s[:48] or "x"

_sheets = {}
def sheet(url):
    if url not in _sheets:
        p = local(url)
        _sheets[url] = Image.open(p).convert("RGBA") if p else None
    return _sheets[url]

written = {}
def save(im, rel, q=80, maxside=900):
    """Salva una sola volta (per contenuto), restituisce il percorso relativo."""
    h = hashlib.md5(im.tobytes()).hexdigest()[:12]
    if h in written:
        return written[h]
    if max(im.size) > maxside:
        r = maxside / max(im.size)
        im = im.resize((round(im.width * r), round(im.height * r)), Image.LANCZOS)
    rel = rel + ".webp"
    p = os.path.join(OUT_IMG, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    if im.mode == "RGBA" and im.getextrema()[3][0] == 255:
        im = im.convert("RGB")
    im.save(p, "WEBP", quality=q, method=4)
    written[h] = rel
    return rel

def card_face(cd, idx, back=False, unique_back=False):
    url = cd["BackURL"] if back else cd["FaceURL"]
    sh = sheet(url)
    if sh is None:
        return None
    if back and not cd.get("UniqueBack"):
        return sh
    w, h = cd["NumWidth"], cd["NumHeight"]
    cw, ch = sh.width / w, sh.height / h
    x, y = idx % w, idx // w
    return sh.crop((round(x * cw), round(y * ch), round((x + 1) * cw), round((y + 1) * ch)))

AR = {}
BIANCHE = set()  # immagini tutte bianche: i "foglietti" di aiuto del modulo TTS
def single_image(url, rel, **kw):
    p = local(url)
    if not p:
        return None
    try:
        im = Image.open(p).convert("RGBA")
        r = save(im, rel, **kw)
        if im.convert("L").resize((32, 32)).getextrema()[0] > 245:
            BIANCHE.add(r)
        AR[r] = round(im.width / im.height, 4)
        return r
    except Exception as e:
        print("immagine non leggibile", url, e)
        return None

def tr(o):
    t = o.get("Transform", {})
    return [round(t.get(k, 0), 3) for k in ("posX", "posY", "posZ", "rotX", "rotY", "rotZ", "scaleX", "scaleY", "scaleZ")]

stats = collections.Counter()

def card_entry(o, deckname, decks):
    cid = o.get("CardID")
    key = str(cid // 100)
    cd = (o.get("CustomDeck") or decks).get(key) or decks.get(key)
    if not cd:
        return None
    idx = cid % 100
    name = o.get("Nickname") or ""
    base = "carte/%s/%s" % (slug(deckname), slug(name) + "_" if name else "")
    f = card_face(cd, idx)
    face = save(f, base + "%d" % cid) if f is not None else None
    b = card_face(cd, idx, back=True)
    back = save(b, "carte/%s/retro_%s" % (slug(deckname), hashlib.md5(cd["BackURL"].encode()).hexdigest()[:6] if not cd.get("UniqueBack") else "%d" % cid), maxside=700) if b is not None else None
    stats["carte"] += 1
    e = {"nome": name, "id": cid, "fronte": face, "retro": back, "guid": o.get("GUID", "")}
    if f is not None: e["ar"] = round(f.width / f.height, 4)
    if o.get("Description"): e["desc"] = o["Description"]
    if o.get("GMNotes"): e["note"] = o["GMNotes"]
    if o.get("Tags"): e["tag"] = o["Tags"]
    if cd.get("Type", 0) == 1 or o.get("SidewaysCard"): e["orizz"] = True
    return e

def obj_entry(o, path):
    n = o["Name"]
    nick = o.get("Nickname") or ""
    e = {"tipo": n, "nome": nick, "guid": o.get("GUID", ""), "t": tr(o)}
    if o.get("Description"): e["desc"] = o["Description"][:2000]
    if o.get("Tags"): e["tag"] = o["Tags"]
    if o.get("Locked"): e["bloccato"] = True
    col = o.get("ColorDiffuse")
    if col: e["colore"] = [round(col.get(k, 1), 3) for k in "rgb"]
    base = "oggetti/%s_%s" % (slug(nick or n), o.get("GUID", "x"))
    if n in ("Deck", "DeckCustom"):
        decks = o.get("CustomDeck", {})
        e["carte"] = [c for c in (card_entry(x, nick or "mazzo", decks) for x in o.get("ContainedObjects") or []) if c]
    elif n in ("Card", "CardCustom"):
        c = card_entry(o, nick or "carte_sciolte", o.get("CustomDeck", {}))
        if c: e.update(c)
    elif n in ("Custom_Token", "Custom_Tile"):
        ci = o.get("CustomImage", {})
        # plance e pagine dei libri: risoluzione alta per poterle leggere da vicino
        e["img"] = single_image(ci.get("ImageURL"), base, maxside=2400, q=78)
        if ci.get("ImageSecondaryURL") and ci.get("ImageSecondaryURL") != ci.get("ImageURL"):
            e["img2"] = single_image(ci.get("ImageSecondaryURL"), base + "_b", maxside=2400, q=78)
        if "CustomTile" in ci:
            e["forma"] = ci["CustomTile"].get("Type", 0)
            e["spessore"] = ci["CustomTile"].get("Thickness", 0.2)
        if "CustomToken" in ci:
            e["spessore"] = ci["CustomToken"].get("Thickness", 0.2)
        stats["tessere"] += 1
    elif n == "Figurine_Custom":
        ci = o.get("CustomImage", {})
        e["img"] = single_image(ci.get("ImageURL"), "standee/" + slug(nick))
        if ci.get("ImageSecondaryURL"):
            e["img2"] = single_image(ci.get("ImageSecondaryURL"), "standee/" + slug(nick) + "_b")
        stats["standee"] += 1
    elif n == "Custom_Dice":
        ci = o.get("CustomImage", {})
        e["img"] = single_image(ci.get("ImageURL"), "dadi/" + slug(nick or "dado") + "_" + o.get("GUID", ""), maxside=1024)
        e["facce"] = ci.get("CustomDice", {}).get("Type", 1)
        e["rot"] = [[round(r["Value"] if isinstance(r["Value"], (int, float)) else 0)] for r in o.get("RotationValues", [])]
        e["valori"] = [str(r.get("Value")) for r in o.get("RotationValues", [])]
        stats["dadi"] += 1
    elif n in ("Custom_Model", "Custom_Model_Bag"):
        cm = o.get("CustomMesh", {})
        e["mesh"] = os.path.basename(local(cm.get("MeshURL")) or "") or None
        e["img"] = single_image(cm.get("DiffuseURL"), base)
    elif n == "Custom_Assetbundle":
        ca = o.get("CustomAssetbundle", {})
        e["bundle"] = os.path.basename(local(ca.get("AssetbundleURL")) or "") or None
    elif n == "3DText":
        tx = o.get("Text", {})
        e["testo"] = tx.get("Text", "")
        e["dim"] = tx.get("fontSize", 64)
        if tx.get("Color"): e["colore"] = [round(tx["Color"].get(k, 1), 3) for k in "rgb"]
    elif n == "Custom_PDF":
        e["pdf"] = os.path.basename(local(o.get("CustomPDF", {}).get("PDFUrl")) or "") or None
    if e.get("img") in AR: e["ar"] = AR[e["img"]]
    if e.get("img") in BIANCHE and n == "Custom_Token": e["nota_tts"] = True
    if o.get("AttachedSnapPoints"):
        e["snap"] = [[round(s["Position"]["x"], 3), round(s["Position"]["z"], 3)] + ([s["Tags"]] if s.get("Tags") else []) for s in o["AttachedSnapPoints"]]
    if o.get("States"):
        e["stati"] = [obj_entry(s, path + [nick]) for k, s in sorted(o["States"].items(), key=lambda kv: int(kv[0]))]
    if n not in ("Deck", "DeckCustom") and o.get("ContainedObjects"):
        e["contenuto"] = [obj_entry(x, path + [nick]) for x in o["ContainedObjects"]]
    return e

cat = {"oggetti": [obj_entry(o, []) for o in mod["ObjectStates"]],
       "snap_tavolo": [[round(s["Position"]["x"], 3), round(s["Position"]["z"], 3)] + ([s["Tags"]] if s.get("Tags") else []) for s in mod.get("SnapPoints", [])],
       "decal": mod.get("CustomDecal") or mod.get("DecalPallet", [])}
os.makedirs(os.path.join(PRJ, "data"), exist_ok=True)
json.dump(cat, open(os.path.join(PRJ, "data/componenti.json"), "w"), ensure_ascii=False, separators=(",", ":"))
print(dict(stats), "file immagine:", len(written))
