extends SceneTree
## Screenshot delle fasi: inizio della campagna e Gestione della Nave (xvfb-run).
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
	var campagna = root.get_node("Campagna")
	campagna.nuova(8, "Prova fasi", "campagna")
	main.mostra_gioco()
	await aspetta(3)
	await foto("inizio_campagna")
	var g = main.get_child(main.get_child_count() - 1)
	g._inizio.queue_free()
	g.apri_nave()
	await aspetta(2)
	await foto("nave")
	quit()
