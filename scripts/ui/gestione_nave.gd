## Gestione della Nave: il Ship Book una pagina alla volta. In alto lo stato della nave (Morale,
## Livello tecnologico, segnalini, sistema), a sinistra i passi del Ship Book, al centro solo il passo
## corrente con le sue scelte; Equipaggio, Scoperte, Progetti, Situazioni e Armeria si consultano
## a richiesta nel cassetto laterale. Quello che il programma non sa fare compare come istruzione.
class_name GestioneNave
extends Control

signal chiusa                       # torna al tavolo
signal esplora(cfg: Dictionary)     # parte l'esplorazione planetaria

signal _scelto(i: int)

const ALTO_HUD := 46
const NOMI_SCOPERTE := {"mineral": "Minerale", "microorganism": "Microrganismo", "live_specimen": "Esemplare vivo",
	"strange_flora": "Flora strana", "alien_tech": "Tecnologia aliena", "any": "qualsiasi"}

var nave: Nave
var _info: RichTextLabel
var _passi_box: VBoxContainer
var _corpo: VBoxContainer
var _cassetto_box: PanelContainer
var _cassetto: VBoxContainer
var _cassetto_titolo: Label
var _cassetto_tipo := ""
var _logbook: PannelloLogbook
var _toast: Label
var _toast_tw: Tween
var _sotto := ""        # sotto-pagina delle Strutture (ricerca, produzione, caserma, situazioni)
var _scelta := {}       # stato temporaneo del passo corrente

func _init(stato: Dictionary) -> void:
	nave = Nave.new(stato)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Tema.tema
	var fondo := ColorRect.new()
	fondo.color = Color(0.008, 0.016, 0.035)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	add_child(_hud())
	var corpo := HBoxContainer.new()
	corpo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corpo.offset_top = ALTO_HUD + 8
	corpo.offset_left = 8
	corpo.offset_right = -8
	corpo.offset_bottom = -8
	corpo.add_theme_constant_override("separation", 12)
	add_child(corpo)
	# passi del Ship Book
	var lp := PanelContainer.new()
	lp.custom_minimum_size = Vector2(250, 0)
	lp.add_theme_stylebox_override("panel", Tema.box(Color(0.02, 0.045, 0.09, 0.9), Tema.CIANO_SCURO, 1, 6, 8))
	corpo.add_child(lp)
	_passi_box = VBoxContainer.new()
	_passi_box.add_theme_constant_override("separation", 2)
	lp.add_child(_passi_box)
	# passo corrente al centro
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corpo.add_child(cc)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(980, 0)
	pc.add_theme_stylebox_override("panel", Tema.box(Color(0.025, 0.055, 0.11, 0.95), Tema.CIANO_SCURO, 1, 8, 16))
	cc.add_child(pc)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(960, 900)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pc.add_child(sc)
	_corpo = VBoxContainer.new()
	_corpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_corpo.add_theme_constant_override("separation", 10)
	sc.add_child(_corpo)
	# cassetto di consultazione
	_cassetto_box = PanelContainer.new()
	_cassetto_box.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_cassetto_box.offset_left = -480
	_cassetto_box.offset_top = ALTO_HUD + 6
	_cassetto_box.offset_bottom = -6
	_cassetto_box.offset_right = -6
	_cassetto_box.add_theme_stylebox_override("panel", Tema.box(Color(0.02, 0.045, 0.09, 0.98), Tema.CIANO_SCURO, 1, 6, 10))
	var cv := VBoxContainer.new()
	_cassetto_box.add_child(cv)
	var ch := HBoxContainer.new()
	_cassetto_titolo = Tema.etichetta("", 15, Tema.CIANO, true)
	_cassetto_titolo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ch.add_child(_cassetto_titolo)
	ch.add_child(Tema.pulsante("✕", func(): apri_cassetto(""), 13))
	cv.add_child(ch)
	var csc := ScrollContainer.new()
	csc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	csc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cv.add_child(csc)
	_cassetto = VBoxContainer.new()
	_cassetto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cassetto.add_theme_constant_override("separation", 6)
	csc.add_child(_cassetto)
	_cassetto_box.visible = false
	add_child(_cassetto_box)
	_logbook = PannelloLogbook.new()
	_logbook.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_logbook.offset_left = -660
	_logbook.offset_top = ALTO_HUD + 6
	_logbook.offset_bottom = -6
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
	aggiorna()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		if _cassetto_box.visible:
			apri_cassetto("")
		elif _logbook.visible:
			_logbook.visible = false
		get_viewport().set_input_as_handled()

func _salva() -> void:
	Campagna.dati["nave"] = nave.s
	Campagna.modificata()

func avviso(t: String) -> void:
	_toast.text = t
	_toast.modulate.a = 1.0
	if _toast_tw:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_interval(3.2)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.6)

# ------------------------------------------------------------------ riga di stato

func _hud() -> Control:
	var barra := PanelContainer.new()
	barra.set_anchors_preset(Control.PRESET_TOP_WIDE)
	barra.offset_bottom = ALTO_HUD
	barra.add_theme_stylebox_override("panel", Tema.box(Color(0.02, 0.05, 0.11, 0.95), Tema.CIANO_SCURO, 0, 0, 6))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	barra.add_child(h)
	h.add_child(Tema.etichetta("NAVE", 17, Tema.TESTO, true))
	_info = Tema.testo_ricco(15)
	_info.fit_content = true
	_info.scroll_active = false
	_info.autowrap_mode = TextServer.AUTOWRAP_OFF
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_info)
	for v in [["equipaggio", "EQUIPAGGIO"], ["progetti", "PROGETTI"], ["situazioni", "SITUAZIONI"], ["magazzino", "MAGAZZINO"], ["diario", "DIARIO"]]:
		var k: String = v[0]
		h.add_child(Tema.pulsante(v[1], func(): apri_cassetto("" if _cassetto_tipo == k and _cassetto_box.visible else k), 12))
	h.add_child(Tema.pulsante_primario("LOGBOOK", func():
		_logbook.visible = not _logbook.visible
		if _logbook.visible:
			apri_cassetto("")
			_logbook.mostra_corrente(), 13))
	h.add_child(Tema.pulsante("TAVOLO", func():
		_salva()
		chiusa.emit(), 12))
	return barra

func aggiorna() -> void:
	var s := nave.s
	if s.is_empty():
		_info.text = ""
	else:
		var ob := nave.carta_obiettivo()
		_info.text = "[color=#9fbbd6]MORALE[/color] [b]%s[/b]  [color=#9fbbd6]TECN.[/color] [b]%d[/b]  [color=#9fbbd6]COMANDO[/color] [b]%d[/b]  [color=#9fbbd6]ENERGIA[/color] [b]%d[/b]  [color=#9fbbd6]SUCCESSI[/color] [b]%d[/b]  [color=#9fbbd6]SISTEMA[/color] [b]%s[/b]  [color=#9fbbd6]OBIETTIVO[/color] %s%s" % [
			Nave.NOMI_MORALE.get(s["morale"], s["morale"]), int(s["tech"]), int(s["pool"]["comando"]), int(s["pool"]["energia"]), int(s["pool"]["successi"]),
			str(s["sistema"]), Carte.titolo(ob), ("   [color=#ffb347]BUSTA %d[/color]" % s["busta"].size()) if not s["busta"].is_empty() else ""]
	_aggiorna_passi()
	_mostra_passo()
	if _cassetto_box.visible:
		_riempi_cassetto()

func _aggiorna_passi() -> void:
	for c in _passi_box.get_children():
		c.queue_free()
	_passi_box.add_child(Tema.etichetta("SHIP BOOK", 13, Tema.TESTO_2, true))
	var cur := nave.passo() if not nave.s.is_empty() else "avvio"
	for p in Nave.PASSI:
		var l := Label.new()
		var pag: int = Nave.PAGINE.get(p, 0)
		l.text = "%s  %s" % ["▶" if p == cur else "  ", Nave.NOMI_PASSI[p]]
		l.tooltip_text = "Ship Book, pag. %d" % pag
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", Tema.AMBRA if p == cur else Tema.TESTO_2)
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		_passi_box.add_child(l)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_passi_box.add_child(sp)
	if not nave.s.is_empty():
		var vai := OptionButton.new()
		vai.add_item("Vai a un passo…")
		for p in Nave.PASSI:
			vai.add_item(Nave.NOMI_PASSI[p])
		vai.item_selected.connect(func(k):
			if k > 0:
				nave.vai(Nave.PASSI[k - 1])
				_sotto = ""
				_scelta = {}
				_salva()
				aggiorna())
		vai.tooltip_text = "Per seguire un'istruzione del Logbook (\"apri il Ship Book a pagina…\") o correggere"
		_passi_box.add_child(vai)

# ------------------------------------------------------------------ mattoni dell'interfaccia

func _svuota() -> void:
	for c in _corpo.get_children():
		c.queue_free()

func _titolo(t: String, pagina := 0) -> void:
	var h := HBoxContainer.new()
	var l := Tema.etichetta(t.to_upper(), 22, Tema.TESTO, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	if pagina > 0:
		h.add_child(Tema.etichetta("Ship Book pag. %d" % pagina, 13, Tema.TESTO_2))
	_corpo.add_child(h)

func _sezione(t: String) -> void:
	_corpo.add_child(Tema.etichetta(t.to_upper(), 15, Tema.CIANO, true))

func _testo(bb: String, dim := 17, dove: Control = null) -> RichTextLabel:
	var r := Tema.testo_ricco(dim)
	r.fit_content = true
	r.scroll_active = false
	r.text = bb
	(dove if dove else _corpo).add_child(r)
	return r

func _riga(dove: Control = null) -> HFlowContainer:
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 8)
	h.add_theme_constant_override("v_separation", 6)
	(dove if dove else _corpo).add_child(h)
	return h

func _avanti(testo := "AVANTI ▶", cb: Callable = Callable()) -> void:
	_corpo.add_child(HSeparator.new())
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_END
	_corpo.add_child(h)
	h.add_child(Tema.pulsante_primario(testo, func():
		if cb.is_valid():
			var r = await cb.call()
			if r is bool and not r:
				return
		_scelta = {}
		_sotto = ""
		nave.prossimo()
		_salva()
		aggiorna(), 17))

