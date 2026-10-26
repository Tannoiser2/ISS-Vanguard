## Mappa stellare visiva (Ship Book pag. 5): a sinistra la pagina vera del libro delle Mappe dei Sistemi con
## le zone cliccabili (sistemi in uscita e destinazioni numerate), a destra la mappa d'insieme della rotta
## della Vanguard: i sistemi come stelle collegate dalle rotte, con la posizione attuale, i sistemi già
## visitati e quelli raggiungibili adesso (con il costo in Energia). Le azioni le esegue la Gestione della Nave.
class_name MappaStellare
extends HBoxContainer

signal vola(indice: int)          # indice della rotta del sistema attuale
signal visita(numero: int)        # numero della destinazione

const RAPPORTO_PAGINA := 1500.0 / 2143.0
static var _zone := {}
static var _galassia := {}

var sistema := ""                 # nome del sistema attuale (chiave di Carte.db["sistemi"])
var visitati: Array = []
var rotte: Array = []             # [{"verso", "energia", "ok", "perche"}] nell'ordine della pagina
var destinazioni: Array = []      # [{"n", "nome", "energia", "ok", "perche"}]
var altezza := 700.0

static func _dati() -> void:
	if _zone.is_empty():
		_zone = JSON.parse_string(FileAccess.get_file_as_string("res://data/mappe_sistemi.json"))
		_galassia = JSON.parse_string(FileAccess.get_file_as_string("res://data/galassia.json"))

func _ready() -> void:
	_dati()
	add_theme_constant_override("separation", 14)
	add_child(_pagina())
	var g := Galassia.new()
	g.mappa = self
	g.custom_minimum_size = Vector2(altezza * 0.95, altezza)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(g)

# ------------------------------------------------------------------ pagina del sistema

func _pagina() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(altezza * RAPPORTO_PAGINA, altezza)
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(tr)
	var sis: Dictionary = Carte.db.get("sistemi", {}).get(sistema, {})
	Immagini.carica(str(sis.get("file", "")), func(t): if is_instance_valid(tr): tr.texture = t)
	var z: Dictionary = _zone.get(sistema, {})
	for r in z.get("rotte", []):
		var k := int(r[0])
		if k >= rotte.size():
			continue
		var rt: Dictionary = rotte[k]
		var b := _zona(Rect2(r[1], r[2], r[3], r[4]), bool(rt["ok"]),
			"→ %s · %d Energia%s" % [rt["verso"], int(rt["energia"]), ("\n" + str(rt["perche"])) if not rt["ok"] else "\nClic: vola verso questo sistema"])
		var kk := k
		b.pressed.connect(func(): vola.emit(kk))
		c.add_child(b)
	for r in z.get("dest", []):
		var n := int(r[0])
		var dd := destinazioni.filter(func(x): return int(x["n"]) == n)
		if dd.is_empty():
			continue
		var d: Dictionary = dd[0]
		var b2 := _zona(Rect2(r[1], r[2], r[3], r[4]), bool(d["ok"]),
			"(%d) %s · %d Energia%s" % [n, d["nome"], int(d["energia"]), ("\n" + str(d["perche"])) if not d["ok"] else "\nClic: visita"])
		var nn := n
		b2.pressed.connect(func(): visita.emit(nn))
		c.add_child(b2)
	return c

## Zona cliccabile trasparente sopra la pagina: si illumina al passaggio del mouse.
func _zona(r: Rect2, ok: bool, suggerimento: String) -> Button:
	var b := Button.new()
	b.flat = false
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = suggerimento
	b.anchor_left = r.position.x
	b.anchor_top = r.position.y
	b.anchor_right = r.position.x + r.size.x
	b.anchor_bottom = r.position.y + r.size.y
	var vuoto := StyleBoxFlat.new()
	vuoto.bg_color = Color(0, 0, 0, 0)
	vuoto.border_color = Color(Tema.CIANO, 0.6) if ok else Color(1, 1, 1, 0)
	vuoto.set_border_width_all(2)
	vuoto.set_corner_radius_all(6)
	var luce := StyleBoxFlat.new()
	luce.bg_color = Color(Tema.CIANO, 0.18) if ok else Color(0.6, 0.1, 0.1, 0.18)
	luce.border_color = Tema.CIANO if ok else Color(1, 0.4, 0.4)
	luce.set_border_width_all(2)
	luce.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", vuoto)
	b.add_theme_stylebox_override("hover", luce)
	b.add_theme_stylebox_override("pressed", luce)
	var spento := vuoto.duplicate()
	spento.border_color = Color(1, 0.4, 0.4, 0.3)
	b.add_theme_stylebox_override("disabled", spento)
	b.disabled = not ok
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if ok else Control.CURSOR_FORBIDDEN
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	return b

# ------------------------------------------------------------------ mappa d'insieme

