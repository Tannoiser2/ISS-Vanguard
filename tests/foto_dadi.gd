extends SceneTree
## Screenshot del vassoio 3D dei dadi nella finestra della Prova (xvfb-run, senza ISS_PROVA).
## ISS_DB_URL=off xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . -s res://tests/foto_dadi.gd
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
	await aspetta(0.4)
	var d := OS.get_user_data_dir() + "/foto"
	DirAccess.make_dir_recursive_absolute(d)
	root.get_viewport().get_texture().get_image().save_png(d + "/f_%s.png" % nome)
	print("foto ", nome)
func _run() -> void:
	var campagna = root.get_node("Campagna")
	campagna.nuova(8, "Prova dadi", "campagna")
	var Carte = root.get_node("Carte")
	var E = load("res://scripts/core/esplorazione.gd")
	var e = E.new()
	var sq := [{"nave": -1, "carta": "AMIR ZAYNAB", "file": "", "reparto": "scienza", "grado": 1, "cariche": 2, "dadi": ["base_rosso", "base_blu", "base_verde", "scienceDice", "biology"], "conv": {}, "mazzo": []},
		{"nave": -1, "carta": "CHO JAE-YONG", "file": "", "reparto": "ingegneria", "grado": 1, "cariche": 2, "dadi": ["base_rosso", "base_blu", "base_verde", "construction", "gathering"], "conv": {}, "mazzo": []}]
	e.prepara("p.4-5", Carte.pianeta("p.4-5"), sq, {"nome": "SPACE RANGER", "provviste": 6}, {})
	e.s["briefing_letto"] = true
	e.membro(0)["dadi_ferita"] = 1
	e.membro(0)["ferite"] = ["wounded"]
	var F = load("res://scripts/ui/finestra_prova.gd")
	var f = F.new()
	f.esp = e
	f.chi = 0
	f.fonte = "Prova dei dadi"
	f.settore = int(e.membro(0)["settore"])
	f.azione = {"nome": {"en": "TEST", "it": "PROVA DEI DADI"}, "prova": true, "pericolo": ["dangerDieA", "dangerDieB"], "speciali": [], "tracce": [],
		"esiti": [{"colore": "green", "req": "vanguard", "en": "Nothing happens.", "it": "Non succede nulla."}, {"colore": "red", "req": "", "en": "Nothing happens.", "it": "Non succede nulla."}]}
	var cl := CanvasLayer.new()
	main.add_child(cl)
	cl.add_child(f)
	await aspetta(1)
	for d in e.dadi_disponibili(0):
		f._scelti[d["id"]] = true
	f._tira()
	await aspetta(0.5)
	await foto("dadi_lancio")
	var t0 := Time.get_ticks_msec()
	while f._fase != 1 and Time.get_ticks_msec() - t0 < 90000:
		await process_frame
	print("lancio concluso in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	await foto("dadi_fermi")
	var testo := []
	for d in f._pool:
		testo.append("%s:%d=%s" % [d["tipo"], int(d["faccia"]), "+".join(Prova.icone(d))])
	print("risultati: ", ", ".join(testo))
	print("3d: ", f._dadi3d != null)
	quit()
