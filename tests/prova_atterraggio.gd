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
	# Laser Minerario, Ustione, Sistema di Difesa, P.E.T.
	var conv_l := [{"da": "qualsiasi", "a": "gathering"}]
	ok(Prova.soddisfa(["gathering"], [{"id": "v", "tipo": "virtuale", "icone": ["construction"]}], conv_l)["ok"], "Laser Minerario: [construction] vale [gathering]")
	ok(not Prova.soddisfa(["gathering"], [{"id": "v", "tipo": "virtuale", "icone": ["accident"]}], conv_l)["ok"], "Laser Minerario: [accident] no")
	var facce: Array = Prova.defs()["reparto"]["base_rosso"]["facce"]
	var fb := -1
	for k in facce.size():
		if "basic" in facce[k]:
			fb = k
	if fb >= 0:
		ok("accident" in Prova.icone({"tipo": "base_rosso", "faccia": fb, "bruciato": true}), "Ustione: [basic] diventa [accident]")
	var mz := {"nome": "Prova", "en": "Prova", "settore": s0, "tempo": 0, "file": ""}
	e.s["settori"][str(s0)]["attrezzature"].append({"id": "E14", "nome": "Defense System", "marcatori": 1})
	mis._sistema_difesa(mz)
	await chiudi()
	ok(not mis._ha_segnalino(s0, "E14"), "Sistema di Difesa: segnalino scartato e carta all'Armeria")
	e.s["azioni"] = 2
	e.s["attivo"] = 0
	for d in e.membro(0)["dadi"]:
		d["stato"] = "disponibile"
	e.membro(0)["attrezzatura"] = ["E23"]
	mis._usa_attrezzatura(0, "E23")
	await chiudi()
	var pet: Dictionary = {}
	for t in mis._segnalini(s0):
		if str(t["id"]) == "E23":
			pet = t
	ok(not pet.is_empty() and pet.get("dado") is Dictionary and e.membro(0)["dadi"].any(func(d): return d["stato"] == "pet"), "P.E.T. piazzato con un dado del Membro")
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
	# carte Reparto guidate: si cliccano i dadi che la carta permette di cambiare
	f._pool = [{"id": "r1", "tipo": "base_rosso", "faccia": 0, "chi": 0}, {"id": "b1", "tipo": "base_blu", "faccia": 0, "chi": 0}, {"id": "g1", "tipo": "base_verde", "faccia": 0, "chi": 0}]
	f._usa_modificatore({"tipo": "carta", "chi": 0, "id": "carte/rank_i_engineering/1306.webp", "titolo": "Prova", "testo": ""})
	ok(str(f._sel_mod.get("modo", "")) == "ritira" and str(f._sel_mod.get("colore", "")) == "red", "Reroll 1 [redDie]: si sceglie un dado rosso")
	f._clic_dado(f._pool[1])
	ok(not f._sel_mod.is_empty(), "un dado blu non si può ritirare con questa carta")
	f._clic_dado(f._pool[0])
	ok(f._sel_mod.is_empty(), "ritirato il dado rosso: la carta è usata")
	f._usa_modificatore({"tipo": "carta", "chi": 0, "id": "carte/rank_ii_science/8424.webp", "titolo": "Prova", "testo": ""})
	f._clic_dado(f._pool[0])
	f._clic_dado(f._pool[0])
	ok(f._pool.size() == 1 and str(f._sel_mod.get("modo", "")) == "vanguard", "2 dadi nei Dadi Spesi, poi si sceglie quello da girare")
	f._clic_dado(f._pool[0])
	ok(Prova.icone(f._pool[0]) == ["vanguard"], "il dado rimasto vale [vanguard]")
	f._risolvi()
	ok(e.dadi_disponibili(1).size() == e.membro(1)["dadi"].filter(func(d): return d["stato"] != "sacrificato").size(), "i dadi di Joppe tornano disponibili")
	# carte Reparto con effetti propri
	f.queue_free()
	e.s["finita"] = ""
	e.s["attivo"] = 0
	e.membro(0)["cariche"] = 1
	e.membro(0)["mano"] = ["carte/rank_i_science/8422.webp"]
	var ind_prima := 0
	for t in Esplorazione.TIPI_SCOPERTA:
		ind_prima += (e.s["indizi"][t] as Array).size()
	var sc_prima: int = e.s["scoperte"].size()
	mis._gioca_reparto(0, "carte/rank_i_science/8422.webp")
	await chiudi()
	var ind_dopo := 0
	for t in Esplorazione.TIPI_SCOPERTA:
		ind_dopo += (e.s["indizi"][t] as Array).size()
	ok(int(e.membro(0)["cariche"]) == 0 and (ind_dopo > ind_prima or e.s["scoperte"].size() > sc_prima) and e.membro(0)["mano"].is_empty(), "carta Reparto: 1 Carica per 2 Indizi")
	e.membro(0)["mano"] = ["carte/rank_iii_security/32905.webp"]
	var nf0: int = e.membro(0)["ferite"].size()
	mis._op({"op": "ferita", "tipo": "wounded"}, 0, int(e.membro(0)["settore"]), [], [], [], "prova")
	await chiudi()
	ok(e.membro(0)["ferite"].size() == nf0 and e.membro(0)["mano"].is_empty(), "carta Reparto: Ferita evitata")
	e.membro(0)["mano"] = ["carte/rank_iii_security/32906.webp"]
	e.s["minacce"] = []
	mis._gioca_reparto(0, "carte/rank_iii_security/32906.webp")
	await chiudi()
	ok(e.membro(0)["mano"].size() == 1, "carta Reparto: senza Minaccia nel settore non si gioca")
	# tabelle dei dadi Pericolo non stampate sulla carta di riferimento: si imparano
	Prova.apprese = {}
	var dj := {"tipo": "pericolo", "lettera": "J", "faccia": 0}
	for k in 8:
		dj["faccia"] = k
		if not Prova.icone(dj).is_empty():
			break
	ok(not Prova.tabella_nota("J", dj) and Prova.tabella_nota("A1", dj), "dado J sconosciuto, A1 usa la tabella A")
	mis._pericolo_ignoto("J", str(Prova.icone(dj)[0]))
	await chiudi()
	ok(Prova.tabella_nota("J", dj), "dado J: la faccia %s ora è nota" % str(Prova.icone(dj)[0]))
	# Visitatore Rapito: il PDI con la parola chiave della Condizione Generale va in cima
	var vers: Array = Carte.versioni("G29")
	var kw := -1
	for k in vers.size():
		if Carte.en(vers[k].get("titolo", "")).to_upper() == "WARP":
			kw = k
	e.s["condizione"] = {"carta": "G29@%d" % kw, "tempo": 0}
	e.s["settori"]["1"]["pdi"] = ["P382"]
	var fz3 := []
	var mz3 := []
	mis._pdi_parola_chiave(1, fz3, mz3)
	ok(Carte.en(Carte.per_id(e.pdi_in_cima(1)).get("titolo", "")).contains("(WARP)"), "Visitatore: in cima il PDI (WARP) → %s" % e.pdi_in_cima(1))
	# Fascicoli del personale: Obiettivo individuale durante l'esplorazione
	var vet: Dictionary = {}
	for c in Carte.categoria("veterani"):
		if int(c.get("traccia", 0)) == 2:
			vet = c
			break
	e.membro(0)["morto"] = false
	e.membro(0)["obiettivo"] = {"file": str(vet["file"]), "traccia": 0}
	e.membro(0)["conv_extra"] = []
	mis.apri_cassetto("squadra")
	await aspetta()
	mis._avanza_obiettivo(0, 1)
	await chiudi()
	ok(int(e.membro(0)["obiettivo"]["traccia"]) == 1, "Obiettivo individuale: traccia 1/2")
	mis._avanza_obiettivo(0, 1)
	await chiudi()
	ok(e.membro(0).get("veterano", false) and str(e.membro(0)["file"]) == str(vet["file"]) and not (e.membro(0)["conv_extra"] as Array).is_empty(), "traccia piena: il Membro diventa Veterano con una conversione in più")
	mis.apri_cassetto("")
	# arrivando in un settore durante un'azione si legge subito la sua annotazione (prima andava persa)
	var s_log := 0
	for k in e.s["settori"]:
		if int(k) != int(e.membro(0)["settore"]):
			s_log = int(k)
			break
	e.s["settori"][str(s_log)]["log"] = 210
	e.s["settori"][str(s_log)]["visitato"] = false
	mis._logbook.visible = false
	mis._occupato = true
	var arr_l := []
	await mis._muovi(0, s_log, arr_l)
	mis._occupato = false
	mis._rivela_arrivo(s_log, arr_l)
	await aspetta()
	ok(arr_l == [210] and mis._logbook.visible, "Viaggio: entrando nel settore si apre l'Annotazione 210")
	mis._logbook.visible = false
	e.s["settori"][str(s_log)]["log"] = 0
	mis._rivela_arrivo(s_log, [])
	ok(mis._cassetto_box.visible and mis._cassetto_tipo == "settore" and mis._sel == s_log, "Viaggio: senza annotazione si mostra la carta del settore")
	mis.apri_cassetto("")
	# effetti delle carte: elenchi, scelte e frasi separate
	var prima_ind := 0
	for t3 in e.s["indizi"]:
		prima_ind += (e.s["indizi"][t3] as Array).size()
	var A = load("res://scripts/core/effetti.gd")
	var an1: Dictionary = A.analizza("Gain 1 [success] and 2 Alien Tech Leads, go to Log 69.")
	ok(an1["resto"] == "" and an1["op"].size() == 3 and an1["op"][1]["op"] == "indizi" and int(an1["op"][1]["n"]) == 2, "elenco: 'and 2 Alien Tech Leads' è un guadagno")
	var an2: Dictionary = A.analizza("Each Crewmember in this Sector rolls [dangerDieC].")
	ok(an2["resto"] == "" and an2["op"][0]["op"] == "tutti" and an2["op"][0]["filtro"].get("settore", "") == "questo", "Each Crewmember in this Sector: effetto per ciascuno nel settore")
	var an3: Dictionary = A.analizza("Discard up to 2 Injury cards and 2 Injury dice from 1 Crewmember.")
	ok(an3["resto"] == "" and an3["op"].size() == 2, "cure: carte e dadi Ferita")
	var an4: Dictionary = A.analizza("Remove 1 marker from the Enemy Advantage Slot, gain 1 [success], go to Log 502.")
	ok(an4["resto"] == "" and an4["op"][0]["dove"] == "slot:vantaggio nemico", "slot Vantaggio Nemico")
	# Obiettivi individuali automatici: gli eventi della partita fanno avanzare le tracce da soli
	var vet_n := {}
	for c in Carte.categoria("veterani"):
		vet_n[str(c.get("nome", "")).to_upper()] = c
	e.membro(0)["veterano"] = false
	e.membro(0)["obiettivo"] = {"file": str(vet_n["AVERY DODGE"]["file"]), "traccia": 0}
	mis.esp.notifica("sforzo", {"chi": 0})
	mis.esp.notifica("sforzo", {"chi": 1})
	ok(int(e.membro(0)["obiettivo"]["traccia"]) == 1, "Avery: uno Sforzo suo avanza la traccia, quello di un altro no")
	e.membro(0)["obiettivo"] = {"file": str(vet_n["SAMUEL HUGHES"]["file"]), "traccia": 0}
	mis.esp.notifica("provviste", {"n": 3})
	ok(int(e.membro(0)["obiettivo"]["traccia"]) == 3, "Samuel: +1 per ogni Provvista guadagnata")
	e.membro(0)["obiettivo"] = {"file": str(vet_n["KLARA ATLADÓTTIR"]["file"]), "traccia": 0}
	mis.esp.notifica("prova", {"chi": 0, "icone_distinte": 6})
	await chiudi()
	ok(e.membro(0).get("veterano", false) and (e.membro(0)["obiettivo"] as Dictionary).is_empty(), "Klara: 6 icone diverse in una Prova → Veterana senza domande")
	e.membro(0)["veterano"] = false
	e.membro(0)["obiettivo"] = {"file": str(vet_n["CHRISTOS NICOLI"]["file"]), "traccia": 0}
	mis.esp.notifica("prova", {"chi": 1, "spesi": {0: [["defence"], ["basic"], ["defence", "physical"]]}})
	ok(int(e.membro(0)["obiettivo"]["traccia"]) == 2, "Christos: due dadi con [defence] nei Dadi Spesi (anche assistendo)")
	e.membro(0)["obiettivo"] = {"file": str(vet_n["GBOLAHAN MUSA"]["file"]), "traccia": 0}
	var sc_ob: Array = e.s["scoperte"]
	e.s["scoperte"] = []
	mis.esp.notifica("fine_esplorazione", {})
	ok(not e.membro(0).get("veterano", false), "Gbolahan: con meno di 8 Scoperte l'Obiettivo non si compie")
	for k in 8:
		e.s["scoperte"].append({"tipo": "mineral", "carta": "x%d" % k})
	mis.esp.notifica("fine_esplorazione", {})
	await chiudi()
	ok(e.membro(0).get("veterano", false), "Gbolahan: 8 Scoperte a fine esplorazione → Veterano")
	e.s["scoperte"] = sc_ob
	# regole sempre attive dei PDI: a fine turno nel settore
	var s_att := int(e.membro(0)["settore"])
	e.s["settori"][str(s_att)]["pdi"] = ["P010"]
	for d in e.membro(0)["dadi"]:
		d["stato"] = "disponibile"
	var disp_p: int = e.dadi_disponibili(0).size()
	mis._passivi("fine_turno", 0)
	await chiudi()
	ok(e.dadi_disponibili(0).size() == disp_p - 1, "P010: chi finisce il turno nel settore spende un dado")
	e.s["settori"][str(s_att)]["pdi"] = ["P192"]
	e.membro(0)["mano"] = []
	mis._passivi("riposo", 0)
	await chiudi()
	ok(e.membro(0)["mano"].size() == e.limite_mano(0), "P192: riposando si pesca fino al limite della mano")
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
