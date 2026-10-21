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
const NOMI_FERITE := {"wounded": "Lesione", "panicked": "Panico", "freezing": "Congelamento", "exhausted": "Allo Stremo",
	"critically_wounded": "Lesione Grave", "burned": "Ustione", "just_a_scratch": "Niente di Grave"}
const REP_EN := {"ingegneria": "engineering", "ricognizione": "recon", "scienza": "science", "sicurezza": "security"}

var esp: Esplorazione
var pl: Dictionary = {}
var _sel := 0
var _destinazione := 0
var _occupato := false
var _scelta := {}

var _plancia: TextureRect
var _p3d: Plancia3D
var _sovra: Control
var _widget := {}          # n settore -> {"box", "img", "crew", "info"}
var _info: RichTextLabel
var _pannello: VBoxContainer
var _logbook: PannelloLogbook
var _toast: Label
var _toast_tw: Tween
var _schede := {}
var _membro_box: HBoxContainer
var _passo: RichTextLabel
var _azioni_box: HBoxContainer
var _cassetto_box: PanelContainer
var _cassetto_titolo: Label
var _cassetto_tipo := ""
var _scelta_settore := false
var _consentiti := {}        # settore -> testo mostrato sulla mappa durante una scelta
var _testo_scelta := ""

signal _settore_scelto(n: int)

const ALTO_HUD := 46
const ALTO_TURNO := 58
const ALTO_BARRA := 74

# ------------------------------------------------------------------ avvio

func _init(stato: Dictionary) -> void:
	esp = Esplorazione.new(stato)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Tema.tema
	pl = Carte.pianeta(str(esp.s.get("pagina", "")))
	if Campagna.dati is Dictionary:
		Prova.apprese = Campagna.dati.get_or_add("tabelle_pericolo", {})
	var fondo := ColorRect.new()
	fondo.color = Color(0.008, 0.016, 0.035)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	# la plancia occupa tutto lo spazio fra la riga di stato e la barra del turno
	_plancia = TextureRect.new()
	_plancia.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_plancia.offset_left = 6
	_plancia.offset_top = ALTO_HUD + ALTO_TURNO + 4
	_plancia.offset_right = -6
	_plancia.offset_bottom = -ALTO_BARRA - 4
	_plancia.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plancia.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_plancia)
	_sovra = Control.new()
	_sovra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sovra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plancia.add_child(_sovra)
	_plancia.resized.connect(_disponi)
	# la stessa plancia in 3D (miniature, segnalini in piedi, telecamera libera)
	_p3d = Plancia3D.new()
	_p3d.mis = self
	_p3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_p3d.offset_top = ALTO_HUD + ALTO_TURNO
	_p3d.offset_bottom = -ALTO_BARRA
	_p3d.cliccato.connect(seleziona)
	add_child(_p3d)
	var img := Carte.img_pianeta(str(esp.s.get("pagina", "")))
	if img != "":
		Immagini.carica(img, func(t):
			_plancia.texture = t
			_p3d.imposta_plancia(t)
			_disponi())
	add_child(_hud())
	add_child(_traccia_turno())
	_imposta_vista(vista_3d())
	add_child(_barra_turno())
	add_child(_cassetto())
	# Logbook sopra a tutto, a destra
	_logbook = PannelloLogbook.new()
	_logbook.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_logbook.offset_left = -660
	_logbook.offset_top = ALTO_HUD + 6
	_logbook.offset_bottom = -ALTO_BARRA - 6
	_logbook.offset_right = -6
	add_child(_logbook)
	_logbook.imposta(Campagna.motore)
	_logbook.contesto = self
	_logbook.chiuso.connect(func(): _logbook.visible = false)
	_logbook.chiedi_carta.connect(_carta_dal_logbook)
	_logbook.visible = false
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = ALTO_HUD + 14
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
	if int(esp.s["round"]) == 1 and esp.s["diario"].size() <= 1 and not esp.s.get("tutorial", false) and str(esp.s.get("grado_superiore", "")) == "":
		_scegli_grado.call_deferred()
	if int(esp.s["round"]) == 1 and esp.s["diario"].size() <= 1:
		var br := int(esp.s["lander"].get("briefing", 0))
		if br > 0 and not esp.s.get("briefing_letto", false):
			# prima l'atterraggio: il briefing del Logbook guida la sequenza (contatore, danni, Ferite)
			esp.s["briefing_letto"] = true
			_apri_log(br)
		else:
			for i in esp.vivi():
				_entra_nel_settore(i, [])

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		if _scelta_settore:
			_settore_scelto.emit(-1)
		elif _cassetto_box.visible:
			apri_cassetto("")
		elif _logbook.visible:
			_logbook.visible = false
		get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ riga di stato in alto

func _hud() -> Control:
	var barra := PanelContainer.new()
	barra.set_anchors_preset(Control.PRESET_TOP_WIDE)
	barra.offset_bottom = ALTO_HUD
	barra.add_theme_stylebox_override("panel", Tema.box(Color(0.02, 0.05, 0.11, 0.92), Tema.CIANO_SCURO, 0, 0, 6))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	barra.add_child(h)
	h.add_child(Tema.etichetta(str(pl.get("pianeta", "ESPLORAZIONE")), 17, Tema.TESTO, true))
	_info = Tema.testo_ricco(16)
	_info.fit_content = true
	_info.scroll_active = false
	_info.autowrap_mode = TextServer.AUTOWRAP_OFF
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_info)
	for v in [["settore", "SETTORE"], ["squadra", "SQUADRA"], ["missione", "MISSIONE"], ["diario", "DIARIO"]]:
		var k: String = v[0]
		var b := Tema.pulsante(v[1], func(): apri_cassetto("" if _cassetto_tipo == k and _cassetto_box.visible else k), 12)
		b.toggle_mode = true
		_schede[k] = b
		h.add_child(b)
	var bv := Tema.pulsante("VISTA 2D", func(): _imposta_vista(not _p3d.visible), 12)
	bv.tooltip_text = "Passa dalla plancia in 3D a quella piatta e viceversa"
	_schede["vista"] = bv
	h.add_child(bv)
	h.add_child(Tema.pulsante_primario("LOGBOOK", func():
		_logbook.visible = not _logbook.visible
		if _logbook.visible:
			apri_cassetto("")
			_logbook.mostra_corrente(), 13))
	var menu := MenuButton.new()
	menu.text = "≡"
	menu.flat = false
	menu.add_theme_font_size_override("font_size", 18)
	menu.get_popup().add_item("Salva adesso", 0)
	menu.get_popup().add_item("Tavolo virtuale (l'esplorazione resta salvata)", 1)
	menu.get_popup().add_item("Correzioni manuali…", 2)
	menu.get_popup().id_pressed.connect(_voce_menu)
	h.add_child(menu)
	return barra

static func vista_3d() -> bool:
	return bool(Campagna.dati.get("opzioni", {}).get("vista_3d", true)) if Campagna.dati is Dictionary else true

func _imposta_vista(tre_d: bool) -> void:
	_p3d.visible = tre_d
	_plancia.visible = not tre_d
	if Campagna.dati is Dictionary:
		Campagna.dati.get_or_add("opzioni", {})["vista_3d"] = tre_d
	if _schede.has("vista"):
		_schede["vista"].text = "VISTA 2D" if tre_d else "VISTA 3D"
	if tre_d:
		_p3d.vista_iniziale()
		_p3d.aggiorna()

# ------------------------------------------------------------------ traccia del turno (sotto la riga di stato)

var _turno_box: HBoxContainer
var _turno_guida: RichTextLabel

## Il turno scandito: Round, ordine della Squadra (chi ha giocato, chi è di turno, chi deve ancora),
## i passi del turno (Azione 1, Azione 2, Fine turno con l'Evento) e una riga "cosa fare adesso".
func _traccia_turno() -> Control:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_TOP_WIDE)
	p.offset_top = ALTO_HUD
	p.offset_bottom = ALTO_HUD + ALTO_TURNO
	p.add_theme_stylebox_override("panel", Tema.box(Color(0.015, 0.035, 0.08, 0.96), Tema.CIANO_SCURO, 0, 0, 6))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	_turno_box = HBoxContainer.new()
	_turno_box.add_theme_constant_override("separation", 6)
	v.add_child(_turno_box)
	_turno_guida = Tema.testo_ricco(15)
	_turno_guida.fit_content = true
	_turno_guida.scroll_active = false
	_turno_guida.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(_turno_guida)
	return p

func _chip_turno(testo: String, stato: String, col := Color.WHITE) -> Control:
	var l := Label.new()
	l.text = testo
	l.add_theme_font_override("font", Tema.titolo)
	l.add_theme_font_size_override("font_size", 14)
	var pc := PanelContainer.new()
	var c: Color = {"fatto": Color(0.25, 0.35, 0.45), "ora": Tema.AMBRA, "dopo": Color(0.45, 0.6, 0.75), "evento": Color(0.85, 0.5, 0.95)}.get(stato, col)
	pc.add_theme_stylebox_override("panel", Tema.box(Color(c.r, c.g, c.b, 0.22 if stato == "ora" else 0.08), c, 2 if stato == "ora" else 1, 10, 6))
	l.add_theme_color_override("font_color", c if stato != "fatto" else Color(0.5, 0.6, 0.7))
	pc.add_child(l)
	return pc

func _freccia() -> Label:
	var l := Label.new()
	l.text = "›"
	l.add_theme_color_override("font_color", Tema.TESTO_2)
	return l

func _aggiorna_traccia_turno() -> void:
	if _turno_box == null:
		return
	for c in _turno_box.get_children():
		c.queue_free()
	var att := int(esp.s["attivo"])
	_turno_box.add_child(_chip_turno("ROUND %d" % int(esp.s["round"]), "dopo"))
	_turno_box.add_child(_freccia())
	# ordine della Squadra in questo round
	for i in esp.s["equipaggio"].size():
		var m := esp.membro(i)
		if m["morto"]:
			_turno_box.add_child(_chip_turno("✝ " + str(m["carta"]).get_slice(" ", 0), "fatto"))
			continue
		var stato := "fatto" if m["turno_fatto"] else ("ora" if i == att else "dopo")
		var chip := _chip_turno(("✓ " if stato == "fatto" else ("▶ " if stato == "ora" else "")) + str(m["carta"]).get_slice(" ", 0), stato, Dati.SEZIONI.get(str(m["reparto"]), {}).get("colore", Color.WHITE))
		# l'ordine dei turni lo decidono i giocatori: finché il Membro di turno non ha agito si può cambiare
		if stato == "dopo" and int(esp.s["azioni"]) == 2 and not esp.s["speciale_usata"] and not _occupato:
			var ii: int = i
			chip.tooltip_text = "Fai giocare adesso %s" % m["carta"]
			chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			chip.gui_input.connect(func(e):
				if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
					esp.scegli_attivo(ii)
					_sel = int(esp.membro(ii)["settore"])
					_salva()
					aggiorna()
					if _inizia():
						await _passivi("inizio_turno", ii)
						_finisci())
		_turno_box.add_child(chip)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(24, 0)
	_turno_box.add_child(sp)
	# passi del turno del Membro attivo
	var az := int(esp.s["azioni"])
	var fatte := 2 - az
	for k in 2:
		var st := "fatto" if k < fatte else ("ora" if k == fatte else "dopo")
		_turno_box.add_child(_chip_turno("AZIONE %d" % (k + 1), st))
		_turno_box.add_child(_freccia())
	_turno_box.add_child(_chip_turno("FINE TURNO · EVENTO", "ora" if az <= 0 else "dopo"))
	var resto := esp.vivi().filter(func(i): return not esp.membro(i)["turno_fatto"] and i != att).size()
	_turno_box.add_child(_freccia())
	_turno_box.add_child(_chip_turno("FINE ROUND" if resto == 0 else "%d ANCORA DA GIOCARE" % resto, "dopo"))
	# cosa fare adesso
	var m2 := esp.membro(att)
	var nome := str(m2["carta"])
	var g := ""
	if str(esp.s.get("finita", "")) != "":
		g = "[b]Esplorazione conclusa.[/b] Apri il RIEPILOGO in basso a destra e torna alla nave."
	elif in_atterraggio():
		g = "[b]Atterraggio.[/b] Segui il Logbook: il contatore dell'Atterraggio, i danni e le Ferite li tiene il programma."
	elif _scelta_settore:
		g = "[color=#ffb347][b]%s[/b][/color]" % _testo_scelta
	elif az == 2:
		g = "[b]%s[/b], prima azione: [b]VIAGGIO[/b] in un settore collegato, l'[b]AZIONE SPECIALE[/b] del settore (una per turno), [b]RIPOSO[/b] o [b]PREPARAZIONE[/b]. Le carte in mano si giocano quando vuoi." % nome
	elif az == 1:
		g = "[b]%s[/b], seconda azione%s. Oppure FINE TURNO se non serve." % [nome, " (l'Azione Speciale l'hai già usata)" if esp.s["speciale_usata"] else ""]
	else:
		g = "[b]%s[/b] ha finito le azioni: premi [b]FINE TURNO[/b] — si pesca e si risolve un Evento, poi tocca %s." % [nome, "al prossimo Membro" if resto > 0 else "alla fine del Round: poi un nuovo Round, e decidete voi chi gioca per primo"]
	_turno_guida.text = "[color=#9fbbd6]COSA FARE ▸[/color] " + g

func _voce_menu(id: int) -> void:
	if id == 0:
		_salva()
		Campagna.salva_subito()
		avviso("Salvato")
	elif id == 1:
		_salva()
		chiusa.emit()
	elif id == 2:
		_correzioni(int(esp.s["attivo"]))

# ------------------------------------------------------------------ barra del turno in basso

func _barra_turno() -> Control:
	var barra := PanelContainer.new()
	barra.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	barra.offset_top = -ALTO_BARRA
	barra.add_theme_stylebox_override("panel", Tema.box(Color(0.02, 0.05, 0.11, 0.95), Tema.CIANO_SCURO, 0, 0, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	barra.add_child(h)
	_membro_box = HBoxContainer.new()
	_membro_box.add_theme_constant_override("separation", 10)
	h.add_child(_membro_box)
	h.add_child(VSeparator.new())
	_passo = Tema.testo_ricco(17)
	_passo.fit_content = true
	_passo.scroll_active = false
	_passo.autowrap_mode = TextServer.AUTOWRAP_OFF
	_passo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_passo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_passo)
	_azioni_box = HBoxContainer.new()
	_azioni_box.add_theme_constant_override("separation", 8)
	_azioni_box.alignment = BoxContainer.ALIGNMENT_END
	h.add_child(_azioni_box)
	return barra

## Il Membro di turno: nome, dadi, Ferite e carte in mano, in una sola riga.
func _aggiorna_membro() -> void:
	for c in _membro_box.get_children():
		c.queue_free()
	var att := int(esp.s["attivo"])
	var m := esp.membro(att)
	var col: Color = Dati.SEZIONI.get(str(m["reparto"]), {}).get("colore", Color.WHITE)
	# chi non ha ancora giocato in questo round (si può scegliere finché il turno non è iniziato)
	var cambio: bool = int(esp.s["azioni"]) == 2 and not esp.s["speciale_usata"] and not _occupato and str(esp.s.get("finita", "")) == ""
	for i in esp.s["equipaggio"].size():
		var mi := esp.membro(i)
		if mi["morto"]:
			continue
		var ci: Color = Dati.SEZIONI.get(str(mi["reparto"]), {}).get("colore", Color.WHITE)
		var g := _gettone(str(mi["carta"]).substr(0, 1), ci if not mi["turno_fatto"] or i == att else ci.darkened(0.6), "%s%s" % [mi["carta"], " (turno fatto)" if mi["turno_fatto"] else ""], i == att)
		if i != att and cambio and not mi["turno_fatto"]:
			var jj: int = i
			g.gui_input.connect(func(ev):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					esp.scegli_attivo(jj)
					_sel = int(esp.membro(jj)["settore"])
					_salva()
					aggiorna())
			g.tooltip_text += " — clic: gioca ora il suo turno"
			g.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_membro_box.add_child(g)
	var v := VBoxContainer.new()
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 2)
	var nome := Tema.etichetta(str(m["carta"]), 15, col, true)
	v.add_child(nome)
	var fd := HBoxContainer.new()
	fd.add_theme_constant_override("separation", 3)
	for d in m["dadi"]:
		if d["stato"] != "sacrificato":
			fd.add_child(_chip_dado(d))
	for f in m["ferite"]:
		var l := Label.new()
		l.text = " ✚"
		l.tooltip_text = "Ferita: " + str(NOMI_FERITE.get(f, f))
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		l.add_theme_color_override("font_color", Tema.ROSSO)
		fd.add_child(l)
	v.add_child(fd)
	_membro_box.add_child(v)
	var mano := HBoxContainer.new()
	mano.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mano.add_theme_constant_override("separation", 4)
	for c in m["mano"]:
		var carta := Carte.per_file(str(c))
		var cc: String = str(c)
		var b := Tema.pulsante(Carte.titolo(carta), func(): _carta_in_mano(att, cc), 11)
		b.tooltip_text = Carte.t(carta.get("effetto", ""))
		mano.add_child(b)
	# attrezzatura e abilità del Membro
	for e in m.get("attrezzatura", []):
		var ee := str(e)
		var ce := Carte.per_id(ee)
		var be := Tema.pulsante("⚙ " + Carte.titolo(ce), func(): _usa_attrezzatura(att, ee), 11)
		be.tooltip_text = Carte.t(ce.get("effetto", ""))
		mano.add_child(be)
	var cm := Carte.per_file(str(m.get("file", "")))
	var ab = cm.get("abilita", {})
	if ab is Dictionary and not ab.is_empty():
		var ba := Tema.pulsante("★ %s (%d)" % [str(ab.get("nome", "ABILITÀ")), int(m["cariche"])], func(): _usa_abilita(att), 11)
		ba.tooltip_text = Carte.t(ab) + "\nCariche: %d" % int(m["cariche"])
		mano.add_child(ba)
	_membro_box.add_child(mano)

func _aggiorna_passo() -> void:
	for c in _azioni_box.get_children():
		c.queue_free()
	var att := int(esp.s["attivo"])
	var m := esp.membro(att)
	if str(esp.s.get("finita", "")) != "":
		_passo.text = "[b]Esplorazione terminata[/b]"
		_azioni_box.add_child(Tema.pulsante_primario("RIEPILOGO", func(): apri_cassetto("fine"), 15))
		return
	if _scelta_settore:
		_passo.text = "[color=#ffb347]%s[/color]" % _testo_scelta
		_azioni_box.add_child(Tema.pulsante("ANNULLA", func(): _settore_scelto.emit(-1), 14))
		return
	if _occupato:
		_passo.text = "[color=#9fbbd6]…[/color]"
		return
	var az := int(esp.s["azioni"])
	var sett := int(m["settore"])
	var pallini := "●".repeat(az) + "○".repeat(max(0, 2 - az))
	if az > 0:
		_passo.text = "[b]%s[/b] [color=#9fbbd6]azioni[/color]  %s" % [pallini, "[color=#9fbbd6]· Azione Speciale usata[/color]" if esp.s["speciale_usata"] else ""]
	else:
		_passo.text = "[b]%s[/b]  [color=#ffb347]Azioni finite: termina il turno[/color]" % pallini
	if az > 0:
		var icone: Array = esp.icone_settore(pl, sett, _carte_pdi())
		if not "noMovement" in icone and not esp.sentieri(pl, sett).is_empty():
			_bottone_azione("VIAGGIO", _viaggio, "Scegli sulla mappa un settore collegato")
		var azs := _azioni_settore(sett)
		if not azs.is_empty() and not esp.s["speciale_usata"]:
			if azs.size() == 1:
				var a: Dictionary = azs[0]["azione"]
				_bottone_azione("◆ " + Carte.t(a.get("nome", "")).to_upper(), func(): _esegui_azione(a, azs[0]["fonte"], azs[0]["chiave"], sett), "Azione Speciale del settore (una per turno)", true)
			else:
				_bottone_azione("◆ AZIONE SPECIALE", func():
					_sel = sett
					apri_cassetto("settore"), "Scegli quale Azione Speciale eseguire", true)
		var tel := _segnalino_ovunque("E10")
		var ls := int(esp.s["lander"]["settore"])
		if tel > 0 and tel != ls and (sett == tel or sett == ls):
			var dest_t := ls if sett == tel else tel
			_bottone_azione("TELEFERICA → %d" % dest_t, func():
				esp.usa_azione(false)
				await _muovi(att, dest_t, [])
				_salva()
				aggiorna(), "Teleferica: ci si muove gratis fra il suo settore e quello del Lander (conta come un'azione)")
		if esp.s.get("provviste_illimitate", false) or int(esp.s["lander"]["provviste"]) > 0:
			_bottone_azione("RIPOSO", _riposo, "-1 Provviste, ricarica metà dei dadi (per eccesso), pesca 1 carta")
		_bottone_azione("PREPARAZIONE", _preparazione, "Pesca 1 carta Reparto e/o fai una Prova per le Combinazioni")
		if sett == int(esp.s["lander"]["settore"]):
			_bottone_azione("DECOLLO", _decollo, "Termina l'esplorazione")
	var mb := MenuButton.new()
	if not esp.s["scoperte"].is_empty():
		_bottone_azione("SCOPERTE (%d)" % esp.s["scoperte"].size(), _usa_scoperte, "Scoperte sul Lander con un effetto da usare")
	mb.text = "⋯"
	mb.flat = false
	mb.tooltip_text = "Sforzo e correzioni"
	mb.add_theme_font_size_override("font_size", 18)
	mb.get_popup().add_item("Sforzo: sacrifica 1 dado e ricarica 5 dadi", 0)
	mb.get_popup().add_item("Correzioni manuali…", 1)
	mb.get_popup().id_pressed.connect(func(id): if id == 0: _sforzo() else: _correzioni(att))
	_azioni_box.add_child(mb)
	var fine := Tema.pulsante_primario("FINE TURNO", _fine_turno, 16) if az == 0 else Tema.pulsante("FINE TURNO", _fine_turno, 15)
	fine.tooltip_text = "Gira il segnalino Turno, pesca e risolvi un Evento"
	_azioni_box.add_child(fine)

