## Pannello del Logbook: mostra l'annotazione corrente, pone le domande Sì/No,
## mostra le istruzioni da eseguire sul tavolo e segue i rinvii fra annotazioni.
class_name PannelloLogbook
extends PanelContainer

signal chiedi_carta(nome: String)      # porta una carta (P107, M02…) sul tavolo
signal apri_registro
signal chiuso
## Chi sa rispondere alle domande e applicare le istruzioni (Missione o GestioneNave): metodi
## rispondi_logbook(q) -> 1/0/-1, istruzione_logbook(t) -> Array (righe fatte), con _ultima_spiegazione.
var contesto: Object = null

const RX_CARTA := "\\b([PMGSBRCALFEO])(\\d{2,3})\\b"

var motore: MotoreLogbook
var _titolo: Label
var _numero: Label
var _corpo: VBoxContainer
var _scroll: ScrollContainer
var _campo: LineEdit
var _banner: TextureRect
var _occupato := false

func _ready() -> void:
	add_theme_stylebox_override("panel", Tema.box_hud(Color(0.02, 0.05, 0.11, 0.97), Tema.CIANO_SCURO))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	# intestazione
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	var ic := TextureRect.new()
	ic.texture = load("res://assets/icona.png")
	ic.custom_minimum_size = Vector2(40, 40)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(ic)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", -2)
	h.add_child(tv)
	_numero = Tema.etichetta("LOGBOOK", 13, Tema.CIANO)
	tv.add_child(_numero)
	_titolo = Tema.etichetta("", 20)
	_titolo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(_titolo)
	var bx := Tema.pulsante("✕", func(): chiuso.emit(), 16)
	bx.tooltip_text = "Chiudi il Logbook (L)"
	h.add_child(bx)
	# barra comandi
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", 6)
	v.add_child(b)
	var bi := Tema.pulsante("◀ INDIETRO", _indietro, 13)
	bi.tooltip_text = "Torna al paragrafo precedente (i flag già segnati restano)"
	b.add_child(bi)
	_campo = LineEdit.new()
	_campo.placeholder_text = "N° annotazione"
	_campo.custom_minimum_size = Vector2(150, 0)
	_campo.max_length = 5
	_campo.text_submitted.connect(func(_t): _vai())
	b.add_child(_campo)
	b.add_child(Tema.pulsante("VAI", _vai, 13))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_child(sp)
	b.add_child(Tema.pulsante("REGISTRO", func(): apri_registro.emit(), 13))
	v.add_child(HSeparator.new())
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_right", 12)
	_scroll.add_child(m)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	m.add_child(inner)
	_banner = TextureRect.new()
	_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_banner.custom_minimum_size = Vector2(0, 150)
	_banner.visible = false
	inner.add_child(_banner)
	_corpo = VBoxContainer.new()
	_corpo.add_theme_constant_override("separation", 12)
	inner.add_child(_corpo)

func imposta(m: MotoreLogbook) -> void:
	motore = m
	mostra_corrente()

func mostra_corrente() -> void:
	var p := motore.posizione()
	if p.is_empty():
		_mostra_inizio()
	else:
		_mostra(p[0], p[1])

## Apre un'annotazione per numero (come digitarlo nell'app).
func apri_numero(n: int) -> bool:
	var id := motore.trova_numero(n)
	if id < 0:
		_avviso("L'annotazione %d non esiste, oppure si raggiunge solo da un'altra annotazione." % n)
		return false
	var p := motore.entra(id)
	Campagna.annota("Annotazione %d" % n)
	_mostra(p[0], p[1])
	return true

func _vai() -> void:
	var t := _campo.text.strip_edges()
	if t.is_valid_int():
		apri_numero(int(t))
	_campo.text = ""

func _indietro() -> void:
	if _occupato:
		return
	var p := motore.indietro()
	if p.is_empty():
		_mostra_inizio()
	else:
		_mostra(p[0], p[1])

func _svuota() -> void:
	for c in _corpo.get_children():
		c.queue_free()

## Apre l'annotazione iniziale della campagna (o delle Operazioni) senza passare dal menu.
func apri_inizio(operazioni := false) -> void:
	var intro: Dictionary = Dati.logbook(motore.camp).get("intro", {})
	var k := "2" if operazioni and intro.has("2") else "1"
	if intro.has(k):
		var p := motore.entra(int(intro[k]))
		_mostra(p[0], p[1])

