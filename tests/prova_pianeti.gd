extends SceneTree
## Pianeti registrati: si lascia un pianeta e ci si torna (PDI, Minacce, Scoperte Eccezionali).
## ISS_PROVA=1 ISS_DB_URL=off godot --headless --path . -s res://tests/prova_pianeti.gd

var errori := 0

func ok(c: bool, msg: String) -> void:
	print(("ok   " if c else "ERRORE ") + msg)
	if not c:
		errori += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var Carte = root.get_node("Carte")
	var E = load("res://scripts/core/esplorazione.gd")
	var squadra := [{"carta": "A", "reparto": "scienza", "grado": 1, "dadi": ["base_rosso"], "mazzo": []},
		{"carta": "B", "reparto": "ingegneria", "grado": 1, "dadi": ["base_blu"], "mazzo": []}]
	var pl: Dictionary = Carte.pianeta("p.18-19")
	var e = E.new()
	e.prepara("p.18-19", pl, squadra, {"nome": "SPACE RANGER", "provviste": 6}, {})
	ok(e.s["eccezionali_pianeta"] == [17, 34], "Scoperte Eccezionali della plancia: 17, 34")
	e.piazza_pdi(2, "P210")
	e.piazza_pdi(4, "P199")          # ha l'icona noSave: non si registra
	e.s["settori"]["3"]["finito"] = true
	e.s["minacce"].append({"nome": "Insetto", "en": "Flower Bug", "file": "carte/flower_bug/" + _file(Carte, "Flower Bug"), "settore": 5, "tempo": 2})
	e.s["minacce"].append({"nome": "Lucciola", "en": "Scintillating Shardfly", "file": "carte/scintillating_shardfly/scintillating_shardfly_7900.webp", "settore": 1, "tempo": 1})
	e.s["eccezionali_pianeta"].pop_back()   # presa la 34
	var reg: Dictionary = e.registra(func(id): return Carte.per_id(id), func(m): return Carte.per_file(str(m["file"])))
	ok(reg["settori"]["2"]["pdi"] == ["P210"], "registrato il PDI P210 nel Settore 2")
	ok((reg["settori"]["4"]["pdi"] as Array).is_empty(), "P199 (noSave) non registrato")
	ok(reg["minacce"].size() == 1 and reg["minacce"][0]["en"] == "Flower Bug", "registrata solo la Minaccia senza noSave")
	ok(reg["eccezionali_pianeta"] == [17], "resta la Scoperta Eccezionale 17")
	var e2 = E.new()
	e2.prepara("p.18-19", pl, squadra, {"nome": "SPACE RANGER", "provviste": 6}, {"registro": JSON.parse_string(JSON.stringify(reg))})
	ok(e2.pdi_in_cima(2) == "P210", "al ritorno il Settore 2 ha P210")
	ok(e2.s["settori"]["3"]["finito"], "il Settore 3 resta finito")
	ok(e2.s["minacce"].size() == 1 and int(e2.s["minacce"][0]["settore"]) == 5 and int(e2.s["minacce"][0]["tempo"]) == 0, "la Minaccia torna nel suo settore con il Tempo azzerato")
	ok(e2.s["eccezionali_pianeta"] == [17], "Scoperte Eccezionali rimaste: 17")
	print("errori: ", errori)
	quit()

func _file(Carte, nome: String) -> String:
	for c in Carte.categoria("minacce"):
		if nome in c.get("nomi", []) and str(c.get("lato", "")) == "fronte":
			return str(c["file"]).get_file()
	return ""
