## Schermata di gioco: tavolo 3D con sopra l'interfaccia (Logbook, anteprima, comandi, registro).
class_name Gioco
extends Node

signal esci

var tavolo: Tavolo
var ui: Control
var logbook: PannelloLogbook
var _anteprima: TextureRect
var _anteprima_box: PanelContainer
var _anteprima_nome: Label
var _stato_salva: Label
var _toast: Label
var _toast_tw: Tween
var _menu: PopupMenu
var _menu_pezzo: Pezzo
var _aiuto: PanelContainer

func _ready() -> void:
	tavolo = Tavolo.new()
	add_child(tavolo)
	var stato_tav: Dictionary = Campagna.dati.get("tavolo", {})
	if stato_tav.get("pezzi", []).is_empty():
		tavolo.allestisci()
		tavolo.vista("nave")
	else:
		tavolo.ripristina(stato_tav)
	tavolo.sopra.connect(_su_sopra)
	tavolo.menu.connect(_apri_menu)
	tavolo.apri_contenuto.connect(_sfoglia)
	tavolo.messaggio.connect(avviso)
	tavolo.dado_tirato.connect(_dado)
	tavolo.libro.connect(func(p):
		if str(p.def.get("pdf", "")).contains("B61A9BAEFA167280"):
			_mostra_logbook(true)
		else:
			ui.add_child(VisoreRegole.new()))
	_costruisci_ui()
	Campagna.cambiata.connect(_salva_tavolo_differito)
	Campagna.salvata.connect(_su_salvata)
	var modo := str(Campagna.dati.get("modo", ""))
	if Campagna.dati.get("esplorazione") is Dictionary and not Campagna.dati["esplorazione"].is_empty():
		# un'esplorazione in corso: si riprende direttamente dalla plancia del pianeta
		apri_esplorazione.call_deferred()
		return
	if Campagna.motore.posizione().is_empty() and Campagna.dati["registro"].get("eventi", []).size() <= 1:
		# prima apertura: il Logbook propone l'annotazione iniziale
		_mostra_logbook(true)
		if modo == "rapido":
			avviso("Inizio rapido: segui il regolamento a pag. 28, poi apri l'annotazione indicata.")
	elif not Campagna.motore.posizione().is_empty():
		_mostra_logbook(true)

var _salvo_tavolo := false
## Prima di ogni salvataggio copia nella campagna lo stato del tavolo.
func _salva_tavolo_differito() -> void:
	if _salvo_tavolo:
		return
	_salvo_tavolo = true
	await get_tree().process_frame
	_salvo_tavolo = false
	if is_instance_valid(tavolo) and Campagna.attiva():
		Campagna.dati["tavolo"] = tavolo.serializza()