func _bottone_azione(t: String, cb: Callable, tip: String, primario := false) -> void:
	var b := Tema.pulsante_primario(t, cb, 15) if primario else Tema.pulsante(t, cb, 15)
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(0, 46)
	_azioni_box.add_child(b)

## Azioni Speciali disponibili nel settore (dal PDI in cima o da quello stampato sulla plancia).
func _azioni_settore(n: int) -> Array:
	var carta := _carta_pdi(n)
	var src: Dictionary = carta
	if carta.is_empty():
		for x in pl.get("settori", []):
			if int(x.get("n", 0)) == n and x.get("stampato") is Dictionary:
				src = x["stampato"]
	var out := []
	var azs: Array = src.get("azioni", []) if src.get("azioni") is Array else []
	for k in azs.size():
		out.append({"azione": azs[k], "fonte": Carte.titolo(src), "chiave": "%s#%d" % [esp.pdi_in_cima(n) if not carta.is_empty() else "S%d" % n, k]})
	for mn in esp.s["minacce"]:
		if int(mn.get("settore", 0)) != n:
			continue
		var cm := _carta_minaccia(mn)
		var am: Array = cm.get("azioni", []) if cm.get("azioni") is Array else []
		for k in am.size():
			out.append({"azione": am[k], "fonte": "Minaccia " + str(mn["nome"]), "chiave": "M:%s#%d" % [mn.get("en", mn["nome"]), k], "globale": true})
	out.append_array(_azioni_grado(n))
	return out

## Azione Speciale della carta Grado Superiore (se ce l'ha e il settore ha uno dei biomi richiesti).
func _azioni_grado(n: int) -> Array:
	var out := []
	var gs := str(esp.s.get("grado_superiore", ""))
	if gs == "" or esp.s.get("grado_girato", false):
		return out
	var c := Carte.per_file(gs)
	var biomi: Array = c.get("campi", {}).get("biomi_ammessi", [])
	var icone: Array = esp.icone_settore(pl, n, _carte_pdi())
	if not biomi.is_empty() and not biomi.any(func(b): return b in icone):
		return out
	var az: Array = c.get("azioni", []) if c.get("azioni") is Array else []
	for k in az.size():
		out.append({"azione": az[k], "fonte": "Grado Superiore", "chiave": "GC#grado%d" % k, "globale": true})
	return out

## Condizioni della carta Grado Superiore controllabili dal programma.
func _controlla_grado(fine: bool) -> void:
	var gs := str(esp.s.get("grado_superiore", ""))
	if gs == "" or esp.s.get("grado_girato", false):
		return
	var cond := Carte.en(Carte.per_file(gs).get("campi", {}).get("condizione", "")).to_lower()
	var ok := false
	var tipi := {"mineral": "mineral", "alien tech": "alien_tech", "strange flora": "strange_flora", "microorganism": "microorganism", "live specimen": "live_specimen"}
	if fine:
		for k in tipi:
			if cond.contains("3 %s discoveries" % k):
				ok = esp.s["scoperte"].filter(func(x): return x["tipo"] == tipi[k]).size() >= 3
		if cond.contains("at least 5 discovery cards"):
			ok = esp.s["scoperte"].size() + esp.s["eccezionali"].size() >= 5
		if cond.contains("at least 4 supplies"):
			ok = int(esp.s["lander"]["provviste"]) >= 4
		if cond.contains("one or fewer injury"):
			ok = esp.vivi().all(func(i): return (esp.membro(i)["ferite"] as Array).size() <= 1)
		if cond.contains("7 discarded section cards"):
			ok = esp.vivi().all(func(i): return (esp.membro(i)["scarti"] as Array).size() >= 7)
	if cond.contains("lead token on 3 different"):
		ok = Esplorazione.TIPI_SCOPERTA.filter(func(t): return not (esp.s["indizi"][t] as Array).is_empty()).size() >= 3
	var cd_ecc = pl.get("colonna_destra", {})
	if cond.contains("no more unique discovery") and cd_ecc is Dictionary and str(cd_ecc.get("scoperta_eccezionale", "")).strip_edges() != "":
		ok = (esp.s.get("eccezionali_pianeta", []) as Array).is_empty()
	if cond.contains("3 mission equipment tokens"):
		var n_tok := 0
		for k in esp.s["settori"]:
			n_tok += _segnalini(int(k)).size()
		ok = n_tok >= 3
	if cond.contains("threat card is discarded"):
		ok = esp.s.get("minaccia_scartata", false)
	if ok:
		esp.s["grado_girato"] = true
		esp.diario("Carta Grado Superiore completata")
		avviso("Carta Grado Superiore completata!")

func _scegli_grado() -> void:
	var tutte := Carte.categoria("ferite_gradi").filter(func(c): return str(c.get("tipo", "")) == "rank_up" and not str(c.get("file", "")).contains("tutorial"))
	if tutte.size() < 2:
		return
	tutte.shuffle()
	var due := tutte.slice(0, 2)
	var j := await _scegli("CARTA GRADO SUPERIORE (scegline una)", due.map(func(c): return Carte.t(c.get("campi", {}).get("condizione", ""))),
		"Ship Book pag. 24: si pescano 2 carte Grado Superiore e se ne sceglie una. Se la si completa, a fine esplorazione i Membri con abbastanza Successi salgono di Grado.", false)
	esp.s["grado_superiore"] = str(due[j]["file"])
	esp.diario("Carta Grado Superiore: %s" % Carte.t(due[j].get("campi", {}).get("condizione", "")))
	_salva()
	aggiorna()

# ------------------------------------------------------------------ cassetto laterale (consultazione)

func _cassetto() -> Control:
	_cassetto_box = PanelContainer.new()
	_cassetto_box.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_cassetto_box.offset_left = -470
	_cassetto_box.offset_top = ALTO_HUD + 6
	_cassetto_box.offset_bottom = -ALTO_BARRA - 6
	_cassetto_box.offset_right = -6
	_cassetto_box.add_theme_stylebox_override("panel", Tema.box(Color(0.02, 0.045, 0.09, 0.97), Tema.CIANO_SCURO, 1, 6, 10))
	var v := VBoxContainer.new()
	_cassetto_box.add_child(v)
	var h := HBoxContainer.new()
	_cassetto_titolo = Tema.etichetta("", 15, Tema.CIANO, true)
	_cassetto_titolo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_cassetto_titolo)
	h.add_child(Tema.pulsante("✕", func(): apri_cassetto(""), 13))
	v.add_child(h)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_pannello = VBoxContainer.new()
	_pannello.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pannello.add_theme_constant_override("separation", 8)
	sc.add_child(_pannello)
	_cassetto_box.visible = false
	return _cassetto_box

## Apre il cassetto con una delle schede (settore, squadra, missione, diario, fine); "" lo chiude.
func apri_cassetto(tipo: String) -> void:
	_cassetto_tipo = tipo
	_cassetto_box.visible = tipo != ""
	if tipo != "":
		_logbook.visible = false
	for k in _schede:
		_schede[k].set_pressed_no_signal(k == tipo)
	_aggiorna_pannello()

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
	if _scelta_settore:
		if _consentiti.has(n):
			_settore_scelto.emit(n)
		return
	if _sel == n and _cassetto_box.visible and _cassetto_tipo == "settore":
		apri_cassetto("")
		return
	_sel = n
	apri_cassetto("settore")
	aggiorna()

## Fa scegliere un settore direttamente sulla mappa: consentiti = {settore: testo da mostrare}.
## Restituisce il settore scelto, oppure -1 (Annulla / Esc).
func _scegli_settore(testo: String, consentiti: Dictionary) -> int:
	if consentiti.is_empty():
		return -1
	_scelta_settore = true
	_consentiti = consentiti
	_testo_scelta = testo
	apri_cassetto("")
	aggiorna()
	var n: int = await _settore_scelto
	_scelta_settore = false
	_consentiti = {}
	aggiorna()
	return n

func _tutti_i_settori(testo := "") -> Dictionary:
	var out := {}
	for k in esp.s["settori"]:
		out[int(k)] = testo
	return out

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
		var sel: bool = int(n) == _sel and _cassetto_box.visible and _cassetto_tipo == "settore"
		var att := int(esp.membro(int(esp.s["attivo"]))["settore"]) == int(n) if not esp.vivi().is_empty() else false
		if _scelta_settore:
			var ok := _consentiti.has(int(n))
			w["bordo"].add_theme_stylebox_override("panel", Tema.box(Color(1, 0.7, 0.28, 0.12) if ok else Color(0, 0, 0, 0.55), Tema.AMBRA if ok else Color(0, 0, 0, 0), 3 if ok else 0, 6, 0))
			w["box"].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if ok else Control.CURSOR_ARROW
		else:
			w["bordo"].add_theme_stylebox_override("panel", Tema.box(Color(0, 0, 0, 0), Tema.AMBRA if sel else (Tema.CIANO if att else Color(0.4, 0.7, 1.0, 0.0)), 3 if sel else (2 if att else 0), 6, 0))
			w["box"].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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
		for tk in st.get("attrezzature", []):
			info.append("⚙ " + str(tk.get("nome", "")))
		if _scelta_settore and _consentiti.has(int(n)):
			info = ["➜ " + str(_consentiti[int(n)])] if str(_consentiti[int(n)]) != "" else ["➜"]
		w["info"].text = "  ".join(info)
	if _p3d and _p3d.visible:
		_p3d.aggiorna()

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
	var ind := []
	for t in Esplorazione.TIPI_SCOPERTA:
		var v := 0
		for x in esp.s["indizi"][t]:
			v += int(x.get("v", 1))
		if v > 0:
			ind.append("%s %d/3" % [NOMI_SCOPERTE[t], v])
	var prov := "∞" if esp.s.get("provviste_illimitate", false) else str(esp.s["lander"]["provviste"])
	var gc := _condizione()
	var tm = gc.get("tempo")
	var tempo := ("   [color=#9fbbd6]TEMPO[/color] [b]%d/%d[/b]" % [int(esp.s["condizione"]["tempo"]), int(tm.get("caselle", 0))]) if tm is Dictionary else ""
	var ld: Dictionary = esp.s["lander"]
	if int(ld.get("contatore", 0)) > 0 or int(ld.get("danni", 0)) > 0:
		tempo += "   [color=#9fbbd6]ATTERRAGGIO[/color] [b]%d/%d[/b]%s" % [int(ld.get("contatore", 0)), int(ld.get("caselle", 5)), (" · danni %d" % int(ld["danni"])) if int(ld.get("danni", 0)) > 0 else ""]
	if int(ld.get("corazza", 0)) + int(ld.get("sensori", 0)) + int(ld.get("agilita", 0)) > 0:
		tempo += "   [color=#9fbbd6]LANDER[/color] C%d S%d A%d" % [int(ld.get("corazza", 0)), int(ld.get("sensori", 0)), int(ld.get("agilita", 0))]
	_info.text = "[color=#9fbbd6]ROUND[/color] [b]%d[/b]   [color=#9fbbd6]PROVVISTE[/color] [b]%s[/b]   [color=#9fbbd6]SUCCESSI[/color] [b]%d[/b]   [color=#9fbbd6]SCOPERTE[/color] [b]%d/%d[/b]%s%s" % [
		int(esp.s["round"]), prov, int(esp.s["successi"]), esp.s["scoperte"].size(), int(esp.s["lander"]["max_scoperte"]), tempo,
		("   [color=#9fbbd6]INDIZI[/color] " + ", ".join(ind)) if not ind.is_empty() else ""]
	_aggiorna_membro()
	_aggiorna_passo()
	_aggiorna_traccia_turno()
	if str(esp.s.get("finita", "")) != "" and _cassetto_tipo != "fine" and not _occupato:
		apri_cassetto("fine")
		return
	_aggiorna_pannello()

func _aggiorna_pannello() -> void:
	if not _cassetto_box.visible:
		return
	for c in _pannello.get_children():
		c.queue_free()
	match _cassetto_tipo:
		"settore":
			_cassetto_titolo.text = "SETTORE %d" % _sel
			_sezione_settore()
		"squadra":
			_cassetto_titolo.text = "SQUADRA DI SBARCO"
			_sezione_squadra()
		"missione":
			_cassetto_titolo.text = "CONDIZIONE E MISSIONI"
			_sezione_condizione()
		"diario":
			_cassetto_titolo.text = "DIARIO"
			var righe: Array = esp.s["diario"]
			_testo("\n".join(righe.slice(max(0, righe.size() - 80)).map(func(x): return "• " + str(x))), 14)
		"fine":
			_cassetto_titolo.text = "FINE DELL'ESPLORAZIONE"
			_pannello_fine()

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
	if tit != "":
		_titolo(tit.to_upper(), Tema.AMBRA)
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
	var voci := []
	for k in azioni.size():
		voci.append({"azione": azioni[k], "chiave": "%s#%d" % [esp.pdi_in_cima(n) if not carta.is_empty() else "S%d" % n, k], "fonte": tit, "n": n})
	# Minacce nel settore: carta, traccia del Tempo e Azione Speciale
	for mn in esp.s["minacce"]:
		if int(mn.get("settore", 0)) != n:
			continue
		var cm := _carta_minaccia(mn)
		var trm: Array = cm.get("tempo", []) if cm.get("tempo") is Array else []
		_titolo("☠ " + str(mn["nome"]).to_upper(), Tema.ROSSO)
		_testo("%s\n[color=#9fbbd6]Tempo %d/%d%s[/color]" % [_bb_regole(Carte.t(cm.get("regole", ""))), int(mn.get("tempo", 0)), trm.size(), (" — segnalini sulla carta: %d" % int(mn["marcatori"])) if int(mn.get("marcatori", 0)) > 0 else ""], 14)
		var mm: Dictionary = mn
		_pannello.add_child(Tema.pulsante("VEDI LA CARTA MINACCIA", func(): _mostra_carta(str(mm["file"]), str(mm["nome"])), 12))
		var am: Array = cm.get("azioni", []) if cm.get("azioni") is Array else []
		for k in am.size():
			voci.append({"azione": am[k], "chiave": "M:%s#%d" % [mn.get("en", mn["nome"]), k], "fonte": "Minaccia " + str(mn["nome"]), "n": -1})
	if int(st.get("segni", 0)) > 0:
		_testo("[color=#ffb347]Segnalini Minaccia in questo settore: %d[/color]" % int(st["segni"]), 14)
	if int(st.get("droni", 0)) > 0:
		_testo("[color=#ffb347]Droni dello Sciame Arrogatore: %d[/color]" % int(st["droni"]), 14)
	var pila_b := []
	for mn2 in esp.s["minacce"]:
		if int(mn2.get("settore", 0)) == n and not (mn2.get("pila", []) as Array).is_empty():
			pila_b = mn2["pila"]
	if not pila_b.is_empty():
		_testo("[color=#9fbbd6]Pila di PDI del Biomebot: %d carte (in cima %s)[/color]" % [pila_b.size(), pila_b[0]], 14)
	for tk in _segnalini(n):
		var ce := Carte.per_id(str(tk["id"]))
		var en_t := Carte.en(ce.get("effetto", ""))
		_titolo("⚙ " + Carte.titolo(ce).to_upper(), Tema.VERDE)
		var dopo := en_t.find("this counts as an Action.")
		_testo(_bb_regole(Carte.t(ce.get("effetto", ""))) + ("\n[color=#9fbbd6]Segnalini sopra: %d[/color]" % int(tk["marcatori"]) if int(tk.get("marcatori", 0)) > 0 else ""), 14)
		var hb2 := HBoxContainer.new()
		var tkk: Dictionary = tk
		# "Any Crewmember in a Sector with the X token may [costo] to effetto."
		var mu := RegEx.create_from_string("(?i)may ((?:\\[\\w+\\]\\s*\\+?\\s*)+) to ([^.]+)\\.").search(en_t.substr(max(0, dopo)))
		if mu and presente:
			var costo_t := mu.get_string(1)
			var eff_t := mu.get_string(2)
			hb2.add_child(Tema.pulsante("USA (%s)" % _txt_icone(costo_t), func():
				if not _inizia():
					return
				await applica([{"en": costo_t, "it": "", "fonte": Carte.titolo(ce)}, {"en": eff_t, "it": Carte.t(ce.get("effetto", "")), "fonte": Carte.titolo(ce)}], chi, n)
				_finisci(), 12))
		var att := en_t.find("Activation:")
		if att >= 0 and presente:
			var eff_a := en_t.substr(att + 11)
			for fine in [" Then, detach", ", detach", " detach"]:
				if eff_a.find(fine) >= 0:
					eff_a = eff_a.substr(0, eff_a.find(fine))
					break
			hb2.add_child(Tema.pulsante("ATTIVA", func():
				if not _inizia():
					return
				_segnalini(n).erase(tkk)
				esp.diario("%s: attivazione" % Carte.titolo(ce))
				await applica([{"en": eff_a.strip_edges(), "it": Carte.t(ce.get("effetto", "")), "fonte": Carte.titolo(ce)}], chi, n)
				_finisci(), 12))
		if str(tk["id"]) == "E23" and int(tk.get("padrone", -1)) == chi and int(tk.get("mosso", -1)) != int(esp.s["round"]):
			hb2.add_child(Tema.pulsante("SPOSTA P.E.T.", func():
				var col := esp.collegati(Carte.pianeta(str(esp.s.get("pagina", ""))), n)
				var j := await _scegli("SPOSTA P.E.T.", col.map(func(x): return "Settore %d" % x), "All'inizio del turno P.E.T. può andare in un settore collegato (ignora i divieti di movimento).")
				if j < 0:
					return
				_segnalini(n).erase(tkk)
				tkk["mosso"] = int(esp.s["round"])
				esp.s["settori"][str(col[j])].get_or_add("attrezzature", []).append(tkk)
				esp.diario("P.E.T. si sposta nel Settore %d" % col[j])
				_salva()
				aggiorna(), 12))
		if int(tk.get("marcatori", 0)) > 0:
			hb2.add_child(Tema.pulsante("SCARTA UN SEGNALINO", func():
				tkk["marcatori"] = int(tkk["marcatori"]) - 1
				esp.diario("%s: un segnalino in meno (%d)" % [Carte.titolo(ce), int(tkk["marcatori"])])
				_salva()
				aggiorna(), 12))
		_pannello.add_child(hb2)
	for vv in voci:
		var a: Dictionary = vv["azione"]
		var riq := PanelContainer.new()
		riq.add_theme_stylebox_override("panel", Tema.box(Color(0.03, 0.08, 0.15), Tema.CIANO_SCURO, 1, 4, 8))
		var v := VBoxContainer.new()
		riq.add_child(v)
		var r := Tema.testo_ricco(15)
		r.fit_content = true
		r.scroll_active = false
		var chiave: String = vv["chiave"]
		var fonte_a: String = vv["fonte"]
		r.text = _descrivi_azione(a, chiave, int(vv["n"]))
		v.add_child(r)
		var b := Tema.pulsante_primario("ESEGUI (%s)" % str(esp.membro(chi)["carta"]), func(): _esegui_azione(a, fonte_a, chiave, n), 13)
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
	hm.visible = false
	var apri := Tema.pulsante("CORREZIONI DEL SETTORE ▾", func(): hm.visible = not hm.visible, 11)
	apri.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_pannello.add_child(apri)
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

func _bb_regole(t: String) -> String:
	return Dati.testo_carta(t, 18)

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
		_obiettivo_individuale(i, v)
		_pannello.add_child(riq)

