## Finestra per iniziare una nuova campagna: campagna, nome della missione e modalità.
class_name NuovaCampagna
extends Control

signal confermata(camp: int, nome: String, modo: String)

const MODI := [
	["campagna", "Campagna completa", "Si parte dall'annotazione iniziale e si prepara il gioco seguendo il regolamento."],
	["rapido", "Inizio rapido", "Come nel regolamento (pag. 28): equipaggio e nave già pronti, si parte subito dal primo pianeta."],
	["tutorial", "Tutorial", "Le annotazioni seguono la versione tutorial, con le spiegazioni passo per passo."],
	["operazioni", "Solo Operazioni", "Scenari singoli fuori dalla campagna (Operazioni del Logbook)."],
]

var _camp := 8
var _modo := "campagna"
var _nome: LineEdit
var _bottoni_camp := {}
var _bottoni_modo := {}
var _desc: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Tema.tema
	var vel := ColorRect.new()
	vel.color = Color(0, 0.01, 0.03, 0.82)
	vel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vel)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(1100, 0)
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	v.add_child(Tema.etichetta("NUOVA CAMPAGNA", 24, Tema.TESTO, true))
	v.add_child(Tema.etichetta("CAMPAGNA", 13, Tema.CIANO))
	var hc := HBoxContainer.new()
	hc.add_theme_constant_override("separation", 14)
	v.add_child(hc)
	for id in Dati.CAMPAGNE:
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(340, 250)
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tr := TextureRect.new()
		tr.texture = load(Dati.CAMPAGNE[id]["copertina"])
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.custom_minimum_size = Vector2(330, 196)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(tr)
		var l := Tema.etichetta(Dati.CAMPAGNE[id]["nome"].to_upper(), 16)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(l)
		b.add_child(vb)
		b.pressed.connect(_scegli_camp.bind(id))
		hc.add_child(b)
		_bottoni_camp[id] = b
	var nota := Label.new()
	nota.text = "Deadly Frontier e Lost Fleet: sono disponibili tutti i paragrafi del Logbook, mentre sul tavolo ci sono solo i componenti del gioco base."
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.add_theme_color_override("font_color", Tema.TESTO_2)
	nota.add_theme_font_size_override("font_size", 15)
	v.add_child(nota)
	v.add_child(Tema.etichetta("MODALITÀ", 13, Tema.CIANO))
	var hm := HBoxContainer.new()
	hm.add_theme_constant_override("separation", 8)
	v.add_child(hm)
	for m in MODI:
		var b := Tema.pulsante(m[1].to_upper(), _scegli_modo.bind(m[0]), 14)
		b.toggle_mode = true
		hm.add_child(b)
		_bottoni_modo[m[0]] = b
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.add_theme_color_override("font_color", Tema.TESTO_2)
	v.add_child(_desc)
	v.add_child(Tema.etichetta("NOME DELLA CAMPAGNA", 13, Tema.CIANO))
	_nome = LineEdit.new()
	_nome.text = "Missione %s" % Time.get_date_string_from_system()
	_nome.max_length = 40
	v.add_child(_nome)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_END
	hb.add_theme_constant_override("separation", 10)
	v.add_child(hb)
	hb.add_child(Tema.pulsante("ANNULLA", queue_free, 16))
	hb.add_child(Tema.pulsante_primario("INIZIA", func():
		confermata.emit(_camp, _nome.text.strip_edges() if _nome.text.strip_edges() != "" else "Missione", _modo)
		queue_free(), 18))
	_scegli_camp(8)
	_scegli_modo("campagna")

func _scegli_camp(id: int) -> void:
	_camp = id
	for k in _bottoni_camp:
		_bottoni_camp[k].button_pressed = k == id
	_bottoni_modo.get("tutorial", Button.new()).disabled = id != 8
	_bottoni_modo.get("rapido", Button.new()).disabled = id != 8
	if id != 8 and _modo in ["tutorial", "rapido"]:
		_scegli_modo("campagna")

func _scegli_modo(m: String) -> void:
	_modo = m
	for k in _bottoni_modo:
		_bottoni_modo[k].button_pressed = k == m
	for x in MODI:
		if x[0] == m:
			_desc.text = x[2]
