## Dati statici del gioco: paragrafi del Logbook (dall'app ufficiale, in italiano),
## catalogo dei componenti estratti dal modulo Tabletop Simulator e icone nel testo.
## Tutto viene letto dai JSON in res://data, generati dagli script in tools/.
extends Node

const CAMPAGNE := {
	8: {"nome": "ISS Vanguard", "file": "res://data/logbook/c8.json", "copertina": "res://assets/app/copertine/8_cover.webp"},
	12: {"nome": "Deadly Frontier", "file": "res://data/logbook/c12.json", "copertina": "res://assets/app/copertine/12_cover.webp"},
	14: {"nome": "Lost Fleet", "file": "res://data/logbook/c14.json", "copertina": "res://assets/app/copertine/14_cover.webp"},
}

## Le quattro Sezioni dell'equipaggio, con colore e miniatura 3D del modulo TTS.
const SEZIONI := {
	"ingegneria": {"nome": "Ingegneria", "en": "Engineering", "colore": Color("e8a33a"), "modello": "capitano"},
	"ricognizione": {"nome": "Ricognizione", "en": "Recon", "colore": Color("4fbf6a"), "modello": "esploratore"},
	"scienza": {"nome": "Scienza", "en": "Science", "colore": Color("4f9dff"), "modello": "pilota"},
	"sicurezza": {"nome": "Sicurezza", "en": "Security", "colore": Color("e8404f"), "modello": "soldato"},
}

var _logbook := {}        # id campagna -> dizionario della campagna
var componenti := {}      # catalogo TTS
var icone := {}           # nome icona -> id file
var equipaggio_app := {}  # id ritratto app -> nome

func _ready() -> void:
	icone = _leggi("res://data/logbook/icone.json")
	componenti = _leggi("res://data/componenti.json")
	equipaggio_app = _leggi("res://data/equipaggio_app.json")

func _leggi(p: String):
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		push_error("File dati mancante: " + p)
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d != null else {}

## Dati del Logbook di una campagna (caricati alla prima richiesta).
func logbook(camp: int) -> Dictionary:
	if not _logbook.has(camp):
		_logbook[camp] = _leggi(CAMPAGNE[camp]["file"])
	return _logbook[camp]

## Annotazione per id interno.
func annotazione(camp: int, id_log: int) -> Dictionary:
	return logbook(camp).get("logs", {}).get(str(id_log), {})

## Id interni delle annotazioni con questo numero (di solito una sola).
func cerca_numero(camp: int, numero: int) -> Array:
	return logbook(camp).get("index", {}).get(str(numero), [])

## Percorso dell'icona da usare nel testo.
func icona(nome: String) -> String:
	if icone.has(nome):
		return "res://assets/app/icone/%d.webp" % int(icone[nome])
	return ""

## Converte i segnaposto {i:nome} nelle immagini BBCode di RichTextLabel.
func testo_bb(t: String, dim := 22) -> String:
	if t.find("{i:") < 0:
		return t
	var rx := RegEx.create_from_string("\\{i:(\\w+)\\}")
	var out := ""
	var k := 0
	for m in rx.search_all(t):
		out += t.substr(k, m.get_start() - k)
		var p := icona(m.get_string(1))
		out += ("[img height=%d]%s[/img]" % [dim, p]) if p != "" else "[lb]%s[rb]" % m.get_string(1)
		k = m.get_end()
	return out + t.substr(k)

## Testo di una carta trascritta: le icone sono scritte "[nome]". Restituisce BBCode con le immagini.
func testo_carta(t: String, dim := 22) -> String:
	var rx := RegEx.create_from_string("\\[([A-Za-z_0-9]+)\\]")
	var out := ""
	var k := 0
	for m in rx.search_all(t):
		out += t.substr(k, m.get_start() - k).replace("[", "[lb]")
		var n := m.get_string(1)
		var alias := {"travel": "", "time": "", "marker": "", "die": "die", "defense": "defence"}
		if alias.has(n) and alias[n] != "":
			n = alias[n]
		var p := icona(n)
		out += ("[img height=%d]%s[/img]" % [dim, p]) if p != "" else "[color=#ffb347]⟨%s⟩[/color]" % Traduzioni.icona(m.get_string(1))
		k = m.get_end()
	return out + t.substr(k).replace("[", "[lb]")

## Elenco piatto di tutte le carte del catalogo: {nome -> [voci]} per cercarle per numero (P107, M02...).
var _carte_per_nome := {}
func carte_per_nome() -> Dictionary:
	if _carte_per_nome.is_empty():
		for o in componenti.get("oggetti", []):
			_indicizza(o, "")
	return _carte_per_nome

func _indicizza(o: Dictionary, mazzo: String) -> void:
	var nome_mazzo: String = o.get("nome", mazzo)
	for c in o.get("carte", []):
		var n: String = c.get("nome", "")
		if n != "":
			_carte_per_nome.get_or_add(n.to_upper(), []).append({"carta": c, "mazzo": nome_mazzo, "guid": o.get("guid", "")})
	if o.has("fronte") and o.get("nome", "") != "":
		_carte_per_nome.get_or_add(str(o["nome"]).to_upper(), []).append({"carta": o, "mazzo": "", "guid": o.get("guid", "")})
	for k in ["contenuto", "stati"]:
		for x in o.get(k, []):
			_indicizza(x, nome_mazzo)