func _carta(id: String) -> String:
	var c := Carte.per_id(id)
	return "%s %s" % [id, Carte.titolo(c)] if not c.is_empty() else id

func _bb(t: String) -> String:
	return Dati.testo_carta(t, 20)

## Finestra di scelta (restituisce l'indice, -1 = annulla).
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
		tr.custom_minimum_size = Vector2(700, 460)
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
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(700, min(520, 48 * opzioni.size() + 8))
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var ov := VBoxContainer.new()
	ov.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(ov)
	for i in opzioni.size():
		var k: int = i
		var b := Tema.pulsante(str(opzioni[i]), func():
			vel.queue_free()
			_scelto.emit(k), 15)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ov.add_child(b)
	if annullabile:
		v.add_child(Tema.pulsante("ANNULLA", func():
			vel.queue_free()
			_scelto.emit(-1), 13))
	var r2: int = await _scelto
	return r2

func _mostra_carta(id: String) -> void:
	var c := Carte.per_id(id)
	if c.has("file"):
		await _scegli(_carta(id), ["CHIUDI"], "", false, str(c["file"]))

## Membri che si possono assegnare a un compito (opzionale: con un'icona di conversione fra quelle date).
func _assegnabili(icone: Array = []) -> Array:
	var out := []
	for i in nave.membri("", "disponibile"):
		if not nave.assegnabile(i):
			continue
		if not icone.is_empty() and not "anySameIcons" in icone and not nave.conversione(i) in icone:
			continue
		out.append(i)
	return out

func _nome_membro(i: int) -> String:
	var m: Dictionary = nave.s["equipaggio"][i]
	return "%s (%s, Grado %d%s)" % [m["carta"], Dati.SEZIONI.get(m["reparto"], {}).get("nome", m["reparto"]), int(m["grado"]),
		(", conv. " + Traduzioni.icona(nave.conversione(i))) if nave.conversione(i) != "" else ""]

## Chiede di assegnare un Membro (restituisce l'indice o -1).
func _assegna(compito: String, icone: Array = []) -> int:
	var cand := _assegnabili(icone)
	if cand.is_empty():
		avviso("Nessun Membro disponibile da assegnare%s" % ((" con l'icona " + ", ".join(icone.map(func(x): return Traduzioni.icona(x)))) if not icone.is_empty() else ""))
		return -1
	var j := await _scegli("ASSEGNA: " + compito.to_upper(), cand.map(func(i): return _nome_membro(i)),
		"Il Membro assegnato va nell'Equipaggio a riposo. Non si può assegnare l'ultimo disponibile di un Reparto.")
	if j < 0:
		return -1
	nave.assegna(cand[j], compito)
	return cand[j]

# ------------------------------------------------------------------ esecuzione degli effetti

## Applica un testo (inglese) di una carta della nave; le alternative "OR" si scelgono.
## id_carta: la Situazione in gioco (per "shuffle into Possible Situations" / "remove from the game").
func applica(en: String, it: String, fonte: String, id_carta := "") -> void:
	var a := EffettiNave.analizza(en)
	var alt: Array = a["alternative"]
	var ops: Array = alt[0] if not alt.is_empty() else []
	if alt.size() > 1:
		var parti := Array(it.split(" OPPURE ")) if it.contains(" OPPURE ") else Array(en.split(" OR "))
		var j := await _scegli(fonte.to_upper(), parti.map(func(x): return _pulito(str(x))), "Scegli una delle alternative:", false)
		ops = alt[j]
	var fatti := []
	var logs := []
	for op in ops:
		match str(op["op"]):
			"pool":
				var p: String = op["pool"]
				nave.s["pool"][p] = max(0, int(nave.s["pool"][p]) + int(op["n"]))
				fatti.append("%+d %s" % [int(op["n"]), {"comando": "Comando", "energia": "Energia", "successi": "Successi"}[p]])
			"morale":
				if int(op["n"]) > 0:
					nave.morale_su()
				else:
					var r := nave.morale_giu()
					if r == "dadi":
						fatti.append("Morale già Molto basso: ogni Reparto ha perso un dado")
				fatti.append("Morale: %s" % Nave.NOMI_MORALE[nave.s["morale"]])
			"log":
				logs.append(int(op["n"]))
				fatti.append("Vai all'Annotazione %d" % int(op["n"]))
			"situazione":
				if id_carta != "":
					nave.s["situazioni"].erase(id_carta)
					if op["dove"] == "possibili":
						nave.s["situazioni_possibili"].append(id_carta)
						fatti.append("%s torna fra le Situazioni possibili" % id_carta)
					else:
						fatti.append("%s rimossa dal gioco" % id_carta)
			"penalita":
				nave.s["penalita"] = true
				fatti.append("Segnalino Penalità nella riserva del Comando")
	nave.diario("%s: %s" % [fonte, ", ".join(fatti) if not fatti.is_empty() else "da applicare a mano"])
	var t := ""
	if not fatti.is_empty():
		t += "[color=#5be39b][b]FATTO[/b][/color]\n" + "\n".join(fatti.map(func(x): return "• " + str(x)))
	if str(a["resto"]) != "":
		t += ("\n\n" if t != "" else "") + "[color=#ffb347][b]DA FARE A MANO[/b][/color]\n" + _bb(it)
	if t != "":
		await _scegli(fonte.to_upper(), ["OK"], t, false)
	_salva()
	aggiorna()
	if not logs.is_empty():
		_apri_log(int(logs[0]))

static func _pulito(t: String) -> String:
	return t.replace("[command]", "Comando").replace("[energy_token]", "Energia").replace("[success]", "Successi").replace("[", "").replace("]", "")

## Retro di un progetto completato: sposta le carte indicate e applica il resto del testo.
func applica_retro(id: String) -> void:
	var c := Carte.per_id(id)
	var r: Dictionary = c.get("retro", {}) if c.get("retro") is Dictionary else {}
	var fatti := []
	for m in r.get("spostamenti", []):
		var cid := str(m.get("carta", ""))
		match str(m.get("a", "")):
			"busta":
				nave.s["busta"].append(cid)
				fatti.append("%s nella busta \"In attesa…\"" % _carta(cid))
			"armeria":
				for k in int(m.get("n", 1)):
					nave.s["armeria"].append(cid)
				fatti.append("%s nell'Armeria" % _carta(cid))
			"hangar":
				nave.s["lander"].append({"nome": Carte.titolo(Carte.per_id(cid)).to_upper(), "danneggiato": false})
				fatti.append("Nuovo Lander: %s" % _carta(cid))
			"situazioni":
				nave.s["situazioni_possibili"].append(cid)
				fatti.append("%s fra le Situazioni possibili" % cid)
			"rimossa":
				fatti.append("%s rimossa dal gioco" % cid)
	var en := Carte.en(r.get("testo", ""))
	var logs := []
	for m in RegEx.create_from_string("(?i)go to log (\\d+)").search_all(en):
		logs.append(int(m.get_string(1)))
	nave.diario("Completato %s: %s" % [_carta(id), ", ".join(fatti)])
	var t := "[b]%s[/b]\n%s\n\n" % [Carte.titolo(r), _bb(Carte.t(r.get("testo", "")))]
	if not fatti.is_empty():
		t += "[color=#5be39b][b]FATTO[/b][/color]\n" + "\n".join(fatti.map(func(x): return "• " + str(x)))
	await _scegli("PROGETTO COMPLETATO", ["OK"], t, false, str(r.get("file", "")).replace("/home/claude/iss-vanguard/web/img/", ""))
	_salva()
	aggiorna()
	if not logs.is_empty():
		_apri_log(int(logs[0]))

# ------------------------------------------------------------------ Logbook automatico (nave)

var _ultima_spiegazione := ""
const PAGINA_PASSO := {2: "ponte", 3: "ponte", 5: "mappa", 6: "strutture", 8: "strutture", 12: "strutture", 16: "strutture", 17: "strutture",
	18: "hangar", 19: "hangar", 21: "hangar", 23: "lancio", 24: "esplorazione", 25: "partenza", 26: "attracco", 28: "scarico",
	29: "scarico", 32: "infermeria", 36: "memoriale", 27: "debriefing", 39: "salvataggio"}

func rispondi_logbook(q: String) -> int:
	if nave.s.is_empty():
		return -1
	var t := q.replace("[b]", "").replace("[/b]", "")
	var m := RegEx.create_from_string("(?i)possiedi la scoperta eccezionale (\\d+)").search(t)
	if m:
		_ultima_spiegazione = "Scoperte Eccezionali sulla nave: %s" % ", ".join(nave.s["eccezionali"].keys())
		return 1 if nave.s["eccezionali"].has(m.get_string(1)) else 0
	var m2 := RegEx.create_from_string("(?i)hai livello di tecnologia (\\d+)").search(t)
	if m2:
		_ultima_spiegazione = "Livello tecnologico %d" % int(nave.s["tech"])
		return 1 if int(nave.s["tech"]) >= int(m2.get_string(1)) else 0
	return -1

func istruzione_logbook(t: String) -> Array:
	if nave.s.is_empty():
		return []
	var fatti := []
	for op in Effetti.analizza_it(t)["op"]:
		match str(op["op"]):
			"nave_pagina":
				var p: String = PAGINA_PASSO.get(int(op["n"]), "")
				if p != "" and p != nave.passo():
					nave.vai(p)
					_sotto = ""
					_scelta = {}
					fatti.append("Ship Book a pagina %d: %s" % [int(op["n"]), Nave.NOMI_PASSI[p]])
			"planetopedia":
				Campagna.dati["prossimo_pianeta"] = str(op["pagina"])
				fatti.append("Planetopedia alle pagine %s (per la prossima esplorazione)" % str(op["pagina"]).trim_prefix("p."))
			"successi":
				nave.s["pool"]["successi"] = int(nave.s["pool"]["successi"]) + int(op["n"])
				fatti.append("+%d Successi" % int(op["n"]))
			"scoperta_eccezionale":
				nave.s["eccezionali"][str(op["n"])] = true
				fatti.append("Scoperta Eccezionale %d" % int(op["n"]))
	if not fatti.is_empty():
		_salva()
		aggiorna()
	return fatti

func _apri_log(n: int) -> void:
	apri_cassetto("")
	_logbook.visible = true
	_logbook.apri_numero(n)

