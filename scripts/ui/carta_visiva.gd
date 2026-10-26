## Una carta vera (immagine del modulo) da mettere "sul tavolo" nelle schermate della nave: sopra
## un'eventuale fascetta di stato, sotto i pulsanti delle azioni. Al passaggio del mouse si illumina,
## con un clic si apre ingrandita (segnale ingrandisci). Spenta = grigia (non si può usare ora).
class_name CartaVisiva
extends VBoxContainer

signal ingrandisci

var file := ""
var larghezza := 150.0
var rapporto := 1.4          # altezza / larghezza
var fascetta := ""
var colore_fascetta := Color("ffb347")
var spenta := false
var azioni: Array = []       # [[testo, Callable, abilitato]]
var didascalia := ""

var _cornice: PanelContainer
var _sb: StyleBoxFlat

static func nuova(f: String, larg := 150.0, rap := 1.4) -> CartaVisiva:
	var c := CartaVisiva.new()
	c.file = f
	c.larghezza = larg
	c.rapporto = rap
	return c

## Rapporto altezza/larghezza tipico per cartella (le carte del modulo hanno tre formati).
static func rapporto_di(f: String) -> float:
	if f.contains("unavailable_equipment") or f.contains("equipment"):
		return 1.0
	for k in ["bridge_cards", "_discoveries", "lander_mods", "wounded", "events"]:
		if f.contains(k):
			return 1.5
	return 1.4

func _ready() -> void:
	add_theme_constant_override("separation", 4)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if fascetta != "":
		var l := Label.new()
		l.text = fascetta
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(larghezza, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_override("font", Tema.titolo)
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", colore_fascetta)
		add_child(l)
	_cornice = PanelContainer.new()
	_sb = StyleBoxFlat.new()
	_sb.bg_color = Color(0, 0, 0, 0.4)
	_sb.border_color = Color(1, 1, 1, 0.12)
	_sb.set_border_width_all(2)
	_sb.set_corner_radius_all(8)
	_sb.set_content_margin_all(2)
	_sb.shadow_color = Color(0, 0, 0, 0.5)
	_sb.shadow_size = 6
	_cornice.add_theme_stylebox_override("panel", _sb)
	_cornice.mouse_filter = Control.MOUSE_FILTER_STOP
	_cornice.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_cornice.tooltip_text = (didascalia + "\n" if didascalia != "" else "") + "Clic: ingrandisci"
	add_child(_cornice)
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(larghezza, larghezza * rapporto)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if spenta:
		tr.modulate = Color(0.55, 0.55, 0.6)
	_cornice.add_child(tr)
	if file != "":
		Immagini.carica(file, func(t):
			if is_instance_valid(tr) and t:
				tr.texture = t
				# l'altezza segue l'immagine vera (carte verticali, mazzi orizzontali, segnalini quadrati)
				tr.custom_minimum_size = Vector2(larghezza, larghezza * float(t.get_height()) / max(1.0, float(t.get_width()))))
	_cornice.mouse_entered.connect(func():
		_sb.border_color = Tema.CIANO
		_cornice.pivot_offset = _cornice.size / 2
		create_tween().tween_property(_cornice, "scale", Vector2(1.04, 1.04), 0.08))
	_cornice.mouse_exited.connect(func():
		_sb.border_color = Color(1, 1, 1, 0.12)
		create_tween().tween_property(_cornice, "scale", Vector2.ONE, 0.08))
	_cornice.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			ingrandisci.emit())
	for a in azioni:
		var b := Tema.pulsante(str(a[0]), a[1], 11)
		b.custom_minimum_size = Vector2(larghezza, 0)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.tooltip_text = str(a[0])
		b.disabled = a.size() > 2 and not bool(a[2])
		add_child(b)

## Riquadro vuoto delle stesse dimensioni di una carta (uno slot libero sul tavolo).
static func slot(testo: String, larg := 150.0, rap := 1.4) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.07, 0.13, 0.6)
	sb.border_color = Color(Tema.CIANO, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(larg + 4, larg * rap + 4)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var l := Label.new()
	l.text = testo
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(Tema.CIANO, 0.6))
	p.add_child(l)
	return p
