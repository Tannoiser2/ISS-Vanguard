## Preparazione dell'esplorazione planetaria (Ship Book, pagine 23-24): pianeta, Squadra di Sbarco
## (Membri, Reparto, Grado), Lander, Missioni e Condizione Generale, mazzi. Con il tutorial è tutto pronto.
class_name PreparazioneMissione
extends Control

signal pronta(cfg: Dictionary)
signal annullata

const REPARTI := {"ingegneria": "engineering", "ricognizione": "recon", "scienza": "science", "sicurezza": "security"}
## Tutorial (Regolamento pag. 14): Amir nel Settore 1, il Membro alla sua sinistra nel 2, poi 1 e 2.
const TUTORIAL := [["AMIR ZAYNAB", "scienza", 1], ["CHO JAE-YONG", "ingegneria", 2], ["JOPPE ULRICH", "ricognizione", 1], ["RIKU HASHIMURA", "sicurezza", 2]]

var pagina_iniziale := "p.2-3"
## Dalla Gestione della Nave: {"pagina", "membri": [{nave, carta, file, reparto, grado, cariche, dadi, conv}], "lander"}
var dalla_nave: Dictionary = {}
var _griglia: GridContainer
var _nota_registro: Label
var _pianeta: OptionButton
var _righe := []          # [{membro: OptionButton, reparto: OptionButton, grado: SpinBox, attivo: CheckBox}]
var _lander: OptionButton
var _missioni: LineEdit
var _condizione: LineEdit
var _tutorial: CheckBox
var _equip: Array = []
var _lander_carte: Array = []
var _pianeti: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Tema.tema
	var vel := ColorRect.new()
	vel.color = Color(0, 0.01, 0.03, 0.88)
	vel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vel)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(1100, 0)
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(Tema.etichetta("PREPARAZIONE DELL'ESPLORAZIONE", 22, Tema.TESTO, true))
	# pianeta
	var hp := HBoxContainer.new()
	v.add_child(hp)
	hp.add_child(_lab("Pianeta (Planetopedia)"))
	_pianeta = OptionButton.new()
	_pianeti = Carte.pianeti()
	var sel := 0
	for i in _pianeti.size():
		_pianeta.add_item("%s — pag. %s" % [_pianeti[i]["nome"], _pianeti[i]["pagine"]])
		if _pianeti[i]["stato"] == pagina_iniziale:
			sel = i
	_pianeta.select(sel)
	_pianeta.item_selected.connect(func(_i): _proponi_condizione())
	_pianeta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp.add_child(_pianeta)
	_tutorial = CheckBox.new()
	_tutorial.text = "Mazzi del tutorial"
	_tutorial.button_pressed = pagina_iniziale == "p.2-3"
	hp.add_child(_tutorial)
	# squadra
	v.add_child(Tema.etichetta("SQUADRA DI SBARCO (in solitario almeno 2 Membri di Reparti diversi)", 14, Tema.CIANO))
	_equip = Carte.categoria("equipaggio")
	_equip.sort_custom(func(a, b): return str(a.get("nome", "")) < str(b.get("nome", "")))
	var g := GridContainer.new()
	_griglia = g
	g.columns = 4
	g.add_theme_constant_override("h_separation", 10)
	v.add_child(g)
	for i in 4:
		var att := CheckBox.new()
		att.button_pressed = i < 2   # in solitario bastano 2 Membri
		var om := OptionButton.new()
		om.custom_minimum_size = Vector2(380, 0)
		for e in _equip:
			om.add_item(str(e.get("nome", "?")))
		var rep := OptionButton.new()
		for k in REPARTI:
			rep.add_item(Dati.SEZIONI[k]["nome"])
		var gr := SpinBox.new()
		gr.min_value = 1
		gr.max_value = 3
		gr.prefix = "Grado"
		var t: Array = TUTORIAL[i]
		for j in _equip.size():
			if str(_equip[j].get("nome", "")).to_upper() == t[0]:
				om.select(j)
		rep.select(REPARTI.keys().find(t[1]))
		g.add_child(att)
		g.add_child(om)
		g.add_child(rep)
		g.add_child(gr)
		_righe.append({"membro": om, "reparto": rep, "grado": gr, "attivo": att, "settore": int(t[2])})
	if not dalla_nave.is_empty():
		g.visible = false
		var lst := Label.new()
		lst.text = "\n".join((dalla_nave.get("membri", []) as Array).map(func(m): return "• %s — %s, Grado %d" % [m["carta"], Dati.SEZIONI[m["reparto"]]["nome"], int(m["grado"])]))
		v.add_child(lst)
		_tutorial.button_pressed = false
		for i in _pianeti.size():
			if _pianeti[i]["stato"] == str(dalla_nave.get("pagina", "")):
				_pianeta.select(i)
	# lander
	var hl := HBoxContainer.new()
	v.add_child(hl)
	hl.add_child(_lab("Lander"))
	_lander = OptionButton.new()
	_lander_carte = Carte.categoria("componenti").filter(func(x): return str(x.get("tipo", "")) == "lander_board")
	for k in _lander_carte.size():
		var cm: Dictionary = _lander_carte[k].get("campi", {})
		_lander.add_item("%s — Provviste %s, Scoperte max %s" % [cm.get("nome", "?"), _provviste(cm), int(cm.get("scoperte_max", 0))])
		if str(cm.get("nome", "")).to_upper() == str(dalla_nave.get("lander", "SPACE RANGER")).to_upper():
			_lander.select(k)
	hl.add_child(_lander)
	# Nella campagna non si sceglie niente a mano: la squadra, il Lander e il pianeta sono quelli decisi
	# sulla nave (o quelli del tutorial). Solo l'esplorazione libera, fuori dalla campagna, resta modificabile.
	var tutorial := dalla_nave.is_empty() and pagina_iniziale == "p.2-3"
	if not dalla_nave.is_empty() or tutorial:
		_pianeta.disabled = true
		_lander.disabled = true
		_tutorial.disabled = true
		var spiega := _lab("")
		spiega.custom_minimum_size = Vector2(0, 0)
		spiega.add_theme_color_override("font_color", Tema.TESTO_2)
		spiega.text = "Lander e Squadra decisi sulla nave (Hangar e Alloggi)." if not tutorial else "Tutorial: Membri di Grado 1 e Lander come da Regolamento (pag. 13). Si possono solo scegliere quali Membri giocare (almeno 2)."
		hl.add_child(spiega)
	if tutorial:
		_tutorial.button_pressed = true
		for rr in _righe:
			rr["membro"].disabled = true
			rr["reparto"].disabled = true
			rr["grado"].value = 1
			rr["grado"].editable = false
	# missioni e condizione
	var hm := HBoxContainer.new()
	v.add_child(hm)
	hm.add_child(_lab("Missioni (codici)"))
	_missioni = LineEdit.new()
	_missioni.custom_minimum_size = Vector2(240, 0)
	hm.add_child(_missioni)
	hm.add_child(_lab("Condizione Generale"))
	_condizione = LineEdit.new()
	_condizione.custom_minimum_size = Vector2(240, 0)
	hm.add_child(_condizione)
	_nota_registro = Label.new()
	_nota_registro.add_theme_color_override("font_color", Tema.AMBRA)
	_nota_registro.add_theme_font_size_override("font_size", 15)
	v.add_child(_nota_registro)
	_proponi_condizione()
	var nota := Label.new()
	nota.text = "Missioni e Condizione: il Logbook e la plancia indicano quali carte usare. Il Lander parte nel settore con l'icona Lander."
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.add_theme_color_override("font_color", Tema.TESTO_2)
	nota.add_theme_font_size_override("font_size", 15)
	v.add_child(nota)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_END
	hb.add_theme_constant_override("separation", 10)
	v.add_child(hb)
	hb.add_child(Tema.pulsante("ANNULLA", func():
		annullata.emit()
		queue_free(), 16))
	hb.add_child(Tema.pulsante_primario("ATTERRA", _conferma, 18))

