## Schermata dell'esplorazione planetaria: solo la plancia del pianeta (niente astronave),
## con i settori, la Squadra di Sbarco, le azioni del turno e il Logbook a portata di mano.
## Il motore (Esplorazione) tiene lo stato; qui si mostrano le scelte e si applicano gli effetti
## delle carte: quello che il programma riconosce lo esegue da solo, il resto lo elenca da fare a mano.
class_name Missione
extends Control

signal chiusa          # torna alla nave (l'esplorazione resta salvata)

signal _scelto(i: int)

const AR_PIANETA := 2.0121
const NOMI_SCOPERTE := {"mineral": "Minerale", "microorganism": "Microrganismo", "live_specimen": "Esemplare vivo",
	"strange_flora": "Flora strana", "alien_tech": "Tecnologia aliena"}
const NOMI_FERITE := {"wounded": "Ferito", "panicked": "In preda al panico", "freezing": "Congelato", "exhausted": "Allo stremo",
	"critically_wounded": "Ferito gravemente", "burned": "Ustionato", "just_a_scratch": "Solo un graffio!"}
const REP_EN := {"ingegneria": "engineering", "ricognizione": "recon", "scienza": "science", "sicurezza": "security"}

var esp: Esplorazione
var pl: Dictionary = {}
var _sel := 0
var _destinazione := 0
var _occupato := false

var _plancia: TextureRect
var _sovra: Control
var _widget := {}          # n settore -> {"box", "img", "crew", "info"}
var _info: RichTextLabel
var _pannello: VBoxContainer
var _logbook: PannelloLogbook
var _toast: Label
var _toast_tw: Tween
var _pulsanti := {}

# ------------------------------------------------------------------ avvio

func _init(stato: Dictionary) -> void:
	esp = Esplorazione.new(stato)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Tema.tema
	pl = Carte.pianeta(str(esp.s.get("pagina", "")))
	var fondo := ColorRect.new()
	fondo.color = Color(0.008, 0.016, 0.035)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var radice := VBoxContainer.new()
	radice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	radice.add_theme_constant_override("separation", 0)
	add_child(radice)
	radice.add_child(_barra_alta())
	var corpo := HBoxContainer.new()
	corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_theme_constant_override("separation", 0)
	radice.add_child(corpo)
	# plancia
	var area := Control.new()
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.clip_contents = true
	corpo.add_child(area)
	_plancia = TextureRect.new()
	_plancia.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_plancia.offset_left = 10
	_plancia.offset_top = 10
	_plancia.offset_right = -10
	_plancia.offset_bottom = -10
	_plancia.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plancia.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	area.add_child(_plancia)
	_sovra = Control.new()
	_sovra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sovra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plancia.add_child(_sovra)
	_plancia.resized.connect(_disponi)
	var img := Carte.img_pianeta(str(esp.s.get("pagina", "")))
	if img != "":
		Immagini.carica(img, func(t):
			_plancia.texture = t
			_disponi())
	# pannello laterale
	var lato := PanelContainer.new()
	lato.custom_minimum_size = Vector2(500, 0)
	lato.add_theme_stylebox_override("panel", Tema.box(Color(0.02, 0.045, 0.09, 0.97), Tema.CIANO_SCURO, 1, 0, 10))
	corpo.add_child(lato)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lato.add_child(sc)
	_pannello = VBoxContainer.new()
	_pannello.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pannello.add_theme_constant_override("separation", 8)
	sc.add_child(_pannello)
	radice.add_child(_barra_azioni())
	# Logbook sopra a tutto, a destra
	_logbook = PannelloLogbook.new()
	_logbook.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_logbook.offset_left = -660
	_logbook.offset_top = 60
	_logbook.offset_bottom = -70
	_logbook.offset_right = -10
	add_child(_logbook)
	_logbook.imposta(Campagna.motore)
	_logbook.chiuso.connect(func(): _logbook.visible = false)
	_logbook.chiedi_carta.connect(_carta_dal_logbook)
	_logbook.visible = false
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 64
	_toast.offset_left = -500
	_toast.offset_right = 500
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_font_override("font", Tema.titolo)
	_toast.add_theme_font_size_override("font_size", 19)
	_toast.add_theme_color_override("font_color", Tema.AMBRA)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)
	_crea_settori()
	_sel = int(esp.membro(int(esp.s["attivo"]))["settore"]) if not esp.s["equipaggio"].is_empty() else 1
	aggiorna()
	# all'inizio: le annotazioni dei settori dove si trova già qualcuno
	if int(esp.s["round"]) == 1 and esp.s["diario"].size() <= 1:
		for i in esp.vivi():
			_entra_nel_settore(i, [])

func _barra_alta() -> Control:
	var barra := PanelContainer.new()
	barra.add_theme_stylebox_override("panel", Tema.box(Color(0.02, 0.05, 0.11, 0.95), Tema.CIANO_SCURO, 0, 0, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	barra.add_child(h)
	h.add_child(Tema.etichetta(str(pl.get("pianeta", "ESPLORAZIONE")), 20, Tema.TESTO, true))
	_info = Tema.testo_ricco(17)
	_info.fit_content = true
	_info.scroll_active = false
	_info.autowrap_mode = TextServer.AUTOWRAP_OFF
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_info)
	h.add_child(Tema.pulsante_primario("LOGBOOK", func():
		_logbook.visible = not _logbook.visible
		if _logbook.visible:
			_logbook.mostra_corrente(), 14))
	h.add_child(Tema.pulsante("DIARIO", _mostra_diario, 12))
	h.add_child(Tema.pulsante("SALVA", func():
		_salva()
		Campagna.salva_subito(), 12))
	h.add_child(Tema.pulsante("NAVE", func():
		_salva()
		chiusa.emit(), 12))
	return barra

func _barra_azioni() -> Control:
	var barra := PanelContainer.new()
	barra.add_theme_stylebox_override("panel", Tema.box(Color(0.02, 0.05, 0.11, 0.95), Tema.CIANO_SCURO, 0, 0, 8))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 10)
	barra.add_child(h)
	var voci := [
		["viaggio", "VIAGGIO", _viaggio, "Scegli un sentiero dal tuo settore e risolvi le sue icone"],
		["riposo", "RIPOSO", _riposo, "-1 Provviste, ricarica metà dei dadi (per eccesso), pesca 1 carta"],
		["prepara", "PREPARAZIONE", _preparazione, "Pesca 1 carta Reparto e/o fai una Prova per le Combinazioni"],
		["decollo", "DECOLLO", _decollo, "Solo nel settore del Lander: termina l'esplorazione"],
		["sforzo", "SFORZO", _sforzo, "Non è un'azione: sacrifica 1 dado (con 3 dadi o meno: Allo stremo) e ricarica 5 dadi"],
		["fine", "FINE TURNO", _fine_turno, "Gira il segnalino Turno, pesca e risolvi un Evento"],
	]
	for v in voci:
		var b := Tema.pulsante_primario(v[1], v[2], 16) if v[0] == "fine" else Tema.pulsante(v[1], v[2], 16)
		b.tooltip_text = v[3]
		b.custom_minimum_size = Vector2(150, 44)
		_pulsanti[v[0]] = b
		h.add_child(b)
	return barra

func _salva() -> void:
	Campagna.dati["esplorazione"] = esp.s
	Campagna.modificata()

func avviso(t: String) -> void:
	_toast.text = t
	_toast.modulate.a = 1.0
	if _toast_tw:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_interval(3.2)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.6)

# ------------------------------------------------------------------ plancia e settori

