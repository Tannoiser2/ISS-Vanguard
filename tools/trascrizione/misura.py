"""Misura con l'OCR dove sono stampate delle frasi inglesi e aggiunge a correzioni.json
le voci "+frase" con il riquadro e la traduzione.

Uso: python3 misura.py carte/x/y.webp '{"FRASE EN": "FRASE IT", ...}' [--centro] [--righe=N]
Una frase può contenere "|" per indicare l'allineamento: "FRASE EN|c".
"""
import json, re, sys
import numpy as np
import pytesseract
from PIL import Image

RADICE = "/home/claude/iss-vanguard/"
CORR = RADICE + "tools/traduci_carte/correzioni.json"


def norm(t):
    return re.sub(r"[^a-z0-9]", "", t.lower())


def parole(img):
    out = []
    for psm in ("11", "6", "3"):
        d = pytesseract.image_to_data(img, lang="eng", output_type=pytesseract.Output.DICT, config="--psm " + psm)
        for i, t in enumerate(d["text"]):
            if norm(t):
                out.append((norm(t), d["left"][i], d["top"][i], d["width"][i], d["height"][i], d["line_num"][i], d["block_num"][i], psm))
    return out


def cerca_tutte(ws, frase):
    trovate = []
    resto = list(ws)
    while True:
        t = cerca(resto, frase)
        if not t:
            return trovate
        x0 = min(a[1] for a in t); y0 = min(a[2] for a in t); x1 = max(a[1] + a[3] for a in t); y1 = max(a[2] + a[4] for a in t)
        if not any(abs(x0 - b[0]) < 20 and abs(y0 - b[1]) < 20 for b in [(min(a[1] for a in u), min(a[2] for a in u)) for u in trovate]):
            trovate.append(t)
        resto = [a for a in resto if not (x0 - 5 <= a[1] <= x1 + 5 and y0 - 5 <= a[2] <= y1 + 5)]


def cerca(ws, frase):
    voc = [norm(x) for x in frase.split() if norm(x)]
    migliori = None
    for psm in ("11", "6", "3"):
        w = [x for x in ws if x[7] == psm]
        for i in range(len(w)):
            j, k, pres = i, 0, []
            while j < len(w) and k < len(voc):
                a, b = w[j][0], voc[k]
                if a == b or (len(b) >= 4 and (a.startswith(b[:4]) or b.startswith(a[:4]))):
                    pres.append(w[j]); k += 1
                j += 1
                if j - i > len(voc) + 3:
                    break
            if pres and len(pres) >= max(1, int(len(voc) * 0.6)) and pres[0][0][:3] == voc[0][:3]:
                if migliori is None or len(pres) > len(migliori):
                    migliori = pres
        if migliori and len(migliori) == len(voc):
            break
    return migliori


def main():
    f = sys.argv[1]
    frasi = json.loads(sys.argv[2])
    img = Image.open(RADICE + "web/img/" + f).convert("RGB")
    W, H = img.size
    big = img.resize((W * 2, H * 2), Image.LANCZOS)
    g = np.asarray(big.convert("L")).astype(float)
    ws = parole(big)
    for x in sys.argv:
        if x.startswith("--sotto="):
            ws = [w for w in ws if w[2] > float(x[8:]) * 2 * H]
    corr = json.load(open(CORR))
    voce = corr.setdefault(f, {})
    for en, it in frasi.items():
        al = "s"
        if "|" in en:
            en, al = en.split("|")
        tutte = cerca_tutte(ws, en) if "--tutte" in sys.argv else [cerca(ws, en)]
        if not tutte or not tutte[0]:
            print("NON TROVATA:", f, en)
            continue
        riq = []
        for trovate in tutte:
            riq.append(misura(g, trovate, W, H, al, it))
        voce["+" + en] = riq[0] if len(riq) == 1 else riq
        print("ok", f, en, voce["+" + en])
    json.dump(corr, open(CORR, "w"), ensure_ascii=False, indent=1)


def misura(g, trovate, W, H, al, it):
    if True:
        x0 = min(t[1] for t in trovate); y0 = min(t[2] for t in trovate)
        x1 = max(t[1] + t[3] for t in trovate); y1 = max(t[2] + t[4] for t in trovate)
        hl = float(np.median([t[4] for t in trovate]))
        righe = max(1, round((y1 - y0) / (hl * 1.25)))
        px, py = hl * 0.25, hl * 0.3
        x0, y0, x1, y1 = x0 - px, y0 - py, x1 + px, y1 + py
        z = g[int(max(0, y0)):int(y1), int(max(0, x0)):int(x1)]
        chiaro = bool(np.percentile(z, 92) - np.median(z) > np.median(z) - np.percentile(z, 8))
        return [round(x0 / (2 * W), 4), round(y0 / (2 * H), 4), round((x1 - x0) / (2 * W), 4),
                round((y1 - y0) / (2 * H), 4), al, righe, chiaro, it]


main()
