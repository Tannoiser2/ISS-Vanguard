extends SceneTree
## Screenshot dell'esplorazione planetaria (serve un display: xvfb-run).
## ISS_PROVA=1 ISS_DB_URL=off xvfb-run -s "-screen 0 1920x1080x24" godot --path . -s res://tests/foto_missione.gd -- [p.18-19]

var main
var n := 0
var cartella := ""

func _initialize() -> void:
	cartella = OS.get_user_data_dir() + "/foto"
	DirAccess.make_dir_recursive_absolute(cartella)
	root.size = Vector2i(1920, 1080)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func foto(nome: String) -> void:
	for i in 4:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	n += 1
	img.save_png(cartella + "/m%02d_%s.png" % [n, nome])
	print("foto ", nome)

func aspetta(sec := 1.0) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000:
		await process_frame

func _run() -> void:
	var pagina := "p.2-3"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("p."):
			pagina = a
	var campagna = root.get_node("Campagna")
	campagna.nuova(8, "Prova", "campagna")
	campagna.dati["prossimo_pianeta"] = pagina
	main.mostra_gioco()
	await aspetta(2)
	var g = main.get_child(main.get_child_count() - 1)
	g.logbook.visible = false
	g.apri_esplorazione()
	await aspetta(1)
	await foto("preparazione")
	var prep = null
	for c in g.ui.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("preparazione_missione.gd"):
			prep = c
	if pagina != "p.2-3":
		prep._tutorial.button_pressed = false
	prep._conferma()
	await aspetta(4)
	var mis = g._missione
	mis._logbook.visible = false
	await foto("missione")
	mis.seleziona(2)
	await aspetta(1)
	await foto("cassetto_settore")
	mis.apri_cassetto("squadra")
	await aspetta(1)
	await foto("cassetto_squadra")
	mis.apri_cassetto("")
	mis._viaggio()
	await aspetta(1)
	if mis._scelta_settore:
		await foto("viaggio_scelta")
		mis._settore_scelto.emit(-1)
		await aspetta(1)
	# una prova di dadi
	var st: Dictionary = {}
	for x in mis.pl.get("settori", []):
		if int(x.get("n", 0)) == int(mis.esp.membro(0)["settore"]):
			st = x
	var c: Dictionary = mis._carta_pdi(int(mis.esp.membro(0)["settore"]))
	var src: Dictionary = c if not c.is_empty() else (st.get("stampato", {}) if st.get("stampato") is Dictionary else {})
	if src.get("azioni") is Array and not src["azioni"].is_empty():
		mis.seleziona(int(mis.esp.membro(0)["settore"]))
		mis._esegui_azione(src["azioni"][0], "prova", "X#0", int(mis.esp.membro(0)["settore"]))
		await aspetta(1)
		await foto("prova_scelta")
		var f = mis.get_child(mis.get_child_count() - 1)
		f._tira()
		await aspetta(1)
		await foto("prova_tiro")
		f._risolvi()
		await aspetta(1)
		await foto("prova_esito")
		for b in _bottoni(f):
			if b.text == "APPLICA":
				b.pressed.emit()
		await aspetta(1)
		await foto("effetti")
	quit()

func _bottoni(n_: Node) -> Array:
	var out := []
	for c in n_.get_children():
		if c is Button:
			out.append(c)
		out.append_array(_bottoni(c))
	return out
