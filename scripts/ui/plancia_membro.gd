## La plancia originale del Membro (Crew board del modulo TTS, una per Reparto) con sopra lo stato della
## partita: dadi disponibili negli alloggiamenti del loro colore, Dadi Spesi a destra con la faccia
## rimasta, carta del Membro al centro, Cariche, Ferite, mazzo e scarti. Tutto è posizionato con le
## ancore in proporzione all'immagine, quindi la plancia si può mostrare a qualsiasi dimensione.
class_name PlanciaMembro
extends Control

signal premuta

const RAPPORTO := 2000.0 / 1366.0
const COLORI := {"red": Color("b0263a"), "blue": Color("1683c8"), "green": Color("3f9a36")}
# zone della plancia (x, y, larghezza, altezza in proporzione)
const SPESI := Rect2(0.688, 0.118, 0.268, 0.705)
const CARTA := Rect2(0.347, 0.066, 0.326, 0.655)
const CARICHE := Rect2(0.347, 0.752, 0.326, 0.062)
const FERITE := [Rect2(0.345, 0.94, 0.205, 0.06), Rect2(0.56, 0.94, 0.205, 0.06), Rect2(0.775, 0.94, 0.215, 0.06)]
static var _slot := {}

var membro: Dictionary
var esp_ref: Esplorazione
var indice := 0
var _base: Control

static func _dati() -> Dictionary:
	if _slot.is_empty():
		_slot = JSON.parse_string(FileAccess.get_file_as_string("res://data/plance.json"))
	return _slot

func _init(m: Dictionary, esp: Esplorazione = null, i := 0) -> void:
	membro = m
	esp_ref = esp
	indice = i
	mouse_filter = Control.MOUSE_FILTER_PASS
	larghezza(420)

## Dimensione fissa (larghezza; l'altezza segue le proporzioni della plancia).
func larghezza(w: float) -> void:
	custom_minimum_size = Vector2(w, w / RAPPORTO)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func _ready() -> void:
	_base = Control.new()
	_base.set_anchors_preset(Control.PRESET_FULL_RECT)
	_base.mouse_filter = Control.MOUSE_FILTER_STOP
	_base.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			premuta.emit())
	add_child(_base)
	_base.resized.connect(_scala_testi)
	var sfondo := TextureRect.new()
	sfondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sfondo.stretch_mode = TextureRect.STRETCH_SCALE
	sfondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	sfondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base.add_child(sfondo)
	var dati: Dictionary = _dati().get(str(membro.get("reparto", "")), {})
	if dati.has("img"):
		Immagini.carica(str(dati["img"]), func(t): if is_instance_valid(sfondo): sfondo.texture = t)
	aggiorna()

