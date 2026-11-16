extends SceneTree
## Screenshot della Prova nella colonna destra con i dadi lanciati sulla mappa (serve un display: xvfb-run).
## ISS_PROVA=1 ISS_DADI_3D=1 ISS_DB_URL=off xvfb-run -s "-screen 0 1920x1080x24" godot --path . -s res://tests/foto_prova.gd -- [1440x1080] [2d]

var main
var n := 0
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
	DisplayServer.window_set_size(dim)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func foto(nome: String) -> void:
	for i in 4:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	n += 1
	img.save_png(cartella + "/p_%s_%02d_%s.png" % [sigla, n, nome])
	print("foto ", nome)

func aspetta(sec := 1.0) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000:
		await process_frame

func _bottoni(n_: Node) -> Array:
	var out := []
	for c in n_.get_children():
		if c is Button:
			out.append(c)
		out.append_array(_bottoni(c))
	return out

func _run() -> void:
	var campagna = root.get_node("Campagna")
	campagna.nuova(8, "Prova", "campagna")
	campagna.dati["prossimo_pianeta"] = "p.2-3"
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
	prep._conferma()
	await aspetta(4)
	var mis = g._missione
	mis._logbook.visible = false
	if "2d" in OS.get_cmdline_user_args():
		mis._imposta_vista(false)
	var sett := int(mis.esp.membro(0)["settore"])
	mis.seleziona(sett)
	await aspetta(1)
	await foto("settore")
	var st: Dictionary = {}
	for x in mis.pl.get("settori", []):
		if int(x.get("n", 0)) == sett:
			st = x
	mis._esegui_azione(st["stampato"]["azioni"][0], "Relitto contorto", "X#0", sett)
	await aspetta(1)
	var f = mis.get_child(mis.get_child_count() - 1)
	for b in _bottoni(f):
		if b.text == "TUTTI":
			b.pressed.emit()
	await aspetta(0.5)
	await foto("prova_scelta")
	f._tira()
	await aspetta(0.45)
	await foto("prova_dadi_in_volo")
	var t0 := Time.get_ticks_msec()
	while f._fase != 1 and Time.get_ticks_msec() - t0 < 90000:
		await process_frame
	await aspetta(0.5)
	await foto("prova_tiro")
	f._risolvi()
	await aspetta(1)
	await foto("prova_esito")
	for b in _bottoni(f):
		if b.text == "APPLICA":
			b.pressed.emit()
	await aspetta(3.5)
	await foto("effetti")
	for cz in mis.get_children():
		if cz is ColorRect and cz.get_child_count() > 0 and cz.get_child(0) is CenterContainer:
			for b in _bottoni(cz):
				if b.text == "OK":
					b.pressed.emit()
	await aspetta(1)
	# un'istruzione del Logbook eseguita dal programma
	mis._occupato = false
	mis.esp.s["attivo"] = 0
	await mis._muovi(0, 5, [])
	await aspetta(1)
	for b in _bottoni(mis._logbook):
		if b.text.begins_with("▸"):
			b.pressed.emit()
			break
	await aspetta(1)
	await foto("logbook_istruzione")
	quit()
