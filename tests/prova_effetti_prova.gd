extends SceneTree
## Effetti che si risolvono dentro la Prova: traccia per ogni Membro che assiste (P283), traccia che fa
## avanzare un'altra traccia (P113), dado Pericolo aggiunto alla Riserva (G07), sacrificare un dado per
## ritirarne uno (P532), Missione completata da sola (M23).
## ISS_PROVA=1 ISS_DB_URL=off godot --headless --path . -s res://tests/prova_effetti_prova.gd

var main
var mis
var e
var errori := 0

func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func aspetta(n := 2) -> void:
	for i in n:
		await process_frame

func ok(cond: bool, t: String) -> void:
	print(("ok   " if cond else "ERRORE ") + t)
	if not cond:
		errori += 1

func _azione(id: String) -> Dictionary:
	var Carte = root.get_node("Carte")
	return (Carte.per_id(id).get("azioni", []) as Array)[0]

func _finestra(az: Dictionary, chiave: String, dadi_virtuali: Array, assistenti := []) -> Object:
	var F = load("res://scripts/ui/finestra_prova.gd")
	var f = F.new()
	f.esp = e
	f.chi = 0
	f.fonte = "Prova"
	f.chiave_tracce = chiave
	f.settore = int(e.membro(0)["settore"])
	f.azione = az
	mis.add_child(f)
	await aspetta(3)
	f._pool = []
	for k in dadi_virtuali.size():
		f._pool.append({"id": "t%d" % k, "tipo": "virtuale", "icone": dadi_virtuali[k], "faccia": 0, "chi": 0})
	for j in assistenti:
		var d: Dictionary = e.membro(j)["dadi"][0]
		f._pool.append({"id": d["id"], "tipo": d["tipo"], "faccia": d.get("faccia", 0), "chi": j})
	return f