func _crea_settori() -> void:
	for st in pl.get("settori", []):
		var n := int(st.get("n", 0))
		var box := Button.new()
		box.flat = true
		box.focus_mode = Control.FOCUS_NONE
		box.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		box.add_theme_stylebox_override("hover", Tema.box(Color(0.3, 0.8, 1.0, 0.08), Tema.CIANO, 2, 6, 0))
		box.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		box.pressed.connect(func(): seleziona(n))
		_sovra.add_child(box)
		var img := TextureRect.new()
		img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(img)
		var bordo := Panel.new()
		bordo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bordo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(bordo)
		var crew := HBoxContainer.new()
		crew.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		crew.offset_top = -40
		crew.offset_left = 6
		crew.offset_bottom = -4
		crew.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crew.add_theme_constant_override("separation", 4)
		box.add_child(crew)
		var info := Label.new()
		info.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		info.offset_left = 6
		info.offset_top = 2
		info.add_theme_font_override("font", Tema.mono)
		info.add_theme_font_size_override("font_size", 15)
		info.add_theme_color_override("font_color", Tema.AMBRA)
		info.add_theme_color_override("font_outline_color", Color.BLACK)
		info.add_theme_constant_override("outline_size", 6)
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(info)
		_widget[n] = {"box": box, "img": img, "bordo": bordo, "crew": crew, "info": info, "dati": st, "pdi": ""}
	_disponi()

## Rettangolo in cui è disegnata l'immagine della plancia (KEEP_ASPECT_CENTERED).
func _rett_plancia() -> Rect2:
	var a := _plancia.size
	var ts := _plancia.texture.get_size() if _plancia.texture else Vector2(AR_PIANETA, 1)
	var k: float = min(a.x / ts.x, a.y / ts.y)
	var dim := ts * k
	return Rect2((a - dim) / 2.0, dim)

func _disponi() -> void:
	var r := _rett_plancia()
	for n in _widget:
		var st: Dictionary = _widget[n]["dati"]
		var w := float(st.get("w", 0.2)) * r.size.x
		var h := float(st.get("h", 0.25)) * r.size.y
		var c := r.position + Vector2(float(st.get("x", 0.5)) * r.size.x, float(st.get("y", 0.5)) * r.size.y)
		var box: Control = _widget[n]["box"]
		box.position = c - Vector2(w, h) / 2.0
		box.size = Vector2(w, h)

func seleziona(n: int) -> void:
	_sel = n
	aggiorna()

func _carta_pdi(n: int) -> Dictionary:
	var id := esp.pdi_in_cima(n)
	return Carte.per_id(id) if id != "" else {}

func _carte_pdi() -> Dictionary:
	var out := {}
	for k in esp.s["settori"]:
		var id := esp.pdi_in_cima(int(k))
		if id != "":
			out[id] = Carte.per_id(id)
	return out

func _aggiorna_settori() -> void:
	for n in _widget:
		var w: Dictionary = _widget[n]
		var id := esp.pdi_in_cima(n)
		if id != w["pdi"]:
			w["pdi"] = id
			w["img"].texture = null
			var c := Carte.per_id(id) if id != "" else {}
			if c.has("file"):
				var tr: TextureRect = w["img"]
				Immagini.carica(str(c["file"]), func(t): if is_instance_valid(tr) and w["pdi"] == id: tr.texture = t)
		var sel: bool = int(n) == _sel
		var att := int(esp.membro(int(esp.s["attivo"]))["settore"]) == int(n) if not esp.vivi().is_empty() else false
		w["bordo"].add_theme_stylebox_override("panel", Tema.box(Color(0, 0, 0, 0), Tema.AMBRA if sel else (Tema.CIANO if att else Color(0.4, 0.7, 1.0, 0.25)), 3 if sel else (2 if att else 1), 6, 0))
		for ch in w["crew"].get_children():
			ch.queue_free()
		if int(esp.s["lander"]["settore"]) == int(n):
			w["crew"].add_child(_gettone("L", Color(0.75, 0.78, 0.82), "Lander " + str(esp.s["lander"]["nome"])))
		for i in esp.nel_settore(n):
			var m := esp.membro(i)
			var col: Color = Dati.SEZIONI.get(str(m["reparto"]), {}).get("colore", Color.WHITE)
			w["crew"].add_child(_gettone(str(m["carta"]).substr(0, 1), col, str(m["carta"]), i == int(esp.s["attivo"])))
		var st: Dictionary = esp.s["settori"].get(str(n), {})
		var info := []
		if int(st.get("tempo", 0)) > 0:
			info.append("⧗%d" % int(st["tempo"]))
		for k in st.get("tracce", {}):
			info.append("▶%d" % int(st["tracce"][k]))
		for mn in esp.s["minacce"]:
			if int(mn.get("settore", 0)) == int(n):
				info.append("☠ " + str(mn.get("nome", "")))
		if int(st.get("log", 0)) > 0 and not st.get("visitato", false):
			info.append("Log %d" % int(st["log"]))
		w["info"].text = "  ".join(info)

func _gettone(t: String, col: Color, tip: String, attivo := false) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(34, 34)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(17)
	sb.border_color = Color.WHITE if attivo else Color(0, 0, 0, 0.8)
	sb.set_border_width_all(3 if attivo else 2)
	p.add_theme_stylebox_override("panel", sb)
	p.tooltip_text = tip
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var l := Label.new()
	l.text = t
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Tema.titolo)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color.BLACK)
	p.add_child(l)
	return p

# ------------------------------------------------------------------ aggiornamento dell'interfaccia

func aggiorna() -> void:
	if esp.s.is_empty():
		return
	_aggiorna_settori()
	var att := int(esp.s["attivo"])
	var m := esp.membro(att)
	var ind := []
	for t in Esplorazione.TIPI_SCOPERTA:
		var v := 0
		for x in esp.s["indizi"][t]:
			v += int(x.get("v", 1))
		if v > 0:
			ind.append("%s %d" % [NOMI_SCOPERTE[t], v])
	var prov := "∞" if esp.s.get("provviste_illimitate", false) else str(esp.s["lander"]["provviste"])
	_info.text = "  [color=#9fbbd6]ROUND[/color] [b]%d[/b]   [color=#9fbbd6]TURNO DI[/color] [b]%s[/b] (%d azioni%s)   [color=#9fbbd6]PROVVISTE[/color] [b]%s[/b]   [color=#9fbbd6]SUCCESSI[/color] [b]%d[/b]   [color=#9fbbd6]SCOPERTE[/color] [b]%d/%d[/b]%s" % [
		int(esp.s["round"]), str(m["carta"]), int(esp.s["azioni"]), ", speciale usata" if esp.s["speciale_usata"] else "",
		prov, int(esp.s["successi"]), esp.s["scoperte"].size(), int(esp.s["lander"]["max_scoperte"]),
		("   [color=#9fbbd6]INDIZI[/color] " + ", ".join(ind)) if not ind.is_empty() else ""]
	var finita := str(esp.s.get("finita", "")) != ""
	for k in _pulsanti:
		_pulsanti[k].disabled = finita or _occupato
	_pulsanti["decollo"].disabled = finita or _occupato or int(m["settore"]) != int(esp.s["lander"]["settore"])
	_aggiorna_pannello()

func _aggiorna_pannello() -> void:
	for c in _pannello.get_children():
		c.queue_free()
	if str(esp.s.get("finita", "")) != "":
		_pannello_fine()
		return
	_sezione_settore()
	_pannello.add_child(HSeparator.new())
	_sezione_squadra()
	_pannello.add_child(HSeparator.new())
	_sezione_condizione()

func _titolo(t: String, col := Tema.CIANO) -> void:
	_pannello.add_child(Tema.etichetta(t, 15, col, true))

func _testo(bb: String, dim := 16) -> RichTextLabel:
	var r := Tema.testo_ricco(dim)
	r.fit_content = true
	r.scroll_active = false
	r.text = bb
	_pannello.add_child(r)
	return r

