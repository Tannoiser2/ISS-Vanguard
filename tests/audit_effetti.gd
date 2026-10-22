extends SceneTree
## Diagnostica: applica ogni testo d'effetto delle carte (esiti, tracce, Eventi, Tempo, Missioni, Scoperte,
## dadi Pericolo, carte Reparto) e conta quelli che il programma lascia "da fare a mano".
## ISS_PROVA=1 ISS_DB_URL=off godot --headless --path . -s res://tests/audit_effetti.gd -- <testi.json> <uscita.json>

var main
var fatto := false

func _initialize() -> void:
	root.size = Vector2i(1280, 800)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func aspetta(n := 2) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var testi: Array = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var campagna = root.get_node("Campagna")
	campagna.nuova(8, "Audit effetti", "campagna")
	var Carte = root.get_node("Carte")
	var E = load("res://scripts/core/esplorazione.gd")
	var e = E.new()
	var sq := [{"nave": -1, "carta": "AMIR ZAYNAB", "file": "", "reparto": "scienza", "grado": 1, "cariche": 2, "dadi": ["base_rosso", "base_blu", "base_verde", "scienceDice", "biology"], "conv": {}, "mazzo": []},
		{"nave": -1, "carta": "CHO JAE-YONG", "file": "", "reparto": "ingegneria", "grado": 1, "cariche": 2, "dadi": ["base_rosso", "base_blu", "base_verde", "construction", "gathering"], "conv": {}, "mazzo": []}]
	e.prepara("p.4-5", Carte.pianeta("p.4-5"), sq, {"nome": "SPACE RANGER", "provviste": 6}, {})
	e.s["briefing_letto"] = true
	var M = load("res://scripts/ui/missione.gd")
	var mis = M.new(e.s)
	var cl := CanvasLayer.new()
	main.add_child(cl)
	cl.add_child(mis)
	await aspetta(5)
	mis.auto_audit = true
	var base: Dictionary = e.s.duplicate(true)
	testi = testi.filter(func(x): return str(x["cat"]) != "minacce/tempo")
	for c in Carte.categoria("minacce"):
		if c.get("tempo") is Array and not (c["tempo"] as Array).is_empty():
			testi.append({"cat": "minaccia_tempo", "src": str((c.get("nomi", [""]) as Array)[0]), "file": str(c["file"]), "en": " / ".join((c["tempo"] as Array).map(func(x): return Carte.en(x)))})
	var out := []
	var n_man := 0
	var n_blocc := 0
	for k in testi.size():
		var t: Dictionary = testi[k]
		e.s.clear()
		e.s.merge(base.duplicate(true))
		mis._occupato = false
		mis.audit_manuali = []
		mis.audit_fatti = []
		mis._logbook.visible = false
		var sett := int(e.membro(0)["settore"])
		fatto = false
		var cat := str(t.get("cat", ""))
		mis._azione_in_corso = ""
		if cat.begins_with("pdi"):
			e.s["settori"][str(sett)]["pdi"] = [str(t["src"])]
			mis._azione_in_corso = "%s#0" % str(t["src"])
		elif cat.begins_with("condizioni"):
			e.s["condizione"] = {"carta": str(t["src"]), "tempo": 0}
			mis._azione_in_corso = "GC#prova"
		elif cat.begins_with("missioni"):
			e.s["missioni"].append(str(t["src"]))
			mis._azione_in_corso = "%s#0" % str(t["src"])
		if cat == "minacce":
			var cm: Dictionary = Carte.categoria("minacce").filter(func(x): return str((x.get("nomi", [""]) as Array)[0]) == str(t["src"]))[0]
			e.s["minacce"] = [{"nome": str(t["src"]), "en": str(t["src"]), "file": str(cm["file"]), "settore": sett, "tempo": 0}]
			mis._azione_in_corso = "M:%s#0" % str(t["src"])
		if cat == "minaccia_tempo":
			_minaccia(mis, e, str(t["file"]), sett)
		elif cat == "reparto":
			e.membro(0)["mano"] = [str(t["file"])]
			_reparto(mis, str(t["file"]), t)
		else:
			_applica(mis, t, sett)
		var f := 0
		while not fatto and f < 120:
			await process_frame
			f += 1
		var r := {"cat": t["cat"], "src": t["src"], "en": t["en"], "manuali": mis.audit_manuali.duplicate(), "fatti": mis.audit_fatti.duplicate()}
		if not fatto:
			r["bloccato"] = true
			n_blocc += 1
			# toglie le finestre rimaste aperte
			for c in mis.get_children():
				if c is ColorRect and c.get_child_count() > 0 and c.get_child(0) is CenterContainer:
					c.queue_free()
		if not (r["manuali"] as Array).is_empty():
			n_man += 1
		out.append(r)
		if k % 50 == 0:
			print("%d/%d" % [k, testi.size()])
	var fa := FileAccess.open(args[1], FileAccess.WRITE)
	fa.store_string(JSON.stringify(out, " "))
	fa.close()
	print("testi: %d, con parti a mano: %d, bloccati: %d" % [testi.size(), n_man, n_blocc])
	print("fine audit")
	quit()

func _applica(mis, t: Dictionary, sett: int) -> void:
	await mis.applica([{"en": str(t["en"]), "it": str(t.get("it", "")), "fonte": str(t["src"])}], 0, sett)
	fatto = true

func _minaccia(mis, e, file: String, sett: int) -> void:
	var c: Dictionary = root.get_node("Carte").per_file(file)
	e.s["minacce"] = [{"nome": str((c.get("nomi", [""]) as Array)[0]), "en": str((c.get("nomi", [""]) as Array)[0]), "file": file, "settore": sett, "tempo": 0}]
	var fatti := []
	var man := []
	var logs := []
	await mis._minacce_avanzano((c["tempo"] as Array).size(), fatti, man, logs)
	mis.audit_manuali.append_array(man)
	fatto = true

func _reparto(mis, file: String, t: Dictionary) -> void:
	if not await mis._gioca_reparto(0, file):
		await mis.applica([{"en": str(t["en"]), "it": str(t.get("it", "")), "fonte": str(t["src"])}], 0, int(mis.esp.membro(0)["settore"]))
	fatto = true