func _run() -> void:
	var campagna = root.get_node("Campagna")
	campagna.nuova(8, "Prova effetti", "campagna")
	var Carte = root.get_node("Carte")
	var E = load("res://scripts/core/esplorazione.gd")
	var e0 = E.new()
	var sq := [{"nave": -1, "carta": "AMIR ZAYNAB", "file": "carte/amir/amir_34404.webp", "reparto": "scienza", "grado": 1, "cariche": 2, "dadi": ["base_rosso", "base_blu", "base_verde", "scienceDice", "biology"], "conv": {}, "mazzo": []},
		{"nave": -1, "carta": "CHO JAE-YONG", "file": "", "reparto": "ingegneria", "grado": 1, "cariche": 2, "dadi": ["base_rosso", "base_blu", "base_verde", "construction", "gathering"], "conv": {}, "mazzo": []},
		{"nave": -1, "carta": "LENA FREEMAN", "file": "", "reparto": "sicurezza", "grado": 1, "cariche": 2, "dadi": ["base_rosso", "base_blu", "base_verde", "physical", "defence"], "conv": {}, "mazzo": []}]
	e0.prepara("p.4-5", Carte.pianeta("p.4-5"), sq, {"nome": "SPACE RANGER", "provviste": 6}, {})
	e0.s["briefing_letto"] = true
	for i in 3:
		e0.membro(i)["settore"] = e0.membro(0)["settore"]
	var M = load("res://scripts/ui/missione.gd")
	mis = M.new(e0.s)
	var cl := CanvasLayer.new()
	main.add_child(cl)
	cl.add_child(mis)
	await aspetta(5)
	e = mis.esp
	var sett := int(e.membro(0)["settore"])
	# --- P283: [outcomeGreenProgress] per ogni Membro che assiste (2 assistenti)
	var f = await _finestra(_azione("P283"), "P283#prova", [["basic"]], [1, 2])
	f._risolvi()
	await aspetta(3)
	ok(e.traccia("P283#prova#green", sett) == 2, "P283: traccia verde +2 con 2 Membri che assistono (%d)" % e.traccia("P283#prova#green", sett))
	f.queue_free()
	# --- P113: la traccia gialla completata fa avanzare la verde e dà 2 Indizi
	var ind0 := 0
	for t in e.s["indizi"]:
		ind0 += (e.s["indizi"][t] as Array).size()
	f = await _finestra(_azione("P113"), "P113#prova", [["gathering"], ["gathering"]])
	f._risolvi()
	await aspetta(3)
	var testi_f: Array = []
	ok(e.traccia("P113#prova#green", sett) >= 1, "P113: la traccia gialla completa fa avanzare la verde (%d; più l'effetto [die])" % e.traccia("P113#prova#green", sett))
	f.queue_free()
	# --- G07: dado Pericolo C aggiunto alla Riserva come effetto speciale della Condizione Generale
	var g07: Dictionary = Carte.per_id("G07")
	f = await _finestra({"nome": {"en": "TEST", "it": "PROVA"}, "prova": true, "pericolo": [], "speciali": [], "tracce": [],
		"esiti": [{"colore": "green", "req": "", "en": "Nothing happens.", "it": "Non succede nulla."}]}, "T#1", [["biology"]])
	f.speciali_globali = [g07["effetto_speciale"]]
	f._risolvi()
	await aspetta(3)
	ok(f._pool.any(func(d): return d["tipo"] == "pericolo" and str(d["lettera"]) == "C"), "G07: tirato il dado Pericolo C e aggiunto alla Riserva")
	f.queue_free()
	# --- P532: sacrificare un dado (fuori dal tiro) per ritirare 1 dado
	f = await _finestra(_azione("P532"), "P532#prova", [["basic"]])
	var mods: Array = f._modificatori().filter(func(x): return x["tipo"] == "sacrifica_ritira")
	ok(not mods.is_empty(), "P532: l'effetto «sacrifica un dado per ritirarne uno» è fra i modificatori")
	var sac0: int = e.membro(0)["dadi"].filter(func(d): return d["stato"] == "sacrificato").size()
	if not mods.is_empty():
		f._usa_modificatore(mods[0])
		await aspetta(3)
	ok(e.membro(0)["dadi"].filter(func(d): return d["stato"] == "sacrificato").size() == sac0 + 1, "P532: un dado sacrificato")
	ok(not f._sel_mod.is_empty() and str(f._sel_mod.get("modo", "")) == "ritira", "P532: si sceglie il dado da ritirare")
	f.queue_free()
	await aspetta(2)
	# --- M23: con le Scoperte Eccezionali 2 e 3 la Missione si completa da sola
	e.s["missioni"] = ["M23"]
	e.s["eccezionali"] = [2, 3]
	var succ0 := int(e.s["successi"])
	mis._occupato = true
	mis._finisci()
	for k in 20:
		await aspetta()
		for c in mis.get_children():
			if c is ColorRect and c.get_child_count() > 0 and c.get_child(0) is CenterContainer and not c.is_queued_for_deletion():
				var bs := []
				_bottoni(c, bs)
				if not bs.is_empty():
					bs[0].pressed.emit()
	ok(not "M23" in e.s["missioni"], "M23: Missione completata da sola")
	ok(int(e.s["successi"]) == succ0 + 1, "M23: +1 Successo (%d → %d)" % [succ0, int(e.s["successi"])])
	await _altri(Carte, sett)
	print("errori: %d" % errori)
	quit()

## Risponde a tutte le finestre aperte (prima opzione, o quella che contiene il testo dato).
func _rispondi(filtro := "", giri := 20) -> void:
	for k in giri:
		await aspetta()
		for c in mis.get_children():
			if c is ColorRect and c.get_child_count() > 0 and c.get_child(0) is CenterContainer and not c.is_queued_for_deletion():
				var bs := []
				_bottoni(c, bs)
				bs = bs.filter(func(b): return b.text != "ANNULLA")
				if bs.is_empty():
					continue
				var sc = bs[0]
				for b in bs:
					if filtro != "" and str(b.text).contains(filtro):
						sc = b
				sc.pressed.emit()

func _applica(en: String) -> void:
	mis._occupato = false
	mis.applica([{"en": en, "it": en, "fonte": "prova"}], 0, int(e.membro(0)["settore"]))
	await _rispondi()