func _sezione_settore() -> void:
	var n := _sel
	var st: Dictionary = esp.s["settori"].get(str(n), {})
	var dati: Dictionary = {}
	for x in pl.get("settori", []):
		if int(x.get("n", 0)) == n:
			dati = x
	var carta := _carta_pdi(n)
	var stampato: Dictionary = dati.get("stampato", {}) if dati.get("stampato") is Dictionary else {}
	var sorgente: Dictionary = carta if not carta.is_empty() else stampato
	var tit := Carte.titolo(sorgente) if not sorgente.is_empty() else ""
	_titolo("SETTORE %d%s" % [n, (" — " + tit) if tit != "" else ""], Tema.AMBRA)
	var icone: Array = esp.icone_settore(pl, n, _carte_pdi())
	if not icone.is_empty():
		_testo("Icone: " + Dati.testo_carta(" ".join(icone.map(func(x): return "[%s]" % x)), 22))
	if not sorgente.is_empty() and sorgente.has("testo_colore"):
		_testo("[i]%s[/i]" % Carte.t(sorgente["testo_colore"]), 15)
	if not carta.is_empty():
		var hb := HBoxContainer.new()
		hb.add_child(Tema.pulsante("VEDI LA CARTA %s" % esp.pdi_in_cima(n), func(): _mostra_carta(str(carta.get("file", "")), tit), 12))
		_pannello.add_child(hb)
	var chi := int(esp.s["attivo"])
	var presente := int(esp.membro(chi)["settore"]) == n
	var azioni: Array = sorgente.get("azioni", []) if sorgente.get("azioni") is Array else []
	for k in azioni.size():
		var a: Dictionary = azioni[k]
		var riq := PanelContainer.new()
		riq.add_theme_stylebox_override("panel", Tema.box(Color(0.03, 0.08, 0.15), Tema.CIANO_SCURO, 1, 4, 8))
		var v := VBoxContainer.new()
		riq.add_child(v)
		var r := Tema.testo_ricco(15)
		r.fit_content = true
		r.scroll_active = false
		r.text = _descrivi_azione(a, "%s#%d" % [esp.pdi_in_cima(n) if not carta.is_empty() else "S%d" % n, k], n)
		v.add_child(r)
		var chiave := "%s#%d" % [esp.pdi_in_cima(n) if not carta.is_empty() else "S%d" % n, k]
		var b := Tema.pulsante_primario("ESEGUI (%s)" % str(esp.membro(chi)["carta"]), func(): _esegui_azione(a, tit, chiave, n), 13)
		b.disabled = not presente or esp.s["speciale_usata"] or int(esp.s["azioni"]) <= 0 or _occupato
		if not presente:
			b.tooltip_text = "Il Membro attivo deve trovarsi in questo settore"
		v.add_child(b)
		_pannello.add_child(riq)
	if int(st.get("log", 0)) > 0:
		var lb := Tema.pulsante("LEGGI L'ANNOTAZIONE %d%s" % [int(st["log"]), " (già letta)" if st.get("visitato", false) else ""], func():
			st["visitato"] = true
			_apri_log(int(st["log"]))
			aggiorna(), 13)
		_pannello.add_child(lb)
	var hm := HBoxContainer.new()
	hm.add_theme_constant_override("separation", 6)
	var campo := LineEdit.new()
	campo.placeholder_text = "P107"
	campo.custom_minimum_size = Vector2(90, 0)
	hm.add_child(campo)
	hm.add_child(Tema.pulsante("PIAZZA PDI QUI", func():
		var id := campo.text.strip_edges().to_upper()
		if Carte.per_id(id).is_empty():
			avviso("Carta %s non trovata" % id)
			return
		esp.piazza_pdi(n, id)
		_salva()
		aggiorna(), 12))
	hm.add_child(Tema.pulsante("SPOSTA QUI " + str(esp.membro(chi)["carta"]).get_slice(" ", 0), func():
		esp.viaggia(chi, n)
		_salva()
		aggiorna(), 12))
	_pannello.add_child(hm)

func _descrivi_azione(a: Dictionary, chiave: String, n: int) -> String:
	var righe := ["[b]%s%s[/b]" % ["◆ " if str(a.get("icona", "")) in ["diceCheck", "specialAction"] else "", Carte.t(a.get("nome", "")).to_upper()]]
	if str(a.get("costo", "")) != "":
		righe.append("Costo: " + Dati.testo_carta(str(a["costo"]), 20))
	if a.has("testo"):
		righe.append(Dati.testo_carta(Carte.t(a["testo"]), 20))
	for p in a.get("pericolo", []):
		righe.append("+ dado " + Dati.testo_carta("[%s]" % str(p), 20))
	for s in a.get("speciali", []):
		righe.append("[color=#ffb347]Speciale[/color] %s = %s" % [_req(str(s.get("req", ""))), _eff(s.get("effetto", ""))])
	for e in a.get("esiti", []):
		righe.append("[color=%s]■[/color] %s → %s" % [FinestraProva._col(str(e.get("colore", ""))), _req(str(e.get("req", ""))) if str(e.get("req", "")) != "" else "(altrimenti)", Dati.testo_carta(Carte.t(e), 20)])
	for t in a.get("tracce", []):
		var k := "%s#%s" % [chiave, str(t.get("colore", ""))]
		righe.append("[color=%s]▶[/color] traccia %d/%d → %s" % [FinestraProva._col(str(t.get("colore", ""))), esp.traccia(k, n), int(t.get("caselle", 1)), Dati.testo_carta(Carte.t(t), 20)])
	return "\n".join(righe)

func _req(s: String) -> String:
	var parti := []
	for alt in s.split("/"):
		var x := []
		for tok in alt.split("+"):
			tok = tok.strip_edges()
			var k := 1
			if tok.contains("*"):
				k = int(tok.get_slice("*", 0))
				tok = tok.get_slice("*", 1)
			for j in k:
				x.append("[%s]" % tok)
		parti.append(Dati.testo_carta("+".join(x), 20))
	return " / ".join(parti)

func _eff(e) -> String:
	if e is String:
		return _req(str(e)) if not str(e).contains(" ") else Dati.testo_carta(str(e), 20)
	return Dati.testo_carta(Carte.t(e), 20)

func _sezione_squadra() -> void:
	_titolo("SQUADRA DI SBARCO")
	for i in esp.s["equipaggio"].size():
		var m := esp.membro(i)
		var riq := PanelContainer.new()
		var col: Color = Dati.SEZIONI.get(str(m["reparto"]), {}).get("colore", Color.WHITE)
		riq.add_theme_stylebox_override("panel", Tema.box(Color(0.03, 0.07, 0.13), col if i == int(esp.s["attivo"]) else Tema.CIANO_SCURO, 2 if i == int(esp.s["attivo"]) else 1, 4, 8))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		riq.add_child(v)
		var disp := esp.dadi_disponibili(i).size()
		var spesi := esp.dadi_spesi(i).size()
		var sacr: int = m["dadi"].filter(func(d): return d["stato"] == "sacrificato").size()
		var stato := "†" if m["morto"] else ("turno fatto" if m["turno_fatto"] else ("di turno" if i == int(esp.s["attivo"]) else "in attesa"))
		var r := Tema.testo_ricco(15)
		r.fit_content = true
		r.scroll_active = false
		r.text = "[color=#%s][b]%s[/b][/color] · %s, Grado %d · Settore %d · [i]%s[/i]\nDadi: [b]%d[/b] disponibili, %d spesi, %d sacrificati · Cariche %d%s" % [
			col.to_html(false), str(m["carta"]), Dati.SEZIONI.get(str(m["reparto"]), {}).get("nome", ""), int(m["grado"]), int(m["settore"]), stato,
			disp, spesi, sacr, int(m["cariche"]),
			("\nFerite: " + ", ".join(m["ferite"].map(func(x): return NOMI_FERITE.get(x, x)))) if not m["ferite"].is_empty() else ""]
		v.add_child(r)
		# dadi
		var fd := HFlowContainer.new()
		fd.add_theme_constant_override("h_separation", 3)
		for d in m["dadi"]:
			fd.add_child(_chip_dado(d))
		v.add_child(fd)
		# mano
		var fm := HFlowContainer.new()
		fm.add_theme_constant_override("h_separation", 4)
		for c in m["mano"]:
			var carta := Carte.per_file(str(c))
			var ii: int = i
			var cc: String = str(c)
			fm.add_child(Tema.pulsante(Carte.titolo(carta), func(): _carta_in_mano(ii, cc), 11))
		if m["mano"].is_empty():
			fm.add_child(Tema.etichetta("mano vuota", 12, Tema.TESTO_2))
		fm.add_child(Tema.etichetta("mazzo %d · scarti %d · limite %d" % [m["mazzo"].size(), m["scarti"].size(), esp.limite_mano(i)], 12, Tema.TESTO_2))
		v.add_child(fm)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		if not m["morto"] and not m["turno_fatto"] and i != int(esp.s["attivo"]) and int(esp.s["azioni"]) == 2 and not esp.s["speciale_usata"]:
			var jj: int = i
			hb.add_child(Tema.pulsante("È IL SUO TURNO", func():
				esp.scegli_attivo(jj)
				_sel = int(esp.membro(jj)["settore"])
				_salva()
				aggiorna(), 12))
		var k2: int = i
		hb.add_child(Tema.pulsante("CORREZIONI…", func(): _correzioni(k2), 12))
		v.add_child(hb)
		_pannello.add_child(riq)

