"""Ritocchi a mano dopo la traduzione automatica: testi verticali che lo strumento non gestisce.

Uso: python3 ritocchi.py   (rielabora le carte elencate in RITOCCHI, partendo dalla versione tradotta)
"""
import os, sys
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

QUI = os.path.dirname(os.path.abspath(__file__))
RADICE = os.path.dirname(os.path.dirname(QUI))
FONT = QUI + "/font/exo-2-latin-400-normal.ttf"

# file: [(x, y, w, h) in frazioni della carta, testo italiano, spaziatura lettere in frazioni del corpo]
RITOCCHI = {
    "carte/builder_s_biomebot/builder_s_biomebot_7806.webp": [((.035, .425, .06, .33), "PDI DEL BIOMEBOT", 0.55)],
    # scritta capovolta (il lato opposto della carta Morale)
    "carte/morale/morale_206700.webp": [((.2, .893, .6, .062), "MORALE ALTO", "capovolto")],
}


def capovolto(img, box, testo):
    W, H = img.size
    x, y, w, h = int(box[0] * W), int(box[1] * H), int(box[2] * W), int(box[3] * H)
    a = np.asarray(img.convert("RGB")).copy()
    zona = cv2.cvtColor(a[y:y + h, x:x + w], cv2.COLOR_RGB2GRAY)
    maschera = np.zeros(a.shape[:2], np.uint8)
    maschera[y:y + h, x:x + w] = (zona > np.median(zona) + 40).astype(np.uint8) * 255
    maschera = cv2.dilate(maschera, np.ones((5, 5), np.uint8))
    a = cv2.inpaint(a, maschera, 5, cv2.INPAINT_TELEA)
    img = Image.fromarray(a)
    corpo = int(h * 0.7)
    f = ImageFont.truetype(QUI + "/font/exo-2-latin-700-normal.ttf", corpo)
    while f.getlength(testo) > w * 0.95:
        corpo -= 1
        f = ImageFont.truetype(QUI + "/font/exo-2-latin-700-normal.ttf", corpo)
    strip = Image.new("RGBA", (int(f.getlength(testo)) + 4, int(corpo * 1.3)), (0, 0, 0, 0))
    ImageDraw.Draw(strip).text((2, 0), testo, font=f, fill=(245, 248, 245, 255))
    strip = strip.rotate(180)
    img.paste(strip, (x + (w - strip.width) // 2, y + (h - strip.height) // 2), strip)
    return img


def verticale(img, box, testo, spazio):
    W, H = img.size
    x, y, w, h = int(box[0] * W), int(box[1] * H), int(box[2] * W), int(box[3] * H)
    a = np.asarray(img.convert("RGB")).copy()
    zona = cv2.cvtColor(a[y:y + h, x:x + w], cv2.COLOR_RGB2GRAY)
    maschera = np.zeros(a.shape[:2], np.uint8)
    maschera[y:y + h, x:x + w] = (zona > np.median(zona) + 45).astype(np.uint8) * 255
    maschera = cv2.dilate(maschera, np.ones((5, 5), np.uint8))
    a = cv2.inpaint(a, maschera, 5, cv2.INPAINT_TELEA)
    img = Image.fromarray(a)
    # testo ruotato di 90° in senso orario (si legge dall'alto in basso)
    corpo = int(w * 0.55)
    f = ImageFont.truetype(FONT, corpo)
    while True:
        larg = sum(f.getlength(ch) for ch in testo) + spazio * corpo * (len(testo) - 1)
        if larg <= h * 0.95 or corpo < 8:
            break
        corpo -= 1
        f = ImageFont.truetype(FONT, corpo)
    strip = Image.new("RGBA", (int(larg) + 4, int(corpo * 1.4)), (0, 0, 0, 0))
    d = ImageDraw.Draw(strip)
    cx = 2
    for ch in testo:
        d.text((cx, 0), ch, font=f, fill=(235, 238, 240, 255))
        cx += f.getlength(ch) + spazio * corpo
    strip = strip.rotate(-90, expand=True)
    px = x + (w - strip.width) // 2
    py = y + (h - strip.height) // 2
    img.paste(strip, (px, py), strip)
    return img


def main(solo=None):
    for f, voci in RITOCCHI.items():
        if solo is not None and f not in solo:
            continue
        dest = RADICE + "/web/img/it/" + f
        orig = dest if os.path.exists(dest) else QUI + "/da_rivedere/" + f.replace("/", "__")
        img = Image.open(orig).convert("RGB")
        for box, testo, spazio in voci:
            img = capovolto(img, box, testo) if spazio == "capovolto" else verticale(img, box, testo, spazio)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        img.save(dest, quality=90)
        print("ritoccata", f)


if __name__ == "__main__":
    main()
