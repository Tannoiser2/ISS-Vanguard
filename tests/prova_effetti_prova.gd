extends SceneTree
## Effetti che si risolvono dentro la Prova: traccia per ogni Membro che assiste (P283), traccia che fa
## avanzare un'altra traccia (P113), dado Pericolo aggiunto alla Riserva (G07), sacrificare un dado per
## ritirarne uno (P532), Missione completata da sola (M23).
## ISS_PROVA=1 ISS_DB_URL=off godot --headless --path . -s res://tests/prova_effetti_prova.gd

var main
var mis
var e
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

func _azione(id: String) -> Dictionary:
	var Carte = root.get_node("Carte")
	return (Carte.per_id(id).get("azioni", []) as Array)[0]

func _finestra(az: Dictionary, chiave: String, dadi_virtuali: Array, assistenti := []) -> Object:
	var F = load("res://scripts/ui/finestra_prova.gd")
	var f = F.new()
	f.esp = e
	f.chi = 0
	f.fonte = "Prova"
	f.chiave_tracce = chiave
	f.settore = int(e.membro(0)["settore"])
	f.azione = az
	mis.add_child(f)
	await aspetta(3)
	f._pool = []
	for k in dadi_virtuali.size():
		f._pool.append({"id": "t%d" % k, "tipo": "virtuale", "icone": dadi_virtuali[k], "faccia": 0, "chi": 0})
	for j in assistenti:
		var d: Dictionary = e.membro(j)["dadi"][0]
		f._pool.append({"id": d["id"], "tipo": d["tipo"], "faccia": d.get("faccia", 0), "chi": j})
	return f

func _run() -> void:
	var campagna = root.get_node("Campagna")
	campagna.nuova(8, "Prova effetti", "campagna")
	var Carte = root.get_node("Carte")
	var E = load("res://scripts/core/esplorazione.gd")
	var e0 = E.new()
	var sq := [{"nave": -1, "carta": "AMIR ZAYNAB", "file": "carte/amir/amir_34404.webp", "reparto": "scienza", "grado": 1, "cariche": 2, "dadi": ["base_rosso", "base_blu", "base_verde", "scienceDice", "biology"], "conv": {}, "mazzo": []},
		{"nave": -1, "carta": "CHO JAE-YONG", "file": "", "reparto": "ingegneria", "grado": 1, "cariche": 2, "dadi": ["base_rosso", "base_blu", "base_verde", "construction", "gathering"], "conv": {}, "mazzo": []},
		{"nave": -1, "carta": "LENA FREEMAN", "file": "", "reparto": "sicurezza", "grado": 1, "cariche": 2, "dadi": ["base_rosso", "base_blu", "base_verde", "physical", "defence"], "conv": {}, "mazzo": []}]
	e0.prepara("p.4-5", Carte.pianeta("p.4-5"), sq, {"nome": "SPACE RANGER", "provviste": 6}, {})
	e0.s["briefing_letto"] = true
	for i in 3:
		e0.membro(i)["settore"] = e0.membro(0)["settore"]
	var M = load("res://scripts/ui/missione.gd")
	mis = M.new(e0.s)
	var cl := CanvasLayer.new()
	main.add_child(cl)
	cl.add_child(mis)
	await aspetta(5)
	e = mis.esp
	var sett := int(e.membro(0)["settore"])
	# --- P283: [outcomeGreenProgress] per ogni Membro che assiste (2 assistenti)
	var f = await _finestra(_azione("P283"), "P283#prova", [["basic"]], [1, 2])
	f._risolvi()
	await aspetta(3)
	ok(e.traccia("P283#prova#green", sett) == 2, "P283: traccia verde +2 con 2 Membri che assistono (%d)" % e.traccia("P283#prova#green", sett))
	f.queue_free()
	# --- P113: la traccia gialla completata fa avanzare la verde e dà 2 Indizi
	var ind0 := 0
	for t in e.s["indizi"]:
		ind0 += (e.s["indizi"][t] as Array).size()
	f = await _finestra(_azione("P113"), "P113#prova", [["gathering"], ["gathering"]])
	f._risolvi()
	await aspetta(3)
	var testi_f: Array = []
	ok(e.traccia("P113#prova#green", sett) >= 1, "P113: la traccia gialla completa fa avanzare la verde (%d; più l'effetto [die])" % e.traccia("P113#prova#green", sett))
	f.queue_free()
	# --- G07: dado Pericolo C aggiunto alla Riserva come effetto speciale della Condizione Generale
	var g07: Dictionary = Carte.per_id("G07")
	f = await _finestra({"nome": {"en": "TEST", "it": "PROVA"}, "prova": true, "pericolo": [], "speciali": [], "tracce": [],
		"esiti": [{"colore": "green", "req": "", "en": "Nothing happens.", "it": "Non succede nulla."}]}, "T#1", [["biology"]])
	f.speciali_globali = [g07["effetto_speciale"]]
	f._risolvi()
	await aspetta(3)
	ok(f._pool.any(func(d): return d["tipo"] == "pericolo" and str(d["lettera"]) == "C"), "G07: tirato il dado Pericolo C e aggiunto alla Riserva")
	f.queue_free()
	# --- P532: sacrificare un dado (fuori dal tiro) per ritirare 1 dado
	f = await _finestra(_azione("P532"), "P532#prova", [["basic"]])
	var mods: Array = f._modificatori().filter(func(x): return x["tipo"] == "sacrifica_ritira")
	ok(not mods.is_empty(), "P532: l'effetto «sacrifica un dado per ritirarne uno» è fra i modificatori")
	var sac0: int = e.membro(0)["dadi"].filter(func(d): return d["stato"] == "sacrificato").size()
	if not mods.is_empty():
		f._usa_modificatore(mods[0])
		await aspetta(3)
	ok(e.membro(0)["dadi"].filter(func(d): return d["stato"] == "sacrificato").size() == sac0 + 1, "P532: un dado sacrificato")
	ok(not f._sel_mod.is_empty() and str(f._sel_mod.get("modo", "")) == "ritira", "P532: si sceglie il dado da ritirare")
	f.queue_free()
	await aspetta(2)
	# --- M23: con le Scoperte Eccezionali 2 e 3 la Missione si completa da sola
	e.s["missioni"] = ["M23"]
	e.s["eccezionali"] = [2, 3]
	var succ0 := int(e.s["successi"])
	mis._occupato = true
	mis._finisci()
	for k in 20:
		await aspetta()
		for c in mis.get_children():
			if c is ColorRect and c.get_child_count() > 0 and c.get_child(0) is CenterContainer and not c.is_queued_for_deletion():
				var bs := []
				_bottoni(c, bs)
				if not bs.is_empty():
					bs[0].pressed.emit()
	ok(not "M23" in e.s["missioni"], "M23: Missione completata da sola")
	ok(int(e.s["successi"]) == succ0 + 1, "M23: +1 Successo (%d → %d)" % [succ0, int(e.s["successi"])])
	print("errori: %d" % errori)
	quit()

func _bottoni(nd: Node, out: Array) -> void:
	for c in nd.get_children():
		if c is Button:
			out.append(c)
		_bottoni(c, out)