## Carte citate dal Logbook: si sceglie dove metterle (di solito la busta "In attesa…").
func _carta_dal_logbook(nome: String) -> void:
	nome = nome.strip_edges().to_upper()
	if nave.s.is_empty():
		return
	var dest := ["Busta \"In attesa…\"", "Armeria", "Situazioni possibili", "Rimuovi dal gioco", "Lascia stare"]
	var pre := 0
	if nome.begins_with("E"):
		pre = 1
	elif nome.begins_with("S"):
		pre = 2
	var ordine := [dest[pre]] + dest.filter(func(x): return x != dest[pre])
	var j := await _scegli("CARTA %s" % _carta(nome), ordine, "Dove va questa carta? (segui l'istruzione del Logbook)")
	if j < 0:
		return
	match ordine[j]:
		"Busta \"In attesa…\"":
			nave.s["busta"].append(nome)
		"Armeria":
			nave.s["armeria"].append(nome)
		"Situazioni possibili":
			nave.s["situazioni_possibili"].append(nome)
			nave.s["situazioni_future"].erase(nome)
		"Rimuovi dal gioco":
			nave.s["busta"].erase(nome)
			nave.s["armeria"].erase(nome)
			nave.s["situazioni"].erase(nome)
			nave.s["situazioni_possibili"].erase(nome)
			nave.s["ricerca"].erase(nome)
			nave.s["produzione_pronti"].erase(nome)
	nave.diario("Logbook: %s → %s" % [nome, ordine[j]])
	_salva()
	aggiorna()

# ------------------------------------------------------------------ cassetto di consultazione

func apri_cassetto(tipo: String) -> void:
	_cassetto_tipo = tipo
	_cassetto_box.visible = tipo != ""
	if tipo != "":
		_logbook.visible = false
		_riempi_cassetto()

func _riempi_cassetto() -> void:
	for c in _cassetto.get_children():
		c.queue_free()
	if nave.s.is_empty():
		return
	var s := nave.s
	match _cassetto_tipo:
		"equipaggio":
			_cassetto_titolo.text = "EQUIPAGGIO"
			for r in Nave.REPARTI:
				_cassetto.add_child(Tema.etichetta("%s — dadi: %s" % [Dati.SEZIONI[r]["nome"].to_upper(), ", ".join(s["dadi"][r])], 13, Dati.SEZIONI[r]["colore"], true))
				for i in nave.membri(r):
					var m: Dictionary = s["equipaggio"][i]
					var st: String = {"disponibile": "disponibile", "riposo": "a riposo", "infermeria": "in infermeria (%s)" % nave.livello_infermeria(i), "morto": "morto", "squadra": "in missione"}.get(m["stato"], m["stato"])
					_testo("• %s · Grado %d · [i]%s[/i]" % [m["carta"], int(m["grado"]), st], 15, _cassetto)
		"progetti":
			_cassetto_titolo.text = "PROGETTI"
			_cassetto.add_child(Tema.etichetta("RICERCA (pag. 9)", 13, Tema.CIANO, true))
			for id in s["ricerca"]:
				var c := Carte.per_id(str(id))
				_testo("• %s — %s" % [_carta(str(id)), _bb(Carte.t(c.get("costo", "")))], 14, _cassetto)
			_cassetto.add_child(Tema.etichetta("PRONTI PER LA PRODUZIONE (pag. 13)", 13, Tema.CIANO, true))
			for id in s["produzione_pronti"]:
				_testo("• %s" % _carta(str(id)), 14, _cassetto)
			_cassetto.add_child(Tema.etichetta("CODE DI PRODUZIONE (pag. 14)", 13, Tema.CIANO, true))
			for q in int(s["code_attive"]):
				_testo("Coda %d: %s" % [q + 1, " → ".join((s["code"][q] as Array).map(func(x): return str(x) if x != null else "·"))], 14, _cassetto)
		"situazioni":
			_cassetto_titolo.text = "SITUAZIONI"
			for id in s["situazioni"]:
				var c := Carte.per_id(str(id))
				_testo("[b]%s[/b]\nEffetto: %s\nRisolta: %s" % [_carta(str(id)), _bb(Carte.t(c.get("effetto", ""))), _bb(Carte.t(c.get("risolta", "")))], 14, _cassetto)
			_testo("[color=#9fbbd6]Possibili ancora nel mazzo: %d[/color]" % s["situazioni_possibili"].size(), 13, _cassetto)
		"magazzino":
			_cassetto_titolo.text = "SCOPERTE E ARMERIA"
			_cassetto.add_child(Tema.etichetta("SCOPERTE RACCOLTE", 13, Tema.CIANO, true))
			for sc in s["scoperte"]:
				_testo("• %s %s%s" % [NOMI_SCOPERTE.get(sc.get("tipo", ""), sc.get("tipo", "")), Carte.titolo(Carte.per_file(str(sc.get("file", "")))), (" (" + str(sc["rarita"]) + ")") if str(sc.get("rarita", "")) not in ["", "common"] else ""], 14, _cassetto)
			_cassetto.add_child(Tema.etichetta("SCOPERTE ECCEZIONALI (pagg. 29-30)", 13, Tema.CIANO, true))
			_testo(", ".join(s["eccezionali"].keys()) if not s["eccezionali"].is_empty() else "nessuna", 14, _cassetto)
			_cassetto.add_child(Tema.etichetta("ARMERIA", 13, Tema.CIANO, true))
			for e in s["armeria"]:
				_testo("• %s" % _carta(str(e)), 14, _cassetto)
			_cassetto.add_child(Tema.etichetta("HANGAR", 13, Tema.CIANO, true))
			for l in s["lander"]:
				_testo("• %s%s" % [l["nome"], " (danneggiato)" if l.get("danneggiato", false) else ""], 14, _cassetto)
			for a in s["mod_lander"]:
				_testo("• Modifica %s" % _carta(str(a)), 14, _cassetto)
			if not s["busta"].is_empty():
				_cassetto.add_child(Tema.etichetta("BUSTA \"IN ATTESA…\"", 13, Tema.AMBRA, true))
				_testo(", ".join(s["busta"].map(func(x): return _carta(str(x)))), 14, _cassetto)
		"diario":
			_cassetto_titolo.text = "DIARIO DELLA NAVE"
			var d: Array = s.get("diario", [])
			_testo("\n".join(d.slice(max(0, d.size() - 100)).map(func(x): return "• " + str(x))), 14, _cassetto)

# ------------------------------------------------------------------ passi

func _mostra_passo() -> void:
	_svuota()
	if nave.s.is_empty():
		_passo_avvio()
		return
	match nave.passo():
		"ponte": _passo_ponte()
		"mappa": _passo_mappa()
		"strutture": _passo_strutture()
		"hangar": _passo_hangar()
		"lancio": _passo_lancio()
		"esplorazione": _passo_esplorazione()
		"partenza": _passo_partenza()
		"attracco": _passo_attracco()
		"scarico": _passo_scarico()
		"infermeria": _passo_infermeria()
		"memoriale": _passo_memoriale()
		"debriefing": _passo_debriefing()
		"salvataggio": _passo_salvataggio()

# --- inizio della campagna -------------------------------------------------------------

func _passo_avvio() -> void:
	_titolo("Inizio della Gestione della Nave")
	_testo("Il Ship Book viene preparato con le carte di partenza (Regolamento pag. 7): Obiettivo O01, Livello tecnologico 1, Morale Medio, Progetto di ricerca R04, Progetti di produzione C01, C02, C03, C06 e il Lander Space Ranger.\n\nOgni Reparto ha i suoi 5 dadi iniziali. Scegli come formare l'equipaggio:")
	var tut := ["AMIR ZAYNAB", "CHO JAE-YONG", "JOPPE ULRICH", "RIKU HASHIMURA"]
	var rep_tut := {"AMIR ZAYNAB": "scienza", "CHO JAE-YONG": "ingegneria", "JOPPE ULRICH": "ricognizione", "RIKU HASHIMURA": "sicurezza"}
	var r := _riga()
	r.add_child(Tema.pulsante_primario("DOPO IL TUTORIAL", func():
		# i quattro Membri del tutorial vanno a riposo, ogni Reparto sceglie 1 recluta fra 2 (Regolamento pag. 25)
		var eq := []
		for c in Carte.categoria("equipaggio"):
			var n := str(c.get("nome", "")).to_upper()
			if n in tut and str(c.get("lato", "fronte")) != "retro":
				var grado := 2 if _tutorial_promosso() else 1
				eq.append({"carta": c["nome"], "file": c["file"], "reparto": rep_tut[n], "grado": grado, "stato": "riposo"})
		nave.inizializza(eq)
		var ultima: Dictionary = (Campagna.dati.get("esplorazioni_concluse", [{}]) as Array).back() if not (Campagna.dati.get("esplorazioni_concluse", []) as Array).is_empty() else {}
		nave.s["pool"]["successi"] = int(ultima.get("successi", 0))
		for e in ultima.get("eccezionali", []):
			nave.s["eccezionali"][str(e)] = true
		for sc in ultima.get("scoperte", []):
			nave.s["scoperte"].append({"tipo": sc.get("tipo", ""), "file": sc.get("carta", ""), "rarita": str(Carte.per_file(str(sc.get("carta", ""))).get("campi", {}).get("rarita", ""))})
		await _reclute_iniziali(2, 1)
		nave.vai("ponte")
		_salva()
		aggiorna()
		_apri_log(750), 16))
	r.add_child(Tema.pulsante("INIZIO RAPIDO (3 reclute, 2 per Reparto)", func():
		nave.inizializza([])
		await _reclute_iniziali(3, 2)
		nave.vai("ponte")
		_salva()
		aggiorna(), 15))
	_testo("[color=#9fbbd6]Dopo il tutorial: Amir, Cho, Joppe e Riku vanno a riposo (promossi al Grado 2 se la carta Grado Superiore del tutorial è stata completata); i Successi rimasti e la Scoperta Eccezionale 1 passano alla nave. Poi il Logbook apre l'Annotazione 750.[/color]", 14)

func _tutorial_promosso() -> bool:
	var a: Array = Campagna.dati.get("esplorazioni_concluse", [])
	return not a.is_empty() and (a.back().get("grado_girato", false) or int(a.back().get("successi", 0)) >= 3)