func _chip_dado(d: Dictionary) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(22, 22)
	var sb := StyleBoxFlat.new()
	var col: Color = {"red": Color("b0263a"), "blue": Color("1683c8"), "green": Color("3f9a36")}.get(Prova.colore(d), Color(0.5, 0.5, 0.5))
	match str(d["stato"]):
		"speso":
			col = col.darkened(0.6)
		"sacrificato":
			col = Color(0.1, 0.1, 0.1)
	sb.bg_color = col
	sb.set_corner_radius_all(4)
	sb.border_color = Color(1, 1, 1, 0.6) if d["stato"] == "disponibile" else Color(0, 0, 0, 0)
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	p.tooltip_text = "%s (%s)" % [str(d["tipo"]), {"disponibile": "disponibile", "speso": "speso", "sacrificato": "sacrificato"}.get(str(d["stato"]), "")]
	return p

func _sezione_condizione() -> void:
	var gc := _condizione()
	_titolo("CONDIZIONE GENERALE — " + Carte.titolo(gc).to_upper(), Tema.AMBRA)
	if gc.has("testo"):
		_testo(Dati.testo_carta(Carte.t(gc["testo"]), 20), 15)
	if gc.get("viaggio") is Dictionary:
		_testo(_descrivi_azione(gc["viaggio"], "GC#viaggio", 0), 15)
	var tm = gc.get("tempo")
	if tm is Dictionary:
		var h := HBoxContainer.new()
		h.add_child(Tema.etichetta("Tempo %d/%d → %s" % [int(esp.s["condizione"]["tempo"]), int(tm.get("caselle", 0)), Carte.t(tm)], 14, Tema.TESTO))
		h.add_child(Tema.pulsante("+1", func():
			await _tempo(1)
			aggiorna(), 12))
		_pannello.add_child(h)
	if str(esp.s["condizione"]["carta"]).begins_with("G") and gc.has("file"):
		_pannello.add_child(Tema.pulsante("VEDI LA CARTA", func(): _mostra_carta(str(gc["file"]), Carte.titolo(gc)), 12))
	for a in gc.get("azioni", []) if gc.get("azioni") is Array else []:
		var r := _testo(_descrivi_azione(a, "GC#" + Carte.t(a.get("nome", "")), 0), 15)
		var aa: Dictionary = a
		_pannello.add_child(Tema.pulsante("ESEGUI", func(): _esegui_azione(aa, Carte.titolo(gc), "GC#" + Carte.t(aa.get("nome", "")), int(esp.membro(int(esp.s["attivo"]))["settore"])), 12))
	# missioni
	_titolo("MISSIONI")
	for id in esp.s["missioni"]:
		var mi := Carte.per_id(str(id))
		if mi.is_empty():
			_testo(str(id), 15)
			continue
		_testo("[b]%s[/b]\n%s\n[color=#9fbbd6]%s[/color]" % [Carte.titolo(mi), Dati.testo_carta(Carte.t(mi.get("obiettivo", "")), 20), Dati.testo_carta(Carte.t(mi.get("completamento", "")), 20)], 15)
		var idd := str(id)
		var hb := HBoxContainer.new()
		hb.add_child(Tema.pulsante("VEDI", func(): _mostra_carta(str(mi.get("file", "")), Carte.titolo(mi)), 12))
		hb.add_child(Tema.pulsante("COMPLETATA", func():
			esp.s["missioni"].erase(idd)
			esp.diario("Missione %s completata" % idd)
			await applica([{"en": Carte.en(mi.get("completamento", "")).replace("When you fulfill the Objective, discard this Mission and", "").replace("When you fulfill the Objective,", ""), "it": Carte.t(mi.get("completamento", "")), "fonte": Carte.titolo(mi)}], int(esp.s["attivo"]), _sel), 12))
		_pannello.add_child(hb)
	var hm := HBoxContainer.new()
	var campo := LineEdit.new()
	campo.placeholder_text = "M02 / G05"
	campo.custom_minimum_size = Vector2(110, 0)
	hm.add_child(campo)
	hm.add_child(Tema.pulsante("AGGIUNGI CARTA", func(): _carta_dal_logbook(campo.text.strip_edges().to_upper()), 12))
	_pannello.add_child(hm)

func _condizione() -> Dictionary:
	var id := str(esp.s["condizione"]["carta"])
	if RegEx.create_from_string("^G\\d+$").search(id):
		var c := Carte.per_id(id)
		if not c.is_empty():
			return c
	var cd = pl.get("colonna_destra", {})
	if cd is Dictionary and cd.get("condizione") is Dictionary:
		return cd["condizione"]
	return {}

func _pannello_fine() -> void:
	_titolo("ESPLORAZIONE TERMINATA", Tema.AMBRA)
	var motivo: String = {"decollo": "Decollo", "evac": "Evacuazione d'emergenza", "fine": "Fine dell'esplorazione"}.get(str(esp.s["finita"]), str(esp.s["finita"]))
	var righe := ["Motivo: [b]%s[/b]" % motivo, "Successi: [b]%d[/b]" % int(esp.s["successi"])]
	righe.append("Scoperte: %s" % (", ".join(esp.s["scoperte"].map(func(x): return NOMI_SCOPERTE.get(x["tipo"], x["tipo"]))) if not esp.s["scoperte"].is_empty() else "nessuna"))
	if not esp.s["eccezionali"].is_empty():
		righe.append("Scoperte Eccezionali: %s" % ", ".join(esp.s["eccezionali"].map(func(x): return str(x))))
	for i in esp.s["equipaggio"].size():
		var m := esp.membro(i)
		righe.append("%s: %s" % [m["carta"], "disperso/morto" if m["morto"] else ("ferite: " + ", ".join(m["ferite"].map(func(x): return NOMI_FERITE.get(x, x))) if not m["ferite"].is_empty() else "illeso")])
	_testo("\n".join(righe), 16)
	var log_fine = pl.get("decollo_log") if str(esp.s["finita"]) == "decollo" else pl.get("evac_log")
	if log_fine != null:
		_pannello.add_child(Tema.pulsante_primario("ANNOTAZIONE %d" % int(log_fine), func(): _apri_log(int(log_fine)), 14))
	_testo("Segui il Ship Book (pag. 25): riporta Scoperte, Ferite e Successi sulla nave.", 14)
	_pannello.add_child(Tema.pulsante_primario("TORNA ALLA NAVE", func():
		var arch: Array = Campagna.dati.get_or_add("esplorazioni_concluse", [])
		arch.append({"pagina": esp.s["pagina"], "finita": esp.s["finita"], "successi": esp.s["successi"], "scoperte": esp.s["scoperte"],
			"eccezionali": esp.s["eccezionali"], "equipaggio": esp.s["equipaggio"].map(func(m): return {"carta": m["carta"], "reparto": m["reparto"], "ferite": m["ferite"], "morto": m["morto"]})})
		Campagna.dati.erase("esplorazione")
		Campagna.annota("Esplorazione conclusa: %s" % str(pl.get("pianeta", "")))
		Campagna.modificata()
		chiusa.emit(), 16))

