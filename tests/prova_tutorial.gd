extends SceneTree
## Prima missione (tutorial, Occhio del Vuoto) seguita dal Logbook: le carte PDI devono comparire da sole
## nei settori, l'annotazione del Settore 4 si rilegge a ogni ingresso e la Missione M01 si completa
## quando tutta la squadra è riunita.
## ISS_PROVA=1 ISS_DB_URL=off godot --headless --path . -s res://tests/prova_tutorial.gd

var main
var mis
var errori := 0

func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func aspetta(f := 3) -> void:
	for i in f:
		await process_frame

func verifica(cond: bool, cosa: String) -> void:
	print(("  ok   " if cond else "  ERRORE ") + cosa)
	if not cond:
		errori += 1

func _bottoni(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Button and c.is_visible_in_tree() and not c.disabled:
			out.append(c)
		_bottoni(c, out)

## Va avanti nel Logbook premendo il primo pulsante di scelta o "PROSEGUI" finché l'annotazione finisce.
func leggi_logbook(preferisci := "") -> void:
	for giro in 60:
		await aspetta(4)
		if not mis._logbook.visible:
			return
		var b := []
		_bottoni(mis._logbook._corpo, b)
		if b.is_empty():
			continue
		var scelto: Button = null
		for x in b:
			if preferisci != "" and x.text.contains(preferisci):
				scelto = x
		if scelto == null:
			for x in b:
				if x.text.contains("PROSEGUI"):
					scelto = x
		if scelto == null:
			for x in b:
				if x.text.begins_with("▸") or x.text.contains("FINE DELL'ANNOTAZIONE"):
					scelto = x
					break
		if scelto == null:
			for x in b:
				if x.text.contains("TORNA AL TAVOLO"):
					mis._logbook.visible = false
					return
			continue
		print("    [Logbook %s] %s" % [mis._logbook._numero.text, scelto.text.substr(0, 60)])
		if not (mis._resto_istruzione as Array).is_empty() and scelto.text.contains("PROSEGUI"):
			print("      resta a mano: ", mis._resto_istruzione)
		scelto.pressed.emit()

func _run() -> void:
	var campagna = root.get_node("Campagna")
	campagna.nuova(8, "Prova tutorial", "campagna")
	var Prep = load("res://scripts/ui/preparazione_missione.gd")
	var prep = Prep.new()
	prep.pagina_iniziale = "p.2-3"
	var cfg := {}
	prep.pronta.connect(func(c): cfg.merge(c))
	main.add_child(prep)
	await aspetta()
	prep._conferma()
	await aspetta()
	var E = load("res://scripts/core/esplorazione.gd")
	var e = E.new()
	var Carte = root.get_node("Carte")
	e.prepara(cfg["pagina"], Carte.pianeta(cfg["pagina"]), cfg["squadra"], cfg["lander"], cfg["mazzi"])
	campagna.dati["esplorazione"] = e.s
	var M = load("res://scripts/ui/missione.gd")
	mis = M.new(e.s)
	var cl := CanvasLayer.new()
	main.add_child(cl)
	cl.add_child(mis)
	await aspetta(6)
	mis._logbook.visible = false
	var s: Dictionary = e.s
	print("squadra: ", s["equipaggio"].map(func(m): return "%s nel Settore %d" % [m["carta"], int(m["settore"])]), " missioni ", s["missioni"])
	var n := (s["equipaggio"] as Array).size()

	print("1. Il primo Membro entra nel Settore 5 (Annotazione 227)")
	s["attivo"] = 0
	await mis._muovi(0, 5, [])
	await leggi_logbook()
	verifica(e.pdi_in_cima(5) == "P109", "nel Settore 5 c'è la carta P109 (c'è: '%s')" % e.pdi_in_cima(5))

	print("2. Il primo Membro entra nel Settore 4 (Annotazione 311): la squadra non è riunita")
	await mis._muovi(0, 4, [])
	await leggi_logbook()
	verifica("M01" in s["missioni"], "la Missione M01 è ancora in gioco")

	print("3. Gli altri entrano nel Settore 4: l'annotazione si rilegge a ogni ingresso")
	for i in range(1, n):
		s["attivo"] = i
		await mis._muovi(i, 4, [])
		verifica(mis._logbook.visible, "%s entra: il Logbook si apre di nuovo" % s["equipaggio"][i]["carta"])
		await leggi_logbook()
	verifica(not "M01" in s["missioni"], "la Missione M01 è stata scartata (missioni: %s)" % str(s["missioni"]))
	verifica(e.pdi_in_cima(4) == "P105", "nel Settore 4 c'è la carta P105 (c'è: '%s')" % e.pdi_in_cima(4))
	verifica(int(s["successi"]) >= 1, "c'è almeno 1 Successo (%d)" % int(s["successi"]))
	print("   missioni ora: ", s["missioni"], " — PDI: ", s["settori"].keys().map(func(k): return "%s:%s" % [k, str(s["settori"][k]["pdi"])]))

	print("4. Un Membro rientra nel Settore 4, ora coperto da una carta: il Logbook non si riapre")
	mis._logbook.visible = false
	s["attivo"] = 0
	await mis._muovi(0, 5, [])
	await aspetta()
	mis._logbook.visible = false
	await mis._muovi(0, 4, [])
	await aspetta()
	verifica(not mis._logbook.visible, "nessuna annotazione riletta")

	print("5. Settore 8 senza carta (Annotazione 130): si legge a ogni ingresso")
	mis._logbook.visible = false
	await mis._muovi(0, 8, [])
	verifica(mis._logbook.visible, "il Logbook si apre nel Settore 8")
	await leggi_logbook()
	verifica(e.pdi_in_cima(8) != "", "nel Settore 8 è comparsa una carta (%s)" % e.pdi_in_cima(8))
	print("diario:")
	for t in s["diario"].slice(max(0, s["diario"].size() - 14)):
		print("   ", t)
	print("ERRORI: %d" % errori)
	quit(1 if errori > 0 else 0)
