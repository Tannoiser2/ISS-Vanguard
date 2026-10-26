extends SceneTree
## Abilità che prendono una carta (Carles: dallo Scomparto del Reparto; Riku: dalla pila degli scarti)
## usate durante una Prova, e i loro Obiettivi individuali (Assistere con quella carta / usarne la
## Combinazione nella stessa Prova).
## ISS_PROVA=1 ISS_DB_URL=off godot --headless --path . -s res://tests/prova_abilita_carte.gd

var main
var mis
var errori := 0

func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func aspetta(n := 2) -> void:
	for i in n:
		await process_frame

func ok(cond: bool, t: String) -> void:
	print(("ok   " if cond else "ERRORE ") + t)
	if not cond:
		errori += 1

func _bottoni(nd: Node, out: Array) -> void:
	for c in nd.get_children():
		if c is Button:
			out.append(c)
		_bottoni(c, out)

## Risponde alla finestra di scelta aperta premendo l'opzione che soddisfa il filtro (o la prima).
func _rispondi(filtro := "") -> void:
	for k in 30:
		await aspetta()
		for c in mis.get_children():
			if c is ColorRect and c.get_child_count() > 0 and c.get_child(0) is CenterContainer and not c.is_queued_for_deletion():
				var bs := []
				_bottoni(c, bs)
				bs = bs.filter(func(b): return b.text != "ANNULLA")
				var sc = bs[0]
				for b in bs:
					for fl in filtro.split("|"):
						if fl != "" and str(b.text).contains(fl):
							sc = b
				sc.pressed.emit()
				if str(sc.text).contains("(Grado"):
					return

