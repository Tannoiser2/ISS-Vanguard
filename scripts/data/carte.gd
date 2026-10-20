## Testo e struttura di tutte le carte (trascritte dalle immagini, vedi tools/unisci_carte.py).
## La chiave è il percorso dell'immagine del fronte, lo stesso usato nel catalogo del tavolo.
extends Node

var db: Dictionary = {}

func _ready() -> void:
	var f := FileAccess.open("res://data/carte_db.json", FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			db = d

func per_file(rel: String) -> Dictionary:
	return db.get("per_file", {}).get(rel, {})

## Carta per codice stampato (P107, G23, M02…). Se ci sono più versioni, la prima;
## "P382@2" indica la terza versione dello stesso codice (carte con lo stesso numero e testi diversi).
func per_id(id: String) -> Dictionary:
	var k := 0
	if id.contains("@"):
		k = int(id.get_slice("@", 1))
		id = id.get_slice("@", 0)
	var l: Array = db.get("per_id", {}).get(id.to_upper(), [])
	return per_file(str(l[clampi(k, 0, l.size() - 1)])) if not l.is_empty() else {}

func versioni(id: String) -> Array:
	return db.get("per_id", {}).get(id.to_upper(), []).map(func(r): return per_file(str(r)))

## Plancia del pianeta per nome dello stato del Planetopedia nel modulo (p.18-19…).
func pianeta(stato: String) -> Dictionary:
	return db.get("pianeti", {}).get(stato, {})

func pianeti() -> Array:
	var out := []
	for k in db.get("pianeti", {}):
		var p: Dictionary = db["pianeti"][k]
		if p.has("settori") and not p.get("settori", []).is_empty():
			out.append({"stato": k, "nome": str(p.get("pianeta", k)), "pagine": str(p.get("pagine", ""))})
	out.sort_custom(func(a, b): return _num(a["pagine"]) < _num(b["pagine"]))
	return out

func _num(p: String) -> int:
	return int(p.get_slice("-", 0)) if p.get_slice("-", 0).is_valid_int() else 999

## Tutte le carte di una categoria (pdi, eventi, condizioni, missioni, minacce, reparto, equipaggio…).
func categoria(cat: String) -> Array:
	var out := []
	for k in db.get("per_file", {}):
		var c: Dictionary = db["per_file"][k]
		if c.get("categoria", "") == cat:
			out.append(c)
	return out

## Testo nella lingua del gioco (italiano, oppure inglese se manca).
static func t(x) -> String:
	if x is Dictionary:
		var it := str(x.get("it", ""))
		return it if it != "" else str(x.get("en", ""))
	return str(x) if x != null else ""

static func en(x) -> String:
	if x is Dictionary:
		return str(x.get("en", ""))
	return str(x) if x != null else ""

## Titolo leggibile di una carta.
static func titolo(c: Dictionary) -> String:
	if c.has("titolo"):
		return t(c["titolo"])
	return str(c.get("nome", c.get("id", "")))

## Immagine della doppia pagina del Planetopedia (stato del modulo TTS, es. "p.18-19").
var _img_pianeti := {}
func img_pianeta(stato: String) -> String:
	if _img_pianeti.is_empty():
		for o in Dati.componenti.get("oggetti", []):
			_cerca_img(o)
	return str(_img_pianeti.get(stato, ""))

func _cerca_img(o: Dictionary) -> void:
	var n := str(o.get("nome", ""))
	if n.begins_with("p.") and o.has("img"):
		_img_pianeti[n] = str(o["img"])
	for k in ["contenuto", "stati"]:
		for x in o.get(k, []):
			_cerca_img(x)

## Pagina della mappa dei sistemi per nome (TOI-2, 81 INF…).
func sistema(nome: String) -> Dictionary:
	return db.get("sistemi", {}).get(nome.to_upper(), {})

## Pianeta del Planetopedia che corrisponde al nome stampato su una carta Atterraggio.
func pianeta_per_nome(nome: String) -> String:
	var n := nome.to_upper().strip_edges()
	for p in pianeti():
		if str(p["nome"]).to_upper() == n:
			return str(p["stato"])
	for p in pianeti():
		if n != "" and (str(p["nome"]).to_upper().contains(n) or n.contains(str(p["nome"]).to_upper())):
			return str(p["stato"])
	return ""