func _costruisci_ui() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = Tema.tema
	cl.add_child(ui)
	# barra in alto
	var barra := PanelContainer.new()
	barra.add_theme_stylebox_override("panel", Tema.box(Color(0.02, 0.05, 0.11, 0.9), Tema.CIANO_SCURO, 0, 0, 10))
	barra.set_anchors_preset(Control.PRESET_TOP_WIDE)
	barra.offset_bottom = 54
	ui.add_child(barra)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	barra.add_child(h)
	var ic := TextureRect.new()
	ic.texture = load("res://assets/icona.png")
	ic.custom_minimum_size = Vector2(36, 36)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(ic)
	var tit := Tema.etichetta("ISS VANGUARD", 18, Tema.TESTO, true)
	h.add_child(tit)
	var info := Label.new()
	info.text = "  %s · %s · codice %s" % [Campagna.dati.get("nome", ""), Dati.CAMPAGNE[Campagna.id_campagna()]["nome"], Campagna.codice()]
	info.add_theme_color_override("font_color", Tema.TESTO_2)
	info.add_theme_font_override("font", Tema.mono)
	info.add_theme_font_size_override("font_size", 17)
	h.add_child(info)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	# viste del tavolo come schede: si guarda solo la parte che serve
	var gruppo := ButtonGroup.new()
	for k in ["nave", "equipaggio", "mazzi", "scoperte", "pianeta", "tutto"]:
		var nome_v: String = {"scoperte": "Scoperte", "tutto": "Tutto"}.get(k, Tavolo.VISTE[k]["nome"])
		var b := Tema.pulsante(nome_v.to_upper(), tavolo.vista.bind(k), 12)
		b.toggle_mode = true
		b.button_group = gruppo
		b.button_pressed = k == "nave"
		b.tooltip_text = "Vista: %s" % Tavolo.VISTE[k]["nome"]
		h.add_child(b)
	h.add_child(VSeparator.new())
	var esp_in_corso: bool = Campagna.dati.get("esplorazione") is Dictionary and not Campagna.dati["esplorazione"].is_empty()
	h.add_child(Tema.pulsante_primario("RIPRENDI ESPLORAZIONE" if esp_in_corso else "ESPLORAZIONE", apri_esplorazione, 14))
	h.add_child(Tema.pulsante_primario("LOGBOOK", func(): _mostra_logbook(not logbook.visible), 14))
	var menu := MenuButton.new()
	menu.text = "≡"
	menu.flat = false
	menu.add_theme_font_size_override("font_size", 18)
	menu.get_popup().add_item("Regolamento", 0)
	menu.get_popup().add_item("Comandi del tavolo", 1)
	menu.get_popup().add_item("Salva adesso", 2)
	menu.get_popup().add_item("Torna al menu", 3)
	menu.get_popup().id_pressed.connect(_voce_menu_barra)
	h.add_child(menu)
	_stato_salva = Label.new()
	_stato_salva.add_theme_font_override("font", Tema.mono)
	_stato_salva.add_theme_font_size_override("font_size", 14)
	_stato_salva.add_theme_color_override("font_color", Tema.TESTO_2)
	_stato_salva.custom_minimum_size = Vector2(150, 0)
	h.add_child(_stato_salva)
	# Logbook a destra
	logbook = PannelloLogbook.new()
	logbook.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	logbook.offset_left = -640
	logbook.offset_top = 62
	logbook.offset_bottom = -10
	logbook.offset_right = -10
	ui.add_child(logbook)
	logbook.imposta(Campagna.motore)
	logbook.chiuso.connect(func(): _mostra_logbook(false))
	logbook.chiedi_carta.connect(func(n): tavolo.porta_carta(n))
	logbook.apri_registro.connect(_registro)
	logbook.visible = false
	# anteprima della carta sotto il mouse (in basso a sinistra)
	_anteprima_box = PanelContainer.new()
	_anteprima_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_anteprima_box.offset_left = 10
	_anteprima_box.offset_bottom = -10
	_anteprima_box.offset_top = -470
	_anteprima_box.offset_right = 470
	_anteprima_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anteprima_box.visible = false
	ui.add_child(_anteprima_box)
	var av := VBoxContainer.new()
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anteprima_box.add_child(av)
	_anteprima_nome = Tema.etichetta("", 14, Tema.CIANO)
	av.add_child(_anteprima_nome)
	_anteprima = TextureRect.new()
	_anteprima.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_anteprima.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_anteprima.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_anteprima.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av.add_child(_anteprima)
	# messaggi brevi
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 70
	_toast.offset_left = -400
	_toast.offset_right = 400
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_override("font", Tema.titolo)
	_toast.add_theme_font_size_override("font_size", 18)
	_toast.add_theme_color_override("font_color", Tema.AMBRA)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_toast)
	# menu contestuale
	_menu = PopupMenu.new()
	_menu.id_pressed.connect(_voce_menu)
	ui.add_child(_menu)
	# riga d'aiuto in basso
	var hint := Label.new()
	hint.text = "Trascina = sposta · tasto destro = menu · destro trascinato = ruota la vista · rotella = zoom · F gira · Q/E ruota · R tira/mescola · D pesca · T stato · Maiusc+trascina un mazzo = prendi la prima carta · 1-5,0 viste"
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -30
	hint.offset_left = -700
	hint.offset_right = 700
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.72, 0.85, 0.85))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.text = "Tasto destro = menu del pezzo · destro trascinato = ruota · rotella = zoom · ≡ > Comandi del tavolo per tutti i tasti"
	ui.add_child(hint)
	var tw := hint.create_tween()
	tw.tween_interval(8.0)
	tw.tween_property(hint, "modulate:a", 0.0, 1.5)

var _missione: Missione

## Esplorazione planetaria: riprende quella in corso oppure apre la preparazione.
func apri_esplorazione() -> void:
	if is_instance_valid(_missione):
		return
	var st = Campagna.dati.get("esplorazione")
	if st is Dictionary and not st.is_empty():
		_mostra_missione(st)
		return
	var prep := PreparazioneMissione.new()
	prep.pagina_iniziale = str(Campagna.dati.get("prossimo_pianeta", "p.2-3"))
	prep.pronta.connect(func(cfg: Dictionary):
		var e := Esplorazione.new()
		e.prepara(cfg["pagina"], Carte.pianeta(cfg["pagina"]), cfg["squadra"], cfg["lander"], cfg["mazzi"])
		Campagna.dati["esplorazione"] = e.s
		Campagna.annota("Inizia l'esplorazione: %s" % str(Carte.pianeta(cfg["pagina"]).get("pianeta", cfg["pagina"])))
		Campagna.modificata()
		_mostra_missione(e.s))
	ui.add_child(prep)

