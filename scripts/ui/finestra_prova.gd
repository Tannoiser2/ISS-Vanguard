## Finestra della Prova di dadi: scelta dei dadi (anche di chi assiste), tiro, modifiche,
## combinazioni delle carte Reparto e della Condizione Generale, effetti speciali ed esito.
## Alla fine emette 'conclusa' con gli effetti da applicare.
class_name FinestraProva
extends Control

signal conclusa(risultato: Dictionary)   # {"testi": [{"en","it"}], "tracce": {...}, "annullata": bool}

var esp: Esplorazione
var chi := 0
var azione: Dictionary
var fonte := ""            # descrizione della fonte (titolo della carta)
var chiave_tracce := ""    # chiave per le tracce di questa azione nel settore
var settore := 0
var speciali_globali: Array = []   # effetti speciali della Condizione Generale (si applicano a tutte le prove)

var _scelti := {}          # id dado -> true
var _assist := {}          # indice membro -> [id dadi]
var _assist_abilita := {}  # indice membro -> "2" / "tutti" / "lontano": abilità "When Assisting" usata
var _assist_restituiti := {}   # indice membro -> true: i dadi di assistenza tornano disponibili
var _pool: Array = []      # dadi tirati (copie con "chi")
var _pet := false          # P.E.T. (E23) assiste con il suo dado
var _fase := 0             # 0 scelta, 1 dopo il tiro
var _corpo: VBoxContainer
var _titolo: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Tema.tema
	var vel := ColorRect.new()
	vel.color = Color(0, 0.01, 0.03, 0.8)
	vel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vel)
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = Vector2(1180, 760)
	p.position = Vector2(-590, -380)
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	_titolo = Tema.etichetta("PROVA", 22, Tema.TESTO, true)
	_titolo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_titolo)
	h.add_child(Tema.pulsante("ANNULLA", func():
		conclusa.emit({"annullata": true})
		queue_free(), 13))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_corpo = VBoxContainer.new()
	_corpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_corpo.add_theme_constant_override("separation", 12)
	sc.add_child(_corpo)
	_titolo.text = ("%s — %s" % [Carte.t(azione.get("nome", "")), fonte]).to_upper()
	_mostra_scelta()

func _svuota() -> void:
	for c in _corpo.get_children():
		c.queue_free()

func _conv(i: int) -> Array:
	var out := []
	var c: Dictionary = esp.membro(i).get("conv", {})
	if not c.is_empty():
		out.append({"colore": str(c.get("colore", "")).replace("Die", ""), "a": str(c.get("a", ""))})
	# attrezzatura con un'abilità di conversione ("[blueDie basic] = [construction]")
	var rx := RegEx.create_from_string("\\[(red|blue|green)Die basic\\]\\s*=\\s*\\[(\\w+)\\]")
	for e in esp.membro(i).get("attrezzatura", []):
		var m := rx.search(Carte.en(Carte.per_id(str(e)).get("effetto", "")))
		if m:
			out.append({"colore": m.get_string(1), "a": m.get_string(2)})
	# Laser Minerario Pesante (E35) nel settore: ogni icona tranne [accident] e [basic] vale [gathering]
	if _token(settore, "E35") != {}:
		out.append({"da": "qualsiasi", "a": "gathering"})
	return out

## Segnalino di attrezzatura di missione con quell'id nel settore n ({} se non c'è).
func _token(n: int, id: String) -> Dictionary:
	for t in esp.s["settori"].get(str(n), {}).get("attrezzature", []):
		if str(t["id"]) == id:
			return t
	return {}

## Torretta Modulare (E62) nel settore o in uno collegato.
func _torretta() -> Dictionary:
	var pl := Carte.pianeta(str(esp.s.get("pagina", "")))
	for n in [settore] + esp.collegati(pl, settore):
		var t := _token(n, "E62")
		if t != {}:
			t["_settore"] = n
			return t
	return {}

