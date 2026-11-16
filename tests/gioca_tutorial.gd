extends SceneTree
## Gioca la prima missione (tutorial) come un giocatore: solo pulsanti dell'interfaccia, nessuna scorciatoia.
## Scrive passo passo che cosa succede e fa uno screenshot a ogni riquadro nuovo.
## ISS_PROVA=1 ISS_DADI_3D=1 ISS_DB_URL=off xvfb-run -s "-screen 0 1440x1080x24" godot --path . -s res://tests/gioca_tutorial.gd -- [seme] [nofoto]

var main
var mis
var cartella := ""
var nfoto := 0
var foto_on := true
var diario_visto := 0
var log_letti := []
var passi := 0
var bloccato := 0
var visitati := {}
var m01_fatta := false
var solo_m01 := false

func _initialize() -> void:
	cartella = OS.get_user_data_dir() + "/gioco"
	DirAccess.make_dir_recursive_absolute(cartella)
	for f in DirAccess.get_files_at(cartella):
		DirAccess.remove_absolute(cartella + "/" + f)
	foto_on = not "nofoto" in OS.get_cmdline_user_args()
	root.size = Vector2i(1440, 1080)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func aspetta(sec := 0.3) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000:
		await process_frame

func foto(nome: String) -> void:
	if not foto_on:
		return
	for i in 5:
		await process_frame
	nfoto += 1
	root.get_viewport().get_texture().get_image().save_png(cartella + "/%03d_%s.png" % [nfoto, nome.validate_filename().substr(0, 40)])

func scrivi(t: String) -> void:
	print(t)

