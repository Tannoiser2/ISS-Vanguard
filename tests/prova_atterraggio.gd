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
	# attrezzatura e abilità
	e.membro(0)["attrezzatura"] = ["E07"]
	e.membro(0)["file"] = "carte/crewmembers/elena_34401.webp"
	e.membro(0)["cariche"] = 1
	e.s["attivo"] = 0
	for d in e.membro(0)["dadi"]:
		d["stato"] = "speso" if d["tipo"] == "base_rosso" else "disponibile"
	var pv := int(e.s["lander"]["provviste"])
	mis._usa_attrezzatura(0, "E07")
	await chiudi()
	ok(int(e.s["lander"]["provviste"]) == pv + 2 and e.membro(0)["attrezzatura"].is_empty(), "attrezzatura E07: +2 Provviste e torna all'Armeria")
	mis._usa_abilita(0)
	await chiudi()
	ok(int(e.membro(0)["cariche"]) == 0, "abilità: spesa 1 Carica")
	ok(e.membro(0)["dadi"].filter(func(d): return d["tipo"] == "base_rosso" and d["stato"] == "speso").is_empty(), "abilità di Elena: ricaricati tutti i dadi rossi")
	# Attrezzature di missione
	e.s["azioni"] = 2
	for d in e.membro(0)["dadi"]:
		d["stato"] = "disponibile"
	e.membro(0)["attrezzatura"] = ["E47", "E08"]
	var s0 := int(e.membro(0)["settore"])
	mis._usa_attrezzatura(0, "E47")
	await chiudi()
	ok(mis._ha_segnalino(s0, "E47") and not "E47" in e.membro(0)["attrezzatura"], "Avamposto piazzato nel settore %d" % s0)
	ok(int(e.s["azioni"]) == 1, "piazzare il segnalino costa un'azione")
	for d in e.membro(0)["dadi"]:
		d["stato"] = "speso"
	e.membro(0)["dadi"].resize(5)
	mis._riposo()
	await chiudi()
	var disp: int = e.membro(0)["dadi"].filter(func(d): return d["stato"] == "disponibile").size()
	ok(disp == 5, "Riposo nell'Avamposto: 3 + 2 dadi ricaricati (%d)" % disp)
	e.s["settori"][str(s0)].get_or_add("attrezzature", []).append({"id": "E08", "nome": "Medevac Drone", "marcatori": 0})
	e.membro(0)["ferite"] = ["wounded", "wounded", "wounded"]
	var fz := []
	e.ferita(0, "wounded")
	ok(mis._salva_con_drone(0, fz) and str(e.s["finita"]) == "", "Drone Medevac: niente evacuazione alla quarta Ferita")
	# effetti a scatto
	e.s["finita"] = ""
	e.s["azioni"] = 2
	e.membro(1)["file"] = "carte/crewmembers/zaima_32904.webp"
	e.membro(1)["cariche"] = 1
	e.s["attivo"] = 1
	var pv2 := int(e.s["lander"]["provviste"])
	mis._riposo()
	await chiudi()
	ok(int(e.s["lander"]["provviste"]) == pv2 and int(e.membro(1)["cariche"]) == 0, "Zaima riposa senza spendere Provviste (1 Carica)")
	e.membro(1)["attrezzatura"] = ["E22"]
	var nf: int = e.membro(1)["ferite"].size()
	var fz2 := []
	var man2 := []
	var lg2 := []
	mis._op({"op": "ferita", "tipo": "burned"}, 1, int(e.membro(1)["settore"]), fz2, man2, lg2, "prova")
	await chiudi()
	ok(e.membro(1)["ferite"].size() == nf and e.membro(1)["attrezzatura"].is_empty(), "la tuta evita l'Ustione e torna all'Armeria")
	var mano_prima: int = e.membro(0)["mano"].size()
	var disp0: int = e.dadi_disponibili(0).size()
	for d in e.membro(0)["dadi"]:
		d["stato"] = "speso"
	mis._op({"op": "scoperta_eccezionale", "n": 9}, 0, 1, fz2, man2, lg2, "prova")
	await chiudi()
	print("   ", fz2)
	ok(e.dadi_disponibili(0).size() >= 2, "Scoperta Eccezionale con effetto all'ottenimento: ogni Membro ricarica 2 dadi")
	# assistenza con l'abilità di Joppe (quanti dadi vuole, poi tornano disponibili)
	e.s["finita"] = ""
	e.membro(1)["file"] = "carte/joppe/joppe_34406.webp"
	e.membro(1)["cariche"] = 1
	e.viaggia(1, int(e.membro(0)["settore"]))
	for i in 2:
		for d in e.membro(i)["dadi"]:
			d["stato"] = "disponibile"
	var FP = load("res://scripts/ui/finestra_prova.gd")
	var f = FP.new()
	f.esp = e
	f.chi = 0
	f.azione = {"nome": {"it": "PROVA"}, "esiti": [{"colore": "red", "req": "", "en": "", "it": ""}], "speciali": [], "tracce": []}
	f.fonte = "prova"
	f.settore = int(e.membro(0)["settore"])
	mis.add_child(f)
	await aspetta()
	f._assist_abilita[1] = "tutti"
	f._assist[1] = e.dadi_disponibili(1).slice(0, 3).map(func(d): return d["id"])
	f._tira()
	ok(f._pool.filter(func(d): return int(d["chi"]) == 1).size() == 3, "Joppe assiste con 3 dadi")
	ok(int(e.membro(1)["cariche"]) == 0, "abilità di assistenza: 1 Carica")
	f._risolvi()
	ok(e.dadi_disponibili(1).size() == e.membro(1)["dadi"].filter(func(d): return d["stato"] != "sacrificato").size(), "i dadi di Joppe tornano disponibili")
	# tutte le Minacce: tre avanzamenti del Tempo ciascuna
	var tot_fatti := 0
	var tot_man := 0
	for cm in Carte.categoria("minacce"):
		if str(cm.get("lato", "")) != "fronte":
			continue
		e.s["minacce"] = []
		e.s["finita"] = ""
		mis._aggiungi_minaccia(cm, int(e.membro(0)["settore"]))
		var ff := []
		var mm := []
		var ll := []
		mis._minacce_avanzano(3, ff, mm, ll)
		await chiudi()
		tot_fatti += ff.size()
		tot_man += mm.size()
		if not mm.is_empty():
			print("   a mano (%s): %s" % [Carte.en(cm.get("titolo", "")), mm])
	print("   Minacce: %d effetti applicati, %d da fare a mano" % [tot_fatti, tot_man])
	print("errori: ", errori)
	quit()