## Fascicoli del personale: la carta Obiettivo individuale accanto alla plancia del Membro.
func _obiettivo_individuale(i: int, v: VBoxContainer) -> void:
	var m := esp.membro(i)
	var ob = m.get("obiettivo")
	if not ob is Dictionary or (ob as Dictionary).is_empty() or m["morto"]:
		return
	var vc := Carte.per_file(str(ob.get("file", "")))
	var n := Fascicoli.caselle(vc)
	var r := Tema.testo_ricco(14)
	r.fit_content = true
	r.scroll_active = false
	r.text = "[color=#ffd36e][b]OBIETTIVO INDIVIDUALE[/b][/color]%s\n%s" % [(" — traccia [b]%d/%d[/b]" % [int(ob.get("traccia", 0)), n]) if n > 0 else "", Dati.testo_carta(Fascicoli.testo_obiettivo(vc), 18)]
	v.add_child(r)
	var hb := HFlowContainer.new()
	hb.add_theme_constant_override("h_separation", 6)
	hb.add_theme_constant_override("v_separation", 4)
	var ii := i
	if n > 0:
		hb.add_child(Tema.pulsante("AVANZA LA TRACCIA", func(): await _avanza_obiettivo(ii, 1), 12))
		hb.add_child(Tema.pulsante("AZZERA", func(): await _avanza_obiettivo(ii, -99), 12))
	hb.add_child(Tema.pulsante_primario("COMPIUTO", func(): await _completa_obiettivo(ii), 12))
	hb.add_child(Tema.pulsante("CARTA", func(): _mostra_carta(str(vc.get("file_retro", vc.get("file", ""))), "Obiettivo individuale"), 12))
	v.add_child(hb)

## Il Membro corrispondente sulla nave (per tenere aggiornata la sua carta Obiettivo).
func _membro_nave(i: int) -> Dictionary:
	var nv = Campagna.dati.get("nave") if Campagna.dati is Dictionary else null
	var k := int(esp.membro(i).get("nave", -1))
	if nv is Dictionary and k >= 0 and k < (nv.get("equipaggio", []) as Array).size():
		return nv["equipaggio"][k]
	return {}

func _avanza_obiettivo(i: int, delta: int) -> void:
	var ob: Dictionary = esp.membro(i)["obiettivo"]
	var vc := Carte.per_file(str(ob.get("file", "")))
	var n := Fascicoli.caselle(vc)
	ob["traccia"] = clampi(int(ob.get("traccia", 0)) + delta, 0, n)
	var mn := _membro_nave(i)
	if mn.get("obiettivo") is Dictionary:
		mn["obiettivo"]["traccia"] = ob["traccia"]
	esp.diario("%s: traccia dell'Obiettivo individuale %d/%d" % [esp.membro(i)["carta"], int(ob["traccia"]), n])
	_salva()
	aggiorna()
	if n > 0 and int(ob["traccia"]) >= n:
		await _completa_obiettivo(i)

## Obiettivo compiuto (File di Completamento, poi File 1): il Membro diventa Veterano subito, anche
## durante una Prova; la nuova abilità di conversione vale da ora, Cariche e plancia non cambiano.
func _completa_obiettivo(i: int) -> void:
	var m := esp.membro(i)
	var ob: Dictionary = m["obiettivo"]
	var vc := Carte.per_file(str(ob.get("file", "")))
	if not await _si_no("OBIETTIVO INDIVIDUALE — %s" % str(m["carta"]).to_upper(), "%s\n\nL'Obiettivo è compiuto? (Completamento: File %s, poi File 1)" % [Dati.testo_carta(Fascicoli.testo_obiettivo(vc), 18), str(vc.get("completamento", "?"))], str(vc.get("file", ""))):
		return
	m["file"] = str(vc.get("file", m["file"]))
	m["veterano"] = true
	var convs := Fascicoli.conversioni(vc)
	var gia := [m.get("conv", {})] + (m.get("conv_extra", []) as Array)
	for c in convs:
		if not gia.any(func(x): return x is Dictionary and str(x.get("colore", "")) == c["colore"] and str(x.get("a", "")) == c["a"]):
			m.get_or_add("conv_extra", []).append(c)
	m["obiettivo"] = {}
	var mn := _membro_nave(i)
	if not mn.is_empty():
		mn["file"] = m["file"]
		mn["veterano"] = true
		mn.erase("obiettivo")
	esp.diario("%s è ora un Veterano" % m["carta"])
	_salva()
	aggiorna()
	await _scegli("NUOVO VETERANO", ["OK"], "[b]%s è ora un Veterano![/b]\nNuovo ritratto e nuova abilità di conversione (vale subito). Le Cariche e la plancia restano come sono." % m["carta"], false, str(vc.get("file", "")))

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
		_testo(_descrivi_azione(gc["viaggio"], "GC#viaggio", -1), 15)
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
		var r := _testo(_descrivi_azione(a, "GC#" + Carte.t(a.get("nome", "")), -1), 15)
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
	if RegEx.create_from_string("^G\\d+(@\\d+)?$").search(id):
		var c := Carte.per_id(id)
		if not c.is_empty():
			return c
	var cd = pl.get("colonna_destra", {})
	if cd is Dictionary and cd.get("condizione") is Dictionary:
		return cd["condizione"]
	return {}

func _pannello_fine() -> void:
	_controlla_grado(true)
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
		# il pianeta resta registrato per la prossima visita (salvo il tutorial)
		if not esp.s.get("tutorial", false):
			Campagna.dati.get_or_add("pianeti_registrati", {})[esp.s["pagina"]] = esp.registra(func(id): return Carte.per_id(id), func(m): return _carta_minaccia(m))
		# le tracce degli Obiettivi individuali che si azzerano a fine esplorazione
		for k in esp.s["equipaggio"].size():
			var mn := _membro_nave(k)
			if mn.get("obiettivo") is Dictionary and Carte.per_file(str(mn["obiettivo"].get("file", ""))).get("azzera_fine_esplorazione", false):
				mn["obiettivo"]["traccia"] = 0
		var arch: Array = Campagna.dati.get_or_add("esplorazioni_concluse", [])
		arch.append({"pagina": esp.s["pagina"], "finita": esp.s["finita"], "successi": esp.s["successi"], "scoperte": esp.s["scoperte"],
			"eccezionali": esp.s["eccezionali"], "grado_girato": esp.s.get("grado_girato", false), "grado_superiore": esp.s.get("grado_superiore", ""), "missioni_rimaste": esp.s["missioni"],
			"tutorial": esp.s.get("tutorial", false), "settori": esp.s["settori"], "minacce": esp.s["minacce"],
			"equipaggio": esp.s["equipaggio"].map(func(m): return {"carta": m["carta"], "reparto": m["reparto"], "ferite": m["ferite"], "morto": m["morto"], "nave": int(m.get("nave", -1)), "grado": int(m["grado"])})})
		var nv = Campagna.dati.get("nave")
		if nv is Dictionary and str(nv.get("passo", "")) == "esplorazione":
			nv["passo"] = "partenza"
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
		f.settore = -1 if (chiave.begins_with("M:") or chiave.begins_with("GC#")) else n
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
	var dest_ok := {}
	var indice := {}
	for k in sentieri.size():
		var a := int(sentieri[k]["a"])
		if not dest_ok.has(a):
			dest_ok[a] = ", ".join((sentieri[k]["icone"] as Array).map(func(x): return _txt_icone("[%s]" % x)))
			indice[a] = k
	var scelto := await _scegli_settore("VIAGGIO: clicca sulla mappa il settore di destinazione", dest_ok)
	if scelto < 0:
		_finisci()
		return
	var j: int = indice[scelto]
	esp.usa_azione(false)
	_scelta = {}
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
				f.settore = -1
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
		elif s == "spendDie" and not _scelta.get("ignorato", false) and await _ignora_spendi_sentiero(chi, sett):
			_scelta["ignorato"] = true
		elif s == "spendDie" or s.begins_with("spendDie") or s == "sacrifaceDie":
			testi.append({"en": "[%s]" % s, "it": "[%s]" % s, "fonte": "sentiero"})
		elif s.begins_with("dangerDie"):
			testi.append({"en": "Roll [%s]." % s, "it": "Tira [%s]." % s, "fonte": "sentiero"})
		else:
			testi.append({"en": "", "it": "Icona del sentiero da risolvere: [%s]" % s, "fonte": "sentiero"})
	await applica(testi, chi, sett)
	if _destinazione > 0 and str(esp.s.get("finita", "")) == "":
		await _muovi(chi, _destinazione, [])
	_destinazione = 0
	_finisci()

func _muovi(chi: int, a: int, logs: Array) -> void:
	esp.viaggia(chi, a)
	_sel = a
	_entra_nel_settore(chi, logs)
	await _passivi("entra", chi)

## Regole sempre attive del PDI del settore e della Condizione Generale, nei momenti in cui scattano:
## "entra" (chi entra nel settore), "inizio_turno", "fine_turno", "riposo", "sforzo".
func _passivi(momento: String, chi: int) -> void:
	if chi < 0 or chi >= esp.s["equipaggio"].size() or esp.membro(chi)["morto"] or str(esp.s.get("finita", "")) != "":
		return
	var sett := int(esp.membro(chi)["settore"])
	var del_settore := ""
	var carta := _carta_pdi(sett)
	if not carta.is_empty():
		del_settore = Carte.en(carta.get("testo", ""))
	else:
		for x in pl.get("settori", []):
			if int(x.get("n", 0)) == sett and x.get("stampato") is Dictionary:
				del_settore = Carte.en(x["stampato"].get("testo", ""))
	var globale := Carte.en(_condizione().get("testo", ""))
	var testi := []
	var icone := esp.icone_settore(pl, sett, _carte_pdi())
	var frasi := func(t: String) -> Array: return Array(RegEx.create_from_string("(?<=\\.)\\s+").sub(t, "§", true).split("§")).map(func(x): return str(x).strip_edges())
	var trova := func(t: String, rx: String) -> String:
		var m := RegEx.create_from_string(rx).search(t)
		return m.get_string(m.get_group_count()) if m else ""
	for f in frasi.call(del_settore):
		var e := ""
		match momento:
			"fine_turno": e = trova.call(f, "(?i)^each crew\\w* who ends their turn in this sector,? (.+)$")
			"entra": e = trova.call(f, "(?i)^each crew\\w* who enters this sector,? (.+)$")
			"inizio_turno": e = trova.call(f, "(?i)^each crew\\w* who starts their turn in this sector,? (?!must)(.+)$")
			"riposo": e = trova.call(f, "(?i)^whenever you rest(?: or exert)? in this sector,? (.+)$")
			"sforzo": e = trova.call(f, "(?i)^whenever you rest or exert in this sector,? (.+)$")
		if e != "":
			testi.append({"en": e, "it": Carte.t(carta.get("testo", "")) if not carta.is_empty() else e, "fonte": "Settore %d" % sett})
	for f in frasi.call(globale):
		var e2 := ""
		match momento:
			"inizio_turno":
				var m1 := RegEx.create_from_string("(?i)^each crew\\w* who starts their turn with (\\d+) or fewer available dice,? (.+)$").search(f)
				if m1 and esp.dadi_disponibili(chi).size() <= int(m1.get_string(1)):
					e2 = m1.get_string(2)
				var m2 := RegEx.create_from_string("(?i)^each crew\\w* who starts their turn in a sector with an? \\[(\\w+)\\]( and without the builder's biomebot)?,? (?:immediately )?(.+)$").search(f)
				if m2 and m2.get_string(1) in icone and (m2.get_string(2) == "" or not _minaccia_in("Builder's Biomebot", sett)):
					e2 = m2.get_string(3)
			"riposo": e2 = trova.call(f, "(?i)^whenever you rest(?: or exert)?,? (.+)$")
			"sforzo": e2 = trova.call(f, "(?i)^whenever you rest or exert,? (.+)$")
		if e2 != "":
			testi.append({"en": e2, "it": e2, "fonte": "Condizione Generale"})
	if testi.is_empty():
		return
	var m := esp.membro(chi)
	var resto := []
	var fatti := []
	for t in testi:
		var en := str(t["en"])
		var lo := en.to_lower()
		if lo.contains("draw cards up to your hand limit"):
			var n := 0
			while (m["mano"] as Array).size() < esp.limite_mano(chi) and esp.pesca_carta(chi) != "":
				n += 1
			fatti.append("%s pesca %d carte fino al limite della mano (%s)" % [m["carta"], n, t["fonte"]])
		elif lo.contains("refresh 1 [die] fewer"):
			esp.spendi_dado(chi)
			fatti.append("%s ricarica 1 dado in meno (%s)" % [m["carta"], t["fonte"]])
		else:
			resto.append(t)
	if not fatti.is_empty():
		avviso("; ".join(fatti))
		esp.diario("; ".join(fatti))
	if not resto.is_empty():
		await applica(resto, chi, sett)

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
	var prov_prima := int(esp.s["lander"]["provviste"])
	esp.riposa(chi)
	_bonus_avamposto(chi)
	await _scatti_riposo(chi, prov_prima)
	await _passivi("riposo", chi)
	await _scarta_eccesso()
	_finisci()

# ------------------------------------------------------------------ effetti a scatto

func _porta(i: int, id: String) -> bool:
	return str(id) in esp.membro(i).get("attrezzatura", [])

func _si_no(titolo: String, testo: String, immagine := "") -> bool:
	var j := await _scegli(titolo.to_upper(), ["SÌ", "NO"], testo, false, immagine)
	return j == 0

## Riposo: abilità "When Resting" (niente Provviste / 1 dado e 1 carta in più) e attrezzatura per tutti.
func _scatti_riposo(chi: int, prov_prima: int) -> void:
	var m := esp.membro(chi)
	var ab = Carte.per_file(str(m.get("file", ""))).get("abilita", {})
	var en := Carte.en(ab).to_lower() if ab is Dictionary else ""
	if en.begins_with("when resting") and int(m["cariche"]) > 0:
		if await _si_no("Abilità " + str(ab.get("nome", "")), Dati.testo_carta(Carte.t(ab), 20) + "\n\nCariche: %d. Usi l'abilità?" % int(m["cariche"])):
			m["cariche"] = int(m["cariche"]) - 1
			if en.contains("not spend supplies"):
				esp.s["lander"]["provviste"] = prov_prima
			if en.contains("refresh 1 [die] more"):
				esp.ricarica(chi, 1, "")
			if en.contains("draw 1 additional card"):
				esp.pesca_carta(chi)
			esp.diario("%s usa l'abilità %s" % [m["carta"], ab.get("nome", "")])
	for i in esp.vivi():
		for e in esp.membro(i).get("attrezzatura", []):
			var ce := Carte.per_id(str(e))
			if str(ce.get("quando", "")) == "on_rest" and Carte.en(ce.get("effetto", "")).to_lower().contains("refreshes 1 [die] more when resting"):
				esp.ricarica(chi, 1, "")
				avviso("%s: 1 dado in più" % Carte.titolo(ce))

## Attrezzatura che evita una Ferita ("you may return this card to the Armory instead of gaining that Injury").
func _evita_ferita(chi: int, tipo: String, fatti: Array) -> bool:
	if esp.s.get("tutorial", false):
		return false
	var nomi := {"wounded": "wounded", "critically_wounded": "critically wounded", "burned": "burned", "panicked": "panicked", "exhausted": "exhausted", "freezing": "freezing"}
	for e in esp.membro(chi).get("attrezzatura", []):
		var ce := Carte.per_id(str(e))
		var en := Carte.en(ce.get("effetto", "")).to_lower()
		if not en.contains("instead of gaining that injury"):
			continue
		var vale := en.contains("if you would gain an injury")
		if not vale and en.contains("if you gain the"):
			var elenco := en.substr(en.find("if you gain the"), en.find("injury") - en.find("if you gain the"))
			vale = elenco.contains(nomi.get(tipo, tipo)) and not (tipo == "wounded" and not RegEx.create_from_string("(^|[ ,])wounded").search(elenco.replace("critically wounded", "")))
		if vale and await _si_no(Carte.titolo(ce), "%s sta per subire la Ferita %s.\n%s\n\nRimetti la carta nell'Armeria per evitarla?" % [esp.membro(chi)["carta"], NOMI_FERITE.get(tipo, tipo), Dati.testo_carta(Carte.t(ce.get("effetto", "")), 20)]):
			(esp.membro(chi)["attrezzatura"] as Array).erase(str(e))
			fatti.append("%s evita la Ferita %s con %s" % [esp.membro(chi)["carta"], NOMI_FERITE.get(tipo, tipo), Carte.titolo(ce)])
			return true
	# carte Reparto in mano: "non subire quella Ferita" o "la subisci tu (Lesione) al posto di un altro"
	for c in esp.membro(chi)["mano"].duplicate():
		var cc := Carte.per_file(str(c))
		if Carte.en(cc.get("effetto", "")).to_lower().contains("when you would gain an injury, do not gain that injury"):
			if await _si_no(Carte.titolo(cc), "%s sta per subire la Ferita %s.\nGiochi la carta per non subirla?" % [esp.membro(chi)["carta"], NOMI_FERITE.get(tipo, tipo)], str(cc.get("file", ""))):
				esp.scarta_carta(chi, str(c))
				fatti.append("%s non subisce la Ferita %s (%s)" % [esp.membro(chi)["carta"], NOMI_FERITE.get(tipo, tipo), Carte.titolo(cc)])
				return true
	var sc := int(esp.membro(chi)["settore"])
	for j in esp.vivi():
		if j == chi:
			continue
		var sj := int(esp.membro(j)["settore"])
		if sj != sc and not sc in esp.collegati(pl, sj):
			continue
		for c in esp.membro(j)["mano"].duplicate():
			var cc2 := Carte.per_file(str(c))
			if Carte.en(cc2.get("effetto", "")).to_lower().contains("you gain a wounded injury instead"):
				if await _si_no(Carte.titolo(cc2), "%s sta per subire la Ferita %s.\n%s gioca la carta e subisce invece una Ferita Lesione?" % [esp.membro(chi)["carta"], NOMI_FERITE.get(tipo, tipo), esp.membro(j)["carta"]], str(cc2.get("file", ""))):
					esp.scarta_carta(j, str(c))
					var r := esp.ferita(j, "wounded")
					fatti.append("%s subisce la Ferita al posto di %s%s" % [esp.membro(j)["carta"], esp.membro(chi)["carta"], " (evacuazione!)" if r == "evac" else ""])
					return true
	return false

## Tute contro il dado Pericolo: ignorare l'effetto (nei biomi indicati) pagando dadi, oppure ritirarlo.
func _pericolo_ignorato(chi: int, sett: int, d: Dictionary, fatti: Array) -> bool:
	var icone := esp.icone_settore(pl, sett, _carte_pdi())
	for e in esp.membro(chi).get("attrezzatura", []):
		var ce := Carte.per_id(str(e))
		var en := Carte.en(ce.get("effetto", ""))
		var q := str(ce.get("quando", ""))
		if not q in ["danger_roll", "on_danger_roll"]:
			continue
		var faccia := "+".join(Prova.icone(d)) if not Prova.icone(d).is_empty() else "vuota"
		if en.to_lower().contains("to ignore that roll's effect"):
			var biomi := RegEx.create_from_string("\\[(\\w+)\\]").search_all(en.substr(0, en.find(":"))).map(func(m): return m.get_string(1))
			if not biomi.is_empty() and not biomi.any(func(b): return b in icone):
				continue
			var costo := 2 if en.contains("2 [spendDie]") else 1
			if esp.dadi_disponibili(chi).size() >= costo and await _si_no(Carte.titolo(ce), "Dado Pericolo: %s.\nSpendi %d dado/i per ignorarne l'effetto?" % [faccia, costo]):
				for k in costo:
					esp.spendi_dado(chi)
				fatti.append("%s ignora il dado Pericolo con %s" % [esp.membro(chi)["carta"], Carte.titolo(ce)])
				return true
		elif en.to_lower().contains("reroll a danger die"):
			if esp.dadi_disponibili(chi).size() >= 1 and await _si_no(Carte.titolo(ce), "Dado Pericolo: %s.\nPaghi il costo della tuta per ritirarlo?" % faccia):
				esp.spendi_dado(chi, "blue") if esp.dadi_disponibili(chi).any(func(x): return Prova.colore(x) == "blue") else esp.spendi_dado(chi)
				Prova.tira(d, esp.rng)
				fatti.append("%s ritira il dado Pericolo con %s" % [esp.membro(chi)["carta"], Carte.titolo(ce)])
	return false

