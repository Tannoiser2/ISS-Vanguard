## Tema grafico fantascientifico: blu notte, ciano dei terminali di bordo, rosso Vanguard.
## Font: Orbitron per i titoli (come le intestazioni delle carte), Exo 2 per il testo,
## Share Tech Mono per numeri e codici (tutti SIL Open Font License).
extends Node

const FONDO := Color("050b18")
const PANNELLO := Color(0.03, 0.07, 0.15, 0.93)
const PANNELLO_2 := Color(0.06, 0.12, 0.24, 0.95)
const BORDO := Color("2b6f9e")
const CIANO := Color("4fd1ff")
const CIANO_SCURO := Color("1d5f82")
const ROSSO := Color("e84060")
const AMBRA := Color("ffb347")
const VERDE := Color("5be39b")
const TESTO := Color("e6f4ff")
const TESTO_2 := Color("9fbbd6")

var titolo: FontVariation
var titolo_forte: FontVariation
var testo: FontFile
var testo_corsivo: FontFile
var testo_grassetto: FontFile
var testo_grassetto_corsivo: FontFile
var mono: FontFile
var tema: Theme

func _ready() -> void:
	var ext_r := _f("exo-2-latin-ext-400-normal")
	var ext_i := _f("exo-2-latin-ext-400-italic")
	var ext_b := _f("exo-2-latin-ext-600-normal")
	var ext_bi := _f("exo-2-latin-ext-600-italic")
	testo = _f("exo-2-latin-400-normal", [ext_r])
	testo_corsivo = _f("exo-2-latin-400-italic", [ext_i])
	testo_grassetto = _f("exo-2-latin-600-normal", [ext_b])
	testo_grassetto_corsivo = _f("exo-2-latin-600-italic", [ext_bi])
	mono = _f("share-tech-mono-latin-400-normal", [testo])
	var orb := _f("orbitron-latin-700-normal", [testo_grassetto])
	titolo = FontVariation.new()
	titolo.base_font = orb
	titolo.spacing_glyph = 1
	var orb9 := _f("orbitron-latin-900-normal", [testo_grassetto])
	titolo_forte = FontVariation.new()
	titolo_forte.base_font = orb9
	titolo_forte.spacing_glyph = 2
	tema = _crea_tema()

func _f(nome: String, fallback: Array = []) -> FontFile:
	var f: FontFile = load("res://assets/font/%s.woff2" % nome)
	if f == null:
		return ThemeDB.fallback_font as FontFile
	f = f.duplicate()
	f.fallbacks = fallback
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	return f

