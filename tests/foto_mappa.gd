extends SceneTree
## Screenshot della Mappa stellare visiva nella Gestione della Nave (xvfb-run).
## ISS_DB_URL=off xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . -s res://tests/foto_mappa.gd -- [sistema]
var main
func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()
func aspetta(sec := 1.0) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000:
		await process_frame
func foto(nome: String) -> void:
	await aspetta(0.5)
	var d := OS.get_user_data_dir() + "/foto"
	DirAccess.make_dir_recursive_absolute(d)
	root.get_viewport().get_texture().get_image().save_png(d + "/f_%s.png" % nome)
	print("foto ", nome)
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var campagna = root.get_node("Campagna")
	campagna.nuova(8, "Prova mappa", "campagna")
	main.mostra_gioco()
	await aspetta(2)
	var g = main.get_child(main.get_child_count() - 1)
	var st := {}
	var N = load("res://scripts/core/nave.gd")
	var n = N.new(st)
	n.inizializza([])
	st["passo"] = "mappa"
	st["pool"]["energia"] = 4
	if args.size() > 0:
		st["sistema"] = args[0]
		st["sistemi_visitati"].append(args[0])
	campagna.dati["nave"] = st
	g.apri_nave()
	await aspetta(3)
	var ms = null
	var coda: Array = [g._nave]
	while not coda.is_empty():
		var x = coda.pop_front()
		if x.get_script() and str(x.get_script().resource_path).ends_with("mappa_stellare.gd"):
			ms = x
			break
		coda += x.get_children()
	print("mappa: ", ms != null)
	if ms:
		var sc = ms.get_parent()
		while sc and not sc is ScrollContainer:
			sc = sc.get_parent()
		if sc:
			sc.ensure_control_visible(ms)
	await foto("mappa_" + (args[0] if args.size() > 0 else "eye").replace(" ", "_"))
	if ms:
		var prima: String = st["sistema"]
		var en0: int = st["pool"]["energia"]
		ms.vola.emit(0)
		await aspetta(1)
		print("clic sulla rotta 0: %s -> %s, energia %d -> %d" % [prima, st["sistema"], en0, st["pool"]["energia"]])
	quit()