## Tute che permettono di ignorare un [spendDie] del sentiero.
func _ignora_spendi_sentiero(chi: int, sett: int) -> bool:
	var icone := esp.icone_settore(pl, sett, _carte_pdi())
	for e in esp.membro(chi).get("attrezzatura", []):
		var ce := Carte.per_id(str(e))
		var en := Carte.en(ce.get("effetto", ""))
		if str(ce.get("quando", "")) != "travel" or not en.contains("ignore 1 [spendDie]"):
			continue
		var m := RegEx.create_from_string("(?i)from sectors with ([^,]*(?:,[^,]*)*?)(?:, add|: add| add)").search(en)
		if m:
			var biomi := RegEx.create_from_string("\\[(\\w+)\\]").search_all(m.get_string(1)).map(func(x): return x.get_string(1))
			if not biomi.any(func(b): return b in icone):
				continue
		if await _si_no(Carte.titolo(ce), "Ignori un [img height=20]%s[/img] del sentiero grazie a %s?" % [Dati.icona("spendDie"), Carte.titolo(ce)]):
			return true
	return false

## Scoperta appena ottenuta: effetto "quando la ottieni" e attrezzatura che dà Indizi in più.
func _scoperta_ottenuta(file: String, tipo: String, chi: int, fatti: Array, manuali: Array, logs: Array) -> void:
	var c := Carte.per_file(file)
	var pe = c.get("campi", {}).get("esplorazione")
	if pe is Dictionary and Carte.en(pe).to_lower().begins_with("when you gain this"):
		var a := Effetti.analizza(Carte.en(pe))
		for op in a["op"]:
			await _op(op, chi, int(esp.membro(chi)["settore"]), fatti, manuali, logs, Carte.titolo(c))
		if str(a["resto"]) != "":
			manuali.append("%s: %s" % [Carte.titolo(c), Carte.t(pe)])
	for e in esp.membro(chi).get("attrezzatura", []):
		var ce := Carte.per_id(str(e))
		if str(ce.get("quando", "")) == "when_gain_discovery" and esp.dadi_disponibili(chi).size() > 0:
			if await _si_no(Carte.titolo(ce), "%s\n\nSpendi un dado per ottenere 2 Indizi %s?" % [Dati.testo_carta(Carte.t(ce.get("effetto", "")), 20), NOMI_SCOPERTE.get(tipo, tipo)]):
				esp.spendi_dado(chi)
				esp.indizi(tipo, 2)
				fatti.append("%s: 2 Indizi %s" % [Carte.titolo(ce), NOMI_SCOPERTE.get(tipo, tipo)])

## Scoperte con un'abilità da usare in esplorazione ("You may discard this card to …").
func _usa_scoperte() -> void:
	var usabili := []
	for k in esp.s["scoperte"].size():
		var c := Carte.per_file(str(esp.s["scoperte"][k]["carta"]))
		var pe = c.get("campi", {}).get("esplorazione")
		if pe is Dictionary and Carte.en(pe).to_lower().begins_with("you may discard this card to"):
			usabili.append([k, c, pe])
	if usabili.is_empty():
		avviso("Nessuna Scoperta con un effetto da usare adesso (quelle \"durante una Prova\" si usano dalla Prova)")
		return
	var j := await _scegli("SCOPERTE DEL LANDER", usabili.map(func(x): return "%s — %s" % [Carte.titolo(x[1]), _pulito_bb(Carte.t(x[2]))]), "Scartando la Scoperta ne applichi l'effetto (torna in fondo al suo mazzo).")
	if j < 0 or not _inizia():
		_finisci()
		return
	var sc: Dictionary = esp.s["scoperte"][usabili[j][0]]
	esp.s["scoperte"].remove_at(usabili[j][0])
	esp.s["mazzi_scoperte"].get_or_add(str(sc["tipo"]), []).insert(0, sc["carta"])
	var en := Carte.en(usabili[j][2])
	en = en.substr(en.to_lower().find(" to ") + 4)
	await applica([{"en": en, "it": Carte.t(usabili[j][2]), "fonte": Carte.titolo(usabili[j][1])}], int(esp.s["attivo"]), int(esp.membro(int(esp.s["attivo"]))["settore"]))
	_finisci()

static func _pulito_bb(t: String) -> String:
	return t.replace("[", "").replace("]", "")

## Attrezzature di missione piazzate in un settore.
func _segnalini(n: int) -> Array:
	return esp.s["settori"].get(str(n), {}).get("attrezzature", [])

func _ha_segnalino(n: int, id: String) -> bool:
	return _segnalini(n).any(func(x): return str(x["id"]) == id)

func _segnalino_ovunque(id: String) -> int:
	for k in esp.s["settori"]:
		if _ha_segnalino(int(k), id):
			return int(k)
	return -1

## Avamposto (E47): riposando o facendo uno Sforzo nel suo settore si ricaricano 2 dadi in più.
func _bonus_avamposto(chi: int) -> void:
	var sm := int(esp.membro(chi)["settore"])
	var av := _segnalino_ovunque("E47")
	if av >= 0 and (av == sm or (_ha_segnalino(av, "E58") and sm in esp.collegati(Carte.pianeta(str(esp.s.get("pagina", ""))), av))):
		var f := esp.ricarica(chi, 2, "")
		avviso("Avamposto: %s ricarica %d dadi in più" % [esp.membro(chi)["carta"], f])

## Drone Medevac (E08): la quarta Ferita si ignora e il Membro va nel settore del Lander.
func _salva_con_drone(chi: int, fatti: Array) -> bool:
	if str(esp.s.get("finita", "")) != "evac" or _segnalino_ovunque("E08") < 0:
		return false
	esp.s["finita"] = ""
	esp.viaggia(chi, int(esp.s["lander"]["settore"]))
	fatti.append("Drone Medevac: la quarta Ferita di %s si ignora e torna nel settore del Lander" % esp.membro(chi)["carta"])
	return true

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
	if str(esp.s.get("finita", "")) == "":
		_bonus_avamposto(chi)
		await _passivi("sforzo", chi)
		for e in esp.membro(chi).get("attrezzatura", []):
			if str(Carte.per_id(str(e)).get("quando", "")) == "on_exert" and Carte.en(Carte.per_id(str(e)).get("effetto", "")).to_lower().contains("refresh 1"):
				esp.ricarica(chi, 1, "")
				avviso("%s: ricarichi 1 dado in più" % Carte.titolo(Carte.per_id(str(e))))
	var fz := []
	if _salva_con_drone(chi, fz):
		avviso(fz[0])
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
	await _passivi("fine_turno", chi)
	_controlla_grado(false)
	var salta: bool = esp.s.get("salta_evento", false)
	esp.s.erase("salta_evento")
	var sosp: bool = esp.s.get("eventi_sospesi", false)
	if salta:
		esp.s["eventi_sospesi"] = true
	var ev := esp.fine_turno()
	if salta:
		esp.s["eventi_sospesi"] = sosp
	if ev != "" and await _scarta_evento(chi, ev):
		ev = ""
	if ev != "":
		await _risolvi_evento(ev, chi)
	if str(esp.s.get("finita", "")) == "":
		if esp.round_finito():
			esp.prossimo_round(int(esp.s.get("primo", 0)))
			avviso("Inizia il Round %d — tocca a %s (clicca un altro nome nella traccia del turno per cambiare)" % [int(esp.s["round"]), esp.membro(int(esp.s["attivo"]))["carta"]])
		else:
			for k in esp.s["equipaggio"].size():
				var j2: int = (chi + 1 + k) % esp.s["equipaggio"].size()
				if not esp.membro(j2)["turno_fatto"] and not esp.membro(j2)["morto"]:
					esp.scegli_attivo(j2)
					break
		_sel = int(esp.membro(int(esp.s["attivo"]))["settore"])
		await _passivi("inizio_turno", int(esp.s["attivo"]))
	_finisci()

## Carta Reparto che scarta l'Evento appena pescato senza risolverlo.
func _scarta_evento(chi: int, ev: String) -> bool:
	for c in esp.membro(chi)["mano"]:
		var en := Carte.en(Carte.per_file(str(c)).get("effetto", "")).to_lower()
		if en.contains("discard an event card you just drew"):
			var ce := Carte.per_file(ev)
			if await _si_no(Carte.titolo(Carte.per_file(str(c))), "Evento pescato: %s\n\nGiochi la carta per scartarlo senza risolverlo?" % Carte.titolo(ce), str(ce.get("file", ""))):
				esp.scarta_carta(chi, str(c))
				esp.diario("%s scarta l'Evento %s" % [esp.membro(chi)["carta"], Carte.titolo(ce)])
				return true
	return false

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

## Attrezzatura: paga il costo (dadi, azione) e applica l'effetto; si può anche passare a chi è nel settore.
func _usa_attrezzatura(i: int, id: String) -> void:
	var c := Carte.per_id(id)
	var en := Carte.en(c.get("effetto", ""))
	var it := Carte.t(c.get("effetto", ""))
	var quando := str(c.get("quando", ""))
	var usabile: bool = quando in ["spend_cost", "anytime", "action", "travel", "start_of_turn", ""] and not _occupato
	var opz := []
	if usabile:
		opz.append("USA")
	var altri := esp.nel_settore(int(esp.membro(i)["settore"])).filter(func(j): return j != i)
	for j in altri:
		opz.append("PASSALA A " + str(esp.membro(j)["carta"]))
	var testo := "[b]%s[/b]\n%s%s" % [{"smallEquipment": "Piccola attrezzatura", "personalEquipment": "Attrezzatura personale", "missionEquipment": "Attrezzatura di missione", "missionEquipmentUpgrades": "Potenziamento"}.get(str(c.get("tipo", "")), ""),
		Dati.testo_carta(it, 20), "\n\n[color=#9fbbd6]Si usa durante una Prova (dalla finestra della Prova) o si applica da sola.[/color]" if not usabile else ""]
	var k := await _scegli(Carte.titolo(c).to_upper(), opz, testo, true, str(c.get("file", "")))
	if k < 0:
		return
	if opz[k] != "USA":
		var j: int = altri[k - (1 if usabile else 0)]
		(esp.membro(i)["attrezzatura"] as Array).erase(id)
		esp.membro(j)["attrezzatura"].append(id)
		esp.diario("%s passa %s a %s" % [esp.membro(i)["carta"], Carte.titolo(c), esp.membro(j)["carta"]])
		_salva()
		aggiorna()
		return
	if not _inizia():
		return
	var rx_tok := RegEx.create_from_string("(?i)place (?:(?:a|an|the) )?([\\w.'-]+(?: [\\w.'-]+){0,3}?) token in your sector(?:,? and (\\d+) markers on the token)?")
	var tok := rx_tok.search(en)
	var sett_i := int(esp.membro(i)["settore"])
	if tok and en.to_lower().contains("if you are in a lander sector") and sett_i != int(esp.s["lander"]["settore"]):
		avviso("Si può piazzare solo nel settore del Lander")
		_finisci()
		return
	if en.to_lower().contains("counts as an action"):
		if not esp.usa_azione(false):
			avviso("Serve un'azione")
			_finisci()
			return
	var testi := []
	var costo := str(c.get("costo", "")) if c.get("costo") != null else ""
	if costo != "" and costo != "null":
		var alt := Array(costo.split(" / "))
		var j2 := 0
		if alt.size() > 1:
			j2 = await _scegli("COSTO", alt.map(func(x): return _txt_icone("[" + str(x).replace("+", "] + [") + "]")), "", false)
		testi.append({"en": "[" + str(alt[j2]).replace("+", "] [") + "]", "it": "", "fonte": Carte.titolo(c)})
	# l'effetto senza il costo iniziale ("[spendDie]: ...")
	var eff := en
	var due := en.find("]:")
	if due >= 0 and due < 60:
		eff = en.substr(due + 2)
	if tok:
		# requisiti dei potenziamenti dell'Avamposto e degli altri segnalini
		var lo := en.to_lower()
		var serve := []
		if lo.contains("if there is an outpost token") or lo.contains("if there are outpost"):
			serve.append("E47")
		if lo.contains("and expansion tokens"):
			serve.append("E58")
		if lo.contains("if there is a modular turret token"):
			serve.append("E62")
		for sv in serve:
			if not _ha_segnalino(sett_i, sv):
				avviso("Serve il segnalino %s in questo settore" % Carte.titolo(Carte.per_id(sv)))
				_finisci()
				return
		if lo.contains("but no other final outpost upgrades") and _segnalini(sett_i).any(func(x): return str(x["id"]) in ["E57", "E59", "E60"]):
			avviso("C'è già un Potenziamento finale dell'Avamposto")
			_finisci()
			return
		var dado_pet := {}
		if id == "E23":
			var dd := esp.dadi_disponibili(i)
			if dd.is_empty():
				avviso("Serve un dado disponibile da mettere su P.E.T.")
				_finisci()
				return
			var jd := await _scegli("DADO PER P.E.T.", dd.map(func(x): return "%s (%s)" % [x["tipo"], Prova.colore(x)]), "Il dado resta su P.E.T. e assiste le Prove nel suo settore.", false)
			dado_pet = dd[max(0, jd)]
			dado_pet["stato"] = "pet"
		# Attrezzatura di missione: il segnalino resta nel settore e i suoi effetti valgono per tutti
		var marc := int(tok.get_string(2)) if tok.get_string(2) != "" else 0
		var m3 := RegEx.create_from_string("(?i)place (\\d+) markers on this card").search(en)
		if m3:
			marc = int(m3.get_string(1))
		var nuovo := {"id": id, "nome": tok.get_string(1), "marcatori": marc}
		if id == "E23":
			nuovo["padrone"] = i
			nuovo["dado"] = dado_pet.duplicate()
			nuovo["mosso"] = int(esp.s["round"])
		esp.s["settori"][str(sett_i)].get_or_add("attrezzature", []).append(nuovo)
		(esp.membro(i)["attrezzatura"] as Array).erase(id)
		esp.diario("%s piazza il segnalino %s nel Settore %d" % [esp.membro(i)["carta"], tok.get_string(1), sett_i])
		await applica(testi, i, sett_i)
		_finisci()
		return
	testi.append({"en": eff, "it": it, "fonte": Carte.titolo(c)})
	if eff.to_lower().contains("return this card to the armory") or eff.to_lower().contains("discard this card"):
		(esp.membro(i)["attrezzatura"] as Array).erase(id)
	esp.diario("%s usa %s" % [esp.membro(i)["carta"], Carte.titolo(c)])
	await applica(testi, i, int(esp.membro(i)["settore"]))
	_finisci()

## Abilità del Membro: spende 1 Carica e applica l'effetto.
func _usa_abilita(i: int) -> void:
	var m := esp.membro(i)
	var cm := Carte.per_file(str(m.get("file", "")))
	var ab: Dictionary = cm.get("abilita", {})
	var en := Carte.en(ab)
	var it := Carte.t(ab)
	var durante: bool = en.to_lower().begins_with("during a dice check") or en.to_lower().begins_with("when assisting")
	var testo := "%s\n\nCariche: [b]%d[/b]%s" % [Dati.testo_carta(it, 20), int(m["cariche"]), "\n[color=#9fbbd6]Si usa dalla finestra della Prova.[/color]" if durante else ""]
	var opz := [] if durante or int(m["cariche"]) <= 0 else ["USA (spendi 1 Carica)"]
	var k := await _scegli("ABILITÀ " + str(ab.get("nome", "")).to_upper() + " — " + str(m["carta"]), opz, testo, true, str(cm.get("file", "")))
	if k != 0:
		return
	if not _inizia():
		return
	m["cariche"] = int(m["cariche"]) - 1
	var eff := en
	var rx := RegEx.create_from_string("(?i)spend (?:1|one) charges? to ").search(en)
	if rx:
		eff = en.substr(rx.get_end())
	esp.diario("%s usa l'abilità %s" % [m["carta"], ab.get("nome", "")])
	await applica([{"en": eff, "it": it, "fonte": "Abilità " + str(ab.get("nome", ""))}], i, int(m["settore"]))
	_finisci()

func _carta_in_mano(i: int, c: String) -> void:
	var carta := Carte.per_file(c)
	var testo := "[b]%s[/b]\n%s" % [Carte.t(carta.get("quando", "")) if carta.get("quando") is Dictionary else str(carta.get("quando", "")).replace("_", " "), Dati.testo_carta(Carte.t(carta.get("effetto", "")), 20)]
	if carta.get("combo") is Dictionary:
		testo += "\n\n[color=#ffb347]Combinazione[/color] %s: %s" % [_req(str(carta["combo"].get("req", ""))), Dati.testo_carta(Carte.t(carta["combo"]), 20)]
	var j := await _scegli(Carte.titolo(carta), ["GIOCA (applica l'effetto e scarta)", "SCARTA"], testo, true, str(carta.get("file", "")))
	if j == 0:
		if not await _gioca_reparto(i, c):
			esp.scarta_carta(i, c)
			await applica([{"en": Carte.en(carta.get("effetto", "")), "it": Carte.t(carta.get("effetto", "")), "fonte": Carte.titolo(carta)}], i, int(esp.membro(i)["settore"]))
	elif j == 1:
		esp.scarta_carta(i, c)
	_salva()
	aggiorna()

const BIOMI := ["ruins", "vegetation", "void", "deadly", "rocky", "caves", "volvanic", "volcanic", "desert", "water", "frigid", "hostile", "crystalline"]

