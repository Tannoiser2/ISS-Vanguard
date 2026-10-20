extends SceneTree
## Partita simulata dell'esplorazione: prepara il tutorial (o un altro pianeta) e gioca a caso
## premendo i pulsanti delle finestre, per scovare errori di esecuzione.
## ISS_PROVA=1 ISS_DB_URL=off godot --headless --path . -s res://tests/prova_missione.gd -- [p.18-19] [passi]

var main
var mis
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func aspetta(f := 2) -> void:
	for i in f:
		await process_frame

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var pagina := "p.2-3"
	var passi := 400
	for a in args:
		if a.begins_with("p."):
			pagina = a
		elif a.is_valid_int():
			passi = int(a)
	rng.seed = hash(pagina) + passi
	var campagna = root.get_node("Campagna")
	campagna.nuova(8, "Prova esplorazione", "campagna")
	var Prep = load("res://scripts/ui/preparazione_missione.gd")
	var prep = Prep.new()
	prep.pagina_iniziale = pagina
	var cfg := {}
	prep.pronta.connect(func(c): cfg.merge(c))
	main.add_child(prep)
	await aspetta()
	if pagina != "p.2-3":
		prep._tutorial.button_pressed = false
	prep._conferma()
	await aspetta()
	print("squadra: ", cfg["squadra"].map(func(m): return "%s/%s mazzo %d dadi %d" % [m["carta"], m["reparto"], m["mazzo"].size(), m["dadi"].size()]))
	print("eventi %d, scoperte %s, indizi %d" % [cfg["mazzi"]["eventi"].size(), cfg["mazzi"]["scoperte"].keys(), cfg["mazzi"]["indizi"].size()])
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
	await aspetta(5)
	var azioni := 0
	for k in passi:
		await aspetta()
		if _premi_finestra():
			continue
		if mis._occupato:
			continue
		if str(mis.esp.s.get("finita", "")) != "":
			print("fine: ", mis.esp.s["finita"], " al passo ", k)
			break
		azioni += 1
		var r := rng.randi_range(0, 9)
		var chi := int(mis.esp.s["attivo"])
		var sett := int(mis.esp.membro(chi)["settore"])
		mis.seleziona(sett)
		if int(mis.esp.s["azioni"]) <= 0 or r == 0:
			mis._fine_turno()
		elif r <= 3:
			var c: Dictionary = mis._carta_pdi(sett)
			var st: Dictionary = {}
			for x in mis.pl.get("settori", []):
				if int(x.get("n", 0)) == sett:
					st = x
			var src: Dictionary = c if not c.is_empty() else (st.get("stampato", {}) if st.get("stampato") is Dictionary else {})
			var az: Array = src.get("azioni", []) if src.get("azioni") is Array else []
			if not az.is_empty() and not mis.esp.s["speciale_usata"]:
				mis._esegui_azione(az[0], "prova", "X#0", sett)
			else:
				mis._viaggio()
		elif r <= 6:
			mis._viaggio()
		elif r == 7:
			mis._riposo()
		elif r == 8:
			mis._preparazione()
		else:
			mis._sforzo()
	var s: Dictionary = mis.esp.s
	print("round %d, successi %d, scoperte %d, provviste %s, azioni tentate %d" % [int(s["round"]), int(s["successi"]), s["scoperte"].size(), str(s["lander"]["provviste"]), azioni])
	for m in s["equipaggio"]:
		print("  %s settore %d ferite %s dadi %s mano %d" % [m["carta"], int(m["settore"]), str(m["ferite"]), str(m["dadi"].map(func(d): return d["stato"].substr(0, 1))), m["mano"].size()])
	print("diario (ultime righe):")
	for t in s["diario"].slice(max(0, s["diario"].size() - int(OS.get_environment("RIGHE") if OS.get_environment("RIGHE") != "" else "15"))):
		print("  ", t)
	# il salvataggio deve essere JSON valido e ricaricabile
	var js := JSON.stringify(campagna.dati)
	var back = JSON.parse_string(js)
	print("salvataggio JSON: ", "ok" if back is Dictionary and back.has("esplorazione") else "ERRORE", " (", js.length(), " caratteri)")
	quit()

## Se è aperta una finestra (scelta, prova di dadi) preme un pulsante a caso fra quelli utili.
func _premi_finestra() -> bool:
	var fin = null
	for c in mis.get_children():
		if c is ColorRect and c.get_child_count() > 0 and c.get_child(0) is CenterContainer:
			fin = c
		elif c.get_script() and str(c.get_script().resource_path).ends_with("finestra_prova.gd"):
			fin = c
	if fin == null:
		return false
	var bott := []
	_raccogli(fin, bott)
	var utili := bott.filter(func(b): return not b.disabled and b.text != "ANNULLA" and b.text != "TUTTI")
	if fin is Control and fin.get_script() and str(fin.get_script().resource_path).ends_with("finestra_prova.gd"):
		# nella prova: scegli qualche dado, poi tira, risolvi, applica
		for b in bott:
			if b.text in ["APPLICA", "RISOLVI LA PROVA"]:
				b.pressed.emit()
				return true
		for b in bott:
			if b.text == "TIRA I DADI":
				for t in bott:
					if t.toggle_mode and rng.randf() < 0.6:
						t.button_pressed = true
				b.pressed.emit()
				return true
	if utili.is_empty():
		return false
	var scelto = utili[rng.randi_range(0, utili.size() - 1)]
	scelto.pressed.emit()
	return true

func _raccogli(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Button and c.is_visible_in_tree():
			out.append(c)
		_raccogli(c, out)