## Ogni Reparto pesca n reclute a caso e ne sceglie k (la prima disponibile, le altre a riposo).
func _reclute_iniziali(n: int, k: int) -> void:
	for r in Nave.REPARTI:
		var pool: Array = nave.s["reclute"].duplicate()
		pool.shuffle()
		var mostra := pool.slice(0, n)
		for volta in k:
			var j := -1
			while j < 0:
				j = await _scegli("%s: SCEGLI UNA RECLUTA (%d/%d)" % [Dati.SEZIONI[r]["nome"].to_upper(), volta + 1, k], mostra.map(func(f): return _desc_recluta(str(f))), "", false)
			nave.recluta(str(mostra[j]), r, "disponibile")
			mostra.remove_at(j)

func _desc_recluta(f: String) -> String:
	var c := Carte.per_file(f)
	var cv = c.get("converti", {})
	var ab = c.get("abilita", {})
	return "%s — converte %s · %s (%s Cariche)" % [c.get("nome", "?"), Traduzioni.icona(str(cv.get("a", ""))) if cv is Dictionary else "-",
		str(ab.get("nome", "")) if ab is Dictionary else "", str(c.get("cariche", "?"))]

# --- Ponte di comando (pag. 2) -----------------------------------------------------------

func _passo_ponte() -> void:
	_titolo("Ponte di comando", 2)
	if not _scelta.get("fatto", false):
		var fatti := nave.installa_ponte()
		var pool := nave.genera_pool()
		_scelta["fatto"] = true
		_scelta["installate"] = fatti
		_scelta["da_risolvere"] = nave.dalla_busta(["S"])
		_salva()
	_sezione("1. Carte del Ponte installate")
	_testo("\n".join((_scelta["installate"] as Array).map(func(x): return "• " + str(x))) if not (_scelta["installate"] as Array).is_empty() else "[color=#9fbbd6]Nessuna carta nuova nella busta.[/color]", 16)
	_sezione("2. Segnalini Comando ed Energia")
	var ob := nave.carta_obiettivo()
	_testo("Obiettivo [b]%s[/b]: %s\nLivello tecnologico %d. %s" % [Carte.titolo(ob), _bb(Carte.t(ob.get("campi", {}).get("obiettivo", ob.get("testo", "")))), int(nave.s["tech"]),
		"[color=#ff5a6e]Segnalino Penalità: solo 1 Comando.[/color]" if nave.s.get("penalita", false) else ""], 16)
	var r := _riga()
	for p in [["comando", "Comando"], ["energia", "Energia"]]:
		var k: String = p[0]
		r.add_child(Tema.etichetta("%s %d" % [p[1], int(nave.s["pool"][k])], 17, Tema.TESTO, true))
		r.add_child(Tema.pulsante("−", func():
			nave.s["pool"][k] = max(0, int(nave.s["pool"][k]) - 1)
			_salva()
			aggiorna(), 13))
		r.add_child(Tema.pulsante("+", func():
			nave.s["pool"][k] = int(nave.s["pool"][k]) + 1
			_salva()
			aggiorna(), 13))
	_testo("[color=#9fbbd6]Il Morale Alto dà +1 Comando; controlla anche i potenziamenti del Ponte e correggi con − / +.[/color]", 13)
	_sezione("3. Situazioni in sospeso")
	var dr: Array = _scelta["da_risolvere"]
	if dr.is_empty():
		_testo("[color=#9fbbd6]Nessuna Situazione dalla scorsa Gestione.[/color]", 16)
	for id in dr.duplicate():
		var c := Carte.per_id(str(id))
		_testo("[b]%s[/b]: %s" % [_carta(str(id)), _bb(Carte.t(c.get("effetto", "")))], 16)
		var idd := str(id)
		_corpo.add_child(Tema.pulsante("RISOLVI L'EFFETTO DI %s" % idd, func():
			nave.s["situazioni"].append(idd)
			(_scelta["da_risolvere"] as Array).erase(idd)
			await applica(Carte.en(c.get("effetto", "")), Carte.t(c.get("effetto", "")), _carta(idd), idd), 14))
	_sezione("4. Nuove Situazioni")
	if not _scelta.get("pescate", false):
		_corpo.add_child(Tema.pulsante("RIVELA %d SITUAZIONI" % nave.n_situazioni(), func():
			_scelta["pescate"] = true
			nave.pesca_situazioni(nave.n_situazioni())
			_salva()
			aggiorna(), 15))
	else:
		for id in nave.s["situazioni"]:
			var c := Carte.per_id(str(id))
			_testo("[b]%s[/b]\nEffetto (alla prossima Gestione, se non risolta): %s\nQuando risolta: %s" % [_carta(str(id)), _bb(Carte.t(c.get("effetto", ""))), _bb(Carte.t(c.get("risolta", "")))], 15)
	_avanti("ALLA MAPPA STELLARE ▶", func():
		if not (_scelta["da_risolvere"] as Array).is_empty():
			avviso("Prima risolvi gli effetti delle Situazioni in sospeso")
			return false
		if not _scelta.get("pescate", false):
			nave.pesca_situazioni(nave.n_situazioni())
		return true)

# --- Mappa stellare (pag. 5) -------------------------------------------------------------

func _passo_mappa() -> void:
	_titolo("Mappa stellare", 5)
	var sis := Carte.sistema(str(nave.s["sistema"]))
	if sis.is_empty():
		_testo("[color=#ffb347]Mappa del sistema %s non trovata.[/color]" % nave.s["sistema"])
	else:
		_testo("[b]%s[/b] — %s" % [str(sis.get("nome", "")), _bb(Carte.t(sis.get("testo", "")))], 15)
	var scanner: Dictionary = nave.s["scanner"]
	if str(scanner.get("carta", "")) == "":
		_sezione("1. Vola verso un nuovo sistema")
		for rt in sis.get("rotte", []):
			var req := str(rt.get("richiede", ""))
			var ok_req: bool = req == "" or req in nave.s["ponte_viaggio"] or req in nave.s["ponte"]
			var en: int = int(rt.get("energia", 0)) if rt.get("energia") != null else 0
			var b := Tema.pulsante("→ %s · %d Energia%s%s" % [rt.get("verso", "?"), en, (" · richiede " + req) if req != "" else "", (" · Annotazione %d" % int(rt["log"])) if rt.get("log") != null else ""], func():
				if not nave.spendi("energia", en):
					avviso("Energia insufficiente")
					return
				nave.diario("Volo verso %s (%d Energia)" % [rt.get("verso", ""), en])
				nave.s["sistema"] = str(rt.get("verso", nave.s["sistema"]))
				if not nave.s["sistema"] in nave.s["sistemi_visitati"]:
					nave.s["sistemi_visitati"].append(nave.s["sistema"])
				_salva()
				aggiorna()
				if rt.get("log") != null:
					_apri_log(int(rt["log"])), 14)
			b.disabled = not ok_req or int(nave.s["pool"]["energia"]) < en
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_corpo.add_child(b)
		_sezione("2. Visita una destinazione")
		for d in sis.get("destinazioni", []):
			var en2: int = int(d.get("energia", 0)) if d.get("energia") != null else 0
			var at := str(d.get("atterraggio", ""))
			var lbl := "%s · %d Energia%s" % [d.get("nome", "?"), en2, (" · ATTERRAGGIO " + at) if at != "" else ""]
			var v := VBoxContainer.new()
			_corpo.add_child(v)
			var b2 := Tema.pulsante(lbl, func():
				if not nave.spendi("energia", en2):
					avviso("Energia insufficiente")
					return
				nave.diario("Visita: %s" % d.get("nome", ""))
				if at != "":
					nave.s["scanner"] = {"carta": at, "rivelate": 0, "destinazione": str(d.get("nome", ""))}
					_salva()
					aggiorna()
				else:
					await applica(Carte.en(d.get("testo", "")), Carte.t(d.get("testo", "")), str(d.get("nome", ""))), 14)
			b2.disabled = int(nave.s["pool"]["energia"]) < en2
			b2.alignment = HORIZONTAL_ALIGNMENT_LEFT
			v.add_child(b2)
			_testo("[color=#9fbbd6]%s[/color] %s" % [Carte.t(d.get("descrizione", "")), _bb(Carte.t(d.get("testo", "")))], 14, v)
		_avanti("ALLA DERIVA ▶", func():
			var j := await _scegli("NESSUN ATTERRAGGIO", ["Sì, la nave resta alla deriva"], "Senza una carta Atterraggio nello scanner: si abbassa il Morale, il segnalino Penalità va nella riserva del Comando e si passa al Punto di salvataggio (Ship Book, ALLA DERIVA).")
			if j != 0:
				return false
			nave.morale_giu()
			nave.s["penalita"] = true
			nave.vai("salvataggio")
			_salva()
			aggiorna()
			return false)
		return
	# scansione del pianeta
	var lc := Carte.per_id(str(scanner["carta"]))
	_sezione("3. Scansione del pianeta: %s" % Carte.titolo(lc))
	var parti: Array = lc.get("campi", {}).get("parti", [])
	var riv := int(scanner.get("rivelate", 0))
	var testo_retro := _retro_atterraggio(str(scanner["carta"]))
	var sezioni := _parti_briefing(testo_retro)
	for k in parti.size():
		var costo := int(parti[k].get("costo_energia", 0))
		if k < riv:
			_testo("[color=#5be39b]Parte %d:[/color] %s" % [k + 1, _bb(sezioni[k]) if k < sezioni.size() else "(vedi la carta)"], 15)
		elif k == riv:
			var kk: int = k
			var r := _riga()
			var scouts := int(_scelta.get("scout", 0))
			r.add_child(Tema.pulsante("RIVELA LA PARTE %d (%d Energia%s)" % [k + 1, max(0, costo - scouts), (", %d in ricognizione" % scouts) if scouts > 0 else ""], func():
				if not nave.spendi("energia", max(0, costo - scouts)):
					avviso("Energia insufficiente")
					return
				nave.s["scanner"]["rivelate"] = kk + 1
				_scelta["scout"] = 0
				_salva()
				aggiorna(), 14))
			r.add_child(Tema.pulsante("ASSEGNA IN RICOGNIZIONE (−1)", func():
				var i := await _assegna("missione di ricognizione")
				if i >= 0:
					_scelta["scout"] = int(_scelta.get("scout", 0)) + 1
					_salva()
					aggiorna(), 13))
	_avanti("ALLE STRUTTURE DELLA NAVE ▶")