## Carte Reparto "In qualsiasi momento" / "Prima o dopo un'Azione" con effetti propri.
## Restituisce true se l'effetto è stato gestito qui (la carta è già scartata o la giocata annullata).
func _gioca_reparto(i: int, c: String) -> bool:
	var carta := Carte.per_file(c)
	var en := Carte.en(carta.get("effetto", ""))
	for pre in ["Anytime: ", "Before or after an Action: "]:
		en = en.trim_prefix(pre)
	var lo := en.to_lower()
	var m := esp.membro(i)
	var sett := int(m["settore"])
	var tit := Carte.titolo(carta)
	# carte che scattano da sole in altri momenti
	if lo.contains("would gain an injury") or lo.contains("event card you just drew") or lo.contains("reroll 1 danger die"):
		avviso("%s scatta da sola al momento giusto (Ferita, Evento o dado Pericolo)" % tit)
		return true
	# condizioni
	var cond := RegEx.create_from_string("(?i)^if (?:you are in a sector with|your sector has) ([^,]+), ").search(en)
	if cond:
		var cl := cond.get_string(1).to_lower()
		var vero := true
		if cl.contains("mission equipment"):
			vero = not _segnalini(sett).is_empty()
		elif cl.contains("at least 2 biome icons"):
			vero = esp.icone_settore(pl, sett, _carte_pdi()).filter(func(x): return str(x) in BIOMI).size() >= 2
		elif cl.contains("no [finalpoi]"):
			vero = not esp.icone_settore(pl, sett, _carte_pdi()).has("finalPOI")
		elif cl.contains("a threat"):
			vero = esp.s["minacce"].any(func(x): return int(x.get("settore", 0)) == sett)
		if not vero:
			avviso("%s: condizione non soddisfatta (%s)" % [tit, _pulito_bb(cond.get_string(1))])
			return true
		en = en.substr(cond.get_end())
		lo = en.to_lower()
	var serve_carta := lo.begins_with("discard 1 additional card to ")
	var altre: Array = (m["mano"] as Array).filter(func(x): return str(x) != c)
	if serve_carta and altre.is_empty():
		avviso("%s: serve un'altra carta da scartare" % tit)
		return true
	var gestita := lo.contains("refresh a total of") or lo.contains("small equipment card from the armory") or lo.contains("move 1 crewmember from your sector") \
		or lo.contains("discard 1 discovery to gain") or lo.contains("discard 1 charge to gain") or lo.contains("move 1 lead token") \
		or lo.contains("discard 1 lead token") or lo.contains("end your turn") or lo.contains("discarded lead token")
	if not gestita:
		if serve_carta:
			# scarto aggiuntivo, poi l'effetto generico
			var k0 := await _scegli("SCARTA UN'ALTRA CARTA", altre.map(func(x): return Carte.titolo(Carte.per_file(str(x)))), "", true)
			if k0 < 0:
				return true
			esp.scarta_carta(i, c)
			esp.scarta_carta(i, str(altre[k0]))
			await applica([{"en": en.substr(29), "it": Carte.t(carta.get("effetto", "")), "fonte": tit}], i, sett)
			return true
		return false
	if not _inizia():
		return true
	var fatti := []
	if serve_carta:
		var k := await _scegli("SCARTA UN'ALTRA CARTA", altre.map(func(x): return Carte.titolo(Carte.per_file(str(x)))), "", true)
		if k < 0:
			_finisci()
			return true
		esp.scarta_carta(i, str(altre[k]))
	var ok := true
	if lo.contains("refresh a total of"):
		var n := int(RegEx.create_from_string("refresh a total of (\\d+)").search(lo).get_string(1))
		var cols := RegEx.create_from_string("\\[(red|blue|green)Die\\]").search_all(en).map(func(x): return x.get_string(1))
		var j := await _scegli(tit, cols.map(func(x): return "Prima i dadi " + {"red": "rossi", "blue": "blu", "green": "verdi"}[x]), "Ricarica in tutto %d dadi di questi colori." % n, false)
		if j > 0:
			cols.reverse()
		var f := 0
		for col in cols:
			f += esp.ricarica(i, n - f, col)
		fatti.append("%s ricarica %d dadi" % [m["carta"], f])
	elif lo.contains("small equipment card from the armory"):
		var arm := _armeria_piccola()
		if arm.is_empty():
			ok = false
			avviso("Nessuna piccola attrezzatura nell'Armeria")
		else:
			var j2 := await _scegli("PRENDI DALL'ARMERIA", arm.map(func(x): return Carte.titolo(Carte.per_id(str(x)))), "", false)
			m.get_or_add("attrezzatura", []).append(str(arm[j2]))
			fatti.append("%s prende %s dall'Armeria" % [m["carta"], Carte.titolo(Carte.per_id(str(arm[j2])))])
	elif lo.contains("move 1 crewmember from your sector"):
		var qui := esp.nel_settore(sett)
		var col := esp.collegati(pl, sett)
		var j3 := await _scegli("CHI SI SPOSTA?", qui.map(func(x): return str(esp.membro(x)["carta"])), "", false)
		var j4 := await _scegli("DOVE?", col.map(func(x): return "Settore %d" % x), "Ignorando le icone del sentiero.", false)
		if col.is_empty():
			ok = false
		else:
			esp.viaggia(qui[j3], col[j4])
			fatti.append("%s si sposta nel Settore %d" % [esp.membro(qui[j3])["carta"], col[j4]])
	elif lo.contains("discard 1 discovery to gain"):
		var sc: Array = esp.s["scoperte"]
		if sc.is_empty():
			ok = false
			avviso("Nessuna Scoperta da scartare")
		else:
			var j5 := await _scegli("SCARTA UNA SCOPERTA", sc.map(func(x): return "%s — %s" % [NOMI_SCOPERTE.get(x["tipo"], x["tipo"]), Carte.titolo(Carte.per_file(str(x["carta"])))]), "", false)
			var vecchia: Dictionary = sc[j5]
			sc.remove_at(j5)
			esp.s["mazzi_scoperte"].get_or_add(str(vecchia["tipo"]), []).insert(0, vecchia["carta"])
			var tipo := await _scegli_tipo_scoperta("QUALE SCOPERTA OTTIENI?")
			await _op({"op": "scoperta", "tipo": tipo, "n": 1}, i, sett, fatti, [], [], tit)
	elif lo.contains("discard 1 charge to gain"):
		if int(m["cariche"]) <= 0:
			ok = false
			avviso("Nessuna Carica")
		else:
			m["cariche"] = int(m["cariche"]) - 1
			var tipo2 := await _scegli_tipo_scoperta("2 INDIZI DI QUALE TIPO?")
			await _op({"op": "indizi", "tipo": tipo2, "n": 2}, i, sett, fatti, [], [], tit)
	elif lo.contains("move 1 lead token") or lo.contains("discard 1 lead token"):
		var con := Esplorazione.TIPI_SCOPERTA.filter(func(t): return not (esp.s["indizi"][t] as Array).is_empty())
		if con.is_empty():
			ok = false
			avviso("Nessun Indizio sui mazzi delle Scoperte")
		else:
			var j6 := await _scegli("DA QUALE MAZZO?", con.map(func(t): return "%s (%d)" % [NOMI_SCOPERTE.get(t, t), (esp.s["indizi"][t] as Array).size()]), "", false)
			var tok: Dictionary = (esp.s["indizi"][con[j6]] as Array).pop_back()
			if lo.contains("move 1 lead token"):
				var altri_t := Esplorazione.TIPI_SCOPERTA.filter(func(t): return t != con[j6])
				var j7 := await _scegli("SU QUALE MAZZO?", altri_t.map(func(t): return str(NOMI_SCOPERTE.get(t, t))), "", false)
				esp.s["indizi"][altri_t[j7]].append(tok)
				fatti.append("Indizio spostato da %s a %s" % [NOMI_SCOPERTE.get(con[j6], con[j6]), NOMI_SCOPERTE.get(altri_t[j7], altri_t[j7])])
			else:
				(esp.s["sacchetto"] if tok.get("riciclo", false) else esp.s["fuori_sacchetto"]).append(tok)
				var pc := esp.pesca_carta(i)
				fatti.append("%s scarta un Indizio e pesca %s" % [m["carta"], Carte.titolo(Carte.per_file(pc)) if pc != "" else "nulla"])
	elif lo.contains("discarded lead token"):
		var fuori: Array = esp.s["fuori_sacchetto"]
		var idx := -1
		for k2 in fuori.size():
			if int(fuori[k2].get("v", 1)) == 1:
				idx = k2
		if idx < 0:
			ok = false
			avviso("Nessun Indizio scartato di valore 1")
		else:
			esp.s["sacchetto"].append(fuori[idx])
			fuori.remove_at(idx)
			fatti.append("Un Indizio di valore 1 torna nel sacchetto")
	elif lo.contains("end your turn"):
		esp.s["salta_evento"] = true
		fatti.append("%s termina il turno senza pescare un Evento" % m["carta"])
	if ok:
		esp.scarta_carta(i, c)
		esp.diario("%s gioca %s: %s" % [m["carta"], tit, "; ".join(fatti)])
		if not fatti.is_empty():
			avviso("; ".join(fatti))
	_salva()
	_finisci()
	aggiorna()
	if ok and lo.contains("end your turn"):
		await _fine_turno()
	return true

func _scegli_tipo_scoperta(titolo: String) -> String:
	var j := await _scegli(titolo, Esplorazione.TIPI_SCOPERTA.map(func(t): return str(NOMI_SCOPERTE.get(t, t))), "", false)
	return Esplorazione.TIPI_SCOPERTA[max(0, j)]

## Piccola attrezzatura nell'Armeria (quella della nave non portata da nessuno; altrimenti tutto il catalogo).
func _armeria_piccola() -> Array:
	var portate := []
	for k in esp.s["equipaggio"].size():
		portate += esp.membro(k).get("attrezzatura", [])
	var fonte: Array = Campagna.dati.get("nave", {}).get("armeria", []) if Campagna.dati.get("nave") is Dictionary else []
	if fonte.is_empty():
		for c in Carte.categoria("unavailable_equipment"):
			var id := Carte.titolo(c)
			for x in c.get("nomi", []):
				id = str(x)
			fonte.append(id)
	var out := []
	for id in fonte:
		var ce := Carte.per_id(str(id))
		if str(ce.get("tipo", "")) == "smallEquipment" and not str(id) in portate and not str(id) in out:
			out.append(str(id))
	return out

func _correzioni(i: int) -> void:
	var voci := ["Sposta in un altro settore", "Ricarica 1 dado", "Spendi 1 dado", "Pesca 1 carta", "Cura l'ultima Ferita", "Subisci una Ferita", "+1 Carica", "+1 Provviste", "-1 Provviste", "+1 Successo", "Avanza tutte le tracce del Tempo", "Termina l'esplorazione"]
	var j := await _scegli("CORREZIONI — " + str(esp.membro(i)["carta"]), voci)
	match j:
		0:
			var k := await _scegli_settore("Dove sposti %s? Clicca il settore" % esp.membro(i)["carta"], _tutti_i_settori())
			if k >= 0:
				esp.viaggia(i, k)
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
		var dove := {}
		for x in esp.s["settori"]:
			dove[int(x)] = nome
		var k := await _scegli_settore("Dove va la carta %s? Clicca il settore sulla mappa" % nome, dove)
		if k >= 0:
			esp.piazza_pdi(k, nome)
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
		var mn := _trova_minaccia(nome)
		if not mn.is_empty():
			var k3 := await _scegli_settore("Dove va la Minaccia %s? Clicca il settore" % Carte.titolo(mn[0]), _tutti_i_settori("☠"))
			if k3 >= 0:
				_aggiungi_minaccia(mn[0], k3)
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
		if t.has("pericolo_ignoto"):
			en = await _pericolo_ignoto(str(t["pericolo_ignoto"]), str(t.get("icona", "")))
			fatti.append("Dado Pericolo %s: %s" % [t["pericolo_ignoto"], _txt_icone(en) if en != "" else "nessun effetto"])
			if en == "":
				continue
		if en.strip_edges() == "":
			if str(t.get("it", "")) != "":
				manuali.append("%s: %s" % [fonte, str(t["it"])])
			continue
		# "X - OR - Y": sceglie il giocatore (solo le alternative che può pagare per intero)
		var alt := Array(RegEx.create_from_string("\\s+-?\\s*OR\\s*-?\\s+").sub(en, "§", true).split("§"))
		if alt.size() > 1:
			var it_alt := Array(RegEx.create_from_string("(?i)\\s+-?\\s*OPPURE\\s*-?\\s+").sub(str(t.get("it", "")), "§", true).split("§"))
			var nomi := []
			for k in alt.size():
				nomi.append(_txt_icone(str(it_alt[k]) if it_alt.size() == alt.size() else str(alt[k])))
			var jj := await _scegli(fonte.to_upper(), nomi, "Scegli una delle alternative:", false)
			en = str(alt[max(0, jj)])
		var a := Effetti.analizza(en)
		for op in a["op"]:
			await _op(op, chi, sett, fatti, manuali, logs, fonte)
			if str(esp.s.get("finita", "")) != "":
				break
		if str(a["resto"]) != "":
			manuali.append("%s: %s" % [fonte, str(t.get("it", en))])
		if str(esp.s.get("finita", "")) != "":
			break
	await _controlla_tempo(fatti, manuali, logs)
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
				await _scoperta_ottenuta(str(c), str(op["tipo"]), chi, fatti, manuali, logs)
			_controlla_scoperte(manuali)
		"scoperta":
			for k in int(op["n"]):
				var c2 := esp.scoperta(str(op["tipo"]))
				fatti.append("Scoperta %s%s" % [NOMI_SCOPERTE.get(op["tipo"], op["tipo"]), "" if c2 != "" else " (mazzo vuoto)"])
				if c2 != "":
					await _scoperta_ottenuta(c2, str(op["tipo"]), chi, fatti, manuali, logs)
			_controlla_scoperte(manuali)
		"scoperta_eccezionale":
			var ep: Array = esp.s.get_or_add("eccezionali_pianeta", [])
			var num := int(op["n"])
			if num == 0:
				if ep.is_empty():
					# "se non ci sono più carte qui, ottieni invece 1 Successo" (plancia del pianeta)
					esp.s["successi"] = int(esp.s["successi"]) + 1
					fatti.append("Nessuna Scoperta Eccezionale rimasta sul pianeta: +1 Successo")
				else:
					num = int(ep.pop_back())
			else:
				ep.erase(num)
			if num > 0:
				esp.s["eccezionali"].append(num)
				var ue := _eccezionale(num)
				fatti.append("[b]Scoperta Eccezionale %d[/b]%s" % [num, (": " + Carte.titolo(ue)) if not ue.is_empty() else ""])
				var pe = ue.get("campi", {}).get("esplorazione")
				if pe is Dictionary and Carte.en(pe).to_lower().begins_with("when you gain this"):
					await _scoperta_ottenuta(str(ue["file"]), "", chi, fatti, manuali, logs)
				elif pe is Dictionary:
					manuali.append("Scoperta Eccezionale %d: %s" % [num, Carte.t(pe)])
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
			if await _evita_ferita(chi, str(op["tipo"]), fatti):
				return
			var r := esp.ferita(chi, str(op["tipo"]))
			if r == "evac" and _salva_con_drone(chi, fatti):
				pass
			elif r == "":
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
			await _minacce_avanzano(int(op["n"]), fatti, manuali, logs)
		"azzera_tempo":
			esp.azzera_tempo()
			fatti.append("Tracce del Tempo azzerate")
		"muovi":
			if _destinazione > 0:
				var d := _destinazione
				_destinazione = 0
				await _muovi(chi, d, logs)
				fatti.append("%s si sposta nel Settore %d" % [m["carta"], d])
			else:
				var sen := esp.sentieri(pl, int(m["settore"]))
				if not sen.is_empty():
					var ok := {}
					for p in sen:
						ok[int(p["a"])] = ""
					var dst := -1
					while dst < 0:
						dst = await _scegli_settore("%s si muove: clicca un settore collegato" % m["carta"], ok)
					await _muovi(chi, dst, logs)
					fatti.append("%s si sposta nel Settore %d" % [m["carta"], dst])
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
		"segni":
			var cont: Dictionary = esp.s.get_or_add("contatori", {})
			cont[op["dove"]] = max(0, int(cont.get(op["dove"], 0)) + int(op["n"]))
			fatti.append("Segnaposto %s: %d" % [str(op["dove"]).get_slice(":", 1), int(cont[op["dove"]])])
		"piaghe":
			var sp := int(op["settore"]) if int(op["settore"]) > 0 else sett
			var stp: Dictionary = esp.s["settori"].get(str(sp), {})
			stp["piaghe"] = max(0, int(stp.get("piaghe", 0)) + int(op["n"]))
			fatti.append("Settore %d: %d Piaghe" % [sp, int(stp["piaghe"])])
		"niente":
			fatti.append("Non succede nulla")
		"perdita_testa":
			# l'icona della testa indica il Membro che ha tirato: la perdita va sulla sua plancia
			for k in int(op["n"]):
				var opz := ["Spendi un dado", "Scarta una carta Reparto dalla mano", "Perdi una Carica", "Altro (lo applico a mano)"]
				var j := await _scegli("%s PERDE 1 [TESTA]" % str(m["carta"]).to_upper(), opz,
					"Il dado Pericolo indica una perdita per il Membro che ha tirato (%s): scegli che cosa perde dalla sua plancia, come indica la carta di riferimento." % m["carta"], false)
				match j:
					0:
						esp.spendi_dado(chi)
						fatti.append("%s spende un dado" % m["carta"])
					1:
						if not (m["mano"] as Array).is_empty():
							var k2 := await _scegli("QUALE CARTA?", (m["mano"] as Array).map(func(c): return Carte.titolo(Carte.per_file(str(c)))), "", false)
							esp.scarta_carta(chi, str(m["mano"][k2]))
							fatti.append("%s scarta una carta" % m["carta"])
					2:
						m["cariche"] = max(0, int(m["cariche"]) - 1)
						fatti.append("%s perde una Carica" % m["carta"])
					3:
						manuali.append("%s perde 1 [testa] (dado Pericolo)" % m["carta"])
		"tutti":
			for i2 in esp.vivi():
				await _op(op["sub"], i2, int(esp.membro(i2)["settore"]), fatti, manuali, logs, fonte)
		"grado":
			if str(esp.s.get("grado_superiore", "")) != "" and not esp.s.get("grado_girato", false):
				esp.s["grado_girato"] = true
				fatti.append("[b]Carta Grado Superiore completata![/b]")
		"gira_carta":
			if fonte.begins_with("Grado"):
				esp.s["grado_girato"] = true
				fatti.append("[b]Carta Grado Superiore completata![/b]")
			else:
				manuali.append("Gira la carta (%s)" % fonte)
		"scoperta_da_indizi":
			var tipi := []
			for t in Esplorazione.TIPI_SCOPERTA:
				var v := 0
				for x in esp.s["indizi"][t]:
					v += int(x.get("v", 1))
				if (int(op["valore"]) > 0 and v >= int(op["valore"])) or (int(op["segnalini"]) > 0 and (esp.s["indizi"][t] as Array).size() >= int(op["segnalini"])):
					tipi.append(t)
			if tipi.is_empty():
				fatti.append("Nessun mazzo Scoperte ha abbastanza Indizi")
			else:
				var k := 0
				if tipi.size() > 1:
					k = await _scegli("DA QUALE MAZZO?", tipi.map(func(x): return NOMI_SCOPERTE[x]), "", false)
				esp.scoperta(tipi[k])
				fatti.append("Scoperta %s ottenuta" % NOMI_SCOPERTE[tipi[k]])
				_controlla_scoperte(manuali)
		"scarta_missione":
			esp.s["missioni"].erase(str(op["carta"]))
			fatti.append("Missione %s scartata" % op["carta"])
		"muovi_tutti":
			for i in esp.vivi():
				esp.viaggia(i, int(op["settore"]))
			fatti.append("Tutta la squadra nel Settore %d" % int(op["settore"]))
		"muovi_attivo":
			esp.viaggia(chi, int(op["settore"]))
			fatti.append("%s nel Settore %d" % [m["carta"], int(op["settore"])])
		"ricarica_tutti":
			for i in esp.vivi():
				esp.ricarica(i, int(op["n"]), str(op["colore"]))
			fatti.append("Ogni Membro ricarica %d dadi" % int(op["n"]))
		"pericolo_tutti":
			for i in esp.vivi():
				await _tira_pericolo(str(op["lettera"]), i, int(esp.membro(i)["settore"]), fatti, manuali, logs, "dado Pericolo")
		"ferita_tutti":
			for i in esp.vivi():
				var r2 := esp.ferita(i, str(op["tipo"]))
				fatti.append("%s: %s" % [esp.membro(i)["carta"], "Ferita " + str(NOMI_FERITE.get(r2, r2)) if r2 not in ["", "evac"] else ("ignorata" if r2 == "" else "evacuazione!")])
		"atterraggio_inizio":
			esp.s["lander"]["contatore"] = int(esp.s["lander"].get("partenza", 1))
			fatti.append("Contatore dell'Atterraggio sulla casella iniziale (%d)" % int(esp.s["lander"]["contatore"]))
		"atterraggio":
			var ld: Dictionary = esp.s["lander"]
			ld["contatore"] = clampi(int(ld.get("contatore", 0)) + int(op["n"]), 1, int(ld.get("caselle", 5)))
			fatti.append("Contatore dell'Atterraggio: %d/%d" % [int(ld["contatore"]), int(ld.get("caselle", 5))])
		"provviste_meno":
			var q: int = max(0, int(op["n"]) - _stat(str(op["stat"])))
			if not esp.s.get("provviste_illimitate", false):
				esp.s["lander"]["provviste"] = max(0, int(esp.s["lander"]["provviste"]) - q)
			fatti.append("-%d Provviste (%d meno %s %d)" % [q, int(op["n"]), _nome_stat(str(op["stat"])), _stat(str(op["stat"]))])
		"dadi_meno":
			var q2: int = max(0, int(op["n"]) - _stat(str(op["stat"])))
			for i in esp.vivi():
				for k in q2:
					if str(op["dado"]) == "spendDie":
						esp.spendi_dado(i)
					else:
						esp.sacrifica_dado(i)
			fatti.append("Ogni Membro %s %d dadi (%d meno %s)" % ["spende" if str(op["dado"]) == "spendDie" else "sacrifica", q2, int(op["n"]), _nome_stat(str(op["stat"]))])
		"danni_meno":
			var q3: int = max(0, int(op["n"]) - _stat(str(op["stat"])))
			esp.s["lander"]["danni"] = int(esp.s["lander"].get("danni", 0)) + q3
			fatti.append("+%d segnalini danno sul Lander (ora %d)" % [q3, int(esp.s["lander"]["danni"])])
		"danni_tiro":
			var tiri: int = max(0, int(op["n"]) - _stat(str(op["stat"])))
			var colpi := 0
			for k in tiri:
				var d := {"tipo": "pericolo", "faccia": 0}
				Prova.tira(d, esp.rng)
				if str(op["faccia"]) in Prova.icone(d):
					colpi += 1
			esp.s["lander"]["danni"] = int(esp.s["lander"].get("danni", 0)) + colpi
			fatti.append("%d tiri del dado Pericolo: %d segnalini danno (ora %d)" % [tiri, colpi, int(esp.s["lander"]["danni"])])
		"nave_pagina":
			fatti.append("Ship Book a pagina %d" % int(op["n"]))
			if int(op["n"]) == 25:
				esp.fine("fine")
				fatti.append("L'esplorazione planetaria finisce: si torna alla nave")
		"planetopedia":
			Campagna.dati["prossimo_pianeta"] = str(op["pagina"])
			fatti.append("Planetopedia alle pagine %s" % str(op["pagina"]).trim_prefix("p."))

func _tira_pericolo(lettera: String, chi: int, sett: int, fatti: Array, manuali: Array, logs: Array, fonte: String) -> void:
	if lettera.to_lower() == "any":
		var lett := ["A", "B", "C", "D", "E", "F", "G", "H", "I"]
		var j := await _scegli("QUALE DADO PERICOLO?", lett.map(func(x): return "Dado Pericolo " + x), "L'annotazione dice di tirare un dado Pericolo qualsiasi: scegli la tabella.", false)
		lettera = lett[max(0, j)]
	var d := {"tipo": "pericolo", "lettera": lettera, "faccia": 0}
	Prova.tira(d, esp.rng)
	if await _pericolo_ignorato(chi, sett, d, fatti):
		return
	var ic := Prova.icone(d)
	var nome := "vuoto" if ic.is_empty() else str(ic[0])
	var nomi_it := {"vuoto": "faccia vuota", "common": "comune", "uncommon": "non comune", "rare": "raro", "special": "speciale"}
	if not Prova.tabella_nota(lettera, d):
		await _pericolo_ignoto(lettera, str(ic[0]))
	if Prova.tabella_nota(lettera, d):
		var e := Prova.effetto_pericolo(lettera, d)
		fatti.append("Dado Pericolo %s: %s → %s" % [lettera, nomi_it.get(nome, nome), _txt_icone(e) if e != "" else "nessun effetto"])
		if e != "":
			for op in Effetti.analizza(e)["op"]:
				await _op(op, chi, sett, fatti, manuali, logs, "dado Pericolo")
	else:
		fatti.append("Dado Pericolo %s: %s" % [lettera, nomi_it.get(nome, nome)])
		manuali.append("Dado Pericolo %s con risultato %s: applica l'effetto indicato per la lettera %s (sulla carta, sulla plancia o nell'annotazione)." % [lettera, nomi_it.get(nome, nome), lettera])