# ------------------------------------------------------------------ finestre di scelta

## Mostra una scelta e restituisce l'indice (-1 = annulla).
func _scegli(titolo: String, opzioni: Array, testo := "", annullabile := true, immagine := "") -> int:
	var vel := ColorRect.new()
	vel.color = Color(0, 0.01, 0.03, 0.75)
	vel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vel)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vel.add_child(c)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(720, 0)
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(Tema.etichetta(titolo, 20, Tema.TESTO, true))
	if immagine != "":
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(700, 420)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		Immagini.carica(immagine, func(t): if is_instance_valid(tr): tr.texture = t)
		v.add_child(tr)
	if testo != "":
		var r := Tema.testo_ricco(17)
		r.fit_content = true
		r.scroll_active = false
		r.custom_minimum_size = Vector2(700, 0)
		r.text = testo
		v.add_child(r)
	for i in opzioni.size():
		var k: int = i
		var b := Tema.pulsante(str(opzioni[i]), func():
			vel.queue_free()
			_scelto.emit(k), 15)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(b)
	if annullabile:
		v.add_child(Tema.pulsante("ANNULLA", func():
			vel.queue_free()
			_scelto.emit(-1), 13))
	var r2: int = await _scelto
	return r2

func _mostra_carta(rel: String, titolo: String) -> void:
	if rel == "":
		return
	await _scegli(titolo, ["CHIUDI"], "", false, rel)

func _mostra_diario() -> void:
	var righe: Array = esp.s["diario"].slice(max(0, esp.s["diario"].size() - 40))
	await _scegli("DIARIO DELL'ESPLORAZIONE", ["CHIUDI"], "\n".join(righe.map(func(x): return "• " + str(x))), false)

func _apri_log(n: int) -> void:
	_logbook.visible = true
	_logbook.apri_numero(n)

# ------------------------------------------------------------------ azioni

func _inizia() -> bool:
	if _occupato:
		return false
	_occupato = true
	aggiorna()
	return true

func _finisci() -> void:
	_occupato = false
	_salva()
	aggiorna()

func _esegui_azione(a: Dictionary, fonte: String, chiave: String, n: int) -> void:
	var chi := int(esp.s["attivo"])
	if not _inizia():
		return
	if not esp.usa_azione(true):
		avviso("Non hai più azioni (o hai già usato l'Azione Speciale)")
		_finisci()
		return
	var testi := []
	if a.get("prova", false) or str(a.get("icona", "")) == "diceCheck":
		var f := FinestraProva.new()
		f.esp = esp
		f.chi = chi
		f.azione = a
		f.fonte = fonte
		f.chiave_tracce = chiave
		f.settore = n
		f.speciali_globali = _speciali_globali()
		add_child(f)
		var r: Dictionary = await f.conclusa
		if r.get("annullata", false):
			esp.s["azioni"] = int(esp.s["azioni"]) + 1
			esp.s["speciale_usata"] = false
			_finisci()
			return
		testi = r.get("testi", [])
	else:
		var costo := str(a.get("costo", ""))
		if costo != "":
			var alt := Array(costo.split(" / "))
			var j := 0
			if alt.size() > 1:
				j = await _scegli("COSTO", alt.map(func(x): return _txt_icone(str(x))))
				if j < 0:
					esp.s["azioni"] = int(esp.s["azioni"]) + 1
					esp.s["speciale_usata"] = false
					_finisci()
					return
			testi.append({"en": alt[j], "it": alt[j], "fonte": "costo"})
		if a.has("testo"):
			testi.append({"en": Carte.en(a["testo"]), "it": Carte.t(a["testo"]), "fonte": fonte})
		for e in a.get("esiti", []):
			testi.append({"en": Carte.en(e), "it": Carte.t(e), "fonte": fonte})
	await applica(testi, chi, n)
	_finisci()

## Effetti speciali della Condizione Generale validi per tutte le Prove.
func _speciali_globali() -> Array:
	var gc := _condizione()
	var es = gc.get("effetto_speciale")
	if es is Dictionary and str(es.get("req", "")) != "":
		return [es]
	return []

static func _txt_icone(t: String) -> String:
	var nomi := {"spendDie": "Spendi un dado", "sacrifaceDie": "Sacrifica un dado", "redDie": "dado rosso", "blueDie": "dado blu", "greenDie": "dado verde"}
	var rx := RegEx.create_from_string("\\[([A-Za-z_0-9]+)\\]")
	var out := t
	for m in rx.search_all(t):
		var n := m.get_string(1)
		var it: String = nomi.get(n, "")
		if it == "" and n.begins_with("dangerDie"):
			it = "tira il dado Pericolo " + n.trim_prefix("dangerDie")
		if it == "":
			it = Traduzioni.icona(n)
		out = out.replace(m.get_string(0), it)
	return out

func _viaggio() -> void:
	var chi := int(esp.s["attivo"])
	var sett := int(esp.membro(chi)["settore"])
	var icone: Array = esp.icone_settore(pl, sett, _carte_pdi())
	if "noMovement" in icone:
		avviso("Da questo settore non si può viaggiare (icona Nessun movimento)")
		return
	var sentieri := esp.sentieri(pl, sett)
	if sentieri.is_empty():
		avviso("Nessun sentiero parte da questo settore")
		return
	if int(esp.s["azioni"]) <= 0:
		avviso("Non hai più azioni: termina il turno")
		return
	if not _inizia():
		return
	var j := await _scegli("VIAGGIO DAL SETTORE %d" % sett, sentieri.map(func(p): return "Settore %d — sentiero: %s" % [int(p["a"]), ", ".join((p["icone"] as Array).map(func(x): return _txt_icone("[%s]" % x)))]))
	if j < 0:
		_finisci()
		return
	esp.usa_azione(false)
	var dest := int(sentieri[j]["a"])
	_destinazione = dest
	var testi := []
	for ic in sentieri[j]["icone"]:
		var s := str(ic)
		if s.begins_with("travel"):
			var gc := _condizione()
			var vg = gc.get("viaggio")
			if vg is Dictionary and (vg.get("prova", false) or str(vg.get("icona", "")) == "diceCheck"):
				var f := FinestraProva.new()
				f.esp = esp
				f.chi = chi
				f.azione = vg
				f.fonte = "Viaggio (" + Carte.titolo(gc) + ")"
				f.chiave_tracce = "GC#viaggio"
				f.settore = sett
				f.speciali_globali = _speciali_globali()
				add_child(f)
				var r: Dictionary = await f.conclusa
				if r.get("annullata", false):
					esp.s["azioni"] = int(esp.s["azioni"]) + 1
					_destinazione = 0
					_finisci()
					return
				testi.append_array(r.get("testi", []))
			elif vg is Dictionary and str(vg.get("costo", "")) != "":
				var alt := Array(str(vg["costo"]).split(" / "))
				var k := 0
				if alt.size() > 1:
					k = await _scegli("ICONA VIAGGIO: " + Carte.titolo(gc), alt.map(func(x): return _txt_icone(str(x))), Dati.testo_carta(Carte.t(vg.get("testo", "")), 20), false)
				testi.append({"en": alt[max(k, 0)], "it": alt[max(k, 0)], "fonte": "icona Viaggio"})
			else:
				testi.append({"en": "", "it": "Risolvi l'icona Viaggio come indicato dalla Condizione Generale.", "fonte": "icona Viaggio"})
		elif s == "spendDie" or s.begins_with("spendDie") or s == "sacrifaceDie":
			testi.append({"en": "[%s]" % s, "it": "[%s]" % s, "fonte": "sentiero"})
		elif s.begins_with("dangerDie"):
			testi.append({"en": "Roll [%s]." % s, "it": "Tira [%s]." % s, "fonte": "sentiero"})
		else:
			testi.append({"en": "", "it": "Icona del sentiero da risolvere: [%s]" % s, "fonte": "sentiero"})
	await applica(testi, chi, sett)
	if _destinazione > 0 and str(esp.s.get("finita", "")) == "":
		_muovi(chi, _destinazione, [])
	_destinazione = 0
	_finisci()

