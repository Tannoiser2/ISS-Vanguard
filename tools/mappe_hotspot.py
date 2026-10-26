"""Zone cliccabili sulle pagine del libro delle Mappe dei Sistemi (OCR con tesseract).
Uscita: data/mappe_sistemi.json  {sistema: {"rotte": [[i, x, y, w, h]], "dest": [[n, x, y, w, h, "box"|"mappa"]]}}
Coordinate in proporzione alla pagina. Uso: python3 tools/mappe_hotspot.py (dalla cartella del progetto)."""
import json, re, sys
import pytesseract
from PIL import Image, ImageOps

def norm(t):
    return re.sub(r'[^a-z0-9]', '', t.lower())

db = json.load(open('data/carte_db.json'))
out = {}
K = 1.6
for nome, s in db['sistemi'].items():
    im = Image.open('web/img/' + s['file']).convert('L')
    W, H = im.size
    big = ImageOps.autocontrast(im.resize((int(W * K), int(H * K))))
    d = pytesseract.image_to_data(big, output_type=pytesseract.Output.DICT, config='--psm 11')
    d2 = pytesseract.image_to_data(big, output_type=pytesseract.Output.DICT)
    righe = {}
    for i in range(len(d2['text'])):
        w = d2['text'][i].strip()
        if not w:
            continue
        k = (d2['block_num'][i], d2['par_num'][i], d2['line_num'][i])
        x, y, ww, hh = d2['left'][i] / K, d2['top'][i] / K, d2['width'][i] / K, d2['height'][i] / K
        r = righe.setdefault(k, {'t': '', 'x0': x, 'y0': y, 'x1': x + ww, 'y1': y + hh})
        r['t'] += ' ' + w
        r['x0'] = min(r['x0'], x); r['y0'] = min(r['y0'], y); r['x1'] = max(r['x1'], x + ww); r['y1'] = max(r['y1'], y + hh)
    righe = sorted(righe.values(), key=lambda r: (r['y0'], r['x0']))
    rotte = []
    for k, rt in enumerate(s.get('rotte', [])):
        v = norm(str(rt.get('verso', '')))
        for r in righe:
            if v and v in norm(r['t']) and norm(r['t']) != norm(nome) and r['y0'] < H * 0.5:
                h = (r['y1'] - r['y0'])
                rotte.append([k, max(0, r['x0'] - 70) / W, max(0, r['y0'] - h * 0.4) / H, max(0.3 * W, r['x1'] - r['x0'] + 90) / W, h * 2.6 / H])
                break
    marc = []
    for i in range(len(d['text'])):
        w = d['text'][i].strip()
        m = re.match(r'^\(\s*(\d)\s*\)?$', w) or re.match(r'^\((\d)\)', w)
        if m:
            marc.append((int(m.group(1)), d['left'][i] / K, d['top'][i] / K, d['width'][i] / K, d['height'][i] / K))
    dest = []
    box = sorted([mm for mm in marc if mm[1] < W * 0.2 and mm[2] > H * 0.45], key=lambda t: t[2])
    visti = set()
    for i, (n, x, y, ww, hh) in enumerate(box):
        if n in visti:
            continue
        visti.add(n)
        fine = min([b[2] for b in box if b[2] > y + hh * 1.5 and b[0] != n] + [H * 0.97])
        dest.append([n, 0.03, (y - 10) / H, 0.94, (fine - y - 2) / H, 'box'])
    for (n, x, y, ww, hh) in marc:
        if not (x < W * 0.2 and y > H * 0.45):
            dest.append([n, (x - 25) / W, (y - 15) / H, (ww + 50) / W, (hh + 30) / H, 'mappa'])
    out[nome] = {'rotte': rotte, 'dest': dest}
    nd = len(s.get('destinazioni', []))
    print(nome, 'rotte %d/%d' % (len(rotte), len(s.get('rotte', []))), 'dest box %d/%d' % (len(visti), nd), 'mappa', len(dest) - len(visti), file=sys.stderr)


# --- seconda passata: il riquadro "OUTBOUND SYSTEMS" ha sempre la stessa impaginazione (una riga ogni
# 3,7% della pagina dall'alto), cambia solo il lato. L'OCR serve a capire il lato; le zone si ricostruiscono.
def lato_destro(nome, db):
    """Il titolo "OUTBOUND SYSTEMS" sta nella metà destra della pagina?"""
    im = Image.open('web/img/' + db['sistemi'][nome]['file']).convert('L')
    W, H = im.size
    top = ImageOps.autocontrast(im.crop((0, 0, W, int(H * 0.05))).resize((W * 2, int(H * 0.1))))
    d = pytesseract.image_to_data(top, output_type=pytesseract.Output.DICT, config='--psm 11')
    for i, t in enumerate(d['text']):
        if re.search(r'OUTB|BOUND|SYSTEM', t.upper()):
            return d['left'][i] / 2 > W * 0.45
    return False

def regolarizza(out, db):
    for nome, z in out.items():
        n = len(db['sistemi'][nome].get('rotte', []))
        x0 = 0.59 if lato_destro(nome, db) else 0.04
        z['rotte'] = [[k, x0, 0.027 + 0.037 * k, 0.37, 0.036] for k in range(n)]
    return out


json.dump(regolarizza(out, db), open('data/mappe_sistemi.json', 'w'), indent=0)