## Tabella di un dado Pericolo non stampata sulla carta di riferimento: la prima volta il giocatore
## sceglie l'effetto letto sulla carta o nell'annotazione, poi il programma lo ricorda.
func _pericolo_ignoto(lettera: String, icona: String) -> String:
	var t: Dictionary = Prova.apprese.get_or_add(lettera, {})
	if t.has(icona):
		return str(t[icona])
	var nomi_it := {"common": "comune", "uncommon": "non comune", "rare": "raro", "special": "speciale"}
	var eff := Prova.effetti_tabelle()
	var opz := ["Nessun effetto"] + eff.map(func(x): return _txt_icone(FinestraProva._it_pericolo(str(x)))) + ["Un altro effetto (lo applico a mano)"]
	var j := await _scegli("DADO PERICOLO %s — %s" % [lettera, nomi_it.get(icona, icona).to_upper()],
		opz, "La tabella del dado Pericolo [b]%s[/b] non è sulla carta di riferimento: è stampata sulla carta o nell'annotazione che ti ha fatto tirare.\nChe effetto c'è per il risultato [b]%s[/b]? Il programma lo ricorderà per le prossime volte." % [lettera, nomi_it.get(icona, icona)], false)
	var e := ""
	if j >= 1 and j <= eff.size():
		e = str(eff[j - 1])
	if j <= eff.size():
		t[icona] = e
		Campagna.modificata()
	return e

# ------------------------------------------------------------------ Minacce

func _trova_minaccia(nome: String) -> Array:
	nome = nome.to_upper()
	return Carte.categoria("minacce").filter(func(x): return str(x.get("lato", "fronte")) != "retro" and (Carte.titolo(x).to_upper() == nome or (not (x.get("nomi", []) as Array).is_empty() and str(x["nomi"][0]).to_upper() == nome) or Carte.en(x.get("titolo", "")).to_upper() == nome))

func _aggiungi_minaccia(c: Dictionary, sett: int) -> void:
	var en := Carte.en(c.get("titolo", ""))
	esp.s["minacce"].append({"nome": Carte.titolo(c), "en": en, "file": str(c["file"]), "settore": sett, "tempo": 0})
	# lo Sciame da Guerra Arrogatore arriva con i suoi 3 Droni nello stesso settore
	if en.to_upper().contains("ARROGATOR WARSWARM") and esp.s["settori"].has(str(sett)):
		esp.s["settori"][str(sett)]["droni"] = int(esp.s["settori"][str(sett)].get("droni", 0)) + 3
	esp.diario("Minaccia %s nel Settore %d" % [Carte.titolo(c), sett])

func _carta_minaccia(m: Dictionary) -> Dictionary:
	return Carte.per_file(str(m.get("file", "")))

## Le tracce del Tempo delle Minacce avanzano: si risolve l'effetto stampato sopra ogni casella raggiunta.
func _minacce_avanzano(n: int, fatti: Array, manuali: Array, logs: Array) -> void:
	for m in esp.s["minacce"].duplicate():
		var c := _carta_minaccia(m)
		var tr: Array = c.get("tempo", []) if c.get("tempo") is Array else []
		if tr.is_empty():
			continue
		for k in n:
			if not m in esp.s["minacce"]:
				break
			if await _sistema_difesa(m):
				continue
			m["tempo"] = int(m["tempo"]) + 1
			var cas: Dictionary = {}
			for x in tr:
				if int(x.get("casella", 0)) == int(m["tempo"]):
					cas = x
			if cas.is_empty():
				m["tempo"] = min(int(m["tempo"]), tr.size())
				continue
			fatti.append("Minaccia %s: tempo %d/%d → %s" % [m["nome"], int(m["tempo"]), tr.size(), Carte.t(cas)])
			for nome_eff in Carte.en(cas).split(","):
				var ne := nome_eff.strip_edges()
				if ne == "":
					continue
				if ne.to_lower().contains("reset this track"):
					m["tempo"] = 0
					continue
				if ne.to_lower().contains("flip this card"):
					_gira_minaccia(m, fatti)
					continue
				await _effetto_minaccia(m, c, ne, fatti, manuali, logs)

## Sistema di Difesa (E14): scartando 1 segnalino si ignora un avanzamento del Tempo di una Minaccia nel suo settore.
func _sistema_difesa(m: Dictionary) -> bool:
	for tk in _segnalini(int(m.get("settore", 0))):
		if str(tk["id"]) == "E14" and int(tk.get("marcatori", 0)) > 0:
			var k := await _scegli("SISTEMA DI DIFESA", ["IGNORA L'AVANZAMENTO (scarta 1 segnalino, ne restano %d)" % (int(tk["marcatori"]) - 1), "NO"],
				"La Minaccia %s sta per avanzare sulla sua traccia del Tempo nel Settore %d." % [m["nome"], int(m["settore"])], false)
			if k != 0:
				return false
			tk["marcatori"] = int(tk["marcatori"]) - 1
			esp.diario("Sistema di Difesa: ignorato l'avanzamento del Tempo di %s" % m["nome"])
			if int(tk["marcatori"]) <= 0:
				_segnalini(int(m["settore"])).erase(tk)
				esp.diario("Sistema di Difesa: segnalini finiti, la carta torna nell'Armeria")
			return true
	return false

func _gira_minaccia(m: Dictionary, fatti: Array) -> void:
	var c := _carta_minaccia(m)
	var nomi: Array = c.get("nomi", [])
	for x in Carte.categoria("minacce"):
		if x.get("nomi", []) == nomi and str(x.get("file", "")) != str(m["file"]):
			m["file"] = str(x["file"])
			m["tempo"] = 0
			fatti.append("La carta Minaccia %s si gira" % m["nome"])
			return

## Minacce con regole tutte loro. true se l'effetto è stato risolto qui.
func _minaccia_speciale(m: Dictionary, c: Dictionary, eff: String, testo: String, fatti: Array, manuali: Array, logs: Array) -> bool:
	var nomi: Array = c.get("nomi", []) if c.get("nomi") is Array else []
	var en := str(nomi[0]) if not nomi.is_empty() else str(m.get("en", ""))
	var sett := int(m["settore"])
	match [en, eff]:
		["Re-Origination Beam", "travel"]:
			# il segnalino parte sulla regola "lenta"; un'annotazione può spostarlo (m["viaggio"] = "veloce")
			if not m.has("viaggio"):
				m["viaggio"] = "lento"
			var meta := 8
			if m["viaggio"] == "lento":
				if (sett - 1) in esp.collegati(pl, sett):
					meta = sett - 1
			elif esp.s["settori"].has(str(sett - 2)) and esp.distanza(pl, sett, sett - 2) > 0:
				meta = sett - 2
			if _minaccia_in("Builder's Biomebot", meta):
				fatti.append("%s: nel Settore %d c'è il Biomebot, il Viaggio si annulla" % [m["nome"], meta])
			else:
				m["settore"] = meta
				fatti.append("%s nel Settore %d" % [m["nome"], meta])
			return true
		["Builder's Biomebot", "travel"]:
			var meta2 := sett + 1 if (sett + 1) in esp.collegati(pl, sett) else 2
			if _minaccia_in("Re-Origination Beam", meta2):
				fatti.append("%s: nel Settore %d c'è il Raggio, il Viaggio si annulla" % [m["nome"], meta2])
				return true
			_biomebot_prende(m, sett, fatti)
			m["settore"] = meta2
			fatti.append("%s nel Settore %d" % [m["nome"], meta2])
			return true
		["Builder's Biomebot", "biome change"]:
			_biomebot_prende(m, sett, fatti)
			var pila: Array = m.get_or_add("pila", [])
			if pila.is_empty():
				manuali.append("Biomebot del Costruttore: la sua pila di PDI è vuota — se ce l'hai sul tavolo, piazza la prima carta nel Settore %d" % sett)
			else:
				var top: String = pila.pop_front()
				esp.s["settori"][str(sett)]["pdi"].append(top)
				fatti.append("Settore %d: il Biomebot piazza %s" % [sett, top])
			return true
		["Idemian Pilgrim", "procession"]:
			var incenso := []
			for k in esp.s["settori"]:
				if "incenseBurner" in esp.icone_settore(pl, int(k), _carte_pdi()):
					incenso.append(int(k))
			incenso.sort()
			if incenso.is_empty():
				manuali.append("Pellegrino Idemiano: nessun settore con il Bruciaincenso visibile")
			else:
				var piu := incenso.filter(func(x): return x > sett)
				m["settore"] = piu[0] if not piu.is_empty() else incenso[0]
				fatti.append("%s nel Settore %d" % [m["nome"], int(m["settore"])])
			m["marcatori"] = max(0, int(m.get("marcatori", 0)) - 2)
			return true
		["Hunters Become Prey", "travel"]:
			var nuovi := {}
			for k in esp.s["settori"]:
				for t in int(esp.s["settori"][k].get("segni", 0)):
					var d := esp.rng.randi_range(0, 9)
					var tmp := {"settore": int(k)}
					esp.muovi_minaccia_verso(pl, tmp, 2, d if d > 0 and esp.s["settori"].has(str(d)) else 1)
					nuovi[int(tmp["settore"])] = int(nuovi.get(int(tmp["settore"]), 0)) + 1
			for k in esp.s["settori"]:
				esp.s["settori"][k]["segni"] = int(nuovi.get(int(k), 0))
			fatti.append("Segnalini spostati: %s" % ", ".join(nuovi.keys().map(func(x): return "Settore %d ×%d" % [x, nuovi[x]])))
			return true
		["Enraptured Visitor", "travel"]:
			var j2 := await _scegli("VISITATORE RAPITO", ["Settore 1", "Settore 2", "Settore 3"], "Il Visitatore Rapito va nel Settore 1, 2 o 3 (a scelta dei giocatori).", false)
			m["settore"] = max(0, j2) + 1
			fatti.append("%s nel Settore %d" % [m["nome"], int(m["settore"])])
			return true
		["Enraptured Visitor", "impulse"]:
			await _frase_minaccia(m, "Each Crewmember in the Sector with Enraptured Visitor [spendDie]+[spendDie].", fatti, manuali, logs, "")
			if sett in [1, 2, 3]:
				_pdi_parola_chiave(sett, fatti, manuali)
			return true
		["Enraptured Visitor", "stimulus"]:
			m["settore"] = 7
			fatti.append("%s nel Settore 7" % m["nome"])
			var gid := str(esp.s["condizione"]["carta"]).get_slice("@", 0)
			var vers := Carte.versioni(gid)
			if vers.size() > 1:
				var j5 := await _scegli("STIMOLO — CONDIZIONE GENERALE", vers.map(func(x): return Carte.titolo(x)), "Scegliete quale Condizione Generale della pila va in cima.", false, str(vers[0].get("file", "")))
				esp.s["condizione"] = {"carta": "%s@%d" % [gid, max(0, j5)], "tempo": 0}
				fatti.append("In cima alla pila delle Condizioni Generali: %s" % Carte.titolo(vers[max(0, j5)]))
			else:
				manuali.append("Visitatore Rapito: metti in cima alla pila delle Condizioni Generali quella che preferite")
			return true
		["Arrogator Warswarm", "hack drone"]:
			var con: Variant = esp.s["settori"].keys().filter(func(k): return int(esp.s["settori"][k].get("droni", 0)) > 0)
			if con.is_empty():
				fatti.append("Nessun Drone sulla plancia")
			else:
				var j3 := 0
				if con.size() > 1:
					j3 = await _scegli("DA DOVE TOGLI IL DRONE?", con.map(func(k): return "Settore %s (%d)" % [k, int(esp.s["settori"][k]["droni"])]), "", false)
				esp.s["settori"][con[j3]]["droni"] = int(esp.s["settori"][con[j3]]["droni"]) - 1
				fatti.append("Un Drone in meno nel Settore %s" % con[j3])
			return true
		["Arrogator Warswarm", "swarm"]:
			if not m.has("droni_totali"):
				m["droni_totali"] = 3      # i Droni dello Sciame sono 3 (Logbook: "tutti e 3 i Droni")
			var sul := 0
			for k in esp.s["settori"]:
				sul += int(esp.s["settori"][k].get("droni", 0))
			var riserva: int = max(0, int(m["droni_totali"]) - sul)
			var con_m := []
			for i in esp.vivi():
				var si := int(esp.membro(i)["settore"])
				if not si in con_m:
					con_m.append(si)
			con_m.sort()
			for si in con_m:
				if riserva <= 0:
					break
				esp.s["settori"][str(si)]["droni"] = int(esp.s["settori"][str(si)].get("droni", 0)) + 1
				riserva -= 1
			if riserva > 0:
				esp.s["settori"][str(sett)]["droni"] = int(esp.s["settori"][str(sett)].get("droni", 0)) + riserva
			var el := []
			for k in esp.s["settori"]:
				if int(esp.s["settori"][k].get("droni", 0)) > 0:
					el.append("Settore %s ×%d" % [k, int(esp.s["settori"][k]["droni"])])
			fatti.append("Droni: " + ", ".join(el))
			return true
		["Maw", "feeding"]:
			pass
	if testo.to_lower().begins_with("discard 1 non-unique discovery"):
		return false
	return false

## Impulso del Visitatore Rapito: nel suo settore va in cima il PDI la cui parola chiave (fra parentesi
## nel titolo) è il nome della Condizione Generale attuale.
func _pdi_parola_chiave(n: int, fatti: Array, manuali: Array) -> void:
	var top := esp.pdi_in_cima(n)
	if top == "":
		return
	var base := top.get_slice("@", 0)
	var vers := Carte.versioni(base)
	var nome_gc := Carte.en(Carte.per_id(str(esp.s["condizione"]["carta"])).get("titolo", "")).to_upper().strip_edges()
	for k in vers.size():
		var t := Carte.en(vers[k].get("titolo", "")).to_upper()
		if nome_gc != "" and t.contains("(" + nome_gc + ")"):
			var p: Array = esp.s["settori"][str(n)]["pdi"]
			p[p.size() - 1] = "%s@%d" % [base, k]
			fatti.append("Settore %d: in cima il PDI %s (parola chiave %s)" % [n, Carte.titolo(vers[k]), Carte.titolo(Carte.per_id(str(esp.s["condizione"]["carta"])))])
			return
	if vers.size() > 1:
		manuali.append("Visitatore Rapito: nessun PDI del Settore %d ha la parola chiave «%s»" % [n, nome_gc])

func _minaccia_in(nome_en: String, n: int) -> bool:
	return esp.s["minacce"].any(func(x): return str(x.get("en", "")).to_lower() == nome_en.to_lower() and int(x.get("settore", 0)) == n)

## Il Biomebot lascia il settore: il PDI in cima va in fondo alla sua pila.
func _biomebot_prende(m: Dictionary, n: int, fatti: Array) -> void:
	var p: Array = esp.s["settori"].get(str(n), {}).get("pdi", [])
	if p.is_empty() or str(p[-1]) == "P000":
		return
	var c: String = p.pop_back()
	m.get_or_add("pila", []).append(c)
	fatti.append("Il Biomebot prende %s dal Settore %d" % [c, n])

## Effetto con nome (es. "Travel", "Scintillation") dal testo delle regole della Minaccia.
func _effetto_minaccia(m: Dictionary, c: Dictionary, nome_eff: String, fatti: Array, manuali: Array, logs: Array) -> void:
	var regole_en := Carte.en(c.get("regole", ""))
	var regole_it := Carte.t(c.get("regole", ""))
	var testo := ""
	var testo_it := ""
	var righe_it := regole_it.split("\n")
	var righe := regole_en.split("\n")
	for k in righe.size():
		var r := righe[k].strip_edges().trim_prefix("- ")
		if r.to_lower().begins_with(nome_eff.to_lower() + ":"):
			testo = r.substr(nome_eff.length() + 1).strip_edges()
			testo_it = righe_it[k] if k < righe_it.size() else testo
			# righe di una tabella che continuano l'effetto ("0-4: …", "5-9: …")
			var k2 := k + 1
			while k2 < righe.size() and RegEx.create_from_string("^\\d+-\\d+:").search(righe[k2].strip_edges()):
				testo += " " + righe[k2].strip_edges()
				k2 += 1
	if testo == "":
		manuali.append("Minaccia %s: %s" % [m["nome"], nome_eff])
		return
	_eff_nome = nome_eff.to_lower()
	_regole_minaccia = regole_en.to_lower()
	if int(m["settore"]) <= 0 and _eff_nome == "travel" and _regole_minaccia.contains("its travel is ignored"):
		fatti.append("%s è fuori dalla plancia: il Viaggio si ignora" % m["nome"])
		return
	if await _minaccia_speciale(m, c, _eff_nome, testo, fatti, manuali, logs):
		return
	var sett0 := int(m["settore"])
	# tabella col D10 sui settori collegati
	if testo.to_lower().contains("roll d10") and testo.contains("0-4"):
		var d := esp.rng.randi_range(0, 9)
		var col := esp.collegati(pl, sett0)
		col.sort()
		if not col.is_empty():
			var basso := testo.substr(testo.find("0-4")).to_lower().begins_with("0-4: the lowest")
			m["settore"] = (col[0] if basso else col[-1]) if d <= 4 else (col[-1] if basso else col[0])
		fatti.append("%s: D10 = %d → Settore %d" % [m["nome"], d, int(m["settore"])])
		return
	# "choose one effect below" con le voci nelle righe successive
	if testo.to_lower().contains("choose one effect below"):
		var voci := []
		var dentro := false
		for r in righe:
			var rr := r.strip_edges()
			if rr.to_lower().begins_with(nome_eff.to_lower() + ":"):
				dentro = true
				continue
			if dentro and rr.begins_with("- "):
				voci.append(rr.substr(2))
			elif dentro and rr != "":
				break
		if not voci.is_empty():
			var j := await _scegli("%s — %s" % [str(m["nome"]).to_upper(), nome_eff.to_upper()], voci.map(func(x): return _txt_icone(str(x))), testo_it, false)
			testo = str(voci[j])
	# frase per frase
	var frasi0 := RegEx.create_from_string("(?<=\\.)\\s+(?=[A-Z])").sub(testo, "§", true).split("§")
	# "Any of these Crewmembers may X to roll Y instead." diventa un'alternativa della frase precedente
	var frasi := []
	for f0 in frasi0:
		var alt := RegEx.create_from_string("(?i)^any of these crewmembers may (.+?) to roll (\\[\\w+\\]) instead\\.?$").search(f0.strip_edges())
		if alt and not frasi.is_empty():
			frasi[-1] = str(frasi[-1]).trim_suffix(".") + " OR " + alt.get_string(1) + " and roll " + alt.get_string(2)
		else:
			frasi.append(f0)
	var nessuno := false
	for f in frasi:
		var fr: Variant = f.strip_edges()
		if fr == "" or not m in esp.s["minacce"]:
			continue
		var frl: Variant = fr.to_lower()
		var cond_n := RegEx.create_from_string("(?i)^if there (?:is none|are none)[:,]\\s*").search(fr)
		if cond_n:
			if nessuno:
				await _frase_minaccia(m, fr.substr(cond_n.get_end()).strip_edges(), fatti, manuali, logs, testo_it)
			continue
		if frl.begins_with("if there is no such sector") or frl.begins_with("if there are no sectors with a higher number") or frl.begins_with("in case of a tie"):
			continue
		# "If there is a Crewmember in the Sector with X, Effetto." / "Otherwise, …"
		var cc := RegEx.create_from_string("(?i)^if there is a crewmember in the sector with .+?, (\\w[\\w -]*)\\.?$").search(fr)
		if cc:
			var vero := not esp.nel_settore(int(m["settore"])).is_empty()
			_altrimenti = not vero
			if vero:
				fatti.append("C'è un Membro nel settore di %s: %s" % [m["nome"], cc.get_string(1)])
				await _effetto_minaccia(m, c, cc.get_string(1), fatti, manuali, logs)
			continue
		var cm2 := RegEx.create_from_string("(?i)^if there(?:'s| is) no marker on the .+? threat card, (.+)$").search(fr)
		if cm2:
			var vero2 := int(m.get("marcatori", 0)) <= 0
			_altrimenti = not vero2
			if vero2:
				await _frase_minaccia(m, cm2.get_string(1), fatti, manuali, logs, testo_it)
			continue
		if frl.begins_with("otherwise, "):
			if _altrimenti:
				await _frase_minaccia(m, fr.substr(11).strip_edges(), fatti, manuali, logs, testo_it)
			continue
		var rag := RegEx.create_from_string("(?i)^if .+? reaches sector (\\d+), go to log (\\d+)").search(fr)
		if rag:
			if int(m["settore"]) == int(rag.get_string(1)):
				logs.append(int(rag.get_string(2)))
				fatti.append("%s raggiunge il Settore %s: Annotazione %s" % [m["nome"], rag.get_string(1), rag.get_string(2)])
			continue
		nessuno = await _frase_minaccia(m, fr, fatti, manuali, logs, testo_it)

