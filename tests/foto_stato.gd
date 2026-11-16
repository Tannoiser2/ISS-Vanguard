extends SceneTree
## Screenshot dello stato del gioco sulla mappa: tracce, segnaposto, Missioni, Condizione Generale, Minacce.
## ISS_PROVA=1 ISS_DB_URL=off xvfb-run -s "-screen 0 1920x1080x24" godot --path . -s res://tests/foto_stato.gd -- [1440x1080]

var main
var cartella := ""
var sigla := ""

func _initialize() -> void:
	cartella = OS.get_user_data_dir() + "/foto"
	DirAccess.make_dir_recursive_absolute(cartella)
	var dim := Vector2i(1920, 1080)
	for a in OS.get_cmdline_user_args():
		if a.contains("x"):
			dim = Vector2i(int(a.get_slice("x", 0)), int(a.get_slice("x", 1)))
	sigla = "%dx%d" % [dim.x, dim.y]
	root.size = dim
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func foto(nome: String) -> void:
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(cartella + "/s_%s_%s.png" % [sigla, nome])
	print("foto ", nome)

func aspetta(sec := 1.0) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000:
		await process_frame

func _run() -> void:
	var campagna = root.get_node("Campagna")
	campagna.nuova(8, "Prova", "campagna")
	campagna.dati["prossimo_pianeta"] = "p.4-5"
	main.mostra_gioco()
	await aspetta(2)
	var g = main.get_child(main.get_child_count() - 1)
	g.logbook.visible = false
	g.apri_esplorazione()
	await aspetta(1)
	var prep = null
	for c in g.ui.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("preparazione_missione.gd"):
			prep = c
	prep._tutorial.button_pressed = false
	prep._conferma()
	await aspetta(4)
	var mis = g._missione
	for c in mis.get_children():
		if c is ColorRect and c.get_child_count() > 0:
			c.queue_free()
	mis._logbook.visible = false
	var e = mis.esp
	var s: Dictionary = e.s
	# uno stato di partita avanzato: tracce piene a metà, segnaposto, Missione con segnaposto, Condizione
	# Generale con il Tempo, una Minaccia, contatori sugli slot
	for n in s["settori"]:
		var tr: Array = mis.tracce_settore(int(n))
		if not tr.is_empty():
			var c: Dictionary = mis._carta_pdi(int(n))
			var base: String = e.pdi_in_cima(int(n)) if not c.is_empty() else "S%s" % n
			e.avanza_traccia(int(n), "%s#0#%s" % [base, tr[0]["colore"]], 2, int(tr[0]["caselle"]))
	s["missioni"] = ["M21", "M22"]
	s["condizione"] = {"carta": "G05", "tempo": 2}
	s.get_or_add("contatori", {})["carta:m21"] = 3
	s["contatori"]["slot:vantaggio nemico"] = 2
	var mn: Array = mis._trova_minaccia("DUST STORM")
	if not mn.is_empty():
		mis._aggiungi_minaccia(mn[0], 2)
		s["minacce"][-1]["tempo"] = 1
	mis.aggiorna()
	mis._p3d.vista_iniziale()
	await aspetta(3)
	await foto("3d")
	mis._imposta_vista(false)
	await aspetta(2)
	await foto("2d")
	quit()