func _mostra_missione(st: Dictionary) -> void:
	_missione = Missione.new(st)
	tavolo.visible = false
	tavolo.process_mode = Node.PROCESS_MODE_DISABLED
	logbook.visible = false
	ui.add_child(_missione)
	_missione.chiusa.connect(func():
		_missione.queue_free()
		tavolo.visible = true
		tavolo.process_mode = Node.PROCESS_MODE_INHERIT)

func _voce_menu_barra(id: int) -> void:
	if id == 0:
		ui.add_child(VisoreRegole.new())
	elif id == 1:
		_mostra_aiuto()
	elif id == 2:
		Campagna.dati["tavolo"] = tavolo.serializza()
		Campagna.salva_subito()
	elif id == 3:
		Campagna.dati["tavolo"] = tavolo.serializza()
		esci.emit()

func _mostra_logbook(v: bool) -> void:
	logbook.visible = v
	if v:
		logbook.mostra_corrente()

func avviso(t: String) -> void:
	_toast.text = t
	_toast.modulate.a = 1.0
	if _toast_tw:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_interval(2.6)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.6)

func _su_salvata(ok: bool, dove: String) -> void:
	if dove == "online":
		_stato_salva.text = "● salvato online" if ok else "○ solo in locale"
		_stato_salva.add_theme_color_override("font_color", Tema.VERDE if ok else Tema.AMBRA)
		_stato_salva.tooltip_text = "" if ok else "Firebase non raggiungibile: " + Net.ultimo_errore

func _su_sopra(p: Pezzo) -> void:
	if p == null:
		_anteprima_box.visible = false
		return
	var rel := p.immagine_visibile()
	_anteprima_nome.text = p.nome_visibile().to_upper()
	if rel == "":
		_anteprima_box.visible = false
		if p.nome_visibile() != "":
			pass
		return
	_anteprima_box.visible = true
	var t := Immagini.subito(rel)
	_anteprima.texture = t
	if t == null:
		Immagini.carica(rel, func(tex):
			if is_instance_valid(p) and p.immagine_visibile() == rel:
				_anteprima.texture = tex)
	# le immagini orizzontali usano un riquadro più largo
	var ar := 1.0
	if t:
		ar = float(t.get_width()) / max(1.0, t.get_height())
	_anteprima_box.offset_right = 10 + (600 if ar > 1.2 else 440)

# ------------------------------------------------------------------ menu contestuale

enum { M_GIRA, M_RUOTA_SX, M_RUOTA_DX, M_PESCA, M_PESCA_COPERTA, M_MESCOLA, M_SFOGLIA, M_TIRA, M_STATO_SUCC, M_STATO_PREC,
	M_BLOCCA, M_INQUADRA, M_INGRANDISCI, M_GIRA_MAZZO, M_PRENDI, M_DADO_FACCIA }

func _apri_menu(p: Pezzo, pos: Vector2) -> void:
	_menu_pezzo = p
	_menu.clear()
	_menu.add_separator(p.nome_visibile())
	match p.tipo:
		"carta":
			_menu.add_item("Gira (F)", M_GIRA)
			_menu.add_item("Ruota a sinistra (Q)", M_RUOTA_SX)
			_menu.add_item("Ruota a destra (E)", M_RUOTA_DX)
			_menu.add_item("Ingrandisci", M_INGRANDISCI)
		"mazzo":
			_menu.add_item("Pesca scoperta (D)", M_PESCA)
			_menu.add_item("Pesca coperta", M_PESCA_COPERTA)
			_menu.add_item("Mescola (R)", M_MESCOLA)
			_menu.add_item("Sfoglia / cerca una carta…", M_SFOGLIA)
			_menu.add_item("Gira il mazzo (F)", M_GIRA_MAZZO)
			_menu.add_item("Ruota (Q)", M_RUOTA_SX)
		"tessera":
			if p.numero_stati() > 1:
				_menu.add_item("Pagina/stato successivo (T)", M_STATO_SUCC)
				_menu.add_item("Pagina/stato precedente", M_STATO_PREC)
			_menu.add_item("Gira (F)", M_GIRA)
			_menu.add_item("Ruota (Q)", M_RUOTA_SX)
			_menu.add_item("Ingrandisci", M_INGRANDISCI)
		"dado":
			_menu.add_item("Tira (R)", M_TIRA)
			if p.def.has("img"):
				_menu.add_item("Scegli la faccia…", M_DADO_FACCIA)
		"sacchetto", "modello":
			if not p.contenuto.is_empty():
				_menu.add_item("Prendi il primo", M_PRENDI)
				_menu.add_item("Sfoglia il contenuto…", M_SFOGLIA)
		"standee", "miniatura":
			_menu.add_item("Ruota (Q)", M_RUOTA_SX)
	_menu.add_separator()
	_menu.add_item("Inquadra (Z)", M_INQUADRA)
	_menu.add_item("Sblocca (L)" if p.bloccato else "Blocca (L)", M_BLOCCA)
	_menu.position = Vector2i(pos) + Vector2i(4, 4)
	_menu.reset_size()
	_menu.popup()