func _bottoni(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Button and c.is_visible_in_tree() and not c.disabled:
			out.append(c)
		_bottoni(c, out)

func bottoni(n: Node) -> Array:
	var out := []
	_bottoni(n, out)
	return out

func premi(b: Button, perche := "") -> void:
	if b == null or not is_instance_valid(b):
		scrivi("      !!! pulsante sparito")
		return
	scrivi("      [premo] %s%s" % [b.text.replace("\n", " ").substr(0, 70), ("  (" + perche + ")") if perche != "" else ""])
	if b is CheckBox:
		b.button_pressed = not b.button_pressed
	else:
		b.pressed.emit()
	await aspetta(0.25)

func testo_di(n: Node) -> String:
	var out := []
	for c in n.find_children("*", "", true, false):
		if not (c is Control) or not c.is_visible_in_tree():
			continue
		if c is RichTextLabel:
			out.append(c.get_parsed_text())
		elif c is Label:
			out.append(c.text)
	return " | ".join(out).replace("\n", " ")

func stato() -> String:
	var e = mis.esp
	var s: Dictionary = e.s
	var sq := []
	for i in s["equipaggio"].size():
		var m: Dictionary = s["equipaggio"][i]
		sq.append("%s%s@S%d dadi %d" % ["*" if i == int(s["attivo"]) else "", str(m["carta"]).get_slice(" ", 0), int(m["settore"]), e.dadi_disponibili(i).size()])
	var pdi := []
	for k in s["settori"]:
		if not (s["settori"][k]["pdi"] as Array).is_empty():
			pdi.append("S%s:%s" % [k, ",".join(s["settori"][k]["pdi"])])
	return "R%d az%d | %s | missioni %s | succ %d | PDI %s" % [int(s["round"]), int(s["azioni"]), ", ".join(sq), str(s["missioni"]), int(s["successi"]), " ".join(pdi)]

func novita() -> void:
	var d: Array = mis.esp.s["diario"]
	for i in range(diario_visto, d.size()):
		scrivi("      diario: " + str(d[i]))
	diario_visto = d.size()
	if mis._toast.modulate.a > 0.5 and mis._toast.text != "":
		scrivi("      avviso: " + mis._toast.text)
		mis._toast.modulate.a = 0.0

## Riquadri aperti che chiedono qualcosa: li risolve finché non ne restano.
func risolvi_riquadri(pref := "") -> void:
	for giro in 200:
		await aspetta(0.2)
		novita()
		var fatto := false
		# finestra della Prova
		for f in mis.get_children():
			if _e_prova(f) and not f.is_queued_for_deletion():
				await prova(f)
				fatto = true
				break
		if fatto:
			continue
		# Logbook
		if mis._logbook.visible:
			await logbook(pref)
			continue
		# riquadri di scelta / effetti (velo scuro con i pulsanti)
		for c in mis.get_children():
			if c is ColorRect and c.visible and not c.is_queued_for_deletion() and c.get_child_count() > 0 and bottoni(c).size() > 0:
				await riquadro(c, pref)
				fatto = true
				break
		if fatto:
			continue
		# scelta di un settore sulla mappa in corso
		if mis._scelta_settore:
			return
		if not mis._occupato:
			return
	scrivi("!!! riquadri senza fine")

func riquadro(c: Control, pref: String) -> void:
	var t := testo_di(c)
	scrivi("    RIQUADRO: " + t.substr(0, 400))
	await foto("riquadro")
	var bs := bottoni(c)
	for b in bs:
		if pref != "" and b.text.to_upper().contains(pref.to_upper()):
			await premi(b, "preferito")
			return
	for nome in ["OK", "CHIUDI", "PROSEGUI", "CONTINUA"]:
		for b in bs:
			if b.text.strip_edges().to_upper() == nome:
				await premi(b)
				return
	for b in bs:
		if not b.text.to_upper().contains("ANNULLA") and not b.text.to_upper().begins_with("VEDI"):
			await premi(b, "prima opzione")
			return
	await premi(bs[0])

func logbook(pref: String) -> void:
	var lb = mis._logbook
	var numero: String = lb._numero.text
	if not numero in log_letti:
		log_letti.append(numero)
	var t := testo_di(lb._corpo)
	scrivi("    LOGBOOK %s: %s" % [numero, t.substr(max(0, t.length() - 500))])
	await foto("logbook_" + numero)
	var bs := bottoni(lb._corpo)
	for prio in ["PROSEGUI", "TIRA IL DADO PERICOLO"]:
		for b in bs:
			if b.text.to_upper().contains(prio):
				await premi(b)
				return
	var scelte := bs.filter(func(b): return b.text.begins_with("▸") or b.text.begins_with("Prosegu") or b.text.begins_with("Procede"))
	for b in scelte:
		if pref != "" and b.text.to_upper().contains(pref.to_upper()):
			await premi(b, "preferita")
			return
	if not scelte.is_empty():
		await premi(scelte[0], "prima scelta")
		return
	for prio in ["FINE DELL'ANNOTAZIONE", "TORNA AL TAVOLO"]:
		for b in bs:
			if b.text.to_upper().contains(prio):
				await premi(b)
				return
	scrivi("    !!! Logbook senza pulsanti utili: " + ", ".join(bs.map(func(b): return b.text)))
	lb.visible = false

func _e_prova(n: Node) -> bool:
	return n.get_script() != null and str(n.get_script().resource_path).ends_with("finestra_prova.gd")

func prova(f) -> void:
	scrivi("    PROVA: " + f._titolo.text)
	# 1. tutti i dadi
	var bt = cerca(f, "TUTTI")
	if bt:
		await premi(bt)
	await foto("prova_scelta")
	var bd = cerca(f, "TIRA I DADI")
	if bd:
		await premi(bd)
	else:
		scrivi("      !!! nessun pulsante TIRA I DADI: " + testo_di(f).substr(0, 300))
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(f) and f._fase == 0 and Time.get_ticks_msec() - t0 < 60000:
		await aspetta(0.2)
	await aspetta(0.5)
	if not is_instance_valid(f):
		return
	scrivi("      tiro: " + testo_di(f._corpo).substr(0, 300))
	await foto("prova_tiro")
	for giro in 20:
		if not is_instance_valid(f) or f.is_queued_for_deletion():
			return
		var bs := bottoni(f)
		var b_ok = null
		for b in bs:
			if b.text in ["RISOLVI LA PROVA", "APPLICA", "FATTO"]:
				b_ok = b
		if b_ok == null:
			await aspetta(0.3)
			continue
		if b_ok.text == "APPLICA":
			scrivi("      esito: " + testo_di(f._corpo).substr(0, 400))
			await foto("prova_esito")
		await premi(b_ok)
		await aspetta(0.4)

func cerca(n: Node, testo: String):
	for b in bottoni(n):
		if b.text == testo:
			return b
	return null

func bottone_barra(prefisso: String) -> Button:
	for b in bottoni(mis._azioni_box):
		if b.text.to_upper().begins_with(prefisso.to_upper()) or b.text.to_upper().contains(prefisso.to_upper()):
			return b
	return null

## distanza in viaggi da un settore al 4
## settore indicato dall'obiettivo della Missione in corso (0 se nessuno)
func obiettivo() -> int:
	for idm in mis.esp.s["missioni"]:
		var c: Dictionary = mis.Carte.per_id(str(idm)) if false else root.get_node("Carte").per_id(str(idm))
		var mm := RegEx.create_from_string("(?i)sector (\\d+)").search(str(c.get("obiettivo", {}).get("en", "")))
		if mm:
			return int(mm.get_string(1))
	return 0

func passo_verso(da: int, a: int) -> int:
	var e = mis.esp
	var visti := {da: -1}
	var coda := [da]
	while not coda.is_empty():
		var x: int = coda.pop_front()
		if x == a:
			var cur := a
			while visti[cur] != da and visti[cur] != -1:
				cur = visti[cur]
			return cur
		var icone: Array = e.icone_settore(mis.pl, x, mis._carte_pdi())
		if "noMovement" in icone:
			continue
		for st in e.sentieri_movimento(mis.pl, x):
			var y := int(st["a"])
			if not visti.has(y):
				visti[y] = x
				coda.append(y)
	return -1

func _run() -> void:
	solo_m01 = "m01" in OS.get_cmdline_user_args()
	seed(int(OS.get_cmdline_user_args()[0]) if not OS.get_cmdline_user_args().is_empty() and OS.get_cmdline_user_args()[0].is_valid_int() else 7)
	var campagna = root.get_node("Campagna")
	campagna.nuova(8, "Prova tutorial", "campagna")
	campagna.dati["prossimo_pianeta"] = "p.2-3"
	main.mostra_gioco()
	await aspetta(2)
	var g = main.get_child(main.get_child_count() - 1)
	g.logbook.visible = false
	g.apri_esplorazione()
	await aspetta(1)
	for c in g.ui.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("preparazione_missione.gd"):
			c._conferma()
	await aspetta(3)
	mis = g._missione
	scrivi("INIZIO: " + stato())
	await foto("inizio")
	await risolvi_riquadri()
	var e = mis.esp
	var ultimo_round := -1
	while passi < 140:
		passi += 1
		await risolvi_riquadri()
		var s: Dictionary = e.s
		if not "M01" in s["missioni"] and not m01_fatta:
			m01_fatta = true
			scrivi("=== MISSIONE M01 COMPLETATA al round %d" % int(s["round"]))
			scrivi("STATO: " + stato())
			await foto("m01_completata")
			if solo_m01:
				break
		if str(s.get("finita", "")) != "":
			scrivi("=== esplorazione finita: " + str(s["finita"]))
			break
		if int(s["round"]) > 16:
			scrivi("=== TROPPI ROUND, missione non completata")
			break
		if int(s["round"]) != ultimo_round:
			ultimo_round = int(s["round"])
			await foto("round_%d" % ultimo_round)
		var chi := int(s["attivo"])
		var m: Dictionary = e.membro(chi)
		var sett := int(m["settore"])
		scrivi("\nTURNO di %s nel Settore %d — %s" % [m["carta"], sett, stato()])
		scrivi("   barra: " + ", ".join(bottoni(mis._azioni_box).map(func(b): return b.text)) + "  | passo: " + mis._passo.get_parsed_text())
		if int(s["azioni"]) <= 0:
			if bottone_barra("FINE TURNO") == null:
				bloccato += 1
				if bloccato > 5:
					scrivi("!!! BLOCCATO: nessun pulsante FINE TURNO")
					break
				continue
			await premi(bottone_barra("FINE TURNO"))
			await risolvi_riquadri()
			continue
		var tutti_in_4: bool = sett == 4
		var b_sp: Button = null
		for b in bottoni(mis._azioni_box):
			if b.text.begins_with("◆"):
				b_sp = b
		var meta := obiettivo()
		scrivi("   obiettivo: Settore %d — guida: %s" % [meta, mis._turno_obiettivo.get_parsed_text()])
		var dest := passo_verso(sett, meta) if sett != meta and meta > 0 else -1
		var esplora := -1
		if dest < 0 and sett != meta:
			# il 4 non è raggiungibile con i sentieri: si va a esplorare un settore collegato mai visitato
			for st in e.sentieri_movimento(mis.pl, sett):
				if not int(st["a"]) in visitati:
					esplora = int(st["a"])
		visitati[sett] = true
		var b_v := bottone_barra("VIAGGIO")
		var spec_txt := ""
		if b_sp:
			for a in mis._azioni_settore(sett):
				spec_txt += JSON.stringify(a["azione"])
		if e.dadi_disponibili(chi).is_empty() and bottone_barra("RIPOSO"):
			await premi(bottone_barra("RIPOSO"), "nessun dado disponibile")
		elif sett == meta and b_sp and e.dadi_disponibili(chi).size() > 1:
			await premi(b_sp, "azione speciale nel settore della Missione")
		elif sett == meta or meta <= 0:
			# aspetta gli altri: riposa se ha poco, altrimenti termina
			if bottone_barra("RIPOSO") and e.dadi_disponibili(chi).size() < 3:
				await premi(bottone_barra("RIPOSO"), "aspetto gli altri nel Settore 4")
			else:
				await premi(bottone_barra("FINE TURNO"), "già nel settore obiettivo")
		elif b_sp and (dest < 0 or spec_txt.contains("Sector %d" % meta)) and e.dadi_disponibili(chi).size() > 0:
			await premi(b_sp, "azione speciale per uscire / andare verso il 4")
		elif b_v and esplora > 0 and not (b_sp and spec_txt.contains("Sector %d" % meta)):
			await premi(b_v, "esploro il Settore %d" % esplora)
			await aspetta(0.3)
			if mis._scelta_settore:
				scrivi("      [clic sulla mappa] Settore %d" % esplora)
				mis._settore_scelto.emit(esplora)
				await aspetta(0.3)
		elif b_v and dest > 0:
			await premi(b_v, "verso il Settore %d" % dest)
			await aspetta(0.3)
			if mis._scelta_settore:
				scrivi("      [clic sulla mappa] Settore %d" % dest)
				mis._settore_scelto.emit(dest)
				await aspetta(0.3)
		elif b_sp and e.dadi_disponibili(chi).size() > 0:
			await premi(b_sp, "esploro")
		elif bottone_barra("RIPOSO"):
			await premi(bottone_barra("RIPOSO"), "nessuna mossa utile")
		else:
			await premi(bottone_barra("FINE TURNO"), "nessuna mossa")
		await risolvi_riquadri()
		await foto("dopo_mossa")
	scrivi("\nAnnotazioni lette: " + ", ".join(log_letti))
	scrivi("FINE: " + stato())
	quit()
