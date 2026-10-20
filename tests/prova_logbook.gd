extends SceneTree
## Prova del motore del Logbook: controlla i rinvii e percorre a caso migliaia di scelte.
## godot --headless --path . -s res://tests/prova_logbook.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var dati = root.get_node("Dati")
	var errori := 0
	for camp in [8, 12, 14]:
		var lb: Dictionary = dati.logbook(camp)
		var logs: Dictionary = lb.get("logs", {})
		var rinvii := 0
		var mancanti := 0
		for id in logs:
			for vid in logs[id]["verses"]:
				for el in logs[id]["verses"][vid]["e"]:
					for c in el.get("c", []):
						if c.has("l"):
							rinvii += 1
							var dl = logs.get(str(int(c["l"])))
							if dl == null or (c.has("v") and not dl["verses"].has(str(int(c["v"])))):
								mancanti += 1
								if mancanti < 5:
									print("  rinvio mancante: log ", id, " -> ", c.get("l"), "/", c.get("v"))
		print("Campagna %d: %d annotazioni, %d rinvii, %d mancanti" % [camp, logs.size(), rinvii, mancanti])
		errori += mancanti
		# passeggiata casuale
		var stato := {"tutorial": camp == 8}
		var m = load("res://scripts/core/motore_logbook.gd").new(camp, stato)
		var p: Array = m.entra(int(lb["intro"]["1"]))
		var passi := 0
		var fini := 0
		var bloccati := 0
		var ids := logs.keys()
		while passi < 20000:
			passi += 1
			if p.is_empty():
				fini += 1
				var nid: int = m.trova_numero(int(logs[ids[randi() % ids.size()]]["n"]))
				if nid < 0:
					continue
				p = m.entra(nid)
				continue
			if p[1] < 0:
				p = []
				continue
			var v: Dictionary = m.verso(p[0], p[1])
			if v.is_empty():
				print("  verso inesistente ", p)
				errori += 1
				p = []
				continue
			var scelte := []
			for el in v["e"]:
				if int(el["t"]) in [6, 15]:
					var alt: Array = m.alternative(el, int(v["t"]))
					if not alt.is_empty():
						scelte.append(alt)
			if scelte.is_empty():
				bloccati += 1
				p = []
				continue
			var alt: Array = scelte[randi() % scelte.size()]
			var scelta: Dictionary = alt[-1]
			for c in alt:
				if not c.has("q") or randf() < 0.5:
					scelta = c
					break
			p = m.scegli(scelta)
		print("  passeggiata: %d passi, %d fine annotazione, %d versi senza scelte valide, %d flag segnati" % [passi, fini, bloccati, m.flag_segnati().size()])
	# testo con icone
	print(dati.testo_bb("prova {i:landerSensors} e {i:inesistente}"))
	print("ERRORI: ", errori)
	quit(1 if errori > 0 else 0)