func _voce_menu(id: int) -> void:
	var p := _menu_pezzo
	if not is_instance_valid(p):
		return
	match id:
		M_GIRA, M_GIRA_MAZZO: p.gira()
		M_RUOTA_SX: p.ruota(90)
		M_RUOTA_DX: p.ruota(-90)
		M_PESCA: tavolo.pesca_da(p, true)
		M_PESCA_COPERTA: tavolo.pesca_da(p, false)
		M_MESCOLA:
			p.mescola()
			avviso("Mazzo mescolato")
		M_SFOGLIA: _sfoglia(p)
		M_TIRA: tavolo.tira(p)
		M_STATO_SUCC: p.cambia_stato()
		M_STATO_PREC: p.cambia_stato((p.stato - 1 + p.numero_stati()) % p.numero_stati())
		M_BLOCCA: p.bloccato = not p.bloccato
		M_INQUADRA: tavolo.inquadra(p)
		M_INGRANDISCI: _ingrandisci(p.immagine_visibile())
		M_PRENDI: tavolo.prendi_da(p, 0)
		M_DADO_FACCIA: _scegli_faccia(p)
	Campagna.modificata()

func _ingrandisci(rel: String) -> void:
	if rel == "":
		return
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vel := ColorRect.new()
	vel.color = Color(0, 0, 0, 0.85)
	vel.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(vel)
	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.offset_left = 40
	tr.offset_right = -40
	tr.offset_top = 40
	tr.offset_bottom = -40
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	c.add_child(tr)
	Immagini.carica(rel, func(t): if is_instance_valid(tr): tr.texture = t)
	vel.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: c.queue_free())
	ui.add_child(c)

## Finestra con il contenuto di un mazzo o di un sacchetto: clic su un elemento per prenderlo.
func _sfoglia(p: Pezzo) -> void:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vel := ColorRect.new()
	vel.color = Color(0, 0.01, 0.03, 0.85)
	vel.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(vel)
	var pan := PanelContainer.new()
	pan.set_anchors_preset(Control.PRESET_FULL_RECT)
	pan.offset_left = 60
	pan.offset_right = -60
	pan.offset_top = 70
	pan.offset_bottom = -50
	c.add_child(pan)
	var v := VBoxContainer.new()
	pan.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	h.add_child(Tema.etichetta(p.nome_visibile().to_upper(), 18))
	var filtro := LineEdit.new()
	filtro.placeholder_text = "Cerca per nome o numero (es. P107)"
	filtro.custom_minimum_size = Vector2(360, 0)
	filtro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(filtro)
	h.add_child(Tema.pulsante("✕ CHIUDI", c.queue_free, 13))
	var nota := Label.new()
	nota.text = "Clic su una carta per prenderla (va accanto al mazzo, scoperta)."
	nota.add_theme_color_override("font_color", Tema.TESTO_2)
	v.add_child(nota)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	var g := HFlowContainer.new()
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	sc.add_child(g)
	var riempi := func(f: String):
		for x in g.get_children():
			x.queue_free()
		for i in p.contenuto.size():
			var d: Dictionary = p.contenuto[i]
			var nome := str(d.get("nome", ""))
			if f != "" and not nome.to_lower().contains(f.to_lower()):
				continue
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(170, 200)
			b.tooltip_text = Traduzioni.nome(nome)
			var tr := TextureRect.new()
			tr.set_anchors_preset(Control.PRESET_FULL_RECT)
			tr.offset_left = 4
			tr.offset_top = 4
			tr.offset_right = -4
			tr.offset_bottom = -22
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(tr)
			var l := Label.new()
			l.text = Traduzioni.nome(nome) if nome != "" else "#%d" % (i + 1)
			l.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			l.offset_top = -22
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.add_theme_font_size_override("font_size", 13)
			l.clip_text = true
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(l)
			var rel := str(d.get("fronte", d.get("img", "")))
			if rel != "":
				Immagini.carica(rel, func(t): if is_instance_valid(tr): tr.texture = t)
			var idx := i
			b.pressed.connect(func():
				tavolo.prendi_da(p, idx)
				c.queue_free())
			g.add_child(b)
	filtro.text_changed.connect(func(t): riempi.call(t))
	riempi.call("")
	ui.add_child(c)
	filtro.grab_focus()

