extends SceneTree
## Screenshot della plancia 3D dell'esplorazione (serve un display: xvfb-run).
## ISS_PROVA=1 ISS_DB_URL=off xvfb-run -s "-screen 0 1920x1080x24" godot --path . -s res://tests/foto_3d.gd -- [p.18-19]

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
	for i in 6:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	n += 1
	img.save_png(cartella + "/3d%02d_%s.png" % [n, nome])
	print("foto ", nome)

func aspetta(sec := 1.0) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000:
		await process_frame

func _chiudi_dialoghi(mis) -> void:
	for k in 10:
		var fin = null
		for c in mis.get_children():
			if c is ColorRect and c.get_child_count() > 0 and c.get_child(0) is CenterContainer:
				fin = c
		if fin == null:
			return
		var b := _bottoni(fin).filter(func(x): return x.text != "ANNULLA" and x.is_visible_in_tree())
		if b.is_empty():
			return
		b[0].pressed.emit()
		await aspetta(0.5)

func _run() -> void:
	var pagina := "p.18-19"
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
	var prep = null
	for c in g.ui.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("preparazione_missione.gd"):
			prep = c
	if pagina != "p.2-3":
		prep._tutorial.button_pressed = false
	prep._conferma()
	await aspetta(3)
	var mis = g._missione
	mis._logbook.visible = false
	await _chiudi_dialoghi(mis)
	mis._logbook.visible = false
	# una Minaccia e un segnalino per vedere i pezzi
	var fatte := 0
	for cm in root.get_node("Carte").categoria("minacce"):
		var nm := str((cm.get("nomi", [""]) as Array)[0])
		if nm in ["Kurma", "Arrogator Warswarm", "Arrogator Behemoth"] and not nm in mis.esp.s["minacce"].map(func(x): return x.get("en", "")):
			mis._aggiungi_minaccia(cm, 2 + fatte)
			fatte += 1
	mis.esp.s["settori"]["1"]["germogli"] = 2
	mis.esp.s["settori"]["1"].get_or_add("attrezzature", []).append({"id": "E47", "nome": "Outpost", "marcatori": 0})
	mis.aggiorna()
	await aspetta(2)
	await foto("panoramica")
	mis._p3d._inquadra_attivo()
	await aspetta(1.5)
	await foto("membro_attivo")
	mis._p3d._vai(mis._p3d._cam_t, 6.0, 28.0, 35.0, false)
	await aspetta(1.5)
	await foto("miniature_vicine")
	mis._p3d.inquadra_settore(2)
	mis._p3d._vai(mis._p3d._v3(mis._p3d._settori[2]["rett"].get_center()), 7.0, 35.0, -20.0, false)
	await aspetta(1.5)
	await foto("minaccia")
	mis._p3d.vista_iniziale()
	mis._viaggio()
	await aspetta(1.5)
	await foto("scelta_settore")
	mis._settore_scelto.emit(-1)
	await aspetta(1)
	var vet: Dictionary = {}
	for c in root.get_node("Carte").categoria("veterani"):
		if int(c.get("traccia", 0)) == 2:
			vet = c
			break
	mis.esp.membro(0)["obiettivo"] = {"file": str(vet["file"]), "traccia": 1}
	mis.apri_cassetto("squadra")
	await aspetta(1.5)
	await foto("obiettivo_individuale")
	quit()

func _bottoni(n_: Node) -> Array:
	var out := []
	for c in n_.get_children():
		if c is Button:
			out.append(c)
		out.append_array(_bottoni(c))
	return out
