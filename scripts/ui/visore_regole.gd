## Visore delle pagine del regolamento e del riassunto delle regole (immagini dai PDF del modulo TTS).
class_name VisoreRegole
extends Control

const LIBRI := {
	"regolamento": {"nome": "Regolamento (inglese)", "pagine": 48},
	"riassunto": {"nome": "Riassunto regole EOG (inglese)", "pagine": 9},
}

var _libro := "regolamento"
var _pagina := 1
var _img: TextureRect
var _etich: Label
var _zoom := false
var _scroll: ScrollContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Tema.tema
	var vel := ColorRect.new()
	vel.color = Color(0, 0.01, 0.03, 0.92)
	vel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 30
	v.offset_right = -30
	v.offset_top = 20
	v.offset_bottom = -20
	add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	for k in LIBRI:
		h.add_child(Tema.pulsante(LIBRI[k]["nome"].to_upper(), _apri.bind(k, 1), 13))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	h.add_child(Tema.pulsante("◀", func(): _vai(-1), 16))
	_etich = Tema.etichetta("", 15, Tema.CIANO)
	_etich.custom_minimum_size = Vector2(160, 0)
	_etich.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(_etich)
	h.add_child(Tema.pulsante("▶", func(): _vai(1), 16))
	h.add_child(Tema.pulsante("ZOOM", func(): _zoom = not _zoom; _mostra(), 13))
	h.add_child(Tema.pulsante("✕ CHIUDI", queue_free, 13))
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_scroll)
	_img = TextureRect.new()
	_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_img.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_img.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_img)
	_apri("regolamento", 1)

func _apri(k: String, p: int) -> void:
	_libro = k
	_pagina = p
	_mostra()

func _vai(d: int) -> void:
	_pagina = clampi(_pagina + d, 1, LIBRI[_libro]["pagine"])
	_mostra()

func _mostra() -> void:
	_etich.text = "PAG. %d / %d" % [_pagina, LIBRI[_libro]["pagine"]]
	var n: int = LIBRI[_libro]["pagine"]
	var rel := "regole/%s-%s.webp" % [_libro, str(_pagina).pad_zeros(2 if n >= 10 else 1)]
	var pag := _pagina
	Immagini.carica(rel, func(t):
		if pag == _pagina and is_instance_valid(_img):
			_img.texture = t
			_aggiorna_dim())

func _aggiorna_dim() -> void:
	if _img.texture == null:
		return
	if _zoom:
		var w := _scroll.size.x - 20
		_img.custom_minimum_size = Vector2(w, w * _img.texture.get_height() / _img.texture.get_width())
	else:
		_img.custom_minimum_size = Vector2(0, _scroll.size.y)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		if e.keycode in [KEY_RIGHT, KEY_PAGEDOWN]:
			_vai(1)
		elif e.keycode in [KEY_LEFT, KEY_PAGEUP]:
			_vai(-1)
		elif e.keycode == KEY_ESCAPE:
			queue_free()
		get_viewport().set_input_as_handled()