func _muovi(chi: int, a: int, logs: Array) -> void:
	esp.viaggia(chi, a)
	_sel = a
	_entra_nel_settore(chi, logs)

## Entrando in un settore con un'annotazione non ancora letta, la si legge subito.
func _entra_nel_settore(chi: int, logs: Array) -> void:
	var st: Dictionary = esp.s["settori"].get(str(int(esp.membro(chi)["settore"])), {})
	if int(st.get("log", 0)) > 0 and not st.get("visitato", false):
		st["visitato"] = true
		if logs.is_empty() and not _occupato:
			_apri_log(int(st["log"]))
		else:
			logs.append(int(st["log"]))
		if not _occupato:
			_salva()
			aggiorna()

func _riposo() -> void:
	var chi := int(esp.s["attivo"])
	if int(esp.s["azioni"]) <= 0:
		avviso("Non hai più azioni: termina il turno")
		return
	if not esp.s.get("provviste_illimitate", false) and int(esp.s["lander"]["provviste"]) <= 0:
		avviso("Niente Provviste: non puoi riposare (usa lo Sforzo)")
		return
	if not _inizia():
		return
	esp.usa_azione(false)
	esp.riposa(chi)
	await _scarta_eccesso()
	_finisci()

func _preparazione() -> void:
	var chi := int(esp.s["attivo"])
	if int(esp.s["azioni"]) <= 0:
		avviso("Non hai più azioni: termina il turno")
		return
	if not _inizia():
		return
	var j := await _scegli("PREPARAZIONE", ["Pesca 1 carta Reparto", "Pesca 1 carta e fai una Prova per le Combinazioni", "Solo una Prova per le Combinazioni"])
	if j < 0:
		_finisci()
		return
	esp.usa_azione(false)
	if j <= 1:
		var c := esp.pesca_carta(chi)
		esp.diario("%s si prepara e pesca %s" % [esp.membro(chi)["carta"], Carte.titolo(Carte.per_file(c)) if c != "" else "nulla"])
		await _scarta_eccesso()
	if j >= 1:
		var f := FinestraProva.new()
		f.esp = esp
		f.chi = chi
		f.azione = {"nome": {"en": "PREPARE", "it": "PREPARAZIONE"}, "esiti": [], "speciali": [], "tracce": []}
		f.fonte = "Combinazioni"
		f.settore = int(esp.membro(chi)["settore"])
		f.speciali_globali = _speciali_globali()
		add_child(f)
		var r: Dictionary = await f.conclusa
		if not r.get("annullata", false):
			await applica(r.get("testi", []), chi, f.settore)
	_finisci()

func _sforzo() -> void:
	var chi := int(esp.s["attivo"])
	var dadi: Array = esp.membro(chi)["dadi"].filter(func(d): return d["stato"] != "sacrificato")
	if not _inizia():
		return
	if dadi.size() <= 3:
		var ok := await _scegli("SFORZO", ["Subisci Allo stremo e ricarica 5 dadi"], "Hai 3 dadi o meno: invece di sacrificarne uno subisci la Ferita Allo stremo.")
		if ok == 0:
			esp.sforzo(chi)
	else:
		var j := await _scegli("SFORZO: QUALE DADO SACRIFICHI?", dadi.map(func(d): return "%s (%s)" % [str(d["tipo"]), str(d["stato"])]))
		if j >= 0:
			esp.sforzo(chi, str(dadi[j]["id"]))
	if str(esp.s.get("finita", "")) == "evac":
		avviso("Quarta Ferita: evacuazione d'emergenza!")
	_finisci()

func _decollo() -> void:
	var chi := int(esp.s["attivo"])
	if int(esp.membro(chi)["settore"]) != int(esp.s["lander"]["settore"]):
		avviso("Il decollo si fa solo dal settore del Lander")
		return
	if not _inizia():
		return
	var fuori := esp.vivi().filter(func(i): return int(esp.membro(i)["settore"]) != int(esp.s["lander"]["settore"]))
	var t := "Tutta la squadra è a bordo." if fuori.is_empty() else "[color=#ff5a6e]Restano a terra: %s[/color]" % ", ".join(fuori.map(func(i): return str(esp.membro(i)["carta"])))
	var j := await _scegli("DECOLLO", ["Decolla e termina l'esplorazione"], t)
	if j == 0:
		esp.decollo()
		var lg = pl.get("decollo_log")
		if lg != null:
			_apri_log(int(lg))
	_finisci()

func _fine_turno() -> void:
	var chi := int(esp.s["attivo"])
	if not _inizia():
		return
	await _scarta_eccesso()
	var ev := esp.fine_turno()
	if ev != "":
		await _risolvi_evento(ev, chi)
	if str(esp.s.get("finita", "")) == "":
		if esp.round_finito():
			esp.prossimo_round(int(esp.s.get("primo", 0)))
			avviso("Round %d" % int(esp.s["round"]))
		else:
			for k in esp.s["equipaggio"].size():
				var j2: int = (chi + 1 + k) % esp.s["equipaggio"].size()
				if not esp.membro(j2)["turno_fatto"] and not esp.membro(j2)["morto"]:
					esp.scegli_attivo(j2)
					break
		_sel = int(esp.membro(int(esp.s["attivo"]))["settore"])
	_finisci()

func _risolvi_evento(ev: String, chi: int) -> void:
	var c := Carte.per_file(ev)
	var sett := int(esp.membro(chi)["settore"])
	var icone := esp.icone_settore(pl, sett, _carte_pdi())
	var principale := esp.evento_principale(c.get("biomi", []), icone)
	var parte: Dictionary = c.get("principale", {}) if principale else c.get("secondario", {})
	var t := "Biomi dell'Evento: %s\nSettore %d: %s\n\n[b]%s[/b]: %s" % [
		Dati.testo_carta(" ".join((c.get("biomi", []) as Array).map(func(x): return "[%s]" % x)), 22),
		sett, Dati.testo_carta(" ".join(icone.map(func(x): return "[%s]" % x)), 22) if not icone.is_empty() else "nessuna icona",
		"Effetto principale (un bioma corrisponde)" if principale else "Effetto secondario (nessun bioma corrisponde)",
		Dati.testo_carta(Carte.t(parte), 20)]
	esp.diario("Evento: %s (%s)" % [Carte.titolo(c), "principale" if principale else "secondario"])
	await _scegli("EVENTO — " + Carte.titolo(c), ["APPLICA"], t, false, str(c.get("file", "")))
	await applica([{"en": Carte.en(parte), "it": Carte.t(parte), "fonte": "Evento " + Carte.titolo(c)}], chi, sett)

## Limite di carte in mano (Grado 1: 2, 2: 3, 3: 4): chi ne ha di più ne scarta subito.
func _scarta_eccesso() -> void:
	for i in esp.vivi():
		while esp.eccesso_mano(i) > 0:
			var mano: Array = esp.membro(i)["mano"]
			var j := await _scegli("%s HA TROPPE CARTE: SCARTANE %d" % [str(esp.membro(i)["carta"]).to_upper(), esp.eccesso_mano(i)], mano.map(func(c): return Carte.titolo(Carte.per_file(str(c)))), "", false)
			esp.scarta_carta(i, str(mano[j]))

