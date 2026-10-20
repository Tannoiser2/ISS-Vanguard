#!/usr/bin/env python3
"""Esporta i paragrafi (Logbook) dal database dell'app ufficiale ISS Vanguard Companion
in file JSON leggibili da Godot, uno per campagna.

Uso: python3 tools/esporta_logbook.py <appData.sqlite> <cartella_uscita>

Testo italiano (lingua 18); dove manca si usa l'inglese (lingua 1).
Il testo è già convertito in BBCode per RichTextLabel di Godot:
  <b>..</b> -> [b]..[/b], <i>..</i> -> [i]..[/i], [icona] -> {i:nome}, le altre parentesi quadre -> [lb]/[rb]
"""
import sqlite3, json, re, sys, os, collections

IT, EN = 18, 1
db, out = sys.argv[1], sys.argv[2]
c = sqlite3.connect(db)
q = lambda s, *a: c.execute(s, a).fetchall()

ICONS = {tag: i for i, tag in q("select _id, InTextTag from InTextIcons")}

def bb(t):
    """HTML dell'app -> BBCode Godot. Le icone [tag] diventano segnaposto {i:tag}."""
    if not t:
        return ""
    t = t.replace("\r", "").replace("\\n", "\n")
    # icone note -> segnaposto
    t = re.sub(r"\[(\w+)\]", lambda m: "\x01%s\x02" % m.group(1) if m.group(1) in ICONS else m.group(0), t)
    t = t.replace("[", "\x03").replace("]", "\x04")
    # tag html (con le varianti sporche trovate nel database)
    t = re.sub(r"<\s*/\s*[bB]\s*>|<\\b>|</b(?=\s)", "\x05/b\x06", t)
    t = re.sub(r"<\s*[bB]\s*/?>", "\x05b\x06", t)
    t = re.sub(r"<\s*/\s*i\s*>|<i/>|<\.i>", "\x05/i\x06", t)
    t = re.sub(r"<\s*i+\s*>", "\x05i\x06", t)
    t = re.sub(r"<sprite=\d+>", "", t)
    t = t.replace("<>", "").replace("</>", "")
    t = t.replace("<<", "<")
    t = t.replace("\x03", "[lb]").replace("\x04", "[rb]")
    t = t.replace("\x05", "[").replace("\x06", "]")
    t = t.replace("\x01", "{i:").replace("\x02", "}")
    # chiude eventuali [b]/[i] rimasti aperti
    for tag in ("b", "i"):
        o, cl = t.count("[%s]" % tag), t.count("[/%s]" % tag)
        if o > cl:
            t += "[/%s]" % tag * (o - cl)
        elif cl > o:
            for _ in range(cl - o):
                k = t.rfind("[/%s]" % tag)
                t = t[:k] + t[k + len(tag) + 3:]
    return t.strip()

def allinea_icone(it, en):
    """Nel testo italiano alcune icone sono state tradotte ([sensore del lander]) o tolte.
    Se le parentesi quadre sono tante quante nell'inglese, rimette il nome dell'icona inglese."""
    if not it or not en:
        return it
    ti = list(re.finditer(r"\[([^\]\n]{1,40})\]", it))
    te = re.findall(r"\[([^\]\n]{1,40})\]", en)
    if len(ti) != len(te):
        return it
    out, k = [], 0
    for m, e in zip(ti, te):
        out.append(it[k:m.start()])
        out.append("[%s]" % e if (e in ICONS and m.group(1) not in ICONS) else m.group(0))
        k = m.end()
    out.append(it[k:])
    return "".join(out)

def pick(it, en):
    return it if (it is not None and str(it).strip() != "") else (en or "")

stats = collections.Counter()

def txt_elem(eid):
    r = dict(q("select _idLang, text from ElemetText where _idElem=?", eid))
    if (r.get(IT) or "").strip() == "" and (r.get(EN) or "").strip() != "":
        stats["elem_fallback_en"] += 1
    return bb(allinea_icone(pick(r.get(IT), r.get(EN)), r.get(EN)))

def txt_choice(cid):
    r = {l: (a, b) for l, a, b in q("select _idLang, reqTxt, resTxt from ChoiceInfoText where _idChoice=?", cid)}
    it, en = r.get(IT, ("", "")), r.get(EN, ("", ""))
    for k in (0, 1):
        if (it[k] or "").strip() == "" and (en[k] or "").strip() != "":
            stats["choice_fallback_en"] += 1
    return (bb(allinea_icone(pick(it[0], en[0]), en[0])),
            bb(allinea_icone(pick(it[1], en[1]), en[1])))