class Galassia extends Control:
	var mappa: MappaStellare
	var _sopra := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true

	func _pos(n: String) -> Vector2:
		var p: Array = MappaStellare._galassia.get(n.to_upper(), [0.5, 0.5])
		# a destra più spazio: i nomi stanno alla destra della stella
		return Vector2(30 + float(p[0]) * (size.x - 30 - 150), 64 + float(p[1]) * (size.y - 64 - 56))

	func _raggiungibile(n: String) -> Dictionary:
		for k in mappa.rotte.size():
			if str(mappa.rotte[k]["verso"]).to_upper() == n.to_upper():
				var r: Dictionary = mappa.rotte[k].duplicate()
				r["indice"] = k
				return r
		return {}

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.025, 0.05, 0.95))
		# stelline di sfondo (sempre uguali)
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		for i in 220:
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			draw_circle(p, rng.randf_range(0.4, 1.3), Color(0.7, 0.8, 1.0, rng.randf_range(0.15, 0.5)))
		var font := Tema.titolo
		draw_string(font, Vector2(14, 26), "ROTTA DELLA VANGUARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Tema.CIANO)
		var sistemi: Dictionary = Carte.db.get("sistemi", {})
		var att := mappa.sistema.to_upper()
		# rotte
		for nome in sistemi:
			for rt in sistemi[nome].get("rotte", []):
				var v := str(rt.get("verso", "")).to_upper()
				if not MappaStellare._galassia.has(v):
					continue
				var da := _pos(nome)
				var a := _pos(v)
				var attiva: bool = str(nome).to_upper() == att
				var col := Color(0.35, 0.55, 0.8, 0.25)
				if attiva:
					col = Color(1.0, 0.75, 0.3, 0.9) if bool(_raggiungibile(v).get("ok", false)) else Color(0.8, 0.35, 0.35, 0.6)
				draw_line(da, a, col, 2.5 if attiva else 1.2, true)
				if attiva:
					var r := _raggiungibile(v)
					var mezzo := da.lerp(a, 0.5)
					var perp := (a - da).orthogonal().normalized() * 14.0
					if perp.y > 0:
						perp = -perp
					var et := "%d En" % int(r.get("energia", 0))
					var lw := font.get_string_size(et, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
					var pe := mezzo + perp - Vector2(lw / 2.0, -5)
					draw_rect(Rect2(pe + Vector2(-4, -15), Vector2(lw + 8, 20)), Color(0.02, 0.04, 0.08, 0.85))
					draw_string(font, pe, et, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.85, 0.45))
		# stelle
		for nome in sistemi:
			var n := str(nome).to_upper()
			var p := _pos(n)
			var visto := n in mappa.visitati.map(func(x): return str(x).to_upper())
			var r := _raggiungibile(n)
			var col := Color(0.55, 0.62, 0.75)
			var raggio := 6.0
			if visto:
				col = Color(0.92, 0.95, 1.0)
			if not r.is_empty():
				col = Color(1.0, 0.78, 0.3) if r.get("ok", false) else Color(0.85, 0.4, 0.4)
				raggio = 8.0
			if n == att:
				draw_circle(p, 18, Color(Tema.CIANO, 0.18))
				draw_arc(p, 13, 0, TAU, 32, Tema.CIANO, 2.0, true)
				col = Tema.CIANO
				raggio = 9.0
			if n == _sopra and not r.is_empty():
				draw_arc(p, raggio + 6, 0, TAU, 28, Color.WHITE, 1.5, true)
			draw_circle(p, raggio, col)
			draw_string(font, p + Vector2(12, 5), str(sistemi[nome].get("nome", nome)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13 if n != att else 15, col.lightened(0.2))
		# legenda
		var y := size.y - 14
		var x := 18.0
		for v in [[Tema.CIANO, "Vanguard"], [Color(1.0, 0.78, 0.3), "raggiungibile (clic)"], [Color(0.85, 0.4, 0.4), "non raggiungibile"], [Color(0.92, 0.95, 1.0), "visitato"]]:
			draw_circle(Vector2(x, y - 4), 5, v[0])
			draw_string(font, Vector2(x + 10, y), v[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Tema.TESTO_2)
			x += 28 + font.get_string_size(v[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x

	func _stella_in(p: Vector2) -> String:
		for nome in Carte.db.get("sistemi", {}):
			if _pos(str(nome)).distance_to(p) < 16:
				return str(nome).to_upper()
		return ""

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion:
			var s := _stella_in(e.position)
			if s != _sopra:
				_sopra = s
				var r := _raggiungibile(s)
				tooltip_text = "" if r.is_empty() else ("%s · %d Energia%s" % [r["verso"], int(r["energia"]), ("\n" + str(r["perche"])) if not r["ok"] else "\nClic: vola"])
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if bool(r.get("ok", false)) else Control.CURSOR_ARROW
				queue_redraw()
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			var r2 := _raggiungibile(_stella_in(e.position))
			if bool(r2.get("ok", false)):
				mappa.vola.emit(int(r2["indice"]))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()