func _retro_atterraggio(id: String) -> String:
	for f in Carte.db.get("per_id", {}).get(id.to_upper(), []):
		var c := Carte.per_file(str(f))
		if str(c.get("lato", "")) == "retro":
			return Carte.t(c.get("testo", ""))
	return ""

## Divide il retro della carta Atterraggio nelle parti rivelate dallo scanner (senza il numero del briefing).
func _parti_briefing(t: String) -> Array:
	var rx := RegEx.create_from_string("(ATTERRAGGIO|PERICOL[IO]|BIOMI|PROVE FREQUENTI|MINACCE|LANDING|DANGERS?|BIOMES|FREQUENT CHECKS|THREATS)\\s*:")
	var pos := []
	for m in rx.search_all(t):
		pos.append(m.get_start())
	var out := []
	for k in pos.size():
		out.append(t.substr(pos[k], (pos[k + 1] if k + 1 < pos.size() else t.length()) - pos[k]).strip_edges())
	return out

func _briefing(id: String) -> int:
	var m := RegEx.create_from_string("\\)\\s*:\\s*(?:Annotazione\\s*)?(\\d+)").search(_retro_atterraggio(id))
	if m:
		return int(m.get_string(1))
	for f in Carte.db.get("per_id", {}).get(id.to_upper(), []):
		var c := Carte.per_file(str(f))
		var m2 := RegEx.create_from_string("(\\d{2,4})").search(Carte.en(c.get("testo", "")))
		if str(c.get("lato", "")) == "retro" and m2:
			return int(m2.get_string(1))
	return 0

# --- Strutture della nave (pag. 6) -------------------------------------------------------

func _passo_strutture() -> void:
	match _sotto:
		"ricerca": return _struttura_ricerca()
		"produzione": return _struttura_produzione()
		"caserma": return _struttura_caserma()
		"situazioni": return _struttura_situazioni()
	_titolo("Strutture della nave", 6)
	_testo("Spendi 1 segnalino Comando per attivare una struttura. Hai [b]%d[/b] Comando." % int(nave.s["pool"]["comando"]))
	var usate: Array = nave.s.get("usate_strutture", [])
	for f in [["ricerca", "LABORATORIO DI RICERCA", 8, "Completa progetti di ricerca pagando Scoperte"],
			["produzione", "COMPLESSO PRODUTTIVO", 12, "Fai avanzare le code e avvia nuovi progetti"],
			["caserma", "CASERMA", 16, "Recluta nuovi Membri, addestra, trasferisci"],
			["situazioni", "SALA SITUAZIONI", 17, "Risolvi le Situazioni sopra il Ship Book"]]:
		var k: String = f[0]
		var h := HBoxContainer.new()
		_corpo.add_child(h)
		var b := Tema.pulsante_primario("%s (pag. %d)" % [f[1], f[2]], func():
			if not nave.spendi("comando", 1):
				avviso("Non hai più segnalini Comando")
				return
			nave.s.get_or_add("usate_strutture", []).append(k)
			nave.diario("Attivata la struttura: %s" % f[1])
			_sotto = k
			_scelta = {}
			_salva()
			aggiorna(), 16)
		b.custom_minimum_size = Vector2(420, 0)
		b.disabled = int(nave.s["pool"]["comando"]) <= 0
		h.add_child(b)
		h.add_child(Tema.etichetta("  %s%s" % [f[3], ("  · usata %d volte" % usate.count(k)) if usate.count(k) > 0 else ""], 14, Tema.TESTO_2))
	_testo("[color=#9fbbd6]Pulizia (passo 2): i segnalini Comando ed Energia rimasti si scartano, i Successi restano, le Situazioni non risolte vanno nella busta \"In attesa…\" e il loro effetto si applica alla prossima Gestione.[/color]", 14)
	_avanti("ALL'HANGAR ▶", func():
		nave.s["pool"]["comando"] = 0
		nave.s["pool"]["energia"] = 0
		for id in nave.s["situazioni"]:
			nave.s["busta"].append(id)
		nave.s["situazioni"] = []
		nave.s["usate_strutture"] = []
		nave.s["penalita"] = false
		return true)

func _torna_strutture() -> void:
	_corpo.add_child(HSeparator.new())
	_corpo.add_child(Tema.pulsante_primario("◀ TORNA ALLE STRUTTURE", func():
		_sotto = ""
		_scelta = {}
		_salva()
		aggiorna(), 16))

func _struttura_ricerca() -> void:
	_titolo("Laboratorio di ricerca", 8)
	if not _scelta.get("installati", false):
		_scelta["installati"] = true
		for id in nave.dalla_busta(["R"]):
			if nave.s["ricerca"].size() < 9:
				nave.s["ricerca"].append(id)
			else:
				nave.s["busta"].append(id)
		_salva()
	var completati: Array = _scelta.get("completati", [])
	var chiave := str(_scelta.get("parola", ""))
	_testo("Completa [b]un[/b] progetto pagando il suo costo in Scoperte raccolte; poi, nella stessa attivazione, puoi completare quelli con la stessa parola chiave. Con un'assegnazione (icone di conversione) puoi completarne altri.", 15)
	for id in nave.s["ricerca"].duplicate():
		var c := Carte.per_id(str(id))
		var costo: Array = c.get("costo_scoperte", []) if c.get("costo_scoperte") is Array else []
		var pagabile: bool = costo.is_empty() or not nave.paga_scoperte(costo).is_empty()
		var pk := str(c.get("parola_chiave", ""))
		var v := VBoxContainer.new()
		_corpo.add_child(v)
		_testo("[b]%s[/b] [color=#9fbbd6](%s)[/color] — costo: %s" % [_carta(str(id)), pk, _bb(Carte.t(c.get("costo", "")))], 16, v)
		var r := _riga(v)
		var idd := str(id)
		var puo: bool = pagabile and (completati.is_empty() or (pk != "" and pk == chiave))
		var b := Tema.pulsante_primario("COMPLETA", func():
			if not nave.completa_ricerca(idd):
				avviso("Scoperte insufficienti")
				return
			(_scelta.get_or_add("completati", []) as Array).append(idd)
			if chiave == "":
				_scelta["parola"] = pk
			await applica_retro(idd), 13)
		b.disabled = not puo
		r.add_child(b)
		r.add_child(Tema.pulsante("POTENZIA CON UN'ASSEGNAZIONE", func():
			if not pagabile:
				avviso("Scoperte insufficienti")
				return
			var i := await _assegna("lavoro di laboratorio")
			if i < 0:
				return
			if nave.completa_ricerca(idd):
				await applica_retro(idd), 12))
		r.add_child(Tema.pulsante("VEDI", func(): _mostra_carta(idd), 12))
	if nave.s["ricerca"].is_empty():
		_testo("[color=#9fbbd6]Nessun progetto di ricerca sulla pagina 9.[/color]")
	_testo("[color=#9fbbd6]Le icone degli slot della pagina 9 decidono quali Membri possono potenziare: scegli il Membro adatto.[/color]", 13)
	_torna_strutture()

func _struttura_produzione() -> void:
	_titolo("Complesso produttivo", 12)
	if not _scelta.get("avanzati", false):
		_scelta["avanzati"] = true
		for id in nave.dalla_busta(["C"]):
			nave.s["produzione_pronti"].append(id)
		for id in nave.dalla_busta(["F"]):
			nave.s["potenziamenti"].append(id)
		_scelta["finiti"] = nave.avanza_produzione()
		_salva()
	if not (_scelta["finiti"] as Array).is_empty():
		_sezione("Progetti completati")
		for id in (_scelta["finiti"] as Array).duplicate():
			var idd := str(id)
			_corpo.add_child(Tema.pulsante_primario("GIRA %s" % _carta(idd), func():
				(_scelta["finiti"] as Array).erase(idd)
				await applica_retro(idd), 14))
	_sezione("Code di produzione (pag. 14)")
	for q in int(nave.s["code_attive"]):
		var r := _riga()
		r.add_child(Tema.etichetta("Coda %d:" % (q + 1), 15, Tema.TESTO, true))
		for k in 3:
			var x = nave.s["code"][q][k]
			var qq: int = q
			var kk: int = k
			if x == null:
				r.add_child(Tema.etichetta("[stadio %d: libero]" % (k + 1), 14, Tema.TESTO_2))
			else:
				var c := Carte.per_id(str(x))
				var icone: Array = c.get("icone_potenziamento", [])
				r.add_child(Tema.pulsante("stadio %d: %s · POTENZIA (%s)" % [k + 1, _carta(str(x)), " / ".join(icone.map(func(i): return Traduzioni.icona(str(i))))], func():
					var i := await _assegna("catena di montaggio", icone)
					if i < 0:
						return
					var fin := nave.potenzia_progetto(qq, kk)
					_salva()
					aggiorna()
					if fin != "":
						await applica_retro(fin), 12))
	_sezione("Pronti per la produzione (pag. 13)")
	for id in nave.s["produzione_pronti"].duplicate():
		var c := Carte.per_id(str(id))
		var r := _riga()
		var idd := str(id)
		r.add_child(Tema.etichetta("%s — stadio iniziale %d" % [_carta(idd), int(c.get("stadio_iniziale", 1))], 15))
		for q in int(nave.s["code_attive"]):
			var qq: int = q
			r.add_child(Tema.pulsante("AVVIA IN CODA %d" % (q + 1), func():
				if not nave.avvia_progetto(idd, qq):
					avviso("Nessuno stadio libero in quella coda")
				_salva()
				aggiorna(), 12))
		r.add_child(Tema.pulsante("VEDI", func(): _mostra_carta(idd), 12))
	var r2 := _riga()
	r2.add_child(Tema.pulsante("SBLOCCA LA CODA 2" if int(nave.s["code_attive"]) < 2 else "CODA 2 ATTIVA", func():
		nave.s["code_attive"] = 2
		_salva()
		aggiorna(), 12))
	_testo("[color=#9fbbd6]All'inizio è disponibile solo la coda 1 (la 2 si sblocca con un potenziamento).[/color]", 13)
	_torna_strutture()