func _mostra_inizio() -> void:
	_svuota()
	_banner.visible = false
	_numero.text = "LOGBOOK · %s" % Dati.CAMPAGNE[motore.camp]["nome"].to_upper()
	_titolo.text = "In attesa di istruzioni"
	var r := Tema.testo_ricco(19)
	r.text = "Quando il gioco ti chiede di andare a un'[b]Annotazione[/b] (Log), scrivi il numero qui sopra e premi [b]VAI[/b].\n\nPer iniziare la campagna apri l'annotazione iniziale."
	_corpo.add_child(r)
	var intro: Dictionary = Dati.logbook(motore.camp).get("intro", {})
	if intro.has("1"):
		_corpo.add_child(Tema.pulsante_primario("APRI L'ANNOTAZIONE INIZIALE", func():
			var p := motore.entra(int(intro["1"]))
			_mostra(p[0], p[1])))
	if intro.has("2"):
		_corpo.add_child(Tema.pulsante("INTRODUZIONE ALLE OPERAZIONI", func():
			var p := motore.entra(int(intro["2"]))
			_mostra(p[0], p[1])))
	var vis: Dictionary = motore.stato.get("visitate", {})
	if not vis.is_empty():
		var nums := []
		for k in vis:
			nums.append(int(k))
		nums.sort()
		var u := Tema.testo_ricco(16)
		u.text = "[color=#9fbbd6]Annotazioni già visitate: %s[/color]" % ", ".join(nums.slice(max(0, nums.size() - 40)).map(func(x): return str(x)))
		_corpo.add_child(u)

func _mostra(id_log: int, id_verso: int) -> void:
	_svuota()
	_occupato = false
	var a := motore.annotazione(id_log)
	var v := motore.verso(id_log, id_verso)
	if a.is_empty():
		_mostra_inizio()
		return
	if v.is_empty():
		_mostra_caselle(a)
		return
	_numero.text = "ANNOTAZIONE %d" % int(a.get("n", 0))
	_titolo.text = _pulito(str(a.get("name", "")))
	if a.has("img"):
		_banner.visible = true
		_banner.texture = load("res://assets/app/sfondi/%d.webp" % int(a["img"]))
	else:
		_banner.visible = false
	var tipo := int(v.get("t", 5))
	var elementi: Array = v.get("e", [])
	var scelte_immagine := []
	for el in elementi:
		var et := int(el.get("t", 0))
		match et:
			MotoreLogbook.EL_TESTO:
				if str(el.get("x", "")) != "":
					_corpo.add_child(_testo(str(el["x"])))
			MotoreLogbook.EL_TITOLO_IMMAGINI:
				if str(el.get("x", "")) != "":
					var t := Tema.etichetta(_pulito(str(el["x"])), 16, Tema.AMBRA)
					t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					_corpo.add_child(t)
				scelte_immagine.append(el)
			MotoreLogbook.EL_VIDEO:
				var r := Tema.testo_ricco(17)
				r.text = "[i][color=#9fbbd6](Nell'app qui parte un filmato.)[/color][/i]"
				_corpo.add_child(r)
				var bv := _pulsante_scelta("Prosegui")
				bv.pressed.connect(_risolvi.bind(el, tipo))
				_corpo.add_child(bv)
			MotoreLogbook.EL_GRAFO:
				_mostra_grafo(str(el.get("x", "")), id_log)
				return
	if tipo == MotoreLogbook.TIPO_AUTO:
		# rinvio automatico: si risolve da solo (eventualmente con domande)
		for el in elementi:
			if int(el.get("t", 0)) == MotoreLogbook.EL_SCELTA:
				_risolvi(el, tipo)
				break
		return
	if not scelte_immagine.is_empty():
		_griglia_immagini(scelte_immagine, tipo)
	var opzioni := VBoxContainer.new()
	opzioni.add_theme_constant_override("separation", 6)
	for el in elementi:
		if int(el.get("t", 0)) != MotoreLogbook.EL_SCELTA:
			continue
		var disp := motore.elemento_disponibile(el)
		if not disp and not v.get("uv", 0):
			continue
		var testo := _pulito(str(el.get("x", "")))
		if testo == "":
			testo = "Prosegui"
		var b := _pulsante_scelta(testo)
		b.disabled = not disp
		b.pressed.connect(_risolvi.bind(el, tipo))
		opzioni.add_child(b)
	if opzioni.get_child_count() > 0:
		_corpo.add_child(opzioni)
	elif scelte_immagine.is_empty() and not elementi.any(func(x): return int(x.get("t", 0)) == MotoreLogbook.EL_VIDEO):
		_corpo.add_child(Tema.pulsante("FINE DELL'ANNOTAZIONE", func():
			motore.esci()
			Campagna.modificata()
			_fine_annotazione(), 16))
	await get_tree().process_frame
	_scroll.scroll_vertical = 0

