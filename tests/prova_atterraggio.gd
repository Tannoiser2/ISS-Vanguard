extends SceneTree
## Atterraggio guidato dal Logbook, risposte automatiche e Minacce che si muovono e colpiscono.
## ISS_PROVA=1 ISS_DB_URL=off godot --headless --path . -s res://tests/prova_atterraggio.gd

var main
var mis
var errori := 0

func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func ok(c: bool, msg: String) -> void:
	print(("ok   " if c else "ERRORE ") + msg)
	if not c:
		errori += 1

func aspetta(f := 2) -> void:
	for i in f:
		await process_frame

## Chiude le finestre aperte dalla missione (primo pulsante).
func chiudi() -> void:
	for k in 30:
		await aspetta()
		var fin = null
		for c in mis.get_children():
			if c is ColorRect and c.get_child_count() > 0 and c.get_child(0) is CenterContainer:
				fin = c
		if fin == null:
			if not mis._occupato:
				return
			continue
		var b := []
		_bottoni(fin, b)
		b = b.filter(func(x): return x.text != "ANNULLA")
		if not b.is_empty():
			b[0].pressed.emit()

func _bottoni(nd: Node, out: Array) -> void:
	for c in nd.get_children():
		if c is Button and c.is_visible_in_tree():
			out.append(c)
		_bottoni(c, out)

func _run() -> void:
	var campagna = root.get_node("Campagna")
	campagna.nuova(8, "Prova atterraggio", "campagna")
	var Prep = load("res://scripts/ui/preparazione_missione.gd")
	var prep = Prep.new()
	prep.dalla_nave = {"pagina": "p.4-5", "lander": "SPACE RANGER", "briefing": 315, "mod": ["A01"],
		"membri": [{"nave": 0, "carta": "AMIR ZAYNAB", "file": "", "reparto": "scienza", "grado": 1, "cariche": 2, "dadi": ["base_rosso", "base_blu", "base_verde", "scienceDice", "biology"], "conv": {}},
			{"nave": 1, "carta": "CHO JAE-YONG", "file": "", "reparto": "ingegneria", "grado": 1, "cariche": 2, "dadi": ["base_rosso", "base_blu", "base_verde", "construction", "gathering"], "conv": {}}]}
	prep.pagina_iniziale = "p.4-5"
	var cfg := {}
	prep.pronta.connect(func(c): cfg.merge(c))
	main.add_child(prep)
	await aspetta()
	prep._conferma()
	await aspetta()
	ok(cfg["lander"]["corazza"] == 4, "Space Ranger con Corazzatura pesante: Corazza 2+2 = %d" % cfg["lander"]["corazza"])
	var E = load("res://scripts/core/esplorazione.gd")
	var e = E.new()
	var Carte = root.get_node("Carte")
	e.prepara(cfg["pagina"], Carte.pianeta(cfg["pagina"]), cfg["squadra"], cfg["lander"], cfg["mazzi"])
	var M = load("res://scripts/ui/missione.gd")
	mis = M.new(e.s)
	var cl := CanvasLayer.new()
	main.add_child(cl)
	cl.add_child(mis)
	await aspetta(5)
	ok(mis._logbook.visible, "all'inizio si apre il briefing (Annotazione 315)")
	# sequenza di atterraggio
	var f1 = await mis.istruzione_logbook("Sulla plancia Lander, posiziona un segnaposto nella casella iniziale\n(indicata con una “S” sul contatore dell’Atterraggio).")
	ok(int(e.s["lander"]["contatore"]) == 3, "contatore sulla casella iniziale dello Space Ranger (3): %s" % str(f1))
	ok(mis.rispondi_logbook("Il segnaposto ha raggiunto la casella “Atterraggio Riuscito”\ndel contatore dell’Atterraggio?") == 0, "non ancora atterrati")
	var prima := int(e.s["lander"]["provviste"])
	await mis.istruzione_logbook("Perdi 4 Provviste meno{i:landerArmor}.")
	ok(int(e.s["lander"]["provviste"]) == prima, "4 Provviste meno Corazza 4 = nessuna perdita")
	await mis.istruzione_logbook("Fai avanzare il contatore dell’Atterraggio (sposta il segnaposto di 1 casella verso destra)")
	await mis.istruzione_logbook("Fai avanzare il contatore dell’Atterraggio di due")
	ok(mis.rispondi_logbook("il segnaposto sul contatore dell’Atterraggio si trova sulla casella “Atterraggio Riuscito”") == 1, "atterraggio riuscito (5/5)")
	ok(mis.rispondi_logbook("il segnaposto sul contatore dell’Atterraggio non si trova sulla casella “Atterraggio Riuscito”?") == 0, "domanda negata")
	ok(mis.rispondi_logbook("{i:landerArmor} è 4 o più?") == 1, "Corazza 4 o più")
	ok(mis.rispondi_logbook("{i:landerSensors} è maggiore o uguale a 6?") == 0, "Sensori < 6")
	ok(mis.rispondi_logbook("Il tuo Lander ha almeno 4 {i:landerArmor} e 1 {i:landerSensors}?") == 1, "almeno 4 Corazza e 1 Sensori")
	ok(mis.rispondi_logbook("ti trovi nel Settore [b]%d[/b]?" % int(e.membro(0)["settore"])) == 1, "posizione del Membro di turno")
	await mis.istruzione_logbook("•Ottieni 1 {i:success} e la Scoperta Eccezionale [b]28[/b].")
	ok(int(e.s["successi"]) == 1 and 28 in e.s["eccezionali"], "Successo e Scoperta Eccezionale dal Logbook")
	await mis.istruzione_logbook("Ciascun Membro dell’Equipaggio ottiene una Ferita Lesione.")
	ok(e.membro(0)["ferite"].size() == 1 and e.membro(1)["ferite"].size() == 1, "una Ferita a ciascuno")
	# Minacce
	var mn: Array = mis._trova_minaccia("Flower Bug")
	ok(not mn.is_empty(), "carta Minaccia Flower Bug trovata")
	var lontano := 1
	for k in e.s["settori"]:
		if int(k) != int(e.membro(0)["settore"]) and int(k) != int(e.membro(1)["settore"]):
			lontano = int(k)
	mis._aggiungi_minaccia(mn[0], lontano)
	var m: Dictionary = e.s["minacce"][0]
	var d0: int = e.distanza(mis.pl, lontano, int(e.membro(0)["settore"]))
	var fatti := []
	var manuali := []
	var logs := []
	mis._minacce_avanzano(1, fatti, manuali, logs)
	await chiudi()
	print("   ", fatti, " ", manuali)
	ok(int(m["tempo"]) == 1, "traccia del Tempo della Minaccia a 1")
	ok(int(m["settore"]) != lontano or d0 <= 0, "Flower Bug si è avvicinata (Travel)")
	# sposta la Minaccia sul Membro e fa scattare il Veleno
	m["settore"] = int(e.membro(0)["settore"])
	fatti = []
	mis._minacce_avanzano(1, fatti, manuali, logs)
	await chiudi()
	print("   ", fatti)
	ok(fatti.any(func(x): return str(x).contains("Pericolo D")), "Veleno: il Membro nel settore tira il dado Pericolo D")
	ok(not mis._azioni_settore(int(m["settore"])).filter(func(x): return str(x["chiave"]).begins_with("M:")).is_empty(), "l'Azione Speciale della Minaccia è disponibile nel suo settore")
	print("errori: ", errori)
	quit()