func _struttura_caserma() -> void:
	_titolo("Caserma", 16)
	_sezione("3. Nuove reclute")
	if not _scelta.has("reclute"):
		_scelta["reclute"] = nave.pesca_reclute()
		_scelta["reparti_fatti"] = []
	var rec: Array = _scelta["reclute"]
	var fatti: Array = _scelta["reparti_fatti"]
	_testo("Reclute rivelate: %d (Morale %s). Ogni Reparto ne sceglie una (Grado 1, disponibile)." % [rec.size(), Nave.NOMI_MORALE[nave.s["morale"]]], 15)
	for r in Nave.REPARTI:
		if r in fatti:
			continue
		var rr: String = r
		_corpo.add_child(Tema.pulsante("%s: SCEGLI UNA RECLUTA" % Dati.SEZIONI[r]["nome"].to_upper(), func():
			if rec.is_empty():
				return
			var j := await _scegli(Dati.SEZIONI[rr]["nome"].to_upper(), rec.map(func(f): return _desc_recluta(str(f))))
			if j < 0:
				return
			nave.recluta(str(rec[j]), rr)
			rec.remove_at(j)
			fatti.append(rr)
			_salva()
			aggiorna(), 14))
	_sezione("2. Addestra le reclute")
	_testo("Un Membro disponibile di Grado 3 può promuovere un Membro di Grado 1 dello stesso Reparto al Grado 2 (entrambi vanno a riposo).", 14)
	_corpo.add_child(Tema.pulsante("ADDESTRA", func():
		var istr := nave.membri("", "disponibile").filter(func(i): return int(nave.s["equipaggio"][i]["grado"]) == 3 and nave.assegnabile(i))
		if istr.is_empty():
			avviso("Nessun Membro di Grado 3 assegnabile")
			return
		var j := await _scegli("ISTRUTTORE", istr.map(func(i): return _nome_membro(i)))
		if j < 0:
			return
		var rep: String = nave.s["equipaggio"][istr[j]]["reparto"]
		var all := nave.membri(rep).filter(func(i): return int(nave.s["equipaggio"][i]["grado"]) == 1 and nave.s["equipaggio"][i]["stato"] in ["disponibile", "riposo"])
		if all.is_empty():
			avviso("Nessun Membro di Grado 1 in quel Reparto")
			return
		var k := await _scegli("CHI PROMUOVI?", all.map(func(i): return _nome_membro(i)))
		if k < 0:
			return
		nave.assegna(istr[j], "istruttore")
		nave.s["equipaggio"][all[k]]["grado"] = 2
		nave.s["equipaggio"][all[k]]["stato"] = "riposo"
		nave.diario("%s promosso al Grado 2" % nave.s["equipaggio"][all[k]]["carta"])
		_salva()
		aggiorna(), 13))
	_sezione("1. Trasferisci o congeda")
	_corpo.add_child(Tema.pulsante("CONGEDA UN MEMBRO", func():
		var c := nave.membri().filter(func(i): return nave.s["equipaggio"][i]["stato"] in ["disponibile", "riposo"])
		var j := await _scegli("CONGEDA", c.map(func(i): return _nome_membro(i)), "Il Membro torna fra le Reclute.")
		if j < 0:
			return
		var m: Dictionary = nave.s["equipaggio"][c[j]]
		m["stato"] = "congedato"
		nave.s["reclute"].append(m["file"])
		nave.diario("%s congedato" % m["carta"])
		_salva()
		aggiorna(), 13))
	_corpo.add_child(Tema.pulsante("TRASFERISCI A UN ALTRO REPARTO", func():
		var c := nave.membri().filter(func(i): return nave.s["equipaggio"][i]["stato"] in ["disponibile", "riposo"])
		var j := await _scegli("TRASFERISCI", c.map(func(i): return _nome_membro(i)), "Un Membro di Grado 2 o 3 perde un Grado.")
		if j < 0:
			return
		var k := await _scegli("VERSO QUALE REPARTO?", Nave.REPARTI.map(func(r): return Dati.SEZIONI[r]["nome"]))
		if k < 0:
			return
		var m: Dictionary = nave.s["equipaggio"][c[j]]
		m["reparto"] = Nave.REPARTI[k]
		m["grado"] = max(1, int(m["grado"]) - 1) if int(m["grado"]) > 1 else 1
		nave.diario("%s trasferito a %s" % [m["carta"], Nave.REPARTI[k]])
		_salva()
		aggiorna(), 13))
	_torna_strutture()

func _struttura_situazioni() -> void:
	_titolo("Sala situazioni", 17)
	var risolte := int(_scelta.get("risolte", 0))
	if nave.s["situazioni"].is_empty():
		_testo("[color=#9fbbd6]Nessuna Situazione sopra il Ship Book.[/color]")
	for id in nave.s["situazioni"].duplicate():
		var c := Carte.per_id(str(id))
		var icone: Array = c.get("icone_risolta", []) if c.get("icone_risolta") is Array else []
		var v := VBoxContainer.new()
		_corpo.add_child(v)
		_testo("[b]%s[/b]\nQuando risolta: %s\n[color=#9fbbd6]Icone: %s[/color]" % [_carta(str(id)), _bb(Carte.t(c.get("risolta", ""))),
			_bb(" ".join(icone.map(func(x): return "[%s]" % x))) if not icone.is_empty() else "nessuna (non si può risolvere con un supervisore)"], 15, v)
		var idd := str(id)
		var r := _riga(v)
		var b := Tema.pulsante_primario("RISOLVI (gratis)", func():
			_scelta["risolte"] = risolte + 1
			nave.s["situazioni"].erase(idd)
			nave.s["situazioni"].append(idd)   # resta finché il testo non dice dove va
			await applica(Carte.en(c.get("risolta", "")), Carte.t(c.get("risolta", "")), _carta(idd), idd), 13)
		b.disabled = risolte > 0
		r.add_child(b)
		var b2 := Tema.pulsante("RISOLVI CON UN SUPERVISORE", func():
			var i := await _assegna("supervisore", icone)
			if i < 0:
				return
			await applica(Carte.en(c.get("risolta", "")), Carte.t(c.get("risolta", "")), _carta(idd), idd), 12)
		b2.disabled = icone.is_empty()
		r.add_child(b2)
		r.add_child(Tema.pulsante("VEDI", func(): _mostra_carta(idd), 12))
	_testo("[color=#9fbbd6]Con il supervisore la Situazione si risolve se l'icona di conversione del Membro è fra quelle accanto a QUANDO RISOLTA (con \"+\" servono più Membri: assegnali uno alla volta).[/color]", 13)
	_torna_strutture()

# --- Hangar (pag. 18) --------------------------------------------------------------------

func _passo_hangar() -> void:
	_titolo("Hangar", 18)
	if not _scelta.get("installati", false):
		_scelta["installati"] = true
		for id in nave.dalla_busta(["A"]):
			nave.s["mod_lander"].append(id)
		_salva()
	_sezione("Scegli il Lander")
	var plance := Carte.categoria("componenti").filter(func(x): return str(x.get("tipo", "")) == "lander_board")
	for l in nave.s["lander"]:
		var nome := str(l["nome"])
		var pl: Array = plance.filter(func(x): return str(x.get("campi", {}).get("nome", "")).to_upper() == nome.to_upper())
		var cm: Dictionary = pl[0].get("campi", {}) if not pl.is_empty() else {}
		var r := _riga()
		var b := Tema.pulsante_primario(("✔ " if nave.s["lander_scelto"] == nome else "") + nome, func():
			nave.s["lander_scelto"] = nome
			nave.s["mod_montate"] = []
			_salva()
			aggiorna(), 14)
		b.disabled = l.get("danneggiato", false)
		r.add_child(b)
		r.add_child(Tema.etichetta("Corazza %s · Sensori %s · Agilità %s · Provviste %s · Scoperte %s · Carico %s+%s · Modifiche %s strutturali, %s utilità" % [
			str(cm.get("corazza", "?")), str(cm.get("sensori", "?")), str(cm.get("agilita", "?")), str(cm.get("provviste", {}).get("base", "?")) if cm.get("provviste") is Dictionary else "?",
			str(cm.get("scoperte_max", "?")), str(cm.get("carico", {}).get("personali", "?")), str(cm.get("carico", {}).get("missione", "?")),
			str(cm.get("modifiche", {}).get("structural", 0)), str(cm.get("modifiche", {}).get("utility", 0))], 13, Tema.TESTO_2))
	if not nave.s["mod_lander"].is_empty():
		_sezione("Modifiche del Lander (pag. 21)")
		for a in nave.s["mod_lander"]:
			var aa := str(a)
			var c := Carte.per_id(aa)
			var montata: bool = aa in nave.s["mod_montate"]
			var cb := CheckBox.new()
			cb.text = "%s (%s): %s" % [_carta(aa), str(c.get("campi", {}).get("modifica", "")), _pulito(Carte.t(c.get("testo", "")))]
			cb.button_pressed = montata
			cb.toggled.connect(func(on):
				if on:
					nave.s["mod_montate"].append(aa)
				else:
					nave.s["mod_montate"].erase(aa)
				_salva())
			_corpo.add_child(cb)
		_testo("[color=#9fbbd6]Al massimo una modifica per slot, solo nel tipo di slot giusto (strutturale o utilità).[/color]", 13)
	var lc := str(nave.s["scanner"].get("carta", ""))
	if lc != "":
		_testo("Destinazione: [b]%s[/b] (carta %s). Rivela le parti della carta per scegliere il Lander adatto." % [Carte.titolo(Carte.per_id(lc)), lc], 15)
	_avanti("ALLA PROCEDURA DI LANCIO ▶")

# --- Procedura di lancio (pag. 23) -------------------------------------------------------

