extends SceneTree
## Screenshot di tutti i passi della Gestione della Nave, delle sotto-pagine delle Strutture e dei cassetti.
## ISS_DB_URL=off xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . -s res://tests/foto_nave.gd
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
	await aspetta(1.2)
	var d := OS.get_user_data_dir() + "/foto"
	DirAccess.make_dir_recursive_absolute(d)
	root.get_viewport().get_texture().get_image().save_png(d + "/nave_%s.png" % nome)
	print("foto ", nome)
func _run() -> void:
	var campagna = root.get_node("Campagna")
	var Carte = root.get_node("Carte")
	campagna.nuova(8, "Prova nave", "campagna")
	main.mostra_gioco()
	await aspetta(2)
	var g = main.get_child(main.get_child_count() - 1)
	var rep := {"AMIR ZAYNAB": "scienza", "CHO JAE-YONG": "ingegneria", "JOPPE ULRICH": "ricognizione", "RIKU HASHIMURA": "sicurezza",
		"LENA FREEMAN": "sicurezza", "PETRA SEDLÁČKOVÁ": "ricognizione", "EBE OKAFOR": "scienza", "MARK BARNES": "ingegneria"}
	var eq := []
	for c in Carte.categoria("equipaggio"):
		var n := str(c.get("nome", "")).to_upper()
		if rep.has(n) and str(c.get("lato", "fronte")) != "retro" and not eq.any(func(x): return str(x["carta"]).to_upper() == n):
			eq.append({"carta": c["nome"], "file": c["file"], "reparto": rep[n], "grado": 1, "stato": "riposo"})
	var st := {}
	var N = load("res://scripts/core/nave.gd")
	var nv = N.new(st)
	nv.inizializza(eq)
	st["pool"] = {"comando": 4, "energia": 5, "successi": 3}
	st["sistema"] = "TOI-2"
	st["sistemi_visitati"].append("TOI-2")
	if st["equipaggio"].size() > 2:
		st["equipaggio"][1]["stato"] = "infermeria"
		st["equipaggio"][1]["ferite"] = ["wounded"]
		st["equipaggio"][2]["stato"] = "morto"
	if not "--vuota" in OS.get_cmdline_user_args():
		st["ponte"] = ["B05", "B08"]
		st["ponte_viaggio"] = ["B01"]
		st["ricerca"] = ["R04", "R02", "R05", "R07"]
		st["code"][0] = ["C04", null, "C05"]
		st["situazioni"] = ["S01", "S03"]
		st["mod_lander"] = ["A01", "A02", "A05"]
		st["armeria"] = ["E01", "E02", "E05"]
		st["busta"] = ["R06"]
		for c in Carte.categoria("scoperte").filter(func(x): return int(str(x.get("file", "")).hash()) % 9 == 0).slice(0, 8):
			st["scoperte"].append({"tipo": str(c.get("campi", {}).get("categoria", "")), "file": str(c.get("file", "")), "rarita": str(c.get("campi", {}).get("rarita", ""))})
		st["eccezionali"]["2"] = true
		st["scanner"] = {"carta": "L1", "rivelate": 3, "destinazione": "Pellucid"}
		st["lander"].append({"nome": "PELICAN", "danneggiato": false})
		st["mod_montate"] = ["A01"]
		st["memoriale"].append({"carta": st["equipaggio"][2]["carta"], "reparto": st["equipaggio"][2]["reparto"]})
		var esq := []
		for i in [0, 3, 4]:
			var m: Dictionary = st["equipaggio"][i]
			esq.append({"nave": i, "carta": m["carta"], "file": m["file"], "ferite": ["wounded"] if i == 3 else [], "morto": false})
		esq.append({"nave": 2, "carta": st["equipaggio"][2]["carta"], "file": st["equipaggio"][2]["file"], "ferite": [], "morto": true})
		var scs := []
		for x in st["scoperte"].slice(0, 3):
			scs.append({"tipo": x["tipo"], "carta": x["file"]})
		campagna.dati["esplorazioni_concluse"] = [{"pagina": "p.4-5", "finita": "decollo", "successi": 4, "scoperte": scs, "eccezionali": [1], "equipaggio": esq, "grado_girato": true}]
	campagna.dati["nave"] = st
	g.apri_nave()
	await aspetta(3)
	var gn = g._nave
	var k := 0
	for p in N.PASSI:
		st["passo"] = p
		gn._sotto = ""
		gn._scelta = {}
		gn.aggiorna()
		k += 1
		await foto("%02d_%s" % [k, p])
		if p == "strutture":
			for s in ["ricerca", "produzione", "caserma", "situazioni"]:
				gn._sotto = s
				gn.aggiorna()
				await foto("%02d_strutture_%s" % [k, s])
	st["passo"] = "ponte"
	gn._sotto = ""
	gn.aggiorna()
	for c in ["equipaggio", "progetti", "situazioni", "magazzino", "diario"]:
		gn.apri_cassetto(c)
		await foto("cassetto_" + c)
	gn.apri_cassetto("")
	quit()