func _carta_in_mano(i: int, c: String) -> void:
	var carta := Carte.per_file(c)
	var testo := "[b]%s[/b]\n%s" % [Carte.t(carta.get("quando", "")) if carta.get("quando") is Dictionary else str(carta.get("quando", "")).replace("_", " "), Dati.testo_carta(Carte.t(carta.get("effetto", "")), 20)]
	if carta.get("combo") is Dictionary:
		testo += "\n\n[color=#ffb347]Combinazione[/color] %s: %s" % [_req(str(carta["combo"].get("req", ""))), Dati.testo_carta(Carte.t(carta["combo"]), 20)]
	var j := await _scegli(Carte.titolo(carta), ["GIOCA (applica l'effetto e scarta)", "SCARTA"], testo, true, str(carta.get("file", "")))
	if j == 0:
		esp.scarta_carta(i, c)
		await applica([{"en": Carte.en(carta.get("effetto", "")), "it": Carte.t(carta.get("effetto", "")), "fonte": Carte.titolo(carta)}], i, int(esp.membro(i)["settore"]))
	elif j == 1:
		esp.scarta_carta(i, c)
	_salva()
	aggiorna()

func _correzioni(i: int) -> void:
	var voci := ["Sposta in un altro settore", "Ricarica 1 dado", "Spendi 1 dado", "Pesca 1 carta", "Cura l'ultima Ferita", "Subisci una Ferita", "+1 Carica", "+1 Provviste", "-1 Provviste", "+1 Successo", "Avanza tutte le tracce del Tempo", "Termina l'esplorazione"]
	var j := await _scegli("CORREZIONI — " + str(esp.membro(i)["carta"]), voci)
	match j:
		0:
			var sett: Array = esp.s["settori"].keys()
			var k := await _scegli("IN QUALE SETTORE?", sett.map(func(x): return "Settore " + str(x)))
			if k >= 0:
				esp.viaggia(i, int(sett[k]))
		1:
			esp.ricarica(i, 1, "")
		2:
			esp.spendi_dado(i)
		3:
			esp.pesca_carta(i)
		4:
			esp.cura(i)
		5:
			var tipi := NOMI_FERITE.keys()
			var k2 := await _scegli("QUALE FERITA?", tipi.map(func(x): return NOMI_FERITE[x]))
			if k2 >= 0:
				esp.ferita(i, tipi[k2])
		6:
			esp.membro(i)["cariche"] = int(esp.membro(i)["cariche"]) + 1
		7:
			esp.s["lander"]["provviste"] = int(esp.s["lander"]["provviste"]) + 1
		8:
			esp.s["lander"]["provviste"] = max(0, int(esp.s["lander"]["provviste"]) - 1)
		9:
			esp.s["successi"] = int(esp.s["successi"]) + 1
		10:
			await _tempo(1)
		11:
			esp.fine("fine")
	_salva()
	aggiorna()

## Le carte che il Logbook chiede di prendere: PDI in un settore, Missioni, Condizioni Generali, Minacce.
func _carta_dal_logbook(nome: String) -> void:
	nome = nome.strip_edges().to_upper()
	var c := Carte.per_id(nome)
	if nome.begins_with("P") and not c.is_empty():
		var sett: Array = esp.s["settori"].keys()
		var k := await _scegli("IN QUALE SETTORE VA %s?" % nome, sett.map(func(x): return "Settore %s%s" % [str(x), " (ora: %s)" % esp.pdi_in_cima(int(x)) if esp.pdi_in_cima(int(x)) != "" else ""]))
		if k >= 0:
			esp.piazza_pdi(int(sett[k]), nome)
	elif nome.begins_with("M") and not c.is_empty():
		if not nome in esp.s["missioni"]:
			esp.s["missioni"].append(nome)
			esp.diario("Nuova Missione: " + nome)
		if nome == "M02" and esp.s.get("eventi_sospesi", false):
			esp.s["eventi_sospesi"] = false
			avviso("Da ora, a fine turno si pescano le carte Evento")
	elif nome.begins_with("G") and not c.is_empty():
		esp.s["condizione"] = {"carta": nome, "tempo": 0}
		esp.diario("Nuova Condizione Generale: " + Carte.titolo(c))
	else:
		var mn := Carte.categoria("minacce").filter(func(x): return Carte.titolo(x).to_upper() == nome or str(x.get("nomi", [""])[0]).to_upper() == nome if not (x.get("nomi", []) as Array).is_empty() else false)
		if not mn.is_empty():
			var sett2: Array = esp.s["settori"].keys()
			var k3 := await _scegli("IN QUALE SETTORE VA LA MINACCIA?", sett2.map(func(x): return "Settore " + str(x)))
			if k3 >= 0:
				esp.s["minacce"].append({"nome": Carte.titolo(mn[0]), "file": str(mn[0]["file"]), "settore": int(sett2[k3]), "tempo": 0})
		else:
			avviso("Carta %s: prendila e applicala a mano" % nome)
			return
	_salva()
	aggiorna()

# ------------------------------------------------------------------ esecuzione degli effetti

## Esegue gli effetti dei testi (in inglese, come sulle carte) per il Membro chi nel settore sett.
## Mostra cosa è stato fatto e cosa resta da fare a mano, poi apre le annotazioni richieste.
func applica(testi: Array, chi: int, sett: int) -> void:
	var fatti := []
	var manuali := []
	var logs := []
	for t in testi:
		var en := str(t.get("en", ""))
		var fonte := str(t.get("fonte", ""))
		if en.strip_edges() == "":
			if str(t.get("it", "")) != "":
				manuali.append("%s: %s" % [fonte, str(t["it"])])
			continue
		var a := Effetti.analizza(en)
		for op in a["op"]:
			await _op(op, chi, sett, fatti, manuali, logs, fonte)
			if str(esp.s.get("finita", "")) != "":
				break
		if str(a["resto"]) != "":
			manuali.append("%s: %s" % [fonte, str(t.get("it", en))])
		if str(esp.s.get("finita", "")) != "":
			break
	_controlla_tempo(fatti, manuali, logs)
	if not fatti.is_empty() or not manuali.is_empty():
		var testo := ""
		if not fatti.is_empty():
			testo += "[color=#5be39b][b]FATTO[/b][/color]\n" + "\n".join(fatti.map(func(x): return "• " + str(x)))
		if not manuali.is_empty():
			testo += ("\n\n" if testo != "" else "") + "[color=#ffb347][b]DA FARE A MANO[/b][/color] (usa CORREZIONI o il pannello del settore)\n" + "\n".join(manuali.map(func(x): return "• " + Dati.testo_carta(str(x), 20)))
		await _scegli("EFFETTI", ["OK"], testo, false)
	await _scarta_eccesso()
	_salva()
	aggiorna()
	if not logs.is_empty():
		_apri_log(int(logs[0]))
		if logs.size() > 1:
			avviso("Poi leggi anche: " + ", ".join(logs.slice(1).map(func(x): return "Annotazione %d" % int(x))))