func _run() -> void:
	var campagna = root.get_node("Campagna")
	campagna.nuova(8, "Prova abilità", "campagna")
	var Carte = root.get_node("Carte")
	var E = load("res://scripts/core/esplorazione.gd")
	var e = E.new()
	var sq := [{"nave": -1, "carta": "AMIR ZAYNAB", "file": "carte/amir/amir_34404.webp", "reparto": "scienza", "grado": 1, "cariche": 2, "dadi": ["base_rosso", "base_blu", "base_verde", "scienceDice", "biology"], "conv": {}, "mazzo": []},
		{"nave": -1, "carta": "CARLES PORRA", "file": "carte/crewmembers/carles_34503.webp", "reparto": "ingegneria", "grado": 1, "cariche": 1, "dadi": ["base_rosso", "base_blu", "base_verde", "construction", "gathering"], "conv": {}, "mazzo": []},
		{"nave": -1, "carta": "RIKU HASHIMURA", "file": "carte/riku/riku_34407.webp", "reparto": "sicurezza", "grado": 1, "cariche": 2, "dadi": ["base_rosso", "base_blu", "base_verde", "physical", "defence"], "conv": {}, "mazzo": []}]
	e.prepara("p.4-5", Carte.pianeta("p.4-5"), sq, {"nome": "SPACE RANGER", "provviste": 6}, {})
	e.s["briefing_letto"] = true
	for i in 3:
		e.membro(i)["settore"] = e.membro(0)["settore"]
	e.membro(1)["obiettivo"] = {"file": "carte/veteran_carles/veteran_carles_35802.webp", "traccia": 0}
	e.membro(2)["obiettivo"] = {"file": "carte/veteran_riku/veteran_riku_35819.webp", "traccia": 0}
	var M = load("res://scripts/ui/missione.gd")
	mis = M.new(e.s)
	var cl := CanvasLayer.new()
	main.add_child(cl)
	cl.add_child(mis)
	await aspetta(5)
	e = mis.esp
	# carte Reparto "durante una Prova" dello Scomparto di Ingegneria
	var rep_ing: Array = Carte.categoria("reparto").filter(func(c): return str(c.get("reparto", "")) == "engineering" and str(c.get("quando", "")) == "during_check")
	ok(not rep_ing.is_empty(), "ci sono carte Ingegneria da usare durante una Prova")
	# --- Carles assiste Amir con una carta presa dallo Scomparto durante la Prova
	var F = load("res://scripts/ui/finestra_prova.gd")
	var f = F.new()
	f.esp = e
	f.chi = 0
	f.fonte = "Prova"
	f.settore = int(e.membro(0)["settore"])
	f.azione = {"nome": {"en": "TEST", "it": "PROVA"}, "prova": true, "pericolo": [], "speciali": [], "tracce": [],
		"esiti": [{"colore": "green", "req": "vanguard", "en": "Nothing happens.", "it": "Non succede nulla."}, {"colore": "red", "req": "", "en": "Nothing happens.", "it": "Non succede nulla."}]}
	mis.add_child(f)
	await aspetta(3)
	for d in e.dadi_disponibili(0):
		f._scelti[d["id"]] = true
	await f._tira()
	await aspetta(2)
	var mods: Array = f._modificatori()
	var ab_c := mods.filter(func(x): return x["tipo"] == "abilita_carta" and int(x["chi"]) == 1)
	ok(not ab_c.is_empty(), "l'abilità di Carles si può usare durante la Prova")
	var nome_carta: String = "|".join(rep_ing.map(func(c): return Carte.titolo(c)))
	# chiude le finestre già aperte (scelte d'inizio esplorazione)
	for k in 10:
		await aspetta()
		for c in mis.get_children():
			if c is ColorRect and c.get_child_count() > 0 and c.get_child(0) is CenterContainer and not c.is_queued_for_deletion():
				var bs := []
				_bottoni(c, bs)
				bs[0].pressed.emit()
	f._usa_modificatore(ab_c[0])
	await _rispondi(nome_carta)
	await aspetta(3)
	var mano_c: Array = e.membro(1)["mano"]
	ok(mano_c.size() == 1, "Carles ha preso una carta in mano (%s)" % (Carte.titolo(Carte.per_file(str(mano_c[0]))) if not mano_c.is_empty() else "-"))
	ok(int(e.membro(1)["cariche"]) == 0, "Carles ha speso la Carica")
	var mods2: Array = f._modificatori().filter(func(x): return x["tipo"] == "carta" and int(x["chi"]) == 1)
	ok(not mods2.is_empty(), "la carta presa si può usare per assistere")
	if not mods2.is_empty():
		f._usa_modificatore(mods2[0])
		await aspetta(3)
	ok(e.membro(1).get("veterano", false) or (e.membro(1).get("obiettivo", {}) as Dictionary).is_empty(), "Obiettivo di Carles compiuto: è un Veterano")
	f.queue_free()
	await aspetta(2)
	# --- Riku riprende dagli scarti una carta con Combinazione e la usa nella stessa Prova
	var con_combo: Array = Carte.categoria("reparto").filter(func(c): return str(c.get("reparto", "")) == "security" and c.get("combo") is Dictionary and str(c["combo"].get("req", "")) != "" and not str(c["combo"]["req"]).contains("any"))
	ok(not con_combo.is_empty(), "ci sono carte Sicurezza con Combinazione")
	var cc: Dictionary = con_combo[0]
	e.membro(2)["scarti"] = [str(cc["file"])]
	var f2 = F.new()
	f2.esp = e
	f2.chi = 2
	f2.fonte = "Prova"
	f2.settore = int(e.membro(2)["settore"])
	f2.azione = f.azione.duplicate(true) if is_instance_valid(f) else {"nome": {"en": "TEST", "it": "PROVA"}, "prova": true, "pericolo": [], "speciali": [], "tracce": [],
		"esiti": [{"colore": "green", "req": "vanguard", "en": "Nothing happens.", "it": "Non succede nulla."}, {"colore": "red", "req": "", "en": "Nothing happens.", "it": "Non succede nulla."}]}
	mis.add_child(f2)
	await aspetta(3)
	for d in e.dadi_disponibili(2):
		f2._scelti[d["id"]] = true
	await f2._tira()
	await aspetta(2)
	var ab_r: Array = f2._modificatori().filter(func(x): return x["tipo"] == "abilita_carta" and int(x["chi"]) == 2)
	ok(not ab_r.is_empty() and str(ab_r[0]["da"]) == "scarti", "l'abilità di Riku (dagli scarti) si può usare durante la Prova")
	f2._usa_modificatore(ab_r[0])
	await _rispondi()
	await aspetta(3)
	ok(str(cc["file"]) in e.membro(2)["mano"], "Riku ha ripreso %s dagli scarti" % Carte.titolo(cc))
	# la Combinazione: si forza un tiro che la soddisfa usando dadi virtuali
	var req := str(cc["combo"]["req"])
	print("  combinazione: ", req)
	for ic in req.replace("[", "").replace("]", "").split("+"):
		f2._pool.append({"id": "t%d" % f2._pool.size(), "tipo": "virtuale", "icone": [ic.strip_edges()], "faccia": 0, "chi": 2})
	f2._combo_scelte[str(cc["file"])] = true
	f2._risolvi()
	await aspetta(5)
	var ob_r = e.membro(2).get("obiettivo", {})
	ok(e.membro(2).get("veterano", false) or (ob_r is Dictionary and int(ob_r.get("traccia", 0)) >= 1), "Obiettivo di Riku avanzato (combinazione della carta ripresa)")
	print("errori: %d" % errori)
	quit()