## Ridisegna i pezzi sulla plancia (dopo un cambio di stato).
func aggiorna() -> void:
	if _base == null:
		return
	for c in _base.get_children().slice(1):
		c.queue_free()
	var dati: Dictionary = _dati().get(str(membro.get("reparto", "")), {"slot": {}})
	# carta del Membro al centro
	var carta := TextureRect.new()
	carta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	carta.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ancora(carta, CARTA)
	if str(membro.get("file", "")) != "":
		Immagini.carica(str(membro["file"]), func(t): if is_instance_valid(carta): carta.texture = t)
	_base.add_child(carta)
	# dadi disponibili negli alloggiamenti del loro colore, dall'alto
	var per_colore := {"red": [], "green": [], "blue": []}
	var spesi := []
	var sacrificati := 0
	for d in membro.get("dadi", []):
		var st := str(d.get("stato", ""))
		if st == "disponibile":
			per_colore.get(Prova.colore(d), per_colore["red"]).append(d)
		elif st == "speso":
			spesi.append(d)
		elif st == "sacrificato":
			sacrificati += 1
	for col in per_colore:
		var slot: Array = dati["slot"].get(col, [])
		for k in (per_colore[col] as Array).size():
			var r: Rect2
			if k < slot.size():
				r = Rect2(slot[k][0], slot[k][1], slot[k][2], slot[k][3])
			else:
				var ultimo: Array = slot[-1] if not slot.is_empty() else [0.04, 0.115, 0.09, 0.13]
				r = Rect2(ultimo[0], ultimo[1] + 0.03 * (k - slot.size() + 1), ultimo[2], ultimo[3])
			_base.add_child(_dado(per_colore[col][k], r.grow(-r.size.x * 0.12), false))
	# Dadi Spesi: con la faccia che avevano nella Prova
	for k in spesi.size():
		var cx := SPESI.position.x + float(k % 3) * SPESI.size.x / 3.0
		var cy := SPESI.position.y + float(k / 3) * SPESI.size.y / 6.0
		var r2 := Rect2(cx, cy, SPESI.size.x / 3.0, SPESI.size.y / 6.0)
		_base.add_child(_dado(spesi[k], r2.grow(-r2.size.x * 0.14), true))
	# Cariche
	var lc := Label.new()
	lc.text = "CARICHE  " + "●".repeat(int(membro.get("cariche", 0))) + ("" if int(membro.get("cariche", 0)) > 0 else "—")
	_testo(lc, CARICHE, Color("ffd36e"))
	# Ferite e dadi Ferita
	var ferite: Array = membro.get("ferite", [])
	for k in mini(ferite.size(), 3):
		var lf := Label.new()
		lf.text = str(_nome_ferita(str(ferite[k]))).to_upper()
		_testo(lf, FERITE[k], Color("ff8a80"))
	if int(membro.get("dadi_ferita", 0)) > 0:
		var ld := Label.new()
		ld.text = "dadi Ferita: %d" % int(membro["dadi_ferita"])
		_testo(ld, Rect2(0.69, 0.83, 0.26, 0.05), Color("e8c21a"))
	# mazzo, scarti e dadi sacrificati
	var lm := Label.new()
	lm.text = "%d" % (membro.get("mazzo", []) as Array).size()
	_testo(lm, Rect2(0.0, 0.14, 0.035, 0.06), Color("ffd36e"))
	var ls := Label.new()
	ls.text = "%d" % (membro.get("scarti", []) as Array).size()
	_testo(ls, Rect2(0.965, 0.14, 0.035, 0.06), Color("ffd36e"))
	if sacrificati > 0:
		var lx := Label.new()
		lx.text = "%d sacrificati" % sacrificati
		_testo(lx, Rect2(0.04, 0.965, 0.29, 0.035), Color("ff8a80"))
	if membro.get("morto", false):
		var vel := ColorRect.new()
		vel.color = Color(0, 0, 0, 0.6)
		vel.set_anchors_preset(Control.PRESET_FULL_RECT)
		vel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_base.add_child(vel)

static func _nome_ferita(t: String) -> String:
	return {"wounded": "Lesione", "panicked": "Panico", "freezing": "Congelamento", "exhausted": "Allo Stremo", "critically_wounded": "Lesione Grave",
		"burned": "Ustione", "just_a_scratch": "Niente di Grave"}.get(t, t)

func _ancora(c: Control, r: Rect2) -> void:
	c.anchor_left = r.position.x
	c.anchor_top = r.position.y
	c.anchor_right = r.position.x + r.size.x
	c.anchor_bottom = r.position.y + r.size.y
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _testo(l: Label, r: Rect2, col: Color) -> void:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.clip_text = true
	_ancora(l, r)
	l.set_meta("h", r.size.y)
	_base.add_child(l)
	_scala_testi()

## Il testo segue la dimensione della plancia (calcolato dall'altezza della plancia, non dell'etichetta).
func _scala_testi() -> void:
	if _base == null or _base.size.y <= 1:
		return
	for c in _base.get_children():
		if c is Label and c.has_meta("h"):
			c.add_theme_font_size_override("font_size", clampi(int(_base.size.y * float(c.get_meta("h")) * 0.6), 8, 40))

## Un dado sulla plancia: colore del dado con la sua icona (quella del tipo, o la faccia se è speso).
func _dado(d: Dictionary, r: Rect2, faccia: bool) -> Control:
	var p := Panel.new()
	var col: Color = COLORI.get(Prova.colore(d), Color.GRAY)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(6)
	sb.border_color = Color(1, 1, 1, 0.85)
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	_ancora(p, r)
	var ic: Array = Prova.icone(d) if faccia else [_icona_tipo(d)]
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	for x in ic:
		var path := Dati.icona(str(x))
		if path == "":
			continue
		var t := TextureRect.new()
		t.texture = load(path)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.modulate = Color(1, 1, 1, 0.95)
		h.add_child(t)
	p.tooltip_text = "%s%s" % [str(d.get("tipo", "")), (" — " + "+".join(Prova.icone(d))) if faccia else ""]
	return p

## Icona che identifica il tipo di dado (la specializzazione, o basic per i dadi base).
static func _icona_tipo(d: Dictionary) -> String:
	var t := str(d.get("tipo", ""))
	if t.begins_with("base_"):
		return "basic"
	var facce: Array = Prova.defs()["reparto"].get(t, {}).get("facce", [])
	for f in facce:
		for x in f:
			if not str(x) in ["basic", "vanguard", "accident"]:
				return str(x)
	return "vanguard"