func box(fondo: Color, bordo: Color = BORDO, spessore := 1, raggio := 4, margine := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = bordo
	s.set_border_width_all(spessore)
	s.set_corner_radius_all(raggio)
	s.content_margin_left = margine
	s.content_margin_right = margine
	s.content_margin_top = margine * 0.6
	s.content_margin_bottom = margine * 0.6
	s.anti_aliasing = true
	return s

## Pannello con l'angolo "tagliato" tipico delle interfacce di bordo.
func box_hud(fondo: Color = PANNELLO, bordo: Color = BORDO) -> StyleBoxFlat:
	var s := box(fondo, bordo, 1, 0, 14)
	s.corner_radius_top_left = 0
	s.corner_radius_bottom_right = 14
	s.corner_detail = 1
	s.border_width_left = 3
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 8
	return s

func _crea_tema() -> Theme:
	var t := Theme.new()
	t.default_font = testo
	t.default_font_size = 20
	# pulsanti
	var n := box(Color(0.05, 0.13, 0.25, 0.95), CIANO_SCURO, 1, 3, 14)
	var h := box(Color(0.08, 0.22, 0.38, 1), CIANO, 1, 3, 14)
	var p := box(Color(0.12, 0.32, 0.5, 1), CIANO, 2, 3, 14)
	var d := box(Color(0.04, 0.07, 0.12, 0.8), Color(0.2, 0.25, 0.32), 1, 3, 14)
	for k in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb: StyleBox = {"normal": n, "hover": h, "pressed": p, "disabled": d, "focus": h}[k]
		t.set_stylebox(k, "Button", sb)
		t.set_stylebox(k, "OptionButton", sb)
		t.set_stylebox(k, "MenuButton", sb)
	t.set_font("font", "Button", titolo)
	t.set_font_size("font_size", "Button", 16)
	t.set_color("font_color", "Button", TESTO)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", CIANO)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.5, 0.58))
	t.set_font("font", "OptionButton", testo_grassetto)
	# etichette
	t.set_color("font_color", "Label", TESTO)
	t.set_color("default_color", "RichTextLabel", TESTO)
	t.set_font("normal_font", "RichTextLabel", testo)
	t.set_font("italics_font", "RichTextLabel", testo_corsivo)
	t.set_font("bold_font", "RichTextLabel", testo_grassetto)
	t.set_font("bold_italics_font", "RichTextLabel", testo_grassetto_corsivo)
	t.set_font("mono_font", "RichTextLabel", mono)
	for k in ["normal_font_size", "italics_font_size", "bold_font_size", "bold_italics_font_size", "mono_font_size"]:
		t.set_font_size(k, "RichTextLabel", 20)
	# pannelli
	t.set_stylebox("panel", "PanelContainer", box_hud())
	t.set_stylebox("panel", "Panel", box_hud())
	t.set_stylebox("panel", "PopupPanel", box_hud(PANNELLO_2, CIANO))
	t.set_stylebox("panel", "PopupMenu", box(PANNELLO_2, CIANO, 1, 3, 8))
	t.set_stylebox("hover", "PopupMenu", box(Color(0.1, 0.3, 0.5), CIANO, 0, 2, 8))
	t.set_font("font", "PopupMenu", testo)
	t.set_font_size("font_size", "PopupMenu", 18)
	t.set_stylebox("panel", "AcceptDialog", box_hud(PANNELLO_2, CIANO))
	t.set_stylebox("embedded_border", "Window", box_hud(PANNELLO_2, CIANO))
	t.set_font("title_font", "Window", titolo)
	# campi di testo
	var le := box(Color(0.02, 0.05, 0.1, 1), CIANO_SCURO, 1, 3, 10)
	var lef := box(Color(0.02, 0.06, 0.12, 1), CIANO, 1, 3, 10)
	for c in ["LineEdit", "TextEdit", "SpinBox"]:
		t.set_stylebox("normal", c, le)
		t.set_stylebox("focus", c, lef)
		t.set_font("font", c, mono)
		t.set_font_size("font_size", c, 20)
	t.set_color("caret_color", "LineEdit", CIANO)
	t.set_color("selection_color", "LineEdit", Color(0.2, 0.5, 0.8, 0.5))
	# barre di scorrimento sottili
	var g := box(Color(0.2, 0.5, 0.7, 0.6), Color(0, 0, 0, 0), 0, 3, 0)
	var gh := box(CIANO, Color(0, 0, 0, 0), 0, 3, 0)
	var sc := box(Color(0, 0, 0, 0.2), Color(0, 0, 0, 0), 0, 3, 0)
	sc.content_margin_left = 4
	sc.content_margin_right = 4
	for c in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("grabber", c, g)
		t.set_stylebox("grabber_highlight", c, gh)
		t.set_stylebox("grabber_pressed", c, gh)
		t.set_stylebox("scroll", c, sc)
	t.set_stylebox("panel", "TooltipPanel", box(PANNELLO_2, CIANO, 1, 3, 8))
	t.set_font("font", "TooltipLabel", testo)
	t.set_font_size("font_size", "TooltipLabel", 17)
	t.set_color("font_color", "TooltipLabel", TESTO)
	t.set_stylebox("panel", "TabContainer", box(PANNELLO, BORDO, 1, 0, 8))
	t.set_stylebox("tab_selected", "TabContainer", box(Color(0.08, 0.22, 0.38), CIANO, 1, 0, 12))
	t.set_stylebox("tab_unselected", "TabContainer", box(Color(0.03, 0.08, 0.15), CIANO_SCURO, 1, 0, 12))
	t.set_stylebox("tab_hovered", "TabContainer", box(Color(0.06, 0.16, 0.3), CIANO, 1, 0, 12))
	t.set_font("font", "TabContainer", titolo)
	t.set_font_size("font_size", "TabContainer", 14)
	t.set_stylebox("separator", "HSeparator", box(CIANO_SCURO, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_constant("separation", "HSeparator", 8)
	var chk := box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 4)
	t.set_stylebox("normal", "CheckBox", chk)
	t.set_stylebox("hover", "CheckBox", chk)
	t.set_stylebox("pressed", "CheckBox", chk)
	t.set_font("font", "CheckBox", testo)
	t.set_font_size("font_size", "CheckBox", 18)
	return t

## Etichetta con il font dei titoli.
func etichetta(testo_: String, dim := 18, colore := TESTO, forte := false) -> Label:
	var l := Label.new()
	l.text = testo_
	l.add_theme_font_override("font", titolo_forte if forte else titolo)
	l.add_theme_font_size_override("font_size", dim)
	l.add_theme_color_override("font_color", colore)
	return l

func pulsante(testo_: String, cb: Callable = Callable(), dim := 16) -> Button:
	var b := Button.new()
	b.text = testo_
	b.add_theme_font_size_override("font_size", dim)
	b.focus_mode = Control.FOCUS_NONE
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

## Pulsante in evidenza (azione principale).
func pulsante_primario(testo_: String, cb: Callable = Callable(), dim := 18) -> Button:
	var b := pulsante(testo_, cb, dim)
	b.add_theme_stylebox_override("normal", box(Color(0.42, 0.08, 0.16, 0.95), ROSSO, 1, 3, 18))
	b.add_theme_stylebox_override("hover", box(Color(0.6, 0.12, 0.22, 1), Color("ff8fa3"), 1, 3, 18))
	b.add_theme_stylebox_override("pressed", box(Color(0.75, 0.15, 0.27, 1), Color.WHITE, 2, 3, 18))
	return b

func testo_ricco(dim := 20) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.selection_enabled = false
	for k in ["normal_font_size", "italics_font_size", "bold_font_size", "bold_italics_font_size"]:
		r.add_theme_font_size_override(k, dim)
	r.add_theme_constant_override("line_separation", 4)
	return r