## Schema del progetto "Diritto di Nascita": si segna un cerchio collegato a quelli già segnati.
func _mostra_grafo(testo: String, id_log: int) -> void:
	var nodi := motore.grafo(testo)
	# nomi italiani dei cerchi, dalle caselle dell'annotazione
	var nomi := {}
	for f in motore.annotazione(id_log).get("flags", []):
		nomi[int(f[0])] = str(f[1]).replace("[nodo dell'albero]", "").strip_edges()
	for n in nodi:
		var fid: int = n["set"] if n["set"] >= 0 else n["req"]
		if nomi.has(fid):
			n["nome"] = nomi[fid]
	var r := Tema.testo_ricco(18)
	r.text = "[b]Schema del progetto[/b] — cerchi già segnati: " + ", ".join(nodi.filter(func(n): return n["liv"] > 1 and motore.nodo_segnato(n)).map(func(n): return "[color=#5be39b]%s[/color]" % n["nome"]))
	_corpo.add_child(r)
	var disp := motore.nodi_disponibili(nodi)
	if disp.is_empty():
		_corpo.add_child(_testo("[i]Nessun cerchio collegato disponibile.[/i]"))
	var v := VBoxContainer.new()
	for n in disp:
		var b := _pulsante_scelta("%s  (livello %d)" % [n["nome"], n["liv"]])
		b.pressed.connect(func():
			var dest := motore.scegli_nodo(n, id_log)
			Campagna.modificata()
			if dest.is_empty():
				_fine_annotazione()
			else:
				_mostra(dest[0], dest[1]))
		v.add_child(b)
	_corpo.add_child(v)

## Annotazione fatta solo di caselle da segnare (A, B, C…).
func _mostra_caselle(a: Dictionary) -> void:
	_banner.visible = false
	_numero.text = "ANNOTAZIONE %d" % int(a.get("n", 0))
	_titolo.text = _pulito(str(a.get("name", "")))
	_corpo.add_child(_testo("Caselle di questa annotazione. Segnale solo quando il gioco lo chiede (di solito si segnano da sole con le scelte)."))
	for f in a.get("flags", []):
		var cb := CheckBox.new()
		cb.text = str(f[1])
		cb.button_pressed = motore.flag(int(f[0])) == 1
		cb.toggled.connect(func(on):
			motore.imposta_flag(int(f[0]), 1 if on else 0)
			Campagna.modificata())
		_corpo.add_child(cb)
	_corpo.add_child(Tema.pulsante("FINE DELL'ANNOTAZIONE", func():
		motore.esci()
		_fine_annotazione(), 16))

func _testo(t: String) -> RichTextLabel:
	var r := Tema.testo_ricco(19)
	r.text = Dati.testo_bb(t, 22)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r

func _pulito(t: String) -> String:
	# per le etichette semplici (senza BBCode)
	var rx := RegEx.create_from_string("\\[/?[bi]\\]")
	t = rx.sub(t, "", true)
	t = t.replace("[lb]", "[").replace("[rb]", "]")
	var ri := RegEx.create_from_string("\\{i:(\\w+)\\}")
	return ri.sub(t, "[$1]", true)

func _pulsante_scelta(testo: String) -> Button:
	var b := Button.new()
	b.text = "▸  " + testo
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_override("font", Tema.testo_grassetto)
	b.add_theme_font_size_override("font_size", 19)
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b

