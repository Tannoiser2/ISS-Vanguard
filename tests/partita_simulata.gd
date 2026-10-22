extends SceneTree
## Partita simulata: un'esplorazione intera giocata da sola (scelte sempre sulla prima opzione, azioni a
## caso fra Viaggio, Azione Speciale con la Prova, Riposo, Preparazione), per trovare blocchi ed errori.
## ISS_PROVA=1 ISS_DB_URL=off godot --headless --path . -s res://tests/partita_simulata.gd -- [pagina] [round] [seme]

var main
var mis
var fatte := {}

func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func aspetta(n := 2) -> void:
	for i in n:
		await process_frame

## Guida la finestra della Prova aperta: tutti i dadi, tiro, risoluzione, applica.
func _guida_prova() -> bool:
	var F = load("res://scripts/ui/finestra_prova.gd")
	for c in mis.get_children():
		if c.get_script() == F:
			for d in mis.esp.dadi_disponibili(c.chi):
				c._scelti[d["id"]] = true
			await c._tira()
			await aspetta()
			c._risolvi()
			await aspetta()
			var bs := []
			_bottoni(c, bs)
			for b in bs:
				if b.text == "APPLICA":
					b.pressed.emit()
					return true
			c.conclusa.emit({"testi": [], "annullata": false})
			c.queue_free()
			return true
	return false

func _bottoni(nd: Node, out: Array) -> void:
	for c in nd.get_children():
		if c is Button:
			out.append(c)
		_bottoni(c, out)