## Carte Reparto, attrezzatura e abilità utilizzabili "durante una Prova" (passo 4).
var _usati: Array = []
func _modificatori() -> Array:
	var out := []
	var m := esp.membro(chi)
	var presenti := esp.nel_settore(int(m["settore"]))
	for j in presenti:
		var mj := esp.membro(j)
		for c in mj["mano"]:
			var carta := Carte.per_file(str(c))
			if str(carta.get("quando", "")) in ["during_check", "when_assisting"] and (j == chi or str(carta.get("quando", "")) == "during_check"):
				out.append({"tipo": "carta", "chi": j, "id": str(c), "titolo": Carte.titolo(carta), "testo": Carte.t(carta.get("effetto", ""))})
	for e in m.get("attrezzatura", []):
		var ce := Carte.per_id(str(e))
		if str(ce.get("quando", "")) == "during_check":
			out.append({"tipo": "attrezzatura", "chi": chi, "id": str(e), "titolo": Carte.titolo(ce), "testo": Carte.t(ce.get("effetto", ""))})
	for k in esp.s["scoperte"].size():
		var sc := Carte.per_file(str(esp.s["scoperte"][k]["carta"]))
		var pe = sc.get("campi", {}).get("esplorazione")
		if pe is Dictionary and Carte.en(pe).to_lower().begins_with("during dice check, you may place this card"):
			out.append({"tipo": "scoperta", "chi": chi, "id": str(esp.s["scoperte"][k]["carta"]), "titolo": "Scoperta " + Carte.titolo(sc), "testo": Carte.t(pe)})
	var cm := Carte.per_file(str(m.get("file", "")))
	var ab = cm.get("abilita", {})
	if ab is Dictionary and (Carte.en(ab).to_lower().begins_with("during a dice check") or str(ab.get("quando", "")).to_lower().contains("dice check")):
		out.append({"tipo": "abilita", "chi": chi, "id": "abilita", "titolo": "Abilità " + str(ab.get("nome", "")), "testo": Carte.t(ab)})
	var tor := _torretta()
	if tor != {} and int(tor.get("marcatori", 0)) > 0:
		if chiave_tracce.begins_with("M:"):
			out.append({"tipo": "torretta", "chi": chi, "id": "E62", "titolo": "Torretta Modulare", "testo": "Scarta 1 segnalino dalla Torretta (ne ha %d) per aggiungere [vanguard] alla Riserva del Tiro." % int(tor["marcatori"])})
		if _token(int(tor["_settore"]), "E63") != {} and _pool.any(func(d): return d["tipo"] == "pericolo"):
			out.append({"tipo": "scudo", "chi": chi, "id": "E63", "titolo": "Unità Scudo", "testo": "Scarta 1 segnalino dalla Torretta (ne ha %d) per togliere tutti i dadi Pericolo da questa Prova." % int(tor["marcatori"])})
	return out.filter(func(x): return not (str(x["tipo"]) + str(x["chi"]) + str(x["id"])) in _usati)

func _mostra_modificatori() -> void:
	var mods := _modificatori()
	if mods.is_empty():
		return
	_corpo.add_child(Tema.etichetta("4. MODIFICA I RISULTATI (carte, attrezzatura, abilità)", 15, Tema.CIANO))
	for x in mods:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var r := Tema.testo_ricco(15)
		r.fit_content = true
		r.scroll_active = false
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.text = "[b]%s[/b]%s: %s" % [x["titolo"], (" (" + str(esp.membro(int(x["chi"]))["carta"]) + ")") if int(x["chi"]) != chi else "", Dati.testo_carta(str(x["testo"]), 18)]
		h.add_child(r)
		var xx: Dictionary = x
		var b := Tema.pulsante("USA", func(): _usa_modificatore(xx), 13)
		if x["tipo"] == "abilita" and int(esp.membro(chi)["cariche"]) <= 0 and str(x["testo"]).to_lower().contains("caric"):
			b.disabled = true
			b.tooltip_text = "Nessuna Carica"
		h.add_child(b)
		_corpo.add_child(h)

func _usa_modificatore(x: Dictionary) -> void:
	var j := int(x["chi"])
	match str(x["tipo"]):
		"torretta", "scudo":
			var tor := _torretta()
			tor["marcatori"] = int(tor["marcatori"]) - 1
			if x["tipo"] == "torretta":
				_pool.append({"id": "v%d" % _pool.size(), "tipo": "virtuale", "icone": ["vanguard"], "faccia": 0, "chi": chi})
				_resoconto_mod.append("Torretta Modulare: +[vanguard] nella Riserva del Tiro")
			else:
				_pool = _pool.filter(func(d): return d["tipo"] != "pericolo")
				_resoconto_mod.append("Unità Scudo: tolti i dadi Pericolo")
		"carta":
			esp.scarta_carta(j, str(x["id"]))
		"attrezzatura":
			if Carte.en(Carte.per_id(str(x["id"])).get("effetto", "")).to_lower().contains("return this card to the armory"):
				(esp.membro(j)["attrezzatura"] as Array).erase(str(x["id"]))
		"abilita":
			if str(x["testo"]).to_lower().contains("caric"):
				esp.membro(j)["cariche"] = max(0, int(esp.membro(j)["cariche"]) - 1)
		"scoperta":
			# la Scoperta torna in fondo al suo mazzo e le sue icone si aggiungono alla Riserva del Tiro
			for k in esp.s["scoperte"].size():
				if str(esp.s["scoperte"][k]["carta"]) == str(x["id"]):
					var sc: Dictionary = esp.s["scoperte"][k]
					esp.s["scoperte"].remove_at(k)
					esp.s["mazzi_scoperte"].get_or_add(str(sc["tipo"]), []).insert(0, sc["carta"])
					break
			var pe = Carte.per_file(str(x["id"])).get("campi", {}).get("esplorazione", {})
			var ma := RegEx.create_from_string("(?i)add ((?:\\[\\w+\\]\\s*\\+?\\s*)+) to this roll pool").search(Carte.en(pe))
			if ma:
				var icone := RegEx.create_from_string("\\[(\\w+)\\]").search_all(ma.get_string(1)).map(func(y): return y.get_string(1))
				_pool.append({"id": "v%d" % _pool.size(), "tipo": "virtuale", "icone": icone, "faccia": 0, "chi": chi})
				_resoconto_mod.append("%s: +%s nella Riserva del Tiro" % [x["titolo"], "+".join(icone)])
	_usati.append(str(x["tipo"]) + str(x["chi"]) + str(x["id"]))
	_resoconto_mod.append("%s: %s" % [x["titolo"], "usata"])
	esp.diario("%s usa %s" % [esp.membro(j)["carta"], x["titolo"]])
	# alcuni effetti si applicano da soli
	var en := ""
	match str(x["tipo"]):
		"carta": en = Carte.en(Carte.per_file(str(x["id"])).get("effetto", ""))
		"attrezzatura": en = Carte.en(Carte.per_id(str(x["id"])).get("effetto", ""))
		_: en = Carte.en(Carte.per_file(str(esp.membro(j).get("file", ""))).get("abilita", {}))
	var rr := RegEx.create_from_string("(?i)reroll (?:any number of|all|up to \\d+) \\[(die|redDie|blueDie|greenDie)\\]").search(en)
	if rr:
		var col: String = {"die": "", "redDie": "red", "blueDie": "blue", "greenDie": "green"}[rr.get_string(1)]
		for d in _pool:
			if d["tipo"] in ["ferita", "pericolo", "virtuale"]:
				continue
			if (col == "" or Prova.colore(d) == col) and not _utile(d):
				Prova.tira(d, esp.rng)
		_resoconto_mod.append("Ritirati i dadi %s che non servivano" % ({"": "", "red": "rossi", "blue": "blu", "green": "verdi"}[col]))
	_mostra_tiro()