static var _facce_pericolo := {}

func _griglia_immagini(els: Array, tipo: int) -> void:
	if _facce_pericolo.is_empty():
		var f := FileAccess.open("res://data/logbook/scelte_pericolo.json", FileAccess.READ)
		if f:
			_facce_pericolo = JSON.parse_string(f.get_as_text())
	# se le immagini sono le facce del dado Pericolo, il programma può tirarlo
	var scelte := []
	for el in els:
		for c in motore.alternative(el, tipo):
			if c.has("img"):
				scelte.append(c)
	var facce := scelte.map(func(c): return str(_facce_pericolo.get(str(c["img"]).get_basename() + ".webp", "")))
	if not scelte.is_empty() and not "" in facce:
		var bt := Tema.pulsante_primario("TIRA IL DADO PERICOLO", func():
			var d := {"tipo": "pericolo", "faccia": 0}
			Prova.tira(d)
			var ic := Prova.icone(d)
			var faccia: String = str(ic[0]) if not ic.is_empty() else "vuota"
			var k := facce.find(faccia)
			if k < 0:
				k = facce.find("altro")
			_avviso("Dado Pericolo: %s" % {"vuota": "faccia vuota", "common": "comune", "uncommon": "non comune", "rare": "raro", "special": "speciale"}.get(faccia, faccia))
			if k >= 0:
				_esegui(scelte[k]), 16)
		_corpo.add_child(bt)
	var g := HFlowContainer.new()
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	for el in els:
		for c in motore.alternative(el, tipo):
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(200, 0)
			var vb := VBoxContainer.new()
			vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.set_anchors_preset(Control.PRESET_FULL_RECT)
			var tr := TextureRect.new()
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.custom_minimum_size = Vector2(196, 146)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			if c.has("img"):
				var p := "res://assets/app/scelte/" + str(c["img"]).get_basename() + ".webp"
				if ResourceLoader.exists(p):
					tr.texture = load(p)
			vb.add_child(tr)
			var l := Label.new()
			l.text = _pulito(str(c.get("q", "")))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(196, 0)
			l.add_theme_font_size_override("font_size", 15)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.add_child(l)
			b.add_child(vb)
			b.custom_minimum_size.y = 200
			b.pressed.connect(func(): _esegui(c))
			g.add_child(b)
	_corpo.add_child(g)

## Risolve un pulsante: prova le alternative in ordine, ponendo le domande Sì/No quando servono.
func _risolvi(el: Dictionary, tipo: int) -> void:
	if _occupato:
		return
	_occupato = true
	var alt := motore.alternative(el, tipo)
	if tipo == MotoreLogbook.TIPO_IMMAGINI:
		alt = alt.filter(func(c): return not c.has("img"))
	for c in alt:
		if c.has("q") and str(c["q"]) != "":
			var auto := -1
			if contesto and contesto.has_method("rispondi_logbook"):
				auto = contesto.rispondi_logbook(str(c["q"]))
			if auto >= 0:
				_avviso("Verifica automatica: %s → %s (%s)" % [_pulito(str(c["q"])), "Sì" if auto == 1 else "No", str(contesto.get("_ultima_spiegazione"))])
				if auto == 0:
					continue
				_occupato = false
				_esegui(c)
				return
			var si: bool = await _domanda(str(c["q"]), str(c.get("yes", "Sì")), str(c.get("no", "No")))
			if not si:
				continue
		_occupato = false
		_esegui(c)
		return
	_occupato = false
	_avviso("Nessuna delle opzioni si applica: controlla le condizioni sul tavolo, oppure torna indietro.")