func _op(op: Dictionary, chi: int, sett: int, fatti: Array, manuali: Array, logs: Array, fonte: String) -> void:
	var m := esp.membro(chi)
	match str(op["op"]):
		"log":
			logs.append(int(op["n"]))
			fatti.append("Vai all'Annotazione %d" % int(op["n"]))
		"indizi":
			var sc := esp.indizi(str(op["tipo"]), int(op["n"]))
			fatti.append("%d Indizi %s" % [int(op["n"]), NOMI_SCOPERTE.get(op["tipo"], op["tipo"])])
			for c in sc:
				fatti.append("[b]Scoperta %s ottenuta![/b] (%s)" % [NOMI_SCOPERTE.get(op["tipo"], op["tipo"]), Carte.titolo(Carte.per_file(str(c)))])
			_controlla_scoperte(manuali)
		"scoperta":
			for k in int(op["n"]):
				var c2 := esp.scoperta(str(op["tipo"]))
				fatti.append("Scoperta %s%s" % [NOMI_SCOPERTE.get(op["tipo"], op["tipo"]), "" if c2 != "" else " (mazzo vuoto)"])
			_controlla_scoperte(manuali)
		"scoperta_eccezionale":
			esp.s["eccezionali"].append(int(op["n"]))
			fatti.append("Scoperta Eccezionale %s" % (str(op["n"]) if int(op["n"]) > 0 else ""))
			manuali.append("Prendi la carta Scoperta Eccezionale %s" % (str(op["n"]) if int(op["n"]) > 0 else "in cima"))
		"successi":
			esp.s["successi"] = int(esp.s["successi"]) + int(op["n"])
			fatti.append("+%d Successo" % int(op["n"]))
			if esp.s.get("tutorial", false) and int(esp.s["successi"]) >= 3 and not esp.s.get("grado_girato", false):
				esp.s["grado_girato"] = true
				manuali.append("Hai 3 Successi: gira la carta Grado Superiore sul lato Completato (Regolamento pag. 21)")
		"provviste":
			if not esp.s.get("provviste_illimitate", false):
				esp.s["lander"]["provviste"] = max(0, int(esp.s["lander"]["provviste"]) + int(op["n"]))
			fatti.append("%+d Provviste" % int(op["n"]))
		"ricarica":
			var f := esp.ricarica(chi, int(op["n"]), str(op["colore"]))
			fatti.append("%s ricarica %d dadi" % [m["carta"], f])
		"pericolo":
			for k in int(op["n"]):
				await _tira_pericolo(str(op["lettera"]), chi, sett, fatti, manuali, logs, fonte)
		"ferita":
			var r := esp.ferita(chi, str(op["tipo"]))
			if r == "":
				fatti.append("%s ha già una Ferita: si ignora (tutorial)" % m["carta"])
			else:
				fatti.append("%s subisce la Ferita %s" % [m["carta"], NOMI_FERITE.get(r, r)] if r != "evac" else "Quarta Ferita: evacuazione d'emergenza!")
		"sostituisci_pdi":
			esp.piazza_pdi(sett, str(op["carta"]))
			fatti.append("Settore %d: ora c'è %s" % [sett, op["carta"]])
		"piazza_pdi":
			esp.piazza_pdi(int(op["settore"]), str(op["carta"]))
			fatti.append("Settore %d: ora c'è %s" % [int(op["settore"]), op["carta"]])
		"pesca":
			for k in int(op["n"]):
				esp.pesca_carta(chi)
			fatti.append("%s pesca %d carte" % [m["carta"], int(op["n"])])
		"cariche":
			m["cariche"] = int(m["cariche"]) + int(op["n"])
			fatti.append("+%d Cariche a %s" % [int(op["n"]), m["carta"]])
		"tempo_tutte":
			esp.tempo_tutte(int(op["n"]))
			fatti.append("Tutte le tracce del Tempo avanzano di %d" % int(op["n"]))
		"azzera_tempo":
			esp.azzera_tempo()
			fatti.append("Tracce del Tempo azzerate")
		"muovi":
			if _destinazione > 0:
				var d := _destinazione
				_destinazione = 0
				_muovi(chi, d, logs)
				fatti.append("%s si sposta nel Settore %d" % [m["carta"], d])
			else:
				var sen := esp.sentieri(pl, int(m["settore"]))
				if not sen.is_empty():
					var j := await _scegli("MUOVITI IN UN SETTORE COLLEGATO", sen.map(func(p): return "Settore %d" % int(p["a"])), "", false)
					_muovi(chi, int(sen[j]["a"]), logs)
					fatti.append("%s si sposta nel Settore %d" % [m["carta"], int(sen[j]["a"])])
		"scarta_questa":
			manuali.append("Scarta la carta (%s)" % fonte)
		"fine_esplorazione":
			esp.fine("fine")
			fatti.append("L'esplorazione planetaria finisce")
		"morale":
			esp.s["morale"] = int(esp.s.get("morale", 0)) + int(op["n"])
			fatti.append("Morale %s (da riportare sulla nave)" % ("+1" if int(op["n"]) > 0 else "-1"))
		"spendi":
			for k in int(op["n"]):
				var prima := esp.dadi_disponibili(chi).size()
				esp.spendi_dado(chi, str(op["colore"]))
				fatti.append("%s %s un dado%s" % [m["carta"], "spende" if esp.dadi_disponibili(chi).size() < prima else "sacrifica (nessuno disponibile)", (" " + {"red": "rosso", "blue": "blu", "green": "verde"}.get(op["colore"], "")) if str(op["colore"]) != "" else ""])
		"sacrifica":
			for k in int(op["n"]):
				esp.sacrifica_dado(chi, "", str(op["colore"]))
			fatti.append("%s sacrifica %d dadi" % [m["carta"], int(op["n"])])
		"niente":
			fatti.append("Non succede nulla")

func _tira_pericolo(lettera: String, chi: int, sett: int, fatti: Array, manuali: Array, logs: Array, fonte: String) -> void:
	var d := {"tipo": "pericolo", "lettera": lettera, "faccia": 0}
	Prova.tira(d, esp.rng)
	var ic := Prova.icone(d)
	var nome := "vuoto" if ic.is_empty() else str(ic[0])
	var nomi_it := {"vuoto": "faccia vuota", "common": "comune", "uncommon": "non comune", "rare": "raro", "special": "speciale"}
	if lettera.substr(0, 1) in ["A", "B", "C", "D", "E", "F", "G", "H", "I", "T"]:
		var e := Prova.effetto_pericolo(lettera, d)
		fatti.append("Dado Pericolo %s: %s → %s" % [lettera, nomi_it.get(nome, nome), _txt_icone(e) if e != "" else "nessun effetto"])
		if e != "":
			for op in Effetti.analizza(e)["op"]:
				await _op(op, chi, sett, fatti, manuali, logs, "dado Pericolo")
	else:
		fatti.append("Dado Pericolo %s: %s" % [lettera, nomi_it.get(nome, nome)])
		manuali.append("Dado Pericolo %s con risultato %s: applica l'effetto indicato per la lettera %s (sulla carta, sulla plancia o nell'annotazione)." % [lettera, nomi_it.get(nome, nome), lettera])

func _controlla_scoperte(manuali: Array) -> void:
	if esp.s["scoperte"].size() > int(esp.s["lander"]["max_scoperte"]):
		manuali.append("Il Lander può trasportare al massimo %d Scoperte: scartane %d" % [int(esp.s["lander"]["max_scoperte"]), esp.s["scoperte"].size() - int(esp.s["lander"]["max_scoperte"])])

func _tempo(n: int) -> void:
	esp.tempo_tutte(n)
	var fatti := ["Tutte le tracce del Tempo avanzano di %d" % n]
	var manuali := []
	var logs := []
	_controlla_tempo(fatti, manuali, logs)
	await _scegli("TEMPO", ["OK"], "\n".join(fatti.map(func(x): return "• " + str(x))) + ("\n" + "\n".join(manuali.map(func(x): return "• " + str(x))) if not manuali.is_empty() else ""), false)
	if not logs.is_empty():
		_apri_log(int(logs[0]))
	_salva()

## Traccia del Tempo della Condizione Generale completa: si applica il suo effetto.
func _controlla_tempo(fatti: Array, manuali: Array, logs: Array) -> void:
	var gc := _condizione()
	var tm = gc.get("tempo")
	if not tm is Dictionary:
		return
	var cas := int(tm.get("caselle", 0))
	if cas <= 0 or int(esp.s["condizione"]["tempo"]) < cas or esp.s["condizione"].get("scattata", false):
		return
	esp.s["condizione"]["scattata"] = true
	var a := Effetti.analizza(Carte.en(tm))
	for op in a["op"]:
		if op["op"] == "log":
			logs.append(int(op["n"]))
			fatti.append("Tempo della Condizione Generale esaurito: Annotazione %d" % int(op["n"]))
		else:
			manuali.append("Tempo della Condizione Generale: " + Carte.t(tm))
	if a["op"].is_empty():
		manuali.append("Tempo della Condizione Generale: " + Carte.t(tm))