func _altri(Carte, sett: int) -> void:
	# --- Nato Fortunato nella Prova: il dado Pericolo va su un risultato senza effetto
	var bl: Array = Carte.categoria("reparto").filter(func(c): return Carte.en(c.get("effetto", "")).to_lower().contains("after rolling a danger die"))
	e.membro(0)["mano"] = [str(bl[0]["file"])]
	var f = await _finestra({"nome": {"en": "TEST", "it": "PROVA"}, "prova": true, "pericolo": [], "speciali": [], "tracce": [],
		"esiti": [{"colore": "green", "req": "", "en": "Nothing happens.", "it": "Non succede nulla."}]}, "T#2", [["basic"]])
	var dp := {"id": "p1", "tipo": "pericolo", "faccia": 0, "chi": 0, "lettera": "A"}
	for fc in 8:
		dp["faccia"] = fc
		if Prova.effetto_pericolo("A", dp) != "":
			break
	f._pool.append(dp)
	var mb: Array = f._modificatori().filter(func(x): return x["tipo"] == "carta" and str(x["id"]) == str(bl[0]["file"]))
	ok(not mb.is_empty(), "Nato Fortunato fra le carte usabili nella Prova")
	if not mb.is_empty():
		f._usa_modificatore(mb[0])
		await aspetta(3)
	ok(Prova.effetto_pericolo("A", dp) == "", "Nato Fortunato: il dado Pericolo non ha più effetto")
	f.queue_free()
	# --- "Se non hai [defence] nella Riserva del Tiro, esito rosso" (P...)
	var con_def: Array = Carte.categoria("pdi").filter(func(c): return JSON.stringify(c.get("azioni", [])).contains("If you have no [defence]"))
	f = await _finestra((con_def[0]["azioni"] as Array)[0], "X#0", [["scouting"]])
	f._risolvi()
	await aspetta(3)
	ok(e.s["diario"].back().contains("rosso") or JSON.stringify(e.s["diario"].slice(-3)).contains("Nessun defence"), "senza [defence]: esito rosso")
	f.queue_free()
	await aspetta(2)
	# --- Uragano: si salvano Indizi tirando il dado Pericolo
	e.s["indizi"]["mineral"] = [{"v": 1}, {"v": 2}]
	e.s["indizi"]["alien_tech"] = [{"v": 1}]
	await _applica("Discard every Lead token from Discovery decks. Each Crewmember may roll [dangerDieA] any number of times to save one chosen Lead token from being discarded.")
	var tot := 0
	for t in e.s["indizi"]:
		tot += (e.s["indizi"][t] as Array).size()
	ok(tot >= 1 and tot <= 3, "Uragano: alcuni Indizi salvati (%d)" % tot)
	# --- Germoglio catturato
	e.s["settori"][str(sett)]["germogli"] = 1
	await _applica("Place this Sprout on this card.")
	ok(int(e.s["settori"][str(sett)]["germogli"]) == 0 and int(e.s.get("germogli_catturati", 0)) == 1, "Germoglio catturato")
	# --- Scoperte Perdute
	e.s["scoperte"] = [{"tipo": "mineral", "carta": "x"}]
	mis._occupato = false
	for op in Effetti.analizza_it("Sposta tutte le Scoperte dalla plancia Lander alla casella sulla plancia Pianeta indicata come “Scoperte Perdute.”")["op"]:
		await mis._op(op, 0, sett, [], [], [], "prova")
	ok((e.s["scoperte"] as Array).is_empty() and (e.s["scoperte_perdute"] as Array).size() == 1, "Scoperte nello slot Scoperte Perdute")
	await _applica("Gain 2 [success], place all Lost Discoveries next to your Crew board.")
	ok((e.s["scoperte"] as Array).size() == 1, "Scoperte Perdute recuperate")
	# --- G35: segnalino su un sentiero collegato con [travel] (lo chiude per il movimento)
	var con_tr: Array = e.sentieri(mis.pl, sett).filter(func(p): return (p["icone"] as Array).any(func(x): return str(x).begins_with("travel")))
	if not con_tr.is_empty():
		var prima: int = e.sentieri_movimento(mis.pl, sett).size()
		await _applica("Place a marker on (or discard a marker from) a connected Path with a [travel].")
		ok(e.sentieri_movimento(mis.pl, sett).size() == prima - 1, "G35: il sentiero con il segnalino è chiuso (%d → %d)" % [prima, e.sentieri_movimento(mis.pl, sett).size()])
		await _applica("Place a marker on (or discard a marker from) a connected Path with a [travel].")
		ok(e.sentieri_movimento(mis.pl, sett).size() == prima, "G35: tolto il segnalino il sentiero si riapre")
	# --- P142: Ferita Panico prima del tiro, poi scartata con l'esito giallo
	var a142: Dictionary = _azione("P142")
	mis._occupato = false
	var r142: String = await mis._costo_prova(a142, 0, sett)
	ok(r142 == "ok" and "panicked" in e.membro(0)["ferite"] and int(e.s.get("_panico_azione", -1)) == 0, "P142: Ferita Panico prima del tiro")
	await _applica("If you gained the Panicked Injury during this Action, discard it along with the Injury die.")
	ok(not "panicked" in e.membro(0)["ferite"], "P142: la Ferita Panico si scarta con il dado Ferita")
	# --- P275: scelta fra le opzioni (vai avanti → P277)
	e.s["settori"][str(sett)]["pdi"] = ["P275"]
	e.s["azioni"] = 2
	e.s["speciale_usata"] = false
	for d in e.membro(0)["dadi"]:
		if d["stato"] != "sacrificato":
			d["stato"] = "disponibile"
	mis._occupato = false
	mis._esegui_azione(_azione("P275"), "P275", "P275#0", sett)
	await _rispondi("avanti", 30)
	await aspetta(5)
	ok(e.pdi_in_cima(sett) == "P277", "P275: scelta «Vai avanti» → carta P277 (%s)" % e.pdi_in_cima(sett))
	# --- P513 si muove di 3 Settori verso la Squadra
	var lontano := -1
	var dmax := -1
	for k in e.s["settori"]:
		var dd: int = e.distanza(mis.pl, int(k), sett)
		if dd > dmax:
			dmax = dd
			lontano = int(k)
	e.s["settori"][str(lontano)]["pdi"].append("P513")
	await _applica("Move card P513 (Hunting Party) by 3 Sectors toward the Crewmember (placing it on top of other cards in those Sectors).")
	var dove := -1
	for k in e.s["settori"]:
		if "P513" in e.s["settori"][k]["pdi"]:
			dove = int(k)
	ok(e.distanza(mis.pl, dove, sett) == maxi(0, dmax - 3), "P513: da distanza %d a %d dalla Squadra" % [dmax, e.distanza(mis.pl, dove, sett)])
	# --- M91: opzione di completamento (scarta 2 Esemplari vivi → Annotazione 426)
	e.s["scoperte"] = [{"tipo": "live_specimen", "carta": "a"}, {"tipo": "live_specimen", "carta": "b"}, {"tipo": "mineral", "carta": "c"}]
	await mis._opzione_missione("M91", "At any moment you may discard 2 Live Specimen Discoveries from your Lander", 426)
	ok((e.s["scoperte"] as Array).size() == 1 and mis._logbook.visible, "M91: scartati 2 Esemplari vivi e aperta l'Annotazione 426")
	mis._logbook.visible = false
	# --- G20: Attrezzatura da Missione bloccata
	e.s["condizione"] = {"carta": "G20", "tempo": 0}
	var me: Array = Carte.categoria("attrezzatura").filter(func(c): return str(c.get("tipo", "")) == "missionEquipment")
	ok(mis.attrezzatura_bloccata(str(me[0]["id"])), "G20: l'Attrezzatura da Missione non si può usare")
	e.s["condizione"] = {"carta": "G01", "tempo": 0}
	ok(not mis.attrezzatura_bloccata(str(me[0]["id"])), "senza G20 l'Attrezzatura si usa")

	pass

func _bottoni(nd: Node, out: Array) -> void:
	for c in nd.get_children():
		if c is Button:
			out.append(c)
		_bottoni(c, out)