func _passo_lancio() -> void:
	_titolo("Procedura di lancio", 23)
	var lc := str(nave.s["scanner"].get("carta", ""))
	if lc == "":
		_testo("[color=#ffb347]Nessuna carta Atterraggio nello scanner: torna alla Mappa stellare.[/color]")
	_sezione("3. Squadra di Sbarco")
	_testo("Scegli i Membri disponibili (in solitario almeno 2 di Reparti diversi). I dadi e i mazzi Reparto si preparano da soli.", 15)
	var squadra: Array = _scelta.get_or_add("squadra", [])
	for i in nave.membri("", "disponibile"):
		var ii: int = i
		var cb := CheckBox.new()
		cb.text = _nome_membro(i)
		cb.button_pressed = i in squadra
		cb.toggled.connect(func(on):
			if on:
				if not ii in squadra:
					squadra.append(ii)
			else:
				squadra.erase(ii))
		_corpo.add_child(cb)
	_sezione("4. Carica il Lander")
	var arm: Array = nave.s["armeria"]
	if arm.is_empty():
		_testo("[color=#9fbbd6]L'Armeria è vuota.[/color]", 14)
	var equip: Array = _scelta.get_or_add("equip", [])
	for e in arm:
		var ee := str(e)
		var c := Carte.per_id(ee)
		var cb := CheckBox.new()
		cb.text = "%s · %s" % [_carta(ee), {"smallEquipment": "piccola (1 per Membro)", "personalEquipment": "personale", "missionEquipment": "di missione", "missionEquipmentUpgrades": "potenziamento"}.get(str(c.get("tipo", "")), str(c.get("tipo", "")))]
		cb.button_pressed = ee in equip
		cb.toggled.connect(func(on):
			if on:
				equip.append(ee)
			else:
				equip.erase(ee))
		_corpo.add_child(cb)
	_sezione("5. Allacciate le cinture!")
	var br := _briefing(lc) if lc != "" else 0
	var r := _riga()
	if br > 0:
		r.add_child(Tema.pulsante("LEGGI IL BRIEFING (Annotazione %d)" % br, func(): _apri_log(br), 14))
	r.add_child(Tema.pulsante_primario("ATTERRA ▶", _atterra, 17))
	_testo("[color=#9fbbd6]Il briefing descrive l'atterraggio; poi si apre la preparazione dell'esplorazione con squadra, Lander e pianeta già impostati.[/color]", 13)

func _atterra() -> void:
	var squadra: Array = _scelta.get("squadra", [])
	var reparti := {}
	for i in squadra:
		reparti[nave.s["equipaggio"][i]["reparto"]] = true
	if squadra.size() < 2 or reparti.size() < 2:
		avviso("Servono almeno 2 Membri di Reparti diversi")
		return
	var lc := str(nave.s["scanner"].get("carta", ""))
	var pagina := Carte.pianeta_per_nome(str(Carte.per_id(lc).get("campi", {}).get("pianeta", "")))
	var membri := []
	for i in squadra:
		var m: Dictionary = nave.s["equipaggio"][i]
		var c := Carte.per_file(str(m["file"]))
		membri.append({"nave": i, "carta": m["carta"], "file": m["file"], "reparto": m["reparto"], "grado": int(m["grado"]),
			"cariche": int(c.get("cariche", 0)), "dadi": _dadi_squadra(m), "conv": c.get("converti", {})})
		m["stato"] = "squadra"
	nave.s["squadra"] = squadra.duplicate()
	nave.s["equip_caricato"] = (_scelta.get("equip", []) as Array).duplicate()
	nave.vai("esplorazione")
	_salva()
	esplora.emit({"pagina": pagina, "membri": membri, "lander": nave.s["lander_scelto"], "equip": nave.s["equip_caricato"], "carta": lc,
		"briefing": _briefing(lc), "mod": (nave.s.get("mod_montate", []) as Array).duplicate()})

## Dadi del Reparto da mettere sulla plancia, rispettando la capienza per colore al Grado del Membro.
func _dadi_squadra(m: Dictionary) -> Array:
	var tutti: Array = (nave.s["dadi"][m["reparto"]] as Array).duplicate()
	var plancia := Carte.categoria("componenti").filter(func(x): return str(x.get("tipo", "")) == "crew_board" and str(x.get("campi", {}).get("reparto", "")) == Nave.REP_EN[m["reparto"]])
	if plancia.is_empty():
		return tutti
	var cap := {}
	for col in plancia[0].get("campi", {}).get("colonne_dadi", []):
		cap[str(col.get("colore", ""))] = int(col.get("dadi_per_grado", {}).get(str(int(m["grado"])), 99))
	var out := []
	var usati := {}
	for t in tutti:
		var col := str(Prova.defs()["reparto"].get(t, {}).get("colore", ""))
		if int(usati.get(col, 0)) < int(cap.get(col, 99)):
			out.append(t)
			usati[col] = int(usati.get(col, 0)) + 1
	return out

func _passo_esplorazione() -> void:
	_titolo("Esplorazione planetaria", 24)
	_testo("La Squadra di Sbarco è sul pianeta. Al termine dell'esplorazione la Gestione della Nave riprende da \"Lasciare il pianeta\".")
	var r := _riga()
	r.add_child(Tema.pulsante_primario("VAI ALL'ESPLORAZIONE", func(): esplora.emit({}), 16))
	r.add_child(Tema.pulsante("L'ESPLORAZIONE È FINITA ▶", func():
		nave.vai("partenza")
		_salva()
		aggiorna(), 14))

# --- Rientro (pagg. 25-28) ---------------------------------------------------------------

func _ultima_esplorazione() -> Dictionary:
	var a: Array = Campagna.dati.get("esplorazioni_concluse", [])
	return a.back() if not a.is_empty() else {}

func _passo_partenza() -> void:
	_titolo("Lasciare il pianeta", 25)
	var e := _ultima_esplorazione()
	if e.is_empty():
		_testo("[color=#ffb347]Nessuna esplorazione conclusa registrata.[/color]")
	else:
		_testo("Esplorazione di [b]%s[/b] conclusa (%s). Successi: %d · Scoperte: %d · Eccezionali: %s" % [str(Carte.pianeta(str(e.get("pagina", ""))).get("pianeta", "")),
			{"decollo": "decollo", "evac": "evacuazione d'emergenza", "fine": "fine"}.get(str(e.get("finita", "")), str(e.get("finita", ""))), int(e.get("successi", 0)),
			(e.get("scoperte", []) as Array).size(), ", ".join((e.get("eccezionali", []) as Array).map(func(x): return str(x))) if not (e.get("eccezionali", []) as Array).is_empty() else "nessuna"], 16)
		for m in e.get("equipaggio", []):
			_testo("• %s: %s" % [m.get("carta", ""), "morto" if m.get("morto", false) else ("%d Ferite" % (m.get("ferite", []) as Array).size() if not (m.get("ferite", []) as Array).is_empty() else "illeso")], 15)
	var cb := CheckBox.new()
	cb.text = "La carta Grado Superiore è stata completata (girata) durante l'esplorazione"
	cb.button_pressed = bool(e.get("grado_girato", false))
	cb.toggled.connect(func(on): e["grado_girato"] = on)
	_corpo.add_child(cb)
	_testo("[color=#9fbbd6]Pulizia dei componenti (PDI, Minacce, Condizioni, segnalini, attrezzatura all'Armeria): fatta.[/color]", 14)
	_avanti("ALL'ATTRACCO ▶", func():
		for x in nave.s.get("equip_caricato", []):
			pass   # l'attrezzatura resta nell'Armeria
		return true)

func _passo_attracco() -> void:
	_titolo("Attracco", 26)
	var e := _ultima_esplorazione()
	var missioni: Array = e.get("missioni_rimaste", [])
	_sezione("1. Missione fallita?")
	var cb := CheckBox.new()
	cb.text = "C'è ancora una carta Missione sulla plancia (o il segnalino Missione fallita): si abbassa il Morale"
	cb.button_pressed = not missioni.is_empty()
	_corpo.add_child(cb)
	_sezione("2. Scoperte in eccesso")
	var lander := str(nave.s.get("lander_scelto", ""))
	var plance := Carte.categoria("componenti").filter(func(x): return str(x.get("tipo", "")) == "lander_board" and str(x.get("campi", {}).get("nome", "")).to_upper() == lander.to_upper())
	var lim := int(plance[0].get("campi", {}).get("scoperte_max", 5)) if not plance.is_empty() else 5
	var sc: Array = e.get("scoperte", [])
	var ecc: Array = e.get("eccezionali", [])
	_testo("Il Lander %s porta al massimo %d Scoperte (comprese le Eccezionali, che non si scartano). Ne hai %d." % [lander, lim, sc.size() + ecc.size()], 15)
	_sezione("3. Equipaggio disponibile")
	_testo("I Membri a riposo tornano disponibili.", 15)
	_avanti("ALLO SCARICO ▶", func():
		if cb.button_pressed:
			nave.morale_giu()
			nave.diario("Missione fallita: Morale giù")
		var tenere: int = max(0, lim - ecc.size())
		if sc.size() > tenere:
			e["scoperte"] = sc.slice(0, tenere)
			nave.diario("Scartate %d Scoperte in eccesso" % (sc.size() - tenere))
		for i in nave.membri("", "riposo"):
			nave.s["equipaggio"][i]["stato"] = "disponibile"
		return true)

func _passo_scarico() -> void:
	_titolo("Scarico", 28)
	var e := _ultima_esplorazione()
	_sezione("1. Scoperte Eccezionali")
	for n in e.get("eccezionali", []):
		_testo("• Scoperta Eccezionale %s → pagine 29-30 (applica il suo effetto \"quando scaricata\")" % str(n), 15)
	_sezione("2. Altre Scoperte → Scoperte raccolte")
	for s in e.get("scoperte", []):
		var c := Carte.per_file(str(s.get("carta", "")))
		var q = c.get("campi", {}).get("scaricata", c.get("campi", {}).get("quando_scaricata", ""))
		_testo("• %s %s%s" % [NOMI_SCOPERTE.get(s.get("tipo", ""), s.get("tipo", "")), Carte.titolo(c), (" — quando scaricata: " + _bb(Carte.t(q))) if q is Dictionary else ""], 15)
	_sezione("4. Riponi il Lander")
	_testo("Le modifiche montate tornano nella busta \"In attesa…\" e si reinstallano all'Hangar.", 15)
	_avanti("ALL'INFERMERIA ▶", func():
		if not e.get("scaricata", false):
			e["scaricata"] = true
			for n in e.get("eccezionali", []):
				nave.s["eccezionali"][str(n)] = true
			for s in e.get("scoperte", []):
				nave.s["scoperte"].append({"tipo": s.get("tipo", ""), "file": s.get("carta", ""), "rarita": str(Carte.per_file(str(s.get("carta", ""))).get("campi", {}).get("rarita", ""))})
			for a in nave.s.get("mod_montate", []):
				nave.s["mod_lander"].erase(a)
				nave.s["busta"].append(a)
			nave.s["mod_montate"] = []
			nave.s["pool"]["successi"] = int(nave.s["pool"]["successi"]) + int(e.get("successi", 0))
		return true)