## Un dado è "utile" se una sua icona compare in un requisito dell'azione.
func _utile(d: Dictionary) -> bool:
	var req := ""
	for e in azione.get("esiti", []):
		req += " " + str(e.get("req", ""))
	for sp in azione.get("speciali", []):
		req += " " + str(sp.get("req", ""))
	for ic in Prova.icone(d):
		if ic == "vanguard" or req.contains(str(ic)):
			return true
	return false

var _resoconto_mod: Array = []

# ------------------------------------------------------------------ 1. scelta dei dadi

func _mostra_scelta() -> void:
	_svuota()
	_corpo.add_child(_riquadro_azione())
	var m := esp.membro(chi)
	_corpo.add_child(Tema.etichetta("1. SCEGLI I DADI DI %s" % str(m["carta"]).to_upper(), 15, Tema.CIANO))
	var riga := HFlowContainer.new()
	riga.add_theme_constant_override("h_separation", 8)
	for d in esp.dadi_disponibili(chi):
		riga.add_child(_chip_dado(d, true, func(on): if on: _scelti[d["id"]] = true else: _scelti.erase(d["id"])))
	if riga.get_child_count() == 0:
		riga.add_child(Tema.etichetta("Nessun dado disponibile", 14, Tema.AMBRA))
	_corpo.add_child(riga)
	var tutti := Tema.pulsante("TUTTI", func():
		for d in esp.dadi_disponibili(chi):
			_scelti[d["id"]] = true
		_mostra_scelta(), 12)
	_corpo.add_child(tutti)
	# chi è nello stesso settore può assistere con un dado (le abilità "When Assisting" cambiano le regole)
	var da_lontano: Variant = m.get("attrezzatura", []).any(func(e): return Carte.en(Carte.per_id(str(e)).get("effetto", "")).contains("may Assist you from other Sectors"))
	var altri := esp.vivi().filter(func(j): return j != chi and (int(esp.membro(j)["settore"]) == int(m["settore"]) or da_lontano or (_abilita_assist(j) == "lontano" and int(esp.membro(j)["cariche"]) > 0)))
	if not altri.is_empty():
		_corpo.add_child(Tema.etichetta("ASSISTENZA (UN DADO CIASCUNO)", 15, Tema.CIANO))
		for j in altri:
			var jj: int = j
			var r := HFlowContainer.new()
			r.add_theme_constant_override("h_separation", 8)
			var l := Label.new()
			l.text = str(esp.membro(j)["carta"]) + ":"
			l.custom_minimum_size = Vector2(160, 0)
			r.add_child(l)
			var ab := _abilita_assist(j)
			var lontano: bool = int(esp.membro(j)["settore"]) != int(m["settore"]) and not da_lontano
			var limite := 1
			if _assist_abilita.has(jj):
				limite = 2 if ab == "2" else (99 if ab == "tutti" else 1)
			var scelti: Array = _assist.get_or_add(jj, [])
			for d in esp.dadi_disponibili(j):
				var idd: String = d["id"]
				r.add_child(_chip_dado(d, idd in scelti, func(on):
					if on and not idd in scelti:
						if scelti.size() >= limite:
							scelti.pop_front()
						scelti.append(idd)
					elif not on:
						scelti.erase(idd)
					_mostra_scelta()))
			if ab != "" and (ab != "lontano" or lontano) and int(esp.membro(j)["cariche"]) > 0:
				var cb := CheckBox.new()
				cb.text = {"2": "Abilità: assiste con 2 dadi (1 Carica)", "tutti": "Abilità: assiste con quanti dadi vuole (1 Carica)", "lontano": "Abilità: assiste da un altro settore (1 Carica)"}[ab]
				cb.button_pressed = _assist_abilita.has(jj) or lontano
				cb.disabled = lontano
				cb.toggled.connect(func(on):
					if on: _assist_abilita[jj] = ab
					else: _assist_abilita.erase(jj)
					_mostra_scelta())
				if lontano:
					_assist_abilita[jj] = ab
				r.add_child(cb)
			_corpo.add_child(r)
	var pet := _token(int(m["settore"]), "E23")
	if pet != {} and pet.get("dado") is Dictionary and not (pet["dado"] as Dictionary).is_empty():
		var cbp := CheckBox.new()
		cbp.text = "P.E.T. assiste con il suo dado (%s)" % str(pet["dado"].get("tipo", ""))
		cbp.button_pressed = _pet
		cbp.toggled.connect(func(on): _pet = on)
		_corpo.add_child(cbp)
	var info := Tema.testo_ricco(17)
	var extra := []
	if int(m["dadi_ferita"]) > 0:
		extra.append("%d dado/i Ferita" % int(m["dadi_ferita"]))
	for p in azione.get("pericolo", []):
		extra.append("dado Pericolo " + str(p).trim_prefix("dangerDie"))
	if not extra.is_empty():
		info.text = "[color=#ffb347]Si aggiungono: %s.[/color]" % ", ".join(extra)
		_corpo.add_child(info)
	_corpo.add_child(Tema.pulsante_primario("TIRA I DADI", _tira, 18))

