extends SceneTree
## Prova del tavolo: allestimento, pesca, mazzi, sacchetti, salvataggio e ripristino.
## godot --headless --path . -s res://tests/prova_tavolo.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var T = load("res://scripts/tavolo/tavolo.gd")
	var t = T.new()
	root.add_child(t)
	t.allestisci()
	await physics_frame
	await physics_frame
	var tipi := {}
	for id in t.pezzi:
		tipi[t.pezzi[id].tipo] = tipi.get(t.pezzi[id].tipo, 0) + 1
	print("pezzi: ", t.pezzi.size(), " ", tipi)
	# pesca dal mazzo dei Punti d'interesse
	var poi = null
	for id in t.pezzi:
		var p = t.pezzi[id]
		if p.tipo == "mazzo" and str(p.def.get("nome", "")).contains("260 Points"):
			poi = p
	var n0: int = poi.contenuto.size()
	var c = t.pesca_da(poi, true)
	print("pescata ", c.def.get("nome"), " mazzo ", n0, " -> ", poi.contenuto.size())
	# rimetti in cima trascinandola sopra
	c.position = poi.position
	t._unisci(c, poi)
	print("rimessa: ", poi.contenuto.size())
	# porta una carta dal Logbook
	print("P107: ", t.porta_carta("P107"), "  M02: ", t.porta_carta("M02"))
	# due carte = nuovo mazzo
	var a = t.pesca_da(poi, true)
	var b = t.pesca_da(poi, true)
	a.position = b.position
	t._unisci(a, b)
	var nuovi := 0
	for id in t.pezzi:
		if str(id).begins_with("mazzo_"): nuovi += 1
	print("mazzi nuovi: ", nuovi)
	# sacchetto infinito
	for id in t.pezzi:
		var p = t.pezzi[id]
		if p.infinito:
			var x = t.prendi_da(p, 0)
			print("dal sacchetto infinito: ", x.tipo, " ", x.id)
			break
	# dado
	for id in t.pezzi:
		var p = t.pezzi[id]
		if p.tipo == "dado":
			print("dado: ", p.tira())
			break
	var s1: Dictionary = t.serializza()
	var testo := JSON.stringify(s1)
	print("stato salvato: ", testo.length() / 1024, " KB")
	var s2 = JSON.parse_string(testo)
	var t2 = T.new()
	root.add_child(t2)
	t2.ripristina(s2)
	await physics_frame
	var s3: Dictionary = t2.serializza()
	var ok: bool = s3["pezzi"].size() == s1["pezzi"].size()
	var diff := 0
	var per_id := {}
	for x in s1["pezzi"]: per_id[x["id"]] = x
	for x in s3["pezzi"]:
		var y = per_id.get(x["id"])
		if y == null or JSON.stringify(y) != JSON.stringify(x):
			diff += 1
			if diff < 4: print("  diverso: ", x, "\n        vs ", y)
	print("ripristino: ", s3["pezzi"].size(), " pezzi, differenze ", diff)
	print("ESITO: ", "OK" if ok and diff == 0 else "ERRORE")
	quit(0 if ok and diff == 0 else 1)