static func _num(x) -> int:
	return int(x) if (x is int or x is float or (x is String and str(x).is_valid_int())) else 0

static func _provviste(cm: Dictionary) -> int:
	var p = cm.get("provviste", 6)
	return int(p.get("base", 6)) if p is Dictionary else int(p)

func _lab(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.custom_minimum_size = Vector2(200, 0)
	return l

func _proponi_condizione() -> void:
	var st: String = _pianeti[_pianeta.selected]["stato"] if not _pianeti.is_empty() else ""
	var pl := Carte.pianeta(st)
	var cd: Dictionary = pl.get("colonna_destra", {}) if pl.get("colonna_destra") is Dictionary else {}
	if _nota_registro:
		var reg: Dictionary = (Campagna.dati.get("pianeti_registrati", {}) as Dictionary).get(st, {})
		if reg.is_empty():
			_nota_registro.text = ""
		else:
			var n_pdi := 0
			for k in reg.get("settori", {}):
				n_pdi += (reg["settori"][k].get("pdi", []) as Array).size()
			_nota_registro.text = "Pianeta già visitato: si ripristinano %d PDI, %d Minacce e le Scoperte Eccezionali rimaste (%s)." % [n_pdi, (reg.get("minacce", []) as Array).size(),
				", ".join((reg.get("eccezionali_pianeta", []) as Array).map(func(x): return str(x))) if not (reg.get("eccezionali_pianeta", []) as Array).is_empty() else "nessuna"]
	var cond = cd.get("condizione", "")
	_condizione.text = cond if cond is String else "(stampata sulla plancia)"
	var mis = cd.get("missione", "")
	_missioni.text = str(mis) if mis is String else ""
	if st == "p.2-3":
		_missioni.text = "M01"
		if _condizione.text == "":
			_condizione.text = "G01"

func _conferma() -> void:
	var st: String = _pianeti[_pianeta.selected]["stato"]
	var squadra := []
	var visti := {}
	for m in dalla_nave.get("membri", []):
		var convs := Fascicoli.conversioni({"converti": m.get("conv", {})})
		var conv: Dictionary = convs[0] if not convs.is_empty() else {}
		squadra.append({"nave": int(m["nave"]), "carta": m["carta"], "file": m["file"], "reparto": m["reparto"], "grado": int(m["grado"]),
			"dadi": m["dadi"], "mazzo": _mazzo_reparto(REPARTI[m["reparto"]], int(m["grado"])), "conv": conv, "conv_extra": convs.slice(1),
			"obiettivo": m.get("obiettivo", {}), "cariche": int(m.get("cariche", 0)), "mano_iniziale": 2})
		visti[m["reparto"]] = true
	for r in _righe:
		if not dalla_nave.is_empty():
			break
		if not r["attivo"].button_pressed:
			continue
		var e: Dictionary = _equip[r["membro"].selected]
		var rep_it: String = REPARTI.keys()[r["reparto"].selected]
		if visti.has(rep_it):
			continue
		visti[rep_it] = true
		var cv: Dictionary = e.get("converti", {}) if e.get("converti") is Dictionary else {}
		var conv := {}
		if not cv.is_empty():
			conv = {"colore": str(cv.get("colore", "")).replace("Die", ""), "a": str(cv.get("a", ""))}
		squadra.append({"carta": str(e.get("nome", "")), "file": str(e.get("file", "")), "reparto": rep_it, "grado": int(r["grado"].value),
			"dadi": Prova.defs()["iniziali"][rep_it], "mazzo": _mazzo_reparto(REPARTI[rep_it], int(r["grado"].value)),
			"conv": conv, "cariche": 0 if _tutorial.button_pressed else int(e.get("cariche", 0)), "mano_iniziale": 2,
			"abilita": e.get("abilita", {})})
		if _tutorial.button_pressed and st == "p.2-3":
			squadra[-1]["settore"] = r["settore"]
	if squadra.size() < 2:
		return
	# attrezzatura caricata sul Lander: piccola una per Membro, quella di Reparto a chi è del Reparto
	var piccole := 0
	for e in dalla_nave.get("equip", []):
		var ce := Carte.per_id(str(e))
		var rep_en := str(ce.get("reparto", "")) if ce.get("reparto") != null else ""
		var dest := 0
		if str(ce.get("tipo", "")) == "smallEquipment":
			dest = piccole % squadra.size()
			piccole += 1
		elif rep_en != "":
			for k in squadra.size():
				if REPARTI[squadra[k]["reparto"]] == rep_en:
					dest = k
		squadra[dest].get_or_add("attrezzatura", []).append(str(e))
	var lc: Dictionary = _lander_carte[_lander.selected] if not _lander_carte.is_empty() else {}
	var cl: Dictionary = lc.get("campi", {})
	var tr: Dictionary = cl.get("traccia_atterraggio", {}) if cl.get("traccia_atterraggio") is Dictionary else {}
	var lander := {"nome": str(cl.get("nome", "Lander")), "provviste": _provviste(cl), "scoperte_max": int(cl.get("scoperte_max", 5)), "file": str(lc.get("file", "")),
		"corazza": _num(cl.get("corazza")), "sensori": _num(cl.get("sensori")), "agilita": _num(cl.get("agilita")),
		"caselle": int(tr.get("caselle", 5)), "partenza": int(tr.get("partenza", 1)),
		"briefing": int(dalla_nave.get("briefing", 0)), "mod": dalla_nave.get("mod", [])}
	# modifiche montate all'Hangar: statistiche, Provviste e Scoperte
	for a in dalla_nave.get("mod", []):
		var cm: Dictionary = Carte.per_id(str(a)).get("campi", {})
		for k in ["corazza", "sensori", "agilita"]:
			lander[k] = int(lander[k]) + _num(cm.get(k))
		lander["provviste"] = int(lander["provviste"]) + _num(cm.get("provviste"))
		lander["scoperte_max"] = int(lander["scoperte_max"]) + _num(cm.get("scoperte_max"))
	var mazzi := {
		"eventi": _eventi(),
		"condizione": _condizione.text.strip_edges().to_upper(),
		"missioni": Array(_missioni.text.to_upper().replace(",", " ").split(" ", false)),
		"scoperte": _scoperte(),
		"indizi": _indizi(),
		"provviste_illimitate": _tutorial.button_pressed and st == "p.2-3",
		"registro": (Campagna.dati.get("pianeti_registrati", {}) as Dictionary).get(st, {}) if not _tutorial.button_pressed else {},
		"tutorial": _tutorial.button_pressed and st == "p.2-3",
	}
	pronta.emit({"pagina": st, "squadra": squadra, "lander": lander, "mazzi": mazzi, "tutorial": _tutorial.button_pressed})
	queue_free()

## Mazzo iniziale del Reparto: le 10 carte con la barra bianca (nel tutorial: le carte tutorial del Reparto).
func _mazzo_reparto(rep: String, grado: int) -> Array:
	var out := []
	for c in Carte.categoria("reparto"):
		if str(c.get("reparto", "")) != rep:
			continue
		var tut: bool = c.get("grado") == null
		if _tutorial.button_pressed:
			if tut:
				out.append(str(c["file"]))
			continue
		if c.get("barra_bianca", false):
			for k in int(c.get("copie", 1)):
				out.append(str(c["file"]))
	return out

func _eventi() -> Array:
	var out := []
	for c in Carte.categoria("eventi"):
		var f := str(c.get("file", ""))
		if (_tutorial.button_pressed and f.contains("tutorial_events")) or (not _tutorial.button_pressed and f.begins_with("carte/events/")):
			for k in int(c.get("copie", 1)):
				out.append(f)
	return out

func _scoperte() -> Dictionary:
	var out := {}
	for c in Carte.categoria("scoperte"):
		var cat := str(c.get("campi", {}).get("categoria", ""))
		if cat == "" or str(c.get("tipo", "")) == "unique_discovery":
			continue
		for k in int(c.get("copie", 1)):
			out.get_or_add(cat, []).append(str(c["file"]))
	return out

func _indizi() -> Array:
	var out := []
	for c in Carte.categoria("componenti"):
		if str(c.get("tipo", "")) != "lead_token":
			continue
		var cm: Dictionary = c.get("campi", {})
		for k in int(cm.get("copie", 1)):
			out.append({"v": int(cm.get("v", 1)), "riciclo": cm.get("riciclo", false), "carta": cm.get("carta", false), "carica": cm.get("carica", false)})
	return out