## Una frase dell'effetto di una Minaccia; restituisce true se "nessun Membro" era nel suo settore.
var _eff_nome := ""
var _regole_minaccia := ""
var _altrimenti := false

func _frase_minaccia(m: Dictionary, testo: String, fatti: Array, manuali: Array, logs: Array, testo_it: String) -> bool:
	for pre in ["Then, ", "then, ", "Then "]:
		testo = testo.trim_prefix(pre)
	testo = testo.strip_edges()
	var en := str(m.get("en", "")).to_lower()
	var tl := testo.to_lower().trim_prefix("then, ").trim_prefix("then ")
	var sett := int(m["settore"])
	var mv := RegEx.create_from_string("(?i)move .+? (?:by )?(\\d+|one|two) sectors? toward the nearest crewmember").search(testo)
	if en != "" and tl.begins_with("if there is no %s on the planet board" % en):
		fatti.append("%s è già sulla plancia: non succede nulla" % m["nome"])
		return false
	if tl.begins_with("roll d10 and place") or tl.begins_with("roll d10. move"):
		var d := esp.rng.randi_range(0, 9)
		if tl.contains("lowest-numbered") or tl.contains("0-4"):
			var col := esp.collegati(pl, sett)
			if not col.is_empty():
				col.sort()
				m["settore"] = col[0] if d <= 4 else col[-1]
			fatti.append("%s: D10 = %d → Settore %d" % [m["nome"], d, int(m["settore"])])
		elif esp.s["settori"].has(str(d)):
			m["settore"] = d
			fatti.append("%s: D10 = %d → Settore %d" % [m["nome"], d, d])
		else:
			fatti.append("%s: D10 = %d, nessun settore: resta dov'è" % [m["nome"], d])
		return false
	if mv:
		if tl.begins_with("if there is no crewmember in the sector") and not esp.nel_settore(sett).is_empty():
			fatti.append("%s: c'è un Membro nel suo settore, non si muove" % m["nome"])
		else:
			esp.muovi_minaccia_verso(pl, m, Effetti._n(mv.get_string(1)))
			fatti.append("%s si sposta verso il Membro più vicino (Settore %d)" % [m["nome"], int(m["settore"])])
		return false
	var mv2 := RegEx.create_from_string("(?i)move .+? to the (highest|lowest)-numbered connected sector").search(testo)
	if mv2:
		var col := esp.collegati(pl, sett)
		col.sort()
		if not col.is_empty():
			m["settore"] = col[-1] if mv2.get_string(1).to_lower() == "highest" else col[0]
		fatti.append("%s nel Settore %d" % [m["nome"], int(m["settore"])])
		return false
	var mv3 := RegEx.create_from_string("(?i)move .+? (?:by )?(\\d+|one|two) sectors? toward (?:a random crewmember|the crewmember with most injuries)").search(testo)
	if mv3:
		var vivi := esp.vivi()
		if not vivi.is_empty():
			var bersaglio: int = vivi[esp.rng.randi_range(0, vivi.size() - 1)]
			if tl.contains("most injuries"):
				vivi.sort_custom(func(a, b): return (esp.membro(a)["ferite"] as Array).size() > (esp.membro(b)["ferite"] as Array).size())
				bersaglio = vivi[0]
			esp.muovi_minaccia_verso(pl, m, Effetti._n(mv3.get_string(1)), int(esp.membro(bersaglio)["settore"]))
			fatti.append("%s si sposta verso %s (Settore %d)" % [m["nome"], esp.membro(bersaglio)["carta"], int(m["settore"])])
		return false
	var pls := RegEx.create_from_string("(?i)^place .+? in sector (\\d+)").search(tl)
	if pls:
		m["settore"] = int(pls.get_string(1))
		fatti.append("%s nel Settore %d" % [m["nome"], int(m["settore"])])
		if tl.contains("discard 1 marker from this card"):
			m["marcatori"] = max(0, int(m.get("marcatori", 0)) - 1)
		return false
	if tl.begins_with("discard 1 non-unique discovery"):
		var sc: Array = esp.s["scoperte"]
		var nu := []
		for k in sc.size():
			if not Carte.en(Carte.per_file(str(sc[k]["carta"])).get("campi", {}).get("esplorazione", {})).to_lower().contains("unique"):
				nu.append(k)
		if nu.is_empty():
			fatti.append("Nessuna Scoperta non Unica da scartare")
		else:
			var j := await _scegli("SCARTA UNA SCOPERTA", nu.map(func(k): return "%s — %s" % [NOMI_SCOPERTE.get(sc[k]["tipo"], sc[k]["tipo"]), Carte.titolo(Carte.per_file(str(sc[k]["carta"])))]), "", false)
			var v: Dictionary = sc[nu[max(0, j)]]
			sc.erase(v)
			esp.s["mazzi_scoperte"].get_or_add(str(v["tipo"]), []).insert(0, v["carta"])
			fatti.append("Scartata la Scoperta %s" % Carte.titolo(Carte.per_file(str(v["carta"]))))
		return false
	var glog := RegEx.create_from_string("(?i)^go to log (\\d+)").search(tl)
	if glog:
		logs.append(int(glog.get_string(1)))
		fatti.append("%s: Annotazione %s" % [m["nome"], glog.get_string(1)])
		return false
	var rmk := RegEx.create_from_string("(?i)^(?:remove|discard) (1|2|3|a|1 chosen) markers? from (?:this card|the .+? threat card|the edge of this threat card)\\.?(?: and (.+))?$").search(testo)
	if rmk:
		var nrm := 1 if not rmk.get_string(1).is_valid_int() else int(rmk.get_string(1))
		m["marcatori"] = max(0, int(m.get("marcatori", 0)) - nrm)
		fatti.append("%s: un segnalino in meno sulla carta (%d)" % [m["nome"], int(m["marcatori"])])
		if rmk.get_string(2) != "":
			return await _frase_minaccia(m, rmk.get_string(2), fatti, manuali, logs, testo_it)
		return false
	if tl.begins_with("place 1 marker there") or tl.begins_with("place 1 marker on this card"):
		m["marcatori"] = int(m.get("marcatori", 0)) + 1
		fatti.append("%s: un segnalino sulla carta (%d)" % [m["nome"], int(m["marcatori"])])
		return false
	if RegEx.create_from_string("(?i)^move .+? to a random connected sector").search(testo):
		var colr := esp.collegati(pl, sett)
		if not colr.is_empty():
			m["settore"] = colr[esp.rng.randi_range(0, colr.size() - 1)]
		fatti.append("%s nel Settore %d" % [m["nome"], int(m["settore"])])
		return false
	# segnalini nei settori (Squarcio Gravitazionale)
	if RegEx.create_from_string("(?i)^place .+? in the lowest-numbered sector with the fewest markers").search(testo):
		var migliore := -1
		var ks: Variant = esp.s["settori"].keys().map(func(x): return int(x))
		ks.sort()
		for k in ks:
			if migliore < 0 or int(esp.s["settori"][str(k)].get("segni", 0)) < int(esp.s["settori"][str(migliore)].get("segni", 0)):
				migliore = k
		m["settore"] = migliore
		fatti.append("%s nel Settore %d" % [m["nome"], migliore])
		return false
	var asg := RegEx.create_from_string("(?i)^(add|remove) 1 marker (?:to|from) (?:that sector|the sector with|sector with)").search(testo)
	if asg:
		var st2: Dictionary = esp.s["settori"][str(int(m["settore"]))]
		st2["segni"] = max(0, int(st2.get("segni", 0)) + (1 if asg.get_string(1).to_lower() == "add" else -1))
		fatti.append("Settore %d: %d segnalini" % [int(m["settore"]), int(st2["segni"])])
		var dopo_p := testo.find(".")
		if dopo_p > 0 and dopo_p < testo.length() - 2:
			return await _frase_minaccia(m, testo.substr(dopo_p + 1), fatti, manuali, logs, testo_it)
		return false
	# segnalini sulle plance dei Membri (Oftalmoide)
	if tl.begins_with("place a marker on a crew board of a crewmember in the highest-numbered sector"):
		var vivi2 := esp.vivi()
		vivi2.shuffle()
		vivi2.sort_custom(func(a, b): return int(esp.membro(a)["settore"]) > int(esp.membro(b)["settore"]))
		if not vivi2.is_empty():
			var mb := esp.membro(vivi2[0])
			mb["segni"] = int(mb.get("segni", 0)) + 1
			fatti.append("%s: un segnalino sulla plancia di %s" % [m["nome"], mb["carta"]])
		return false
	var cpm := RegEx.create_from_string("(?i)^each player with a marker on their crew board discards 1 marker from their crew board and (.+?)(?: \\(if no player has a marker, (\\w+) instead\\))?\\.?$").search(testo)
	if cpm:
		var con := esp.vivi().filter(func(i): return int(esp.membro(i).get("segni", 0)) > 0)
		if con.is_empty() and cpm.get_string(2) != "":
			await _effetto_minaccia(m, _carta_minaccia(m), cpm.get_string(2), fatti, manuali, logs)
			return false
		for i in con:
			esp.membro(i)["segni"] = int(esp.membro(i)["segni"]) - 1
			for op in Effetti.analizza(cpm.get_string(1))["op"]:
				await _op(op, i, sett, fatti, manuali, logs, "Minaccia " + str(m["nome"]))
		return false
	var rmb := RegEx.create_from_string("(?i)^remove .+? from the planet board(?: and \\[outcome(Red|Green|Yellow)Reduction\\])?").search(testo)
	if rmb:
		m["settore"] = 0
		fatti.append("%s esce dalla plancia del Pianeta" % m["nome"])
		if rmb.get_string(1) != "":
			var col4 := rmb.get_string(1).to_lower()
			var v4 := esp.avanza_traccia(-1, "M:%s#0#%s" % [m.get("en", m["nome"]), col4], -1, 99)
			fatti.append("Traccia %s dell'azione di %s: %d" % [col4, m["nome"], v4])
		return false
	if tl.begins_with("travel and [outcome"):
		var c := _carta_minaccia(m)
		await _effetto_minaccia(m, c, "Travel", fatti, manuali, logs)
		var pr := RegEx.create_from_string("outcome(Red|Green|Yellow)Progress").search(testo)
		if pr:
			var col2 := pr.get_string(1).to_lower()
			var tr: Array = (c.get("azioni", [{}]) as Array)[0].get("tracce", []) if not (c.get("azioni", []) as Array).is_empty() else []
			var cas := 3
			for t in tr:
				if str(t.get("colore", "")) == col2:
					cas = int(t.get("caselle", 3))
			var v := esp.avanza_traccia(-1, "M:%s#0#%s" % [m.get("en", m["nome"]), col2], 1, cas)
			fatti.append("Traccia %s dell'azione di %s: %d/%d" % [col2, m["nome"], v, cas])
		return false
	if tl.contains("place") and tl.contains("one number higher"):
		var nx := sett + 1
		if not esp.s["settori"].has(str(nx)):
			nx = 1
		m["settore"] = nx
		fatti.append("%s nel Settore %d" % [m["nome"], nx])
		return false
	if tl.begins_with("discard") and tl.contains("threat card"):
		esp.s["minacce"].erase(m)
		esp.s["minaccia_scartata"] = true
		fatti.append("%s viene scartata" % m["nome"])
		return false
	if tl.begins_with("travel") or tl == "":
		return false
	# effetti sui Membri
	var bersagli := []
	var resto := testo
	var tl2 := testo.to_lower()
	var bs := RegEx.create_from_string("(?i)^each crewmember in the sector with (?:the )?[\\w' .-]+?( or (?:in )?a (?:sector )?connected(?: sector)?(?: \\(ignore the path's arrowheads\\))?(?: to the sector with (?:the )?[\\w' .-]+?)?)?\\s+(?=rolls|gains|moves|loses|discards|draws|\\[)").search(testo)
	var bs2 := RegEx.create_from_string("(?i)^each crewmember in a sector with at least 1 (marker|drone)\\s+").search(testo)
	var bs3 := RegEx.create_from_string("(?i)^each crewmember who is not in the lander sector\\s+").search(testo)
	if bs:
		var setts := [sett]
		if bs.get_string(1) != "":
			for k in esp.s["settori"]:
				var kk := int(k)
				if kk != sett and (kk in esp.collegati(pl, sett) or sett in esp.collegati(pl, kk)):
					setts.append(kk)
		bersagli = esp.vivi().filter(func(i): return int(esp.membro(i)["settore"]) in setts)
		resto = testo.substr(bs.get_end()).strip_edges()
	elif bs2:
		var campo := "segni" if bs2.get_string(1).to_lower() == "marker" else "droni"
		bersagli = esp.vivi().filter(func(i): return int(esp.s["settori"].get(str(int(esp.membro(i)["settore"])), {}).get(campo, 0)) > 0)
		resto = testo.substr(bs2.get_end()).strip_edges()
		if bersagli.is_empty():
			fatti.append("%s: nessun Membro coinvolto" % m["nome"])
			return true
	elif bs3:
		bersagli = esp.vivi().filter(func(i): return int(esp.membro(i)["settore"]) != int(esp.s["lander"]["settore"]))
		resto = testo.substr(bs3.get_end()).strip_edges()
		if bersagli.is_empty():
			fatti.append("%s: tutti sono nel settore del Lander" % m["nome"])
			return true
	elif tl2.begins_with("each crewmember in the sector with"):
		bersagli = esp.nel_settore(sett)
		resto = testo.substr(testo.find(" ", 36)).strip_edges()
	if tl2.begins_with("each crewmember in that sector"):
		bersagli = esp.nel_settore(sett)
		resto = testo.substr(30).strip_edges()
	# "Attack affects …" (Predatore Alfa): tutti nel suo settore, o 1 a caso se è fuori plancia
	if bersagli.is_empty() and _regole_minaccia.contains(_eff_nome + " affects") and not tl2.begins_with("each "):
		if sett <= 0:
			var vv := esp.vivi()
			bersagli = [vv[esp.rng.randi_range(0, vv.size() - 1)]] if not vv.is_empty() else []
		else:
			bersagli = esp.nel_settore(sett)
		if bersagli.is_empty():
			fatti.append("%s: nessun Membro coinvolto" % m["nome"])
			return true
	if tl2.begins_with("each other crewmember"):
		bersagli = esp.vivi().filter(func(i): return int(esp.membro(i)["settore"]) != sett)
		resto = testo.substr(21).strip_edges()
	elif tl2.begins_with("1 random crewmember in the sector with"):
		var qui := esp.nel_settore(sett)
		bersagli = [qui[esp.rng.randi_range(0, qui.size() - 1)]] if not qui.is_empty() else []
		resto = testo.substr(testo.find(en.substr(0, 4)) + en.length()) if en != "" else testo
	elif bersagli.is_empty() and not tl2.begins_with("each "):
		# effetto generale (Provviste, Scoperte…)
		var a := Effetti.analizza(testo)
		for op in a["op"]:
			await _op(op, int(esp.s["attivo"]), sett, fatti, manuali, logs, "Minaccia " + str(m["nome"]))
		if a["op"].is_empty() or str(a["resto"]) != "":
			manuali.append("Minaccia %s: %s" % [m["nome"], testo_it])
		return false
	if bersagli.is_empty():
		fatti.append("%s: nessun Membro coinvolto" % m["nome"])
		return true
	for i in bersagli:
		var opzioni := Array(resto.split(" OR ")) if resto.contains(" OR ") else [resto]
		var scelta: Variant = opzioni[0]
		if opzioni.size() > 1:
			var j := await _scegli("%s — %s" % [str(m["nome"]).to_upper(), esp.membro(i)["carta"]], opzioni.map(func(x): return _txt_icone(str(x))), testo_it, false)
			scelta = opzioni[j]
		if str(scelta).to_lower().begins_with("moves all dice of a chosen color to the spent pool"):
			var cols := ["red", "blue", "green"]
			var jc := await _scegli("%s — %s" % [str(m["nome"]).to_upper(), esp.membro(i)["carta"]], ["Dadi rossi", "Dadi blu", "Dadi verdi"], "Quale colore va nei Dadi Spesi?", false)
			var nsp := 0
			for d in esp.membro(i)["dadi"]:
				if d["stato"] == "disponibile" and Prova.colore(d) == cols[max(0, jc)]:
					d["stato"] = "speso"
					nsp += 1
			fatti.append("%s spende %d dadi" % [esp.membro(i)["carta"], nsp])
			continue
		var a2 := Effetti.analizza(str(scelta))
		for op in a2["op"]:
			await _op(op, i, sett, fatti, manuali, logs, "Minaccia " + str(m["nome"]))
		if a2["op"].is_empty() or str(a2["resto"]).length() > 12:
			manuali.append("Minaccia %s, per %s: %s" % [m["nome"], esp.membro(i)["carta"], testo_it])
	return false

# ------------------------------------------------------------------ Lander e atterraggio

const STAT := {"landerArmor": "corazza", "landerSensors": "sensori", "landerAgility": "agilita"}

func _stat(nome: String) -> int:
	return int(esp.s["lander"].get(STAT.get(nome, nome), 0))

static func _nome_stat(nome: String) -> String:
	return {"landerArmor": "Corazza", "landerSensors": "Sensori", "landerAgility": "Agilità"}.get(nome, nome)

func in_atterraggio() -> bool:
	var ld: Dictionary = esp.s["lander"]
	return int(ld.get("contatore", 0)) > 0 and int(ld["contatore"]) < int(ld.get("caselle", 5)) and int(esp.s["round"]) == 1

# ------------------------------------------------------------------ Logbook automatico

## Risposta alle domande Sì/No del Logbook che dipendono dallo stato della partita:
## 1 = sì, 0 = no, -1 = non si sa (la decide il giocatore). spiegazione in _ultima_spiegazione.
var _ultima_spiegazione := ""
func rispondi_logbook(q: String) -> int:
	var t := RegEx.create_from_string("\\{i:(\\w+)\\}").sub(q, "[$1]", true)
	t = RegEx.create_from_string("\\[/?[bi]\\]").sub(t, "", true).replace("\n", " ").replace("’", "'").strip_edges()
	t = RegEx.create_from_string("\\s+").sub(t, " ", true)
	var tl := t.to_lower()
	var st := _rispondi_stato(t, tl)
	if st >= 0:
		return st
	# contatore dell'Atterraggio
	if tl.contains("atterraggio riuscito"):
		var ld: Dictionary = esp.s["lander"]
		var arrivato: bool = int(ld.get("contatore", 0)) >= int(ld.get("caselle", 5))
		var neg: bool = tl.contains(" non ")
		_ultima_spiegazione = "contatore dell'Atterraggio %d/%d" % [int(ld.get("contatore", 0)), int(ld.get("caselle", 5))]
		return 1 if (arrivato != neg) else 0
	# statistiche del Lander: "[landerX] è maggiore o uguale a N", "è N o più", "minore o uguale a N", "almeno N [x] e N [y]"
	var rx_cmp := RegEx.create_from_string("\\[(landerArmor|landerSensors|landerAgility)\\]\\s*è\\s*(maggiore o uguale a|minore o uguale a)?\\s*(\\d+)\\s*(o più|o meno)?")
	var rx_alm := RegEx.create_from_string("(\\d+)\\s*\\[(landerArmor|landerSensors|landerAgility)\\]")
	var ok := true
	var trovato := false
	var spieg := []
	if tl.contains("almeno"):
		for m in rx_alm.search_all(t):
			trovato = true
			var v := _stat(m.get_string(2))
			spieg.append("%s %d" % [_nome_stat(m.get_string(2)), v])
			ok = ok and v >= int(m.get_string(1))
	else:
		for m in rx_cmp.search_all(t):
			trovato = true
			var v2 := _stat(m.get_string(1))
			var n := int(m.get_string(3))
			spieg.append("%s %d" % [_nome_stat(m.get_string(1)), v2])
			if m.get_string(2).begins_with("minore") or m.get_string(4) == "o meno":
				ok = ok and v2 <= n
			else:
				ok = ok and v2 >= n
	if trovato:
		_ultima_spiegazione = ", ".join(spieg)
		return 1 if ok else 0
	var m2 := RegEx.create_from_string("(?i)segnaposto danno sulla plancia lander").search(t)
	if m2 and tl.contains("o più"):
		var n2 := int(RegEx.create_from_string("(\\d+)").search(t).get_string(1))
		_ultima_spiegazione = "%d segnalini danno sul Lander" % int(esp.s["lander"].get("danni", 0))
		return 1 if int(esp.s["lander"].get("danni", 0)) >= n2 else 0
	# posizione del Membro di turno
	var m3 := RegEx.create_from_string("(?i)ti trovi nel settore (\\d+)").search(t)
	if m3:
		var sett := int(esp.membro(int(esp.s["attivo"]))["settore"])
		_ultima_spiegazione = "%s è nel Settore %d" % [esp.membro(int(esp.s["attivo"]))["carta"], sett]
		return 1 if sett == int(m3.get_string(1)) else 0
	if Campagna.dati.get("nave") is Dictionary and not (Campagna.dati["nave"] as Dictionary).is_empty():
		var pc := Nave.domanda_carte(t, Nave.new(Campagna.dati["nave"]))
		if pc >= 0:
			_ultima_spiegazione = "Carte del Ponte: %s" % ", ".join(Campagna.dati["nave"].get("ponte", []) + Campagna.dati["nave"].get("ponte_viaggio", []))
			return pc
	var m4 := RegEx.create_from_string("(?i)(?:carta )?missione (M\\d+) è scoperta").search(t)
	if m4:
		_ultima_spiegazione = "Missioni in gioco: %s" % ", ".join(esp.s["missioni"])
		return 1 if m4.get_string(1).to_upper() in esp.s["missioni"] else 0
	var m5 := RegEx.create_from_string("(?i)possiedi la scoperta eccezionale (\\d+)").search(t)
	if m5:
		var ecc: Array = esp.s["eccezionali"].map(func(x): return int(x))
		_ultima_spiegazione = "Scoperte Eccezionali: %s" % ", ".join(ecc.map(func(x): return str(x)))
		return 1 if int(m5.get_string(1)) in ecc else 0
	var m6 := RegEx.create_from_string("(?i)segnaposto nel settore (\\d+)").search(t)
	if m6 and tl.contains("presente"):
		return -1
	return -1