## Abilità "When Assisting" del Membro j: "2", "tutti", "lontano" o "".
func _abilita_assist(j: int) -> String:
	var en := Carte.en(Carte.per_file(str(esp.membro(j).get("file", ""))).get("abilita", {}))
	if not en.begins_with("When Assisting"):
		return ""
	if en.contains("with 2 [die]"):
		return "2"
	if en.contains("any number of [die]"):
		return "tutti"
	if en.contains("in any Sector"):
		return "lontano"
	return ""

func _chip_dado(d: Dictionary, premuto: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = premuto or _scelti.has(d["id"])
	b.custom_minimum_size = Vector2(64, 64)
	b.focus_mode = Control.FOCUS_NONE
	var col: Color = {"red": Color("b0263a"), "blue": Color("1683c8"), "green": Color("3f9a36")}.get(Prova.colore(d), Color(0.5, 0.5, 0.5))
	b.add_theme_stylebox_override("normal", Tema.box(col.darkened(0.45), col, 2, 6, 4))
	b.add_theme_stylebox_override("pressed", Tema.box(col, Color.WHITE, 3, 6, 4))
	b.add_theme_stylebox_override("hover", Tema.box(col.darkened(0.2), Color.WHITE, 2, 6, 4))
	b.tooltip_text = "%s (%s)" % [d["tipo"], ", ".join(Prova.defs()["reparto"].get(d["tipo"], {}).get("facce", []).map(func(f): return "+".join(f)))]
	b.text = _sigla(d["tipo"])
	b.add_theme_font_size_override("font_size", 13)
	b.toggled.connect(cb)
	return b

static func _sigla(t: String) -> String:
	return {"base_rosso": "BASE", "base_blu": "BASE", "base_verde": "BASE"}.get(t, t.substr(0, 5).to_upper())

# ------------------------------------------------------------------ 2-3. tiro

func _tira() -> void:
	_pool = []
	var m := esp.membro(chi)
	for d in esp.dadi_disponibili(chi):
		if _scelti.has(d["id"]):
			var c: Dictionary = d.duplicate()
			c["chi"] = chi
			Prova.tira(c, esp.rng)
			_pool.append(c)
	for j in _assist:
		if (_assist[j] as Array).is_empty():
			continue
		if _assist_abilita.has(j):
			esp.membro(j)["cariche"] = max(0, int(esp.membro(j)["cariche"]) - 1)
			_resoconto_mod.append("%s usa la sua abilità per assistere" % esp.membro(j)["carta"])
			if Carte.en(Carte.per_file(str(esp.membro(j).get("file", ""))).get("abilita", {})).contains("return those [die] to your Available dice"):
				_assist_restituiti[j] = true
		for d in esp.dadi_disponibili(j):
			if d["id"] in _assist[j]:
				var c: Dictionary = d.duplicate()
				c["chi"] = j
				Prova.tira(c, esp.rng)
				_pool.append(c)
	var pet := _token(int(m["settore"]), "E23")
	if _pet and pet != {} and pet.get("dado") is Dictionary:
		var cp: Dictionary = (pet["dado"] as Dictionary).duplicate()
		cp["id"] = "pet"
		cp["chi"] = chi
		Prova.tira(cp, esp.rng)
		_pool.append(cp)
		_resoconto_mod.append("P.E.T. assiste con un dado")
	var n_ferita := int(m["dadi_ferita"])
	var icone_sett := esp.icone_settore(Carte.pianeta(str(esp.s.get("pagina", ""))), int(m["settore"]), {}) if n_ferita > 0 else []
	for e in m.get("attrezzatura", []):
		var en := Carte.en(Carte.per_id(str(e)).get("effetto", ""))
		var mr := RegEx.create_from_string("(?i)roll (\\d+) injury dic?e less in sectors with (.*)").search(en)
		if mr:
			var biomi := RegEx.create_from_string("\\[(\\w+)\\]").search_all(mr.get_string(2)).map(func(x): return x.get_string(1))
			if biomi.any(func(b): return b in icone_sett):
				n_ferita -= int(mr.get_string(1))
				_resoconto_mod.append("%s: %s dado Ferita in meno" % [Carte.titolo(Carte.per_id(str(e))), mr.get_string(1)])
		if en.to_lower().contains("ignore 1 injury die per roll") and n_ferita > 0:
			n_ferita -= 1
			_resoconto_mod.append("%s: un dado Ferita ignorato" % Carte.titolo(Carte.per_id(str(e))))
	for k in max(0, n_ferita):
		var f := {"id": "f%d" % k, "tipo": "ferita", "faccia": 0, "chi": chi}
		Prova.tira(f, esp.rng)
		_pool.append(f)
	var n := 0
	for p in azione.get("pericolo", []):
		n += 1
		var d := {"id": "p%d" % n, "tipo": "pericolo", "faccia": 0, "chi": chi, "lettera": str(p).trim_prefix("dangerDie")}
		Prova.tira(d, esp.rng)
		_pool.append(d)
	_fase = 1
	_mostra_tiro()

func _mostra_tiro() -> void:
	_svuota()
	_corpo.add_child(_riquadro_azione())
	_corpo.add_child(Tema.etichetta("RISULTATO DEL TIRO", 15, Tema.CIANO))
	var r := HFlowContainer.new()
	r.add_theme_constant_override("h_separation", 10)
	for d in _pool:
		r.add_child(_faccia(d))
	_corpo.add_child(r)
	var nota := Label.new()
	nota.text = "Clic su un dado per ritirarlo o cambiarne il risultato, come permette la carta o l'abilità usata."
	nota.add_theme_color_override("font_color", Tema.TESTO_2)
	nota.add_theme_font_size_override("font_size", 14)
	_corpo.add_child(nota)
	if not _resoconto_mod.is_empty():
		var rm := Tema.testo_ricco(14)
		rm.fit_content = true
		rm.scroll_active = false
		rm.text = "[color=#5be39b]" + " · ".join(_resoconto_mod) + "[/color]"
		_corpo.add_child(rm)
	_mostra_modificatori()
	_mostra_combinazioni()
	_corpo.add_child(Tema.pulsante_primario("RISOLVI LA PROVA", _risolvi, 18))

func _faccia(d: Dictionary) -> Control:
	var v := VBoxContainer.new()
	var b := Button.new()
	b.custom_minimum_size = Vector2(72, 72)
	b.focus_mode = Control.FOCUS_NONE
	var col: Color = {"red": Color("b0263a"), "blue": Color("1683c8"), "green": Color("3f9a36")}.get(Prova.colore(d), Color("e8c21a") if d["tipo"] == "ferita" else Color("f0901a"))
	b.add_theme_stylebox_override("normal", Tema.box(col, Color.WHITE, 2, 8, 2))
	b.add_theme_stylebox_override("hover", Tema.box(col.lightened(0.2), Color.WHITE, 3, 8, 2))
	var ic := Prova.icone(d)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for x in ic:
		var p := Dati.icona(x)
		if p != "":
			var t := TextureRect.new()
			t.texture = load(p)
			t.custom_minimum_size = Vector2(30, 30) if ic.size() > 1 else Vector2(46, 46)
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(t)
		else:
			var l := Label.new()
			l.text = x
			h.add_child(l)
	if ic.is_empty():
		var l2 := Label.new()
		l2.text = "—"
		h.add_child(l2)
	b.add_child(h)
	b.pressed.connect(_menu_dado.bind(d))
	v.add_child(b)
	var l3 := Label.new()
	l3.text = ("dado " + d.get("lettera", "")) if d["tipo"] == "pericolo" else ("Ferita" if d["tipo"] == "ferita" else str(esp.membro(int(d["chi"]))["carta"]).get_slice(" ", 0))
	l3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l3.add_theme_font_size_override("font_size", 12)
	v.add_child(l3)
	return v

func _menu_dado(d: Dictionary) -> void:
	var pm := PopupMenu.new()
	pm.add_item("Ritira", 0)
	var facce := Prova.numero_facce(d)
	for f in facce:
		var ic := Prova.icone({"tipo": d["tipo"], "faccia": f})
		pm.add_item("Gira su: " + ("+".join(ic) if not ic.is_empty() else "vuota"), 10 + f)
	pm.id_pressed.connect(func(id):
		if id == 0:
			Prova.tira(d, esp.rng)
		else:
			d["faccia"] = id - 10
		_mostra_tiro())
	add_child(pm)
	pm.popup(Rect2i(get_global_mouse_position(), Vector2i(10, 10)))

# ------------------------------------------------------------------ combinazioni (passo 5)

var _combo_scelte := {}   # id carta -> true

func _mostra_combinazioni() -> void:
	var m := esp.membro(chi)
	var conv := _conv(chi)
	var righe := []
	for c in m["mano"]:
		var carta := Carte.per_file(str(c))
		var combo: Dictionary = carta.get("combo", {})
		if combo.is_empty() or str(combo.get("req", "")) == "":
			continue
		var ok: bool = Prova.soddisfa_req(str(combo["req"]), _pool, conv)["ok"]
		righe.append([c, carta, combo, ok])
	if righe.is_empty():
		return
	_corpo.add_child(Tema.etichetta("COMBINAZIONI DELLE CARTE REPARTO IN MANO", 15, Tema.CIANO))
	for r in righe:
		var cb := CheckBox.new()
		cb.text = "%s — %s: %s" % [Carte.titolo(r[1]), r[2].get("req", ""), Carte.t(r[2])]
		cb.disabled = not r[3]
		cb.button_pressed = _combo_scelte.has(r[0])
		cb.toggled.connect(func(on): if on: _combo_scelte[r[0]] = true else: _combo_scelte.erase(r[0]))
		_corpo.add_child(cb)

# ------------------------------------------------------------------ risoluzione (passi 5-10)

func _risolvi() -> void:
	var conv := _conv(chi)
	var vietati := {}
	var testi := []   # effetti da applicare in ordine
	var resoconto := []
	var m := esp.membro(chi)
	# 5. combinazioni scelte
	for c in _combo_scelte:
		var carta := Carte.per_file(str(c))
		var combo: Dictionary = carta.get("combo", {})
		var r := Prova.soddisfa_req(str(combo.get("req", "")), _pool, conv, vietati)
		if r["ok"]:
			for id in r["dadi"]:
				vietati[id] = true
			testi.append({"en": Carte.en(combo), "it": Carte.t(combo), "fonte": Carte.titolo(carta)})
			esp.scarta_carta(chi, str(c))
			resoconto.append("Combinazione: " + Carte.titolo(carta))
	# 6. dadi Ferita: ognuno va sulla prima carta Ferita (da sinistra) libera con la sua icona
	var ignora := []
	for e in m.get("attrezzatura", []):
		if Carte.en(Carte.per_id(str(e)).get("effetto", "")).contains("Ignore all Wounded and Critically Wounded Injury effects"):
			ignora = ["wounded", "critically_wounded"]
	var carte_ferita := (m["ferite"] as Array).map(func(t): return {} if str(t) in ignora else _carta_ferita(str(t)))
	var occupate := {}
	var ferita_tracce := {}
	var ferita_esito := ""
	for d in _pool:
		if d["tipo"] != "ferita":
			continue
		var ic := Prova.icone(d)
		var applicato := false
		for k in carte_ferita.size():
			if occupate.has(k):
				continue
			for ef in carte_ferita[k].get("effetti", []):
				if str(ef.get("icona", "")) in ic:
					occupate[k] = true
					applicato = true
					var en := str(ef.get("en", ""))
					resoconto.append("Dado Ferita %s su %s: %s" % ["+".join(ic), Carte.titolo(carte_ferita[k]), Carte.t(ef)])
					if en.contains("outcomeRedProgress"):
						if (azione.get("tracce", []) as Array).is_empty():
							ferita_esito = "red"
						else:
							ferita_tracce["red"] = int(ferita_tracce.get("red", 0)) + 1
					elif en.to_lower().begins_with("reroll 1 [vanguard]"):
						for dd in _pool:
							if dd["tipo"] not in ["ferita", "pericolo"] and "vanguard" in Prova.icone(dd):
								Prova.tira(dd, esp.rng)
								resoconto.append("ritirato un Vanguard: ora %s" % "+".join(Prova.icone(dd)))
								break
					elif en.to_lower().contains("count as [accident]"):
						for dd in _pool:
							if dd["tipo"] not in ["ferita", "pericolo", "virtuale"]:
								dd["bruciato"] = true
						resoconto.append("%s: i risultati [basic] contano come [accident]" % Carte.titolo(carte_ferita[k]))
					else:
						testi.append({"en": en, "it": Carte.t(ef), "fonte": "Ferita " + Carte.titolo(carte_ferita[k])})
					break
			if applicato:
				break
		if not applicato:
			resoconto.append("Dado Ferita: %s (nessuna carta corrisponde)" % ("+".join(ic) if not ic.is_empty() else "vuoto"))
	for d in _pool:
		if d["tipo"] == "ferita":
			pass
		elif d["tipo"] == "pericolo":
			var e := Prova.effetto_pericolo(str(d["lettera"]), d)
			var ic2 := Prova.icone(d)
			if str(d["lettera"]).substr(0, 1) in ["A", "B", "C", "D", "E", "F", "G", "H", "I", "T"]:
				resoconto.append("Dado Pericolo %s: %s → %s" % [d["lettera"], "+".join(ic2) if not ic2.is_empty() else "vuoto", e if e != "" else "nessun effetto"])
				if e != "":
					testi.append({"en": e, "it": _it_pericolo(e), "fonte": "dado Pericolo"})
			else:
				resoconto.append("Dado Pericolo %s: %s (tabella sulla carta o nell'annotazione)" % [d["lettera"], "+".join(ic2) if not ic2.is_empty() else "vuoto"])
				testi.append({"en": "", "it": "Dado Pericolo %s: risultato %s — applica l'effetto indicato per questa lettera." % [d["lettera"], "+".join(ic2) if not ic2.is_empty() else "vuoto"], "manuale": true})
	# 7. effetti speciali (prima quelli della Condizione Generale)
	var esito_immediato := ferita_esito
	var tutte := speciali_globali + (azione.get("speciali", []) as Array)
	var ris := Prova.risolvi_speciali(tutte, _pool, conv, vietati)
	var tracce := ferita_tracce.duplicate()
	for x in ris:
		var riga: Dictionary = tutte[x["riga"]]
		var eff = riga.get("effetto", "")
		var volte: int = x["volte"]
		if eff is String:
			var e := str(eff)
			for parte in e.split("+"):
				parte = parte.strip_edges()
				if parte.begins_with("outcome") and parte.ends_with("Progress"):
					var col := parte.trim_prefix("outcome").trim_suffix("Progress").to_lower()
					tracce[col] = int(tracce.get(col, 0)) + volte
				elif parte.begins_with("outcome") and parte.ends_with("Reduction"):
					var col2 := parte.trim_prefix("outcome").trim_suffix("Reduction").to_lower()
					tracce[col2] = int(tracce.get(col2, 0)) - volte
				elif parte in ["outcomeGreen", "outcomeYellow", "outcomeRed"]:
					esito_immediato = parte.trim_prefix("outcome").to_lower()
				elif parte != "":
					for k in volte:
						testi.append({"en": parte, "it": parte, "fonte": "effetto speciale"})
		else:
			for k in volte:
				testi.append({"en": Carte.en(eff), "it": Carte.t(eff), "fonte": "effetto speciale"})
		resoconto.append("Effetto speciale \"%s\" ×%d" % [riga.get("req", ""), volte])
		if esito_immediato != "":
			break
	# 8-10. esito o tracce
	var esiti: Array = azione.get("esiti", [])
	var colore_esito := ""
	if esito_immediato != "":
		colore_esito = esito_immediato
	elif not (azione.get("tracce", []) as Array).is_empty():
		pass
	elif not esiti.is_empty():
		var e2 := Prova.scegli_esito(esiti, _pool, conv, vietati)
		if e2["riga"] >= 0:
			colore_esito = str(esiti[e2["riga"]].get("colore", ""))
			var r0: Dictionary = esiti[e2["riga"]]
			testi.append({"en": r0.get("en", ""), "it": r0.get("it", ""), "fonte": "esito " + colore_esito})
			_segui(esiti, r0, testi)
			resoconto.append("Esito: %s" % _nome_colore(colore_esito))
		else:
			resoconto.append("Nessun esito (manca la riga rossa)")
	if colore_esito != "" and esito_immediato != "":
		for r1 in esiti:
			if str(r1.get("colore", "")) == colore_esito:
				testi.append({"en": r1.get("en", ""), "it": r1.get("it", ""), "fonte": "esito " + colore_esito})
				_segui(esiti, r1, testi)
				break
		for t1 in azione.get("tracce", []):
			if str(t1.get("colore", "")) == colore_esito:
				testi.append({"en": t1.get("en", ""), "it": t1.get("it", ""), "fonte": "traccia " + colore_esito})
		resoconto.append("Esito immediato: %s" % _nome_colore(colore_esito))
	# tracce: avanzano e si risolvono quelle complete
	var tr_finite := []
	for t2 in azione.get("tracce", []):
		var col3 := str(t2.get("colore", ""))
		var k := "%s#%s" % [chiave_tracce, col3]
		var v := esp.traccia(k, settore) if false else esp.traccia(k, settore)
		if tracce.has(col3):
			v = esp.avanza_traccia(settore, k, int(tracce[col3]), int(t2.get("caselle", 1)))
			resoconto.append("Traccia %s: %d/%d" % [_nome_colore(col3), v, int(t2.get("caselle", 1))])
		if v >= int(t2.get("caselle", 1)) and esito_immediato == "":
			tr_finite.append(t2)
			esp.avanza_traccia(settore, k, -99, int(t2.get("caselle", 1)))
	for t3 in tr_finite:
		testi.append({"en": t3.get("en", ""), "it": t3.get("it", ""), "fonte": "traccia " + str(t3.get("colore", ""))})
		# freccia verso un'altra traccia: si risolve anche quella
		var sg := str(t3.get("segue", ""))
		for t4 in azione.get("tracce", []):
			if sg != "" and str(t4.get("colore", "")) == sg and not t4 in tr_finite:
				testi.append({"en": t4.get("en", ""), "it": t4.get("it", ""), "fonte": "traccia " + sg})
	# 9. tutti i dadi di Reparto tirati vanno nei Dadi Spesi
	for d in _pool:
		if d["tipo"] in ["ferita", "pericolo", "virtuale"]:
			continue
		var j := int(d["chi"])
		for dd in esp.membro(j)["dadi"]:
			if dd["id"] == d["id"]:
				dd["stato"] = "disponibile" if _assist_restituiti.has(j) else "speso"
				dd["faccia"] = d["faccia"]
	if _token(settore, "E35") != {}:
		var r_n := 0
		for dd in m["dadi"]:
			if dd["stato"] == "speso" and Prova.colore(dd) == "red":
				dd["stato"] = "disponibile"
				r_n += 1
		if r_n > 0:
			resoconto.append("Laser Minerario Pesante: %d dadi rossi ricaricati" % r_n)
	resoconto = _resoconto_mod + resoconto
	esp.diario("%s: %s" % [m["carta"], "; ".join(resoconto)])
	_mostra_riepilogo(resoconto, testi)

const CARTE_FERITA := {"wounded": "Wounded", "panicked": "Panicked", "freezing": "Freezing", "exhausted": "Exhausted",
	"critically_wounded": "Critically Wounded", "burned": "Burned", "just_a_scratch": "Just a Scratch!"}

static func _carta_ferita(tipo: String) -> Dictionary:
	var nome: String = CARTE_FERITA.get(tipo, "Wounded")
	for c in Carte.categoria("ferite_gradi"):
		if nome in c.get("nomi", []):
			return c
	return {}

func _segui(esiti: Array, r: Dictionary, testi: Array) -> void:
	var s := str(r.get("segue", ""))
	if s == "":
		return
	for r2 in esiti:
		if str(r2.get("colore", "")) == s and r2 != r:
			testi.append({"en": r2.get("en", ""), "it": r2.get("it", ""), "fonte": "esito " + s})
			return

static func _nome_colore(c: String) -> String:
	return {"green": "verde", "yellow": "giallo", "red": "rosso"}.get(c, c)

static func _it_pericolo(e: String) -> String:
	return e.replace("[spendDie]", "Spendi un dado").replace("Gain a Wounded Injury", "Subisci la Ferita Ferito") \
		.replace("Gain a Burned Injury", "Subisci la Ferita Ustione").replace("Gain an Exhausted Injury", "Subisci la Ferita Allo Stremo") \
		.replace("Gain a Panicked Injury", "Subisci la Ferita Panico").replace("Lose 1 Supplies", "Perdi 1 Provvista")

func _mostra_riepilogo(resoconto: Array, testi: Array) -> void:
	_svuota()
	_corpo.add_child(Tema.etichetta("ESITO DELLA PROVA", 15, Tema.CIANO))
	var r := Tema.testo_ricco(18)
	r.text = "\n".join(resoconto.map(func(x): return "• " + str(x)))
	_corpo.add_child(r)
	if not testi.is_empty():
		_corpo.add_child(Tema.etichetta("EFFETTI DA APPLICARE", 15, Tema.VERDE))
		for t in testi:
			var rt := Tema.testo_ricco(18)
			rt.text = "[b]%s[/b]: %s" % [str(t.get("fonte", "")), Dati.testo_carta(str(t.get("it", ""))) if str(t.get("it", "")) != "" else "(nessun testo)"]
			_corpo.add_child(rt)
	_corpo.add_child(Tema.pulsante_primario("APPLICA", func():
		conclusa.emit({"testi": testi, "annullata": false})
		queue_free(), 18))

func _riquadro_azione() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Tema.box(Color(0.03, 0.08, 0.15), Tema.CIANO_SCURO, 1, 4, 12))
	var r := Tema.testo_ricco(17)
	var righe := []
	for s in speciali_globali:
		righe.append("[color=#ffb347]Condizione:[/color] %s = %s" % [_req(str(s.get("req", ""))), _eff(s.get("effetto", ""))])
	for s in azione.get("speciali", []):
		righe.append("[b]Speciale:[/b] %s = %s" % [_req(str(s.get("req", ""))), _eff(s.get("effetto", ""))])
	for e in azione.get("esiti", []):
		righe.append("[color=%s]■[/color] %s → %s" % [_col(str(e.get("colore", ""))), _req(str(e.get("req", ""))) if str(e.get("req", "")) != "" else "(sempre)", Dati.testo_carta(str(e.get("it", ""))) ])
	for t in azione.get("tracce", []):
		var k := "%s#%s" % [chiave_tracce, str(t.get("colore", ""))]
		righe.append("[color=%s]▶[/color] Traccia %d/%d → %s" % [_col(str(t.get("colore", ""))), esp.traccia(k, settore), int(t.get("caselle", 1)), Dati.testo_carta(str(t.get("it", "")))])
	r.text = "\n".join(righe)
	p.add_child(r)
	return p

func _req(s: String) -> String:
	var parti := []
	for alt in s.split("/"):
		var x := []
		for tok in alt.split("+"):
			tok = tok.strip_edges()
			var n := 1
			if tok.contains("*"):
				n = int(tok.get_slice("*", 0))
				tok = tok.get_slice("*", 1)
			for k in n:
				x.append("[%s]" % tok)
		parti.append(Dati.testo_carta("+".join(x), 20))
	return " / ".join(parti)

func _eff(e) -> String:
	if e is String:
		return _req(e) if not str(e).contains(" ") else Dati.testo_carta(str(e))
	return Dati.testo_carta(Carte.t(e))

static func _col(c: String) -> String:
	return {"green": "#5be39b", "yellow": "#ffd23f", "red": "#ff5a6e"}.get(c, "#9fbbd6")
