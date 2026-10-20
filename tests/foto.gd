extends SceneTree
## Screenshot automatici (serve un display: xvfb-run).
## ISS_PROVA=1 ISS_DB_URL=off xvfb-run -s "-screen 0 1920x1080x24" godot --path . -s res://tests/foto.gd -- [cosa]

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
	img.save_png(cartella + "/%02d_%s.png" % [n, nome])
	print("foto ", nome)

func aspetta(f := 10) -> void:
	for i in f:
		await process_frame

func aspetta_immagini(sec := 8.0) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000:
		await process_frame

func _run() -> void:
	var cosa := OS.get_cmdline_user_args()
	var campagna = root.get_node("Campagna")
	main.mostra_menu()
	await aspetta(20)
	await foto("menu")
	if "menu" in cosa:
		quit()
		return
	campagna.nuova(8, "Prova", "campagna")
	main.mostra_gioco()
	await aspetta_immagini(6)
	await foto("tavolo_tutto")
	var g = main.get_child(main.get_child_count() - 1)
	g.logbook.visible = false
	for v in ["pianeta", "nave", "equipaggio", "mazzi", "scoperte"]:
		g.tavolo.vista(v)
		await aspetta_immagini(3)
		await foto("vista_" + v)
	g.tavolo.vista("pianeta")
	g.logbook.visible = true
	g.logbook.apri_numero(63)
	await aspetta(30)
	await foto("logbook_63")
	g.logbook.apri_numero(60)
	await aspetta(30)
	await foto("logbook_60")
	g.tavolo.porta_carta("P107")
	await aspetta_immagini(3)
	await foto("carta_p107")
	quit()