## Domande del Logbook sullo stato della partita che il programma conosce (carte sulla plancia,
## Condizione Generale, Missioni, Minacce, Equipaggio, segnaposto, Piaghe, modalità di gioco…).
func _rispondi_stato(t: String, tl: String) -> int:
	var si := func(v: bool, perche: String) -> int:
		_ultima_spiegazione = perche
		return 1 if v else 0
	# domande in inglese (alcune annotazioni non tradotte): le stesse verifiche
	tl = tl.replace("has the marker reached the “landing successful” space", "il segnaposto ha raggiunto la casella atterraggio riuscito") \
		.replace("is the global condition card", "la carta condizione generale").replace(" on the board", " si trova sulla plancia") \
		.replace("is mission", "la carta missione").replace(" revealed", " è scoperta").replace("are you on ", "ti trovi su ") \
		.replace("are you playing this operation as a single scenario", "sessione di gioco singola").replace("sei nel settore", "ti trovi nel settore")
	var ce := RegEx.create_from_string("is (?:the )?card (P\\d{3}).*? in sector (\\d+)").search(tl)
	if ce:
		tl = "la carta %s si trova nel settore %s" % [ce.get_string(1), ce.get_string(2)]
		t = tl.to_upper().replace("LA CARTA", "la carta")
	# due statistiche del Lander insieme ("e" / "oppure"), "pari o superiore", "N or more"
	var due := RegEx.create_from_string("\\[(lander\\w+)\\] (e|oppure) \\[(lander\\w+)\\] sono maggiori o uguali a (\\d+)").search(t)
	if due:
		var a1 := _stat(due.get_string(1)) >= int(due.get_string(4))
		var a2 := _stat(due.get_string(3)) >= int(due.get_string(4))
		_ultima_spiegazione = "%s %d, %s %d" % [_nome_stat(due.get_string(1)), _stat(due.get_string(1)), _nome_stat(due.get_string(3)), _stat(due.get_string(3))]
		return 1 if ((a1 and a2) if due.get_string(2) == "e" else (a1 or a2)) else 0
	var ps := RegEx.create_from_string("\\[(lander\\w+)\\]\\s*(?:è pari o superiore a|is|)\\s*(\\d+)\\s*(?:or more|o superiore)?").search(t)
	if ps and (tl.contains("pari o superiore") or tl.contains("or more")):
		_ultima_spiegazione = "%s %d" % [_nome_stat(ps.get_string(1)), _stat(ps.get_string(1))]
		return 1 if _stat(ps.get_string(1)) >= int(ps.get_string(2)) else 0
	if tl.contains("girare la tua carta rank-up") or tl.contains("girare la carta grado superiore"):
		_ultima_spiegazione = "carta Grado Superiore %s" % ("girata" if esp.s.get("grado_girato", false) else "non girata")
		return 1 if esp.s.get("grado_girato", false) else 0
	var modo := str(Campagna.dati.get("modo", "campagna")) if Campagna.dati is Dictionary else "campagna"
	# modalità di gioco
	if RegEx.create_from_string("stai giocando (?:la|una) campagna|all'interno di una campagna").search(tl):
		return si.call(modo in ["campagna", "rapido"], "modalità: %s" % modo)
	if RegEx.create_from_string("sessione di gioco singola|scenario indipendente").search(tl):
		return si.call(modo == "operazioni", "modalità: %s" % modo)
	if tl.contains("stai effettuando un'esplorazione planetaria"):
		return si.call(true, "sei in esplorazione")
	# quarta Ferita, Membri morti o rimasti
	if RegEx.create_from_string("(?:riportato|ricevuto|ottenuto|gain) (?:una |la |a )?(?:quarta|fourth) (?:ferita|injury)").search(tl):
		return si.call(esp.s.get("quarta_ferita", false), "quarta Ferita: %s" % ("sì" if esp.s.get("quarta_ferita", false) else "no"))
	if RegEx.create_from_string("(?:tutti i membri dell'equipaggio sono morti|sono morti tutti i membri)").search(tl):
		return si.call(esp.vivi().is_empty(), "Membri vivi: %d" % esp.vivi().size())
	if RegEx.create_from_string("ultimo membro dell'equipaggio").search(tl):
		return si.call(esp.vivi().size() <= 1, "Membri vivi: %d" % esp.vivi().size())
	if RegEx.create_from_string("ci sono (?:ancora )?membri dell'equipaggio sulla plancia|almeno un membro dell'equipaggio non è impossibilitato").search(tl):
		return si.call(not esp.vivi().is_empty(), "Membri vivi: %d" % esp.vivi().size())
	if tl.contains("solo una miniatura di un membro"):
		return si.call(esp.vivi().size() == 1, "Membri sulla plancia: %d" % esp.vivi().size())
	var mm := RegEx.create_from_string("sono presenti (\\d+) o più membri").search(tl)
	if mm:
		return si.call(esp.vivi().size() >= int(mm.get_string(1)), "Membri: %d" % esp.vivi().size())
	mm = RegEx.create_from_string("tutti i membri dell'equipaggio si trovano nel settore (\\d+)").search(tl)
	if mm:
		return si.call(esp.vivi().all(func(i): return int(esp.membro(i)["settore"]) == int(mm.get_string(1))), "posizioni della Squadra")
	mm = RegEx.create_from_string("un membro dell'equipaggio ha (\\d+) ferite").search(tl)
	if mm:
		return si.call(esp.vivi().any(func(i): return (esp.membro(i)["ferite"] as Array).size() >= int(mm.get_string(1))), "Ferite della Squadra")
	mm = RegEx.create_from_string("il tuo membro dell'equipaggio (?:adesso )?si trova nel settore (\\d+)(?: oppure (\\d+))?").search(tl)
	if mm and not tl.contains(", e "):
		var sa := int(esp.membro(int(esp.s["attivo"]))["settore"])
		return si.call(sa == int(mm.get_string(1)) or (mm.get_string(2) != "" and sa == int(mm.get_string(2))), "il Membro di turno è nel Settore %d" % sa)
	# carte PDI sulla plancia
	var cod := RegEx.create_from_string("\\b(P\\d{3})\\b").search_all(t).map(func(x): return x.get_string(1))
	var sett_q := RegEx.create_from_string("nel settore (\\d+)").search_all(tl).map(func(x): return int(x.get_string(1)))
	if not cod.is_empty() and not tl.contains("segnaposto") and not tl.contains("missione") and (tl.contains("si trova") or tl.contains("è presente") or tl.contains("pdi nel settore") or tl.contains("ci sono altre")):
		var dove := _pdi_sulla_plancia()
		var trovati := []
		for c in cod:
			for n in dove.get(c, []):
				trovati.append(n)
		var v := false
		if tl.contains("non ci sono altre"):
			v = trovati.is_empty()
		elif not sett_q.is_empty():
			v = trovati.any(func(n): return n in sett_q)
			if tl.contains(" non si trova"):
				v = not v
		else:
			v = not trovati.is_empty()
		return si.call(v, "%s: %s" % [", ".join(cod), ("Settore " + ", ".join(trovati.map(func(x): return str(x)))) if not trovati.is_empty() else "non sulla plancia"])
	mm = RegEx.create_from_string("il pdi stampato \\(([^)]+)\\) si trova nel settore (\\d+)").search(tl)
	if mm:
		var n2 := int(mm.get_string(2))
		var p: Array = esp.s["settori"].get(str(n2), {}).get("pdi", [])
		return si.call(p.is_empty() or str(p[-1]) == "P000", "Settore %d: %s" % [n2, "PDI stampato" if p.is_empty() else str(p[-1])])
	mm = RegEx.create_from_string("almeno una carta pdi in ognuno dei settori ([\\d, e]+)").search(tl)
	if mm:
		var ss := RegEx.create_from_string("\\d+").search_all(mm.get_string(1)).map(func(x): return int(x.get_string(0)))
		return si.call(ss.all(func(n): return not (esp.s["settori"].get(str(n), {}).get("pdi", []) as Array).is_empty()), "PDI nei Settori %s" % mm.get_string(1))
	# Condizione Generale
	var gc_id := str(esp.s["condizione"]["carta"]).get_slice("@", 0).to_upper()
	var gc := Carte.per_id(str(esp.s["condizione"]["carta"]))
	mm = RegEx.create_from_string("(?i)condizione (?:generale|globale) (G\\d+)").search(t)
	if mm and (tl.contains("plancia") or tl.contains("attuale")):
		return si.call(gc_id == mm.get_string(1).to_upper(), "Condizione Generale in gioco: %s %s" % [gc_id, Carte.titolo(gc)])
	mm = RegEx.create_from_string("condizione (?:generale|globale) attuale è\\s+(.+?)\\?*$").search(tl)
	if mm:
		var nome := mm.get_string(1).strip_edges().to_lower()
		return si.call(Carte.t(gc.get("titolo", "")).to_lower().contains(nome) or Carte.en(gc.get("titolo", "")).to_lower().contains(nome), "Condizione Generale in gioco: %s" % Carte.titolo(gc))
	# Missioni
	var mis_cod := RegEx.create_from_string("\\b(M\\d+)\\b").search_all(t).map(func(x): return x.get_string(1).to_upper())
	if not mis_cod.is_empty() and not tl.contains("segnaposto") and not tl.contains("p0") and (tl.contains("scopert") or tl.contains("attuale")):
		var in_gioco: Array = (esp.s["missioni"] as Array).map(func(x): return str(x).to_upper())
		return si.call(mis_cod.any(func(x): return x in in_gioco), "Missioni in gioco: %s" % ", ".join(in_gioco))
	if RegEx.create_from_string("ci sono carte missione scoperte|una carta missione è scoperta|almeno (?:1|una) carta missione").search(tl):
		return si.call(not (esp.s["missioni"] as Array).is_empty(), "Missioni in gioco: %d" % (esp.s["missioni"] as Array).size())
	# Minacce
	if tl.contains("non ci sono più carte minaccia"):
		return si.call((esp.s["minacce"] as Array).is_empty(), "Minacce in gioco: %d" % (esp.s["minacce"] as Array).size())
	mm = RegEx.create_from_string("(?:è presente una minaccia|il segnalino|la carta minaccia|la minaccia) ([\\w' ]+?) (?:sulla plancia|si trova sulla plancia|è sulla plancia)").search(tl)
	if mm:
		var nm := mm.get_string(1).strip_edges()
		var c := (esp.s["minacce"] as Array).filter(func(x): return str(x.get("nome", "")).to_lower().contains(nm) or str(x.get("en", "")).to_lower().contains(nm) or nm.contains(str(x.get("nome", "")).to_lower()))
		return si.call(not c.is_empty(), "Minacce in gioco: %s" % ", ".join((esp.s["minacce"] as Array).map(func(x): return str(x.get("nome", "")))))
	# attrezzatura accanto alle plance
	var ecod := RegEx.create_from_string("\\b(E\\d{2,3})\\b").search_all(t).map(func(x): return x.get_string(1))
	if not ecod.is_empty() and tl.contains("accanto"):
		var tutte := []
		for i in esp.vivi():
			tutte += esp.membro(i).get("attrezzatura", [])
		return si.call(ecod.any(func(x): return x in tutte), "attrezzatura della Squadra: %s" % ", ".join(tutte))
	# Scoperte Eccezionali sulle plance
	mm = RegEx.create_from_string("la scoperta eccezionale (\\d+) si trova sulla plancia (pianeta|lander)").search(tl)
	if mm:
		var num := int(mm.get_string(1))
		var v2: bool = num in (esp.s.get("eccezionali_pianeta", []) as Array).map(func(x): return int(x)) if mm.get_string(2) == "pianeta" else num in (esp.s["eccezionali"] as Array).map(func(x): return int(x))
		return si.call(v2, "Scoperte Eccezionali")
	if tl.contains("non c'è alcuna scoperta eccezionale sulla plancia pianeta"):
		return si.call((esp.s.get("eccezionali_pianeta", []) as Array).is_empty(), "Scoperte Eccezionali sulla plancia: %d" % (esp.s.get("eccezionali_pianeta", []) as Array).size())
	# pianeta e Lander
	mm = RegEx.create_from_string("(?:ti trovi su(?:l pianeta)?|plancia pianeta attualmente aperta è) ([^?(]+)").search(tl)
	if mm:
		var nome2 := mm.get_string(1).strip_edges()
		return si.call(str(pl.get("pianeta", "")).to_lower().begins_with(nome2.substr(0, 6)), "pianeta: %s" % pl.get("pianeta", ""))
	mm = RegEx.create_from_string("stai usando il lander (\\w+)").search(tl)
	if mm:
		return si.call(str(esp.s["lander"].get("nome", "")).to_lower().contains(mm.get_string(1)), "Lander: %s" % esp.s["lander"].get("nome", ""))
	# Piaghe
	mm = RegEx.create_from_string("sono presenti (\\d+) piaghe nel settore (\\d+)").search(tl)
	if mm:
		var pg := int(esp.s["settori"].get(mm.get_string(2), {}).get("piaghe", 0))
		return si.call(pg >= int(mm.get_string(1)), "Settore %s: %d Piaghe" % [mm.get_string(2), pg])
	mm = RegEx.create_from_string("ancora un settore con almeno (\\d+) piag").search(tl)
	if mm:
		var c2: Variant = esp.s["settori"].keys().filter(func(k): return int(esp.s["settori"][k].get("piaghe", 0)) >= int(mm.get_string(1)))
		return si.call(not c2.is_empty(), "Settori con Piaghe: %s" % ", ".join(c2))
	# segnaposto su carte, riserve e slot
	mm = RegEx.create_from_string("(?:sono presenti|possiedi|hai|è presente)(?: almeno| esattamente)? (\\d+)( o più| o meno)? segnaposto (sulla carta [^?]+|nella riserva [^?]+|nello slot [^?]+)").search(tl)
	if mm:
		var n3 := int(mm.get_string(1))
		var cont: Dictionary = esp.s.get("contatori", {})
		var dove := mm.get_string(3)
		var chiavi := [Effetti.chiave_segni(dove)]
		if dove.contains(" oppure "):
			chiavi = Array(dove.split(" oppure ")).map(func(x): return Effetti.chiave_segni(("sulla carta " + str(x)) if not str(x).begins_with("sulla") else str(x)))
		if dove.contains("missione attuale") and not (esp.s["missioni"] as Array).is_empty():
			chiavi = ["carta:" + str(esp.s["missioni"][0]).to_lower()]
		var v3 := 0
		for k in chiavi:
			v3 = max(v3, int(cont.get(k, 0)))
		var ok3 := v3 >= n3 if (tl.contains("almeno") or mm.get_string(2) == " o più") else (v3 <= n3 if mm.get_string(2) == " o meno" else v3 == n3)
		return si.call(ok3, "segnaposto %s: %d" % [chiavi[0].get_slice(":", 1), v3])
	# nave (Obiettivo, Scanner, Morale, Progetti)
	if Campagna.dati.get("nave") is Dictionary and not (Campagna.dati["nave"] as Dictionary).is_empty():
		var rn := Nave.domanda_nave(t, Nave.new(Campagna.dati["nave"]))
		if rn["r"] >= 0:
			_ultima_spiegazione = rn["perche"]
			return rn["r"]
	return -1

## Dove si trova ogni carta PDI sulla plancia: codice -> [settori] (in cima o sotto nella pila).
func _pdi_sulla_plancia() -> Dictionary:
	var out := {}
	for k in esp.s["settori"]:
		for c in esp.s["settori"][k].get("pdi", []):
			out.get_or_add(str(c).get_slice("@", 0).to_upper(), []).append(int(k))
	return out

## Istruzioni del Logbook eseguite dal programma; restituisce le righe "fatto" (vuoto = niente).
func istruzione_logbook(t: String) -> Array:
	var carte := []
	if Campagna.dati.get("nave") is Dictionary and not (Campagna.dati["nave"] as Dictionary).is_empty():
		carte = Nave.new(Campagna.dati["nave"]).istruzione_carte(t)
		if not carte.is_empty():
			Campagna.modificata()
	var ops: Array = Effetti.analizza_it(t)["op"]
	if ops.is_empty() or str(esp.s.get("finita", "")) != "":
		return carte
	var chi := int(esp.s["attivo"])
	var sett := int(esp.membro(chi)["settore"])
	var fatti := []
	var manuali := []
	var logs := []
	for op in ops:
		await _op(op, chi, sett, fatti, manuali, logs, "Logbook")
	fatti = carte + fatti
	_salva()
	aggiorna()
	return fatti

func _eccezionale(n: int) -> Dictionary:
	for c in Carte.categoria("scoperte"):
		if str(c.get("tipo", "")) == "unique_discovery" and int(c.get("campi", {}).get("numero", -1)) == n:
			return c
	return {}

func _controlla_scoperte(manuali: Array) -> void:
	if esp.s["scoperte"].size() > int(esp.s["lander"]["max_scoperte"]):
		manuali.append("Il Lander può trasportare al massimo %d Scoperte: scartane %d" % [int(esp.s["lander"]["max_scoperte"]), esp.s["scoperte"].size() - int(esp.s["lander"]["max_scoperte"])])

func _tempo(n: int) -> void:
	esp.tempo_tutte(n)
	var fatti := ["Tutte le tracce del Tempo avanzano di %d" % n]
	var manuali := []
	var logs := []
	await _minacce_avanzano(n, fatti, manuali, logs)
	await _controlla_tempo(fatti, manuali, logs)
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
	fatti.append("[b]Traccia del Tempo della Condizione Generale completa[/b]: %s" % Carte.t(tm))
	var testo := Carte.en(tm)
	for f in RegEx.create_from_string("(?<=\\.)\\s+").sub(testo, "§", true).split("§"):
		var fr := str(f).strip_edges()
		var fl := fr.to_lower()
		if fr == "":
			continue
		if fl.begins_with("discard this condition"):
			esp.s["condizione"] = {"carta": "", "tempo": 0}
			fatti.append("La Condizione Generale si scarta: torna quella stampata sulla plancia")
			continue
		if fl.begins_with("reset this track"):
			esp.s["condizione"]["tempo"] = 0
			esp.s["condizione"]["scattata"] = false
			fatti.append("La traccia del Tempo della Condizione Generale si azzera")
			continue
		var bers: Array = [int(esp.s["attivo"])]
		var resto := fr
		if fl.begins_with("each crewmember "):
			bers = esp.vivi()
			resto = fr.substr(16)
		var a := Effetti.analizza(resto)
		for i in bers:
			for op in a["op"]:
				await _op(op, i, int(esp.membro(i)["settore"]), fatti, manuali, logs, "Tempo della Condizione Generale")
		if a["op"].is_empty() or str(a["resto"]).length() > 12:
			manuali.append("Tempo della Condizione Generale: " + fr)