func _scegli_faccia(p: Pezzo) -> void:
	var c := PopupPanel.new()
	var h := HBoxContainer.new()
	c.add_child(h)
	var img_rel := str(p.def.get("img", ""))
	for i in 6:
		var b := Button.new()
		b.custom_minimum_size = Vector2(90, 90)
		var at := AtlasTexture.new()
		var idx := i
		Immagini.carica(img_rel, func(t):
			at.atlas = t
			if t:
				var w: float = t.get_width() / 3.0
				at.region = Rect2((idx % 3) * w, (1 + idx / 3) * w, w, w)
			b.icon = at)
		b.expand_icon = true
		b.pressed.connect(func():
			p.imposta_faccia_dado(idx)
			Campagna.modificata()
			c.queue_free())
		h.add_child(b)
	ui.add_child(c)
	c.popup_centered()

func _dado(p: Pezzo, f: int) -> void:
	if not p.def.has("img"):
		avviso("Risultato: %d" % (f + 1))
		return
	var valori: Array = p.def.get("valori", [])
	avviso("Dado tirato")

# ------------------------------------------------------------------ registro di bordo

func _registro() -> void:
	ui.add_child(Registro.new())

func _mostra_aiuto() -> void:
	if is_instance_valid(_aiuto):
		_aiuto.queue_free()
		return
	_aiuto = PanelContainer.new()
	_aiuto.set_anchors_preset(Control.PRESET_CENTER)
	_aiuto.custom_minimum_size = Vector2(820, 0)
	_aiuto.offset_left = -410
	_aiuto.offset_top = -330
	var r := Tema.testo_ricco(18)
	r.custom_minimum_size = Vector2(800, 0)
	r.text = """[font_size=22][b]COMANDI DEL TAVOLO[/b][/font_size]

[b]Vista[/b]: tasto destro trascinato per ruotare, rotella (o pizzico) per lo zoom, trascina sul tavolo vuoto (o tasto centrale) per spostarti. Tasti [b]1[/b] Pianeta, [b]2[/b] Nave, [b]3[/b] Equipaggio, [b]4[/b] Mazzi, [b]5[/b] Scoperte, [b]0[/b] tutto il tavolo.
[b]Pezzi[/b]: trascina per spostare; lascia una carta su un'altra per fare un mazzo, su un mazzo per metterla in cima, su un sacchetto o una scatola per riporla. Doppio clic: gira una carta, cambia pagina al Planetopedia, pesca da un mazzo, tira un dado, apre un sacchetto.
[b]Tasti sul pezzo sotto il mouse[/b]: [b]F[/b] gira · [b]Q/E[/b] ruota di 90° (con Maiusc 15°) · [b]R[/b] tira il dado / mescola il mazzo · [b]D[/b] pesca · [b]T[/b] stato o pagina successiva · [b]L[/b] blocca · [b]Z[/b] inquadra.
[b]Mazzi[/b]: Maiusc + trascina prende la prima carta; dal menu (tasto destro) si sfoglia il mazzo e si cerca una carta per nome (P107, M02…).
[b]Logbook[/b]: pulsante in alto o i libri sul tavolo. Le domande Sì/No e i flag sono gestiti come nell'app; le carte citate nelle istruzioni si portano sul tavolo con un clic.
[b]Salvataggio[/b]: automatico dopo ogni modifica, sul dispositivo e online. Il codice della campagna (in alto) serve per riprenderla da un altro dispositivo.

[i]Clic qui per chiudere.[/i]"""
	_aiuto.add_child(r)
	_aiuto.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _aiuto.queue_free())
	ui.add_child(_aiuto)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and Campagna.attiva() and is_instance_valid(tavolo):
		Campagna.dati["tavolo"] = tavolo.serializza()
		Campagna.salva_subito()
