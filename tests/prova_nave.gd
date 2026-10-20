extends SceneTree
## Giro completo della Gestione della Nave: inizio rapido, Ponte, Mappa, Strutture, Hangar, Lancio,
## poi un rientro simulato (Partenza → Salvataggio). Le finestre si chiudono premendo il primo pulsante.
## ISS_PROVA=1 ISS_DB_URL=off godot --headless --path . -s res://tests/prova_nave.gd [-- foto]

var main
var gn
var rng := RandomNumberGenerator.new()
var foto := false
var n := 0

func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func aspetta(f := 2) -> void:
	for i in f:
		await process_frame

func scatta(nome: String) -> void:
	if not foto:
		return
	await aspetta(4)
	var d := OS.get_user_data_dir() + "/foto"
	DirAccess.make_dir_recursive_absolute(d)
	n += 1
	root.get_viewport().get_texture().get_image().save_png(d + "/n%02d_%s.png" % [n, nome])
	print("foto ", nome)

func _run() -> void:
	foto = "foto" in OS.get_cmdline_user_args()
	rng.seed = 7
	var campagna = root.get_node("Campagna")
	campagna.nuova(8, "Prova nave", "campagna")
	campagna.dati["nave"] = {}
	var G = load("res://scripts/ui/gestione_nave.gd")
	gn = G.new(campagna.dati["nave"])
	var cl := CanvasLayer.new()
	main.add_child(cl)
	cl.add_child(gn)
	gn.esplora.connect(func(cfg): print("ESPLORA: ", cfg.get("pagina"), " ", cfg.get("membri", []).map(func(m): return m["carta"])))
	await aspetta(3)
	await scatta("avvio")
	# inizio rapido
	_premi("INIZIO RAPIDO")
	await _chiudi_finestre(20)
	print("equipaggio: ", gn.nave.s["equipaggio"].map(func(m): return "%s/%s" % [m["carta"], m["reparto"]]))
	gn.nave.s["ponte"] += ["B08", "B16", "B17"]
	gn.nave.s["ponte_viaggio"] += ["B07", "B15", "B06"]
	gn.nave.s["pool"]["comando"] = 3
	gn.aggiorna()
	await aspetta()
	await scatta("ponte")
	_premi("RIVELA")
	await _chiudi_finestre()
	await scatta("ponte_situazioni")
	await _chiudi_finestre()
	await _avanti()          # → mappa
	print("passo: ", gn.nave.passo(), " energia ", gn.nave.s["pool"]["energia"], " comando ", gn.nave.s["pool"]["comando"])
	await scatta("mappa")
	# volo verso TOI-2 (annotazione 400) e visita a Pellucid
	gn.nave.s["pool"]["energia"] = 6
	gn.nave.s["sistema"] = "TOI-2"
	gn.aggiorna()
	await aspetta()
	_premi("PELLUCID")
	await _chiudi_finestre()
	print("scanner: ", gn.nave.s["scanner"])
	await scatta("scansione")
	_premi("RIVELA LA PARTE 1")
	await aspetta()
	_premi("RIVELA LA PARTE 2")
	await aspetta()
	await scatta("scansione_2")
	await _avanti()          # → strutture
	await scatta("strutture")
	_premi("CASERMA")
	await aspetta()
	_premi("INGEGNERIA: SCEGLI")
	await _chiudi_finestre()
	await scatta("caserma")
	_premi("TORNA ALLE STRUTTURE")
	await aspetta()
	_premi("COMPLESSO PRODUTTIVO")
	await aspetta()
	await scatta("produzione")
	_premi("AVVIA IN CODA 1")
	await aspetta()
	print("code: ", gn.nave.s["code"], " pronti ", gn.nave.s["produzione_pronti"])
	_premi("TORNA ALLE STRUTTURE")
	await aspetta()
	_premi("LABORATORIO")
	await aspetta()
	await scatta("ricerca")
	_premi("TORNA ALLE STRUTTURE")
	await aspetta()
	await _avanti()          # → hangar
	await scatta("hangar")
	await _avanti()          # → lancio
	var disp: Array = gn.nave.membri("", "disponibile")
	gn._scelta["squadra"] = [disp[0], disp[2]] if disp.size() > 2 else disp
	gn.aggiorna()
	await aspetta()
	await scatta("lancio")
	_premi("ATTERRA")
	await aspetta()
	print("passo dopo il lancio: ", gn.nave.passo())
	# rientro simulato
	var sq: Array = gn.nave.s["squadra"]
	campagna.dati["esplorazioni_concluse"] = [{"pagina": "p.4-5", "finita": "decollo", "successi": 7, "grado_girato": true,
		"scoperte": [{"tipo": "mineral", "carta": "carte/mineral_discoveries/6109.webp"}], "eccezionali": [2], "missioni_rimaste": [],
		"equipaggio": [{"carta": gn.nave.s["equipaggio"][sq[0]]["carta"], "nave": sq[0], "ferite": ["wounded", "burned", "exhausted"], "morto": false},
			{"carta": gn.nave.s["equipaggio"][sq[1]]["carta"], "nave": sq[1], "ferite": [], "morto": false}]}]
	gn.nave.vai("partenza")
	gn.aggiorna()
	await aspetta()
	for k in 7:
		await scatta("rientro_" + gn.nave.passo())
		if gn.nave.passo() == "debriefing":
			_premi("PROMUOVI")
			await aspetta()
			_premi("COMPRA UN DADO")
			await _chiudi_finestre()
		await _avanti()
		print("→ ", gn.nave.passo(), " successi ", gn.nave.s["pool"]["successi"], " dadi ", gn.nave.n_dadi())
	print("infermeria: ", gn.nave.s["infermeria"], " memoriale: ", gn.nave.s["memoriale"])
	print("equipaggio: ", gn.nave.s["equipaggio"].map(func(m): return "%s G%d %s" % [m["carta"], int(m["grado"]), m["stato"]]))
	print("scoperte raccolte: ", gn.nave.s["scoperte"].size(), " eccezionali ", gn.nave.s["eccezionali"])
	print("JSON: ", "ok" if JSON.parse_string(JSON.stringify(campagna.dati)) is Dictionary else "ERRORE")
	quit()

func _bottoni(nd: Node, out: Array) -> void:
	for c in nd.get_children():
		if c is Button and c.is_visible_in_tree():
			out.append(c)
		_bottoni(c, out)

func _premi(inizio: String) -> bool:
	var b := []
	_bottoni(gn, b)
	for x in b:
		if str(x.text).to_upper().contains(inizio.to_upper()) and not x.disabled:
			x.pressed.emit()
			return true
	print("  (pulsante non trovato: ", inizio, ")")
	return false

## Chiude le finestre di scelta che si aprono (primo pulsante utile).
func _chiudi_finestre(max_ := 8) -> void:
	for k in max_:
		await aspetta()
		var fin = null
		for c in gn.get_children():
			if c is ColorRect and c.get_child_count() > 0 and c.get_child(0) is CenterContainer:
				fin = c
		if fin == null:
			return
		var b := []
		_bottoni(fin, b)
		b = b.filter(func(x): return x.text != "ANNULLA")
		if b.is_empty():
			return
		b[0].pressed.emit()

func _avanti() -> void:
	await aspetta()
	var b := []
	_bottoni(gn, b)
	for x in b:
		if str(x.text).ends_with("▶") and not x.disabled:
			x.pressed.emit()
			await _chiudi_finestre()
			return
	print("  (nessun AVANTI)")
