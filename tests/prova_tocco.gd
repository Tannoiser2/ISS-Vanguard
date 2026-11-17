extends SceneTree
## Gesti a due dita sulla mappa 3D (iPad): pizzico, rotazione, spostamento.
## ISS_PROVA=1 ISS_DB_URL=off xvfb-run -s "-screen 0 1920x1080x24" godot --path . -s res://tests/prova_tocco.gd

var main
var errori := 0

func _initialize() -> void:
	root.size = Vector2i(1366, 1024)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func aspetta(sec := 1.0) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000:
		await process_frame

func verifica(cond: bool, testo: String) -> void:
	print(("  ok   " if cond else "  FALLITA ") + testo)
	if not cond:
		errori += 1

func tocco(i: int, pos: Vector2, giu: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = pos
	e.pressed = giu
	Input.parse_input_event(e)
	await process_frame

func trascina(i: int, da: Vector2, a: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = a
	e.relative = a - da
	Input.parse_input_event(e)
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
	for c in g.ui.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("preparazione_missione.gd"):
			c._tutorial.button_pressed = false
			c._conferma()
	await aspetta(4)
	var mis = g._missione
	for c in mis.get_children():
		if c is ColorRect and c.get_child_count() > 0:
			c.queue_free()
	mis._logbook.visible = false
	await aspetta(1)
	var p3 = null
	for n in mis.find_children("*", "", true, false):
		if n.get_script() and str(n.get_script().resource_path).ends_with("plancia_3d.gd"):
			p3 = n
	verifica(p3 != null, "c'è la mappa 3D")
	if p3 == null:
		quit(1)
		return
	var r: Rect2 = p3._vpc.get_global_rect()
	var c0 := r.get_center()
	# pizzico che allarga: zoom avanti
	var d0: float = p3._cam_d
	await tocco(0, c0 - Vector2(60, 0), true)
	await tocco(1, c0 + Vector2(60, 0), true)
	for k in 10:
		await trascina(0, c0 - Vector2(60 + k * 12, 0), c0 - Vector2(72 + k * 12, 0))
		await trascina(1, c0 + Vector2(60 + k * 12, 0), c0 + Vector2(72 + k * 12, 0))
	verifica(p3._cam_d < d0 * 0.8, "pizzico che allarga: la vista si avvicina (%.1f -> %.1f)" % [d0, p3._cam_d])
	# due dita che ruotano
	var y0: float = p3._cam_y
	var a := Vector2(-180, 0)
	for k in 10:
		var b := a.rotated(deg_to_rad(4))
		await trascina(0, c0 + a, c0 + b)
		await trascina(1, c0 - a, c0 - b)
		a = b
	verifica(absf(p3._cam_y - y0) > 20, "due dita che girano: la vista ruota (%.0f° -> %.0f°)" % [y0, p3._cam_y])
	# due dita che scorrono insieme
	var t0: Vector3 = p3._cam_t
	for k in 10:
		await trascina(0, c0 + a + Vector2(0, k * 10), c0 + a + Vector2(0, (k + 1) * 10))
		await trascina(1, c0 - a + Vector2(0, k * 10), c0 - a + Vector2(0, (k + 1) * 10))
	verifica(p3._cam_t.distance_to(t0) > 0.3, "due dita che scorrono: la vista si sposta (%.2f)" % p3._cam_t.distance_to(t0))
	await tocco(0, c0, false)
	await tocco(1, c0, false)
	# un dito: trascinare sposta ancora la vista
	var t1: Vector3 = p3._cam_t
	await tocco(0, c0, true)
	for k in 8:
		await trascina(0, c0 + Vector2(k * 15, 0), c0 + Vector2((k + 1) * 15, 0))
	await tocco(0, c0 + Vector2(120, 0), false)
	verifica(p3._cam_t.distance_to(t1) > 0.3, "un dito trascinato: la vista si sposta (%.2f)" % p3._cam_t.distance_to(t1))
	print("ERRORI: ", errori)
	quit(errori)