## Domanda Sì/No mostrata nel corpo del Logbook. Restituisce true per Sì.
func _domanda(q: String, si: String, no: String) -> bool:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Tema.box(Color(0.12, 0.09, 0.02, 0.95), Tema.AMBRA, 1, 4, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(Tema.etichetta("VERIFICA", 13, Tema.AMBRA))
	var r := Tema.testo_ricco(19)
	var tq := q.strip_edges()
	if not tq.ends_with("?"):
		tq += "?"
	r.text = Dati.testo_bb(tq[0].to_upper() + tq.substr(1), 22)
	v.add_child(r)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	var esito := [false, false]
	var bs := Tema.pulsante(si.to_upper(), func(): esito[0] = true; esito[1] = true, 16)
	var bn := Tema.pulsante(no.to_upper(), func(): esito[1] = true, 16)
	bs.custom_minimum_size = Vector2(120, 0)
	bn.custom_minimum_size = Vector2(120, 0)
	h.add_child(bs)
	h.add_child(bn)
	_corpo.add_child(p)
	await get_tree().process_frame
	_scroll.ensure_control_visible(p)
	while not esito[1]:
		await get_tree().process_frame
	p.queue_free()
	return esito[0]

## Esegue un'alternativa: mostra le istruzioni (se ci sono), poi segna i flag e segue il rinvio.
func _esegui(c: Dictionary) -> void:
	var istr := str(c.get("r", ""))
	if istr != "":
		_occupato = true
		await _istruzioni(istr)
		_occupato = false
	var dest := motore.scegli(c)
	Campagna.modificata()
	if dest.is_empty():
		_fine_annotazione()
	else:
		var a := motore.annotazione(dest[0])
		var vis: Array = Campagna.dati["registro"].get_or_add("ultime", [])
		if vis.is_empty() or vis[-1] != int(a.get("n", 0)):
			vis.append(int(a.get("n", 0)))
		_mostra(dest[0], dest[1])

func _istruzioni(t: String) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Tema.box(Color(0.02, 0.14, 0.12, 0.95), Tema.VERDE, 1, 4, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(Tema.etichetta("ESEGUI SUL TAVOLO", 13, Tema.VERDE))
	var r := Tema.testo_ricco(19)
	r.text = Dati.testo_bb(t, 22)
	v.add_child(r)
	if contesto and contesto.has_method("istruzione_logbook"):
		var fatti: Array = await contesto.istruzione_logbook(t)
		if not fatti.is_empty():
			var rf := Tema.testo_ricco(17)
			rf.text = "[color=#5be39b][b]FATTO DAL PROGRAMMA[/b][/color] (non ripeterlo sul tavolo)\n" + "\n".join(fatti.map(func(x): return "• " + str(x)))
			v.add_child(rf)
	var rx := RegEx.create_from_string(RX_CARTA)
	var viste := {}
	var hb := HFlowContainer.new()
	hb.add_theme_constant_override("h_separation", 6)
	var catalogo := Dati.carte_per_nome()
	for m in rx.search_all(_pulito(t)):
		var nome := m.get_string(0).to_upper()
		if viste.has(nome) or not catalogo.has(nome):
			continue
		viste[nome] = true
		var b := Tema.pulsante("PRENDI " + nome, func(): chiedi_carta.emit(nome), 13)
		b.tooltip_text = "Porta la carta %s sul tavolo, vicino al Planetopedia" % nome
		hb.add_child(b)
	if hb.get_child_count() > 0:
		v.add_child(hb)
	var fatto := [false]
	var bf := Tema.pulsante_primario("FATTO, PROSEGUI", func(): fatto[0] = true, 16)
	v.add_child(bf)
	# le opzioni precedenti non servono più
	for ch in _corpo.get_children():
		if ch is VBoxContainer or ch is HFlowContainer:
			ch.queue_free()
	_corpo.add_child(p)
	await get_tree().process_frame
	_scroll.ensure_control_visible(p)
	while not fatto[0]:
		await get_tree().process_frame
	p.queue_free()

func _fine_annotazione() -> void:
	_svuota()
	_banner.visible = false
	_titolo.text = "Fine dell'annotazione"
	var r := Tema.testo_ricco(19)
	r.text = "Torna al gioco sul tavolo. Quando una carta o una regola ti rimanda a un'altra annotazione, scrivi il numero qui sopra."
	_corpo.add_child(r)
	_corpo.add_child(Tema.pulsante("TORNA AL TAVOLO", func(): chiuso.emit(), 16))

func _avviso(t: String) -> void:
	var r := Tema.testo_ricco(18)
	r.text = "[color=#ffb347]%s[/color]" % t
	_corpo.add_child(r)
	await get_tree().process_frame
	_scroll.ensure_control_visible(r)
	await get_tree().create_timer(6.0).timeout
	if is_instance_valid(r):
		r.queue_free()
