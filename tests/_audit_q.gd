extends SceneTree
var main
func _initialize() -> void:
	root.size = Vector2i(1280, 800)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()
func aspetta(n := 3) -> void:
	for i in n:
		await process_frame
func _run() -> void:
	var campagna = root.get_node("Campagna")
	campagna.nuova(8, "Audit", "campagna")
	var Carte = root.get_node("Carte")
	var E = load("res://scripts/core/esplorazione.gd")
	var e = E.new()
	var sq := [{"nave": 0, "carta": "AMIR", "file": "", "reparto": "scienza", "grado": 1, "dadi": ["base_rosso"], "mazzo": []}, {"nave": 1, "carta": "CHO", "file": "", "reparto": "ingegneria", "grado": 1, "dadi": ["base_blu"], "mazzo": []}]
	e.prepara("p.18-19", Carte.pianeta("p.18-19"), sq, {"nome": "SPACE RANGER", "provviste": 6}, {})
	var M = load("res://scripts/ui/missione.gd")
	var mis = M.new(e.s)
	var cl := CanvasLayer.new()
	main.add_child(cl)
	cl.add_child(mis)
	campagna.dati["nave"] = {}
	var GN = load("res://scripts/ui/gestione_nave.gd")
	var gn = GN.new(campagna.dati["nave"])
	await aspetta()
	gn.nave.inizializza([{"carta": "A", "file": "", "reparto": "scienza", "grado": 1, "stato": "disponibile"}])
	var non := {}
	var tot := 0
	var ok := 0
	for camp in [8, 12, 14]:
		var s = JSON.parse_string(FileAccess.get_file_as_string("res://data/logbook/c%d.json" % camp))
		var qs := []
		_q(s, qs)
		for q in qs:
			tot += 1
			var r: int = mis.rispondi_logbook(q)
			if r < 0:
				r = gn.rispondi_logbook(q)
			if r >= 0:
				ok += 1
				continue
			var k := RegEx.create_from_string("\\d+").sub(RegEx.create_from_string("\\[/?[bi]\\]").sub(q, "", true), "N", true).replace("\n", " ").substr(0, 100)
			non[k] = int(non.get(k, 0)) + 1
	print("DOMANDE ", tot, " risolte ", ok)
	var ks := non.keys()
	ks.sort_custom(func(a, b): return non[a] > non[b])
	for k in ks:
		print(non[k], "  ", k)
	quit()
func _q(o, out: Array) -> void:
	if o is Dictionary:
		if o.has("q") and o["q"] is String and str(o["q"]) != "" and not o.has("img"):
			out.append(str(o["q"]))
		for v in o.values():
			_q(v, out)
	elif o is Array:
		for v in o:
			_q(v, out)