## Aspetta che l'azione in corso finisca, guidando le Prove che si aprono.
func _attendi_azione(nome: String) -> void:
	for k in 600:
		await process_frame
		await _guida_prova()
		if not mis._occupato:
			return
	print("BLOCCO: ", nome, " non finisce (turno di ", mis.esp.membro(int(mis.esp.s["attivo"]))["carta"], ")")
	mis._occupato = false

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var pagina: String = args[0] if args.size() > 0 else "p.4-5"
	var round_max: int = int(args[1]) if args.size() > 1 else 6
	seed(int(args[2]) if args.size() > 2 else 7)
	var campagna = root.get_node("Campagna")
	campagna.nuova(8, "Partita simulata", "campagna")
	var Carte = root.get_node("Carte")
	var E = load("res://scripts/core/esplorazione.gd")
	var e = E.new()
	var sq := []
	var reparti := [["AMIR ZAYNAB", "scienza", ["base_rosso", "base_blu", "base_verde", "scienceDice", "biology"]], ["CHO JAE-YONG", "ingegneria", ["base_rosso", "base_blu", "base_verde", "construction", "gathering"]],
		["LENA FREEMAN", "sicurezza", ["base_rosso", "base_blu", "base_verde", "physical", "defence"]], ["PETRA SEDLÁČKOVÁ", "ricognizione", ["base_rosso", "base_blu", "base_verde", "scouting", "xenology"]]]
	var mazzi := {}
	for k in reparti.size():
		var r: Array = reparti[k]
		var file := ""
		var conv := {}
		for c in Carte.categoria("equipaggio"):
			if str(c.get("nome", "")).to_upper() == str(r[0]):
				file = str(c["file"])
				var cv = c.get("converti", {})
				conv = cv if cv is Dictionary else {}
		var mazzo := []
		for c in Carte.categoria("reparto"):
			if str(c.get("reparto", "")) == {"scienza": "science", "ingegneria": "engineering", "sicurezza": "security", "ricognizione": "recon"}[r[1]] and str(c.get("grado", 1)) in ["1", "1.0", "<null>"] and mazzo.size() < 10:
				mazzo.append(str(c["file"]))
		sq.append({"nave": -1, "carta": r[0], "file": file, "reparto": r[1], "grado": 1, "cariche": 2, "dadi": r[2], "conv": conv, "mazzo": mazzo})
	# preparazione vera (mazzi delle Scoperte, sacchetto degli Indizi, Eventi, Lander) come dalla nave
	var Prep = load("res://scripts/ui/preparazione_missione.gd")
	var prep = Prep.new()
	prep.dalla_nave = {"pagina": pagina, "lander": "SPACE RANGER", "briefing": 0, "mod": [],
		"membri": sq.map(func(x): return {"nave": -1, "carta": x["carta"], "file": x["file"], "reparto": x["reparto"], "grado": 1, "cariche": 2, "dadi": x["dadi"], "conv": x["conv"]})}
	prep.pagina_iniziale = pagina
	var cfg := {}
	prep.pronta.connect(func(c): cfg.merge(c))
	main.add_child(prep)
	await aspetta()
	prep._conferma()
	await aspetta()
	e.prepara(cfg["pagina"], Carte.pianeta(cfg["pagina"]), cfg["squadra"], cfg["lander"], cfg["mazzi"])
	e.s["briefing_letto"] = true
	print("squadra: %d -> equipaggio %d" % [sq.size(), (e.s["equipaggio"] as Array).size()])
	var M = load("res://scripts/ui/missione.gd")
	mis = M.new(e.s)
	var cl := CanvasLayer.new()
	main.add_child(cl)
	cl.add_child(mis)
	await aspetta(5)
	mis.auto_audit = true
	mis._logbook.visible = false
	var turni := 0
	while int(e.s["round"]) <= round_max and str(e.s.get("finita", "")) == "" and turni < 80:
		turni += 1
		var chi := int(e.s["attivo"])
		for a in 2:
			if str(e.s.get("finita", "")) != "" or int(e.s["azioni"]) <= 0:
				break
			var sett := int(e.membro(chi)["settore"])
			var scelte := ["viaggio", "riposo", "preparazione"]
			var azs: Array = mis._azioni_settore(sett)
			if not azs.is_empty() and not e.s["speciale_usata"]:
				scelte += ["speciale", "speciale"]
			if e.dadi_disponibili(chi).size() < 2:
				scelte = ["riposo"] if int(e.s["lander"]["provviste"]) > 0 else ["sforzo"]
			var s: String = scelte[randi() % scelte.size()]
			fatte[s] = int(fatte.get(s, 0)) + 1
			match s:
				"viaggio": mis._viaggio()
				"riposo": mis._riposo()
				"preparazione": mis._preparazione()
				"sforzo": mis._sforzo()
				"speciale":
					var v: Dictionary = azs[randi() % azs.size()]
					mis._esegui_azione(v["azione"], v["fonte"], v["chiave"], sett)
			await _attendi_azione(s)
		mis._fine_turno()
		await _attendi_azione("fine turno")
	print("round %d, turni %d, finita: '%s', successi %d, scoperte %d, provviste %d" % [int(e.s["round"]), turni, str(e.s.get("finita", "")), int(e.s["successi"]), (e.s["scoperte"] as Array).size(), int(e.s["lander"]["provviste"])])
	print("azioni: ", fatte)
	for i in e.s["equipaggio"].size():
		var m: Dictionary = e.membro(i)
		print("  %s sett %d dadi %d/%d ferite %s%s" % [m["carta"], int(m["settore"]), e.dadi_disponibili(i).size(), (m["dadi"] as Array).size(), str(m["ferite"]), " MORTO" if m["morto"] else ""])
	var ind := 0
	for t in e.s["indizi"]:
		ind += (e.s["indizi"][t] as Array).size()
	print("indizi sui mazzi: %d, sacchetto %d" % [ind, (e.s["sacchetto"] as Array).size()])
	print("righe di diario con Indizi: ", (e.s["diario"] as Array).filter(func(x): return str(x).contains("Indizi")).size())
	print("diario (ultime righe):")
	for r in (e.s["diario"] as Array).slice(-12):
		print("  ", r)
	print("fine simulazione")
	quit()