func _passo_infermeria() -> void:
	_titolo("Infermeria", 32)
	var e := _ultima_esplorazione()
	if not _scelta.get("fatto", false):
		_scelta["fatto"] = true
		for id in nave.dalla_busta(["F"]):
			nave.s["potenziamenti"].append(id)
		_salva()
	_sezione("3. Recupero")
	var ric := nave.in_infermeria()
	if ric.is_empty():
		_testo("[color=#9fbbd6]Nessuno in infermeria dalla volta scorsa.[/color]", 15)
	else:
		for i in ric:
			_testo("• %s (%s)" % [nave.s["equipaggio"][i]["carta"], nave.livello_infermeria(i)], 15)
		if not _scelta.get("recupero", false):
			var r := _riga()
			r.add_child(Tema.pulsante("ASSEGNA UN TERAPISTA", func():
				var t := await _assegna("terapista")
				if t < 0:
					return
				var j := await _scegli("CHI CURA?", ric.map(func(x): return str(nave.s["equipaggio"][x]["carta"])), "", false)
				(_scelta.get_or_add("terapie", []) as Array).append(ric[j])
				_salva(), 13))
			r.add_child(Tema.pulsante_primario("RECUPERO", func():
				_scelta["recupero"] = true
				var g := nave.recupero(_scelta.get("terapie", []))
				if not g.is_empty():
					avviso("Guariti: " + ", ".join(g.map(func(x): return str(nave.s["equipaggio"][x]["carta"]))))
				_salva()
				aggiorna(), 14))
	_sezione("4. I feriti vanno in infermeria · 2. gli illesi a riposo")
	for m in e.get("equipaggio", []):
		var n := (m.get("ferite", []) as Array).size()
		_testo("• %s: %s" % [m.get("carta", ""), "morto" if m.get("morto", false) else ("%d Ferite → %s" % [n, {1: "lievi", 2: "moderate", 3: "critiche"}.get(clampi(n, 1, 3), "")] if n > 0 else "illeso → a riposo")], 15)
	_sezione("5. Prove di sopravvivenza")
	_testo("Chi è nelle caselle delle Ferite critiche tira 3 dadi Ferita: muore con un [img height=20]%s[/img] e un [img height=20]%s[/img], oppure con due [img height=20]%s[/img]." % [Dati.icona("heavyDamage"), Dati.icona("damage"), Dati.icona("heavyDamage")], 15)
	_avanti("AL MURO DELLA MEMORIA ▶", func():
		if e.get("infermeria_fatta", false):
			return true
		e["infermeria_fatta"] = true
		if not _scelta.get("recupero", false):
			nave.recupero(_scelta.get("terapie", []))
		var esiti := []
		for m in e.get("equipaggio", []):
			var i := int(m.get("nave", -1))
			if i < 0 or i >= nave.s["equipaggio"].size():
				continue
			if m.get("morto", false):
				nave.muori(i)
				continue
			var n := (m.get("ferite", []) as Array).size()
			if n == 0:
				nave.s["equipaggio"][i]["stato"] = "riposo"
			else:
				var t := nave.ricovera(i, n)
				esiti.append("%s → %s" % [m.get("carta", ""), {"light": "Ferite lievi", "moderate": "Ferite moderate", "critical": "Ferite critiche", "morto": "nessun posto: muore"}.get(t, t)])
		for i in nave.in_infermeria():
			if nave.livello_infermeria(i) == "critical":
				var p := nave.prova_sopravvivenza(i)
				esiti.append("Prova di sopravvivenza di %s: %s → %s" % [nave.s["equipaggio"][i]["carta"] if not p["morto"] else nave.s["memoriale"].back()["carta"], ", ".join(p["facce"]), "MUORE" if p["morto"] else "sopravvive"])
		if not esiti.is_empty():
			await _scegli("INFERMERIA", ["OK"], "\n".join(esiti.map(func(x): return "• " + str(x))) + "\n\n[color=#9fbbd6]I potenziamenti dell'infermeria (es. ritiro di un dado) vanno applicati a mano con le correzioni dell'Equipaggio.[/color]", false)
		return true)

func _passo_memoriale() -> void:
	_titolo("Muro della memoria", 36)
	var nuovi: Array = nave.s["memoriale"].filter(func(x): return not x.get("onorato", false))
	if nuovi.is_empty():
		_testo("[color=#9fbbd6]Nessun caduto in questa missione.[/color]")
	for m in nuovi:
		_testo("• [b]%s[/b] (%s)" % [m["carta"], Dati.SEZIONI.get(m["reparto"], {}).get("nome", "")], 16)
	if not nuovi.is_empty():
		_testo("Ogni caduto va nella prima casella libera del suo Reparto (pagg. 37-38) e se ne applica il bonus. Le caselle generiche: Morale su (se è già Alto, +1 Comando).", 15)
	_avanti("AL DEBRIEFING ▶", func():
		for m in nuovi:
			m["onorato"] = true
			if nave.s["morale"] == "high":
				nave.s["pool"]["comando"] = int(nave.s["pool"]["comando"]) + 1
			else:
				nave.morale_su()
		return true)

func _passo_debriefing() -> void:
	_titolo("Debriefing", 27)
	var e := _ultima_esplorazione()
	_sezione("1. Promozioni")
	if e.get("grado_girato", false):
		var req: Dictionary = Carte.per_file(str(e.get("grado_superiore", ""))).get("campi", {}).get("successi_per_grado", {})
		_testo("La carta Grado Superiore è completata: i Membri della Squadra ancora vivi salgono di Grado se hanno i Successi richiesti dalla carta%s (Successi della riserva: %d)." % [
			(": " + ", ".join(req.keys().map(func(k): return "Grado %s → %d" % [str(k).trim_prefix("rank"), int(req[k])]))) if not req.is_empty() else "", int(nave.s["pool"]["successi"])], 15)
		for m in e.get("equipaggio", []):
			var i := int(m.get("nave", -1))
			if i < 0 or m.get("morto", false) or i >= nave.s["equipaggio"].size():
				continue
			var mm: Dictionary = nave.s["equipaggio"][i]
			if mm["stato"] == "morto":
				continue
			var ii: int = i
			var b := Tema.pulsante("PROMUOVI %s (ora Grado %d)" % [mm["carta"], int(mm["grado"])], func():
				nave.s["equipaggio"][ii]["grado"] = min(3, int(nave.s["equipaggio"][ii]["grado"]) + 1)
				nave.diario("%s promosso al Grado %d" % [mm["carta"], int(nave.s["equipaggio"][ii]["grado"])])
				(_scelta.get_or_add("promossi", []) as Array).append(ii)
				_salva()
				aggiorna(), 14)
			b.disabled = ii in _scelta.get("promossi", []) or int(mm["grado"]) >= 3
			_corpo.add_child(b)
	else:
		_testo("[color=#9fbbd6]La carta Grado Superiore non è stata completata: nessuna promozione.[/color]", 15)
	_sezione("2. Riserva dei Successi: %d" % int(nave.s["pool"]["successi"]))
	_sezione("3. Compra o vendi dadi")
	_testo("Ogni Reparto ha [b]%d[/b] dadi. Comprare un dado per ciascun Reparto costa %d Successi (un istruttore di Grado 2/3 sconta 1/2)." % [nave.n_dadi(), nave.costo_dado()], 15)
	var r := _riga()
	r.add_child(Tema.pulsante_primario("COMPRA UN DADO PER REPARTO", func():
		var tipi := {}
		var nomi: Array = Prova.defs()["reparto"].keys().filter(func(k): return not str(k).begins_with("base_"))
		for rep in Nave.REPARTI:
			var j := await _scegli("%s: QUALE DADO?" % Dati.SEZIONI[rep]["nome"].to_upper(), nomi.map(func(k): return "%s (%s)" % [k, Prova.defs()["reparto"][k].get("colore", "")]))
			if j < 0:
				return
			tipi[rep] = nomi[j]
		var sconto := 0
		var ist := nave.membri("", "disponibile").filter(func(i): return int(nave.s["equipaggio"][i]["grado"]) >= 2 and nave.assegnabile(i))
		if not ist.is_empty():
			var k := await _scegli("ISTRUTTORE?", ["Nessuno"] + ist.map(func(i): return _nome_membro(i)), "", false)
			if k > 0:
				sconto = int(nave.s["equipaggio"][ist[k - 1]]["grado"]) - 1
				nave.assegna(ist[k - 1], "istruttore")
		if not nave.compra_dadi(tipi, sconto):
			avviso("Successi insufficienti")
		_salva()
		aggiorna(), 14))
	r.add_child(Tema.pulsante("VENDI UN DADO PER REPARTO (+4 Successi)", func():
		if not nave.vendi_dadi():
			avviso("Non si può vendere (minimo 4 dadi, una volta per Gestione)")
		_salva()
		aggiorna(), 13))
	_avanti("AL PUNTO DI SALVATAGGIO ▶", func():
		for i in nave.membri("", "squadra"):
			nave.s["equipaggio"][i]["stato"] = "riposo"
		nave.s["venduti_qui"] = false
		nave.s["scanner"] = {"carta": "", "rivelate": 0}
		return true)

func _passo_salvataggio() -> void:
	_titolo("Punto di salvataggio", 39)
	_testo("È il momento più comodo per interrompere la partita: tutto lo stato della nave è salvato nella campagna (sul dispositivo e online).")
	var r := _riga()
	r.add_child(Tema.pulsante("SALVA E TORNA AL TAVOLO", func():
		nave.vai("ponte")
		_salva()
		Campagna.salva_subito()
		chiusa.emit(), 15))
	_avanti("CONTINUA: NUOVA GESTIONE ▶")