def flags(s):
    """'0.455#AND#1.12' -> {"op":"and","f":[[455,0],[12,1]]}; '1.3#1.4' (impostazioni) -> lista."""
    s = (s or "").strip()
    if not s:
        return None
    op = "or" if "#OR#" in s else "and"
    parts = re.split(r"#(?:AND|OR)#|#", s)
    f = []
    for p in parts:
        v, _, n = p.partition(".")
        f.append([int(n), int(v)])
    if "#AND#" in s and "#OR#" in s:
        op = "mix"  # un solo caso: lo valutiamo da sinistra a destra
        return {"op": op, "expr": s}
    return {"op": op, "f": f}

btn = {i: pick(t, "") for i, l, ty, t in q("select _id,_idLang,type,translation from ChoiceButton where _idLang=?", IT)}
img_choice_dir = os.path.join(os.path.dirname(db), "appcontent", "campaigns")

for camp, in q("select _id from Campaign"):
    name = q("select name from CampaignTexts where _idCamp=? and _idLang=?", camp, IT)[0][0]
    data = {"camp": camp, "name": name, "intro": {}, "logs": {}, "index": {}}
    for ty, loc in q("select _type, location from CampaignIntro where _idCamp=?", camp):
        data["intro"][str(ty)] = loc
    for lid, dn, block, tut, ops in q("select _id, displayNumber, BlockDirectAccess, tutorialLog, OperationLog from Location where _campId=? order by displayNumber, _id", camp):
        lt = {l: n for l, n in q("select _idLang, name from LocationTexts where _idLoc=?", lid)}
        lname = pick(lt.get(IT), lt.get(EN))
        if lname in ("DELETE",):
            continue
        log = {"n": dn, "name": bb(lname), "verses": {}, "start": None}
        if block: log["block"] = 1
        if tut: log["tut"] = tut
        if ops: log["ops"] = 1
        fl = []
        for fid, order in q("select _id, \"order\" from LocationFlags where _id_location=? order by \"order\"", lid):
            ft = dict(q("select _idLang, text from LocationFlagsTexts where _idFlag=?", fid))
            fl.append([fid, pick(ft.get(IT), ft.get(EN))])
        if fl: log["flags"] = fl
        im = q("select _id_image from ImageUsage where _id_location=?", lid)
        if im: log["img"] = im[0][0]
        for vid, vdn, vty, vnu, vu, uv in q("select _id, displayNumber, type, visibleNotUsed, visibleUsed, unavailableVisible from Verse where _locationId=? order by displayNumber, _id", lid):
            v = {"d": vdn, "t": vty, "e": []}
            if uv: v["uv"] = 1
            if vnu: v["vnu"] = 1
            for eid, ety in q("select _id, type from VerseElements where _idVer=? order by _id", vid):
                e = {"t": ety}
                tx = txt_elem(eid)
                if tx: e["x"] = tx
                if ety == 7:
                    e["graph"] = True
                chs = []
                for cid, tl, tv, rf, tf, yb, nb in q("select _id,_idTargetLoc,_idTargetVer,_idReqFlags,_idTargetFlags,_CustomYesBtn,_CustomNoBtn from ChoiceInfo where _elemId=? order by _id", eid):
                    ch = {"id": cid}
                    if tl: ch["l"] = tl
                    if tv: ch["v"] = tv
                    r = flags(rf); s = flags(tf)
                    if r: ch["req"] = r
                    if s: ch["set"] = s["f"] if "f" in s else s
                    a, b = txt_choice(cid)
                    if a: ch["q"] = a
                    if b: ch["r"] = b
                    if yb: ch["yes"] = btn.get(yb, "")
                    if nb: ch["no"] = btn.get(nb, "")
                    p = os.path.join(img_choice_dir, str(camp), str(lid), str(vid))
                    for ext in ("png", "jpg"):
                        if os.path.exists(os.path.join(p, "ic_%d.%s" % (cid, ext))):
                            ch["img"] = "%d/%d/%d/ic_%d.%s" % (camp, lid, vid, cid, ext)
                            break
                    chs.append(ch)
                if chs: e["c"] = chs
                v["e"].append(e)
            log["verses"][str(vid)] = v
            if log["start"] is None:
                log["start"] = vid
        data["logs"][str(lid)] = log
        data["index"].setdefault(str(dn), []).append(lid)
        stats["logs"] += 1
    p = os.path.join(out, "c%d.json" % camp)
    with open(p, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    print(p, os.path.getsize(p) // 1024, "KB", len(data["logs"]), "annotazioni")

with open(os.path.join(out, "icone.json"), "w") as f:
    json.dump(ICONS, f)
print(dict(stats))
