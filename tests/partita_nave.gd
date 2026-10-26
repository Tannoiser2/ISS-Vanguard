extends SceneTree
## Partita simulata della Gestione della Nave: percorre tutti i passi del Ship Book per più giri e preme
## ogni pulsante attivo (anche quelli sotto le carte e nelle carte ingrandite), rispondendo da sola alle
## finestre di scelta. L'esplorazione planetaria è sostituita da un esito finto (Ferite, un caduto,
## Scoperte in eccesso). Cerca errori di script e blocchi.
## ISS_PROVA=1 ISS_DB_URL=off godot --headless --path . -s res://tests/partita_nave.gd -- [giri] [seme]

var main
var gn
var premuti := 0
var finestre := 0
var zoom := 0

func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func aspetta(n := 2) -> void:
	for i in n:
		await process_frame

func _bottoni(nd: Node, out: Array) -> void:
	for c in nd.get_children():
		if c is Button and not c is CheckBox and not c is OptionButton and c.is_visible_in_tree() and not c.disabled:
			out.append(c)
		_bottoni(c, out)

## Le finestre di scelta aperte (velo con il riquadro al centro).
func _finestre() -> Array:
	return gn.get_children().filter(func(c): return c is ColorRect and c.get_child_count() > 0 and c.get_child(0) is CenterContainer and not c.is_queued_for_deletion())

## Risponde alle finestre aperte: la prima opzione che non sia ANNULLA (a caso fra le prime se ce ne sono di più).
func _rispondi() -> void:
	for k in 40:
		await aspetta()
		var fs := _finestre()
		if fs.is_empty():
			return
		var bs := []
		_bottoni(fs.back(), bs)
		bs = bs.filter(func(b): return b.text != "ANNULLA")
		if bs.is_empty():
			fs.back().queue_free()
			continue
		finestre += 1
		bs[randi() % mini(2, bs.size())].pressed.emit()
	print("  BLOCCO: finestre che non si chiudono")

const VIETATI := ["SALVA E TORNA AL TAVOLO", "VAI ALL'ESPLORAZIONE", "CONGEDA UN MEMBRO", "TRASFERISCI A UN ALTRO REPARTO"]

func _avanti(b: Button) -> bool:
	return b.text.ends_with("▶") and not b.text.begins_with("◀")

func _passo() -> void:
	var fatti := {}
	for giro in 60:
		var bs := []
		_bottoni(gn._corpo, bs)
		var chiave_passo: String = gn.nave.passo() + "/" + gn._sotto
		var scelto: Button = null
		var visti := {}
		for b in bs:
			var t: String = b.text
			var n := int(visti.get(t, 0))
			visti[t] = n + 1
			var k := "%s|%s|%d" % [chiave_passo, t, n]
			if fatti.has(k) or t in VIETATI or _avanti(b) or t.contains("TORNA ALLE STRUTTURE") or t.contains("ATTERRA") or t.contains("ESPLORAZIONE È FINITA"):
				continue
			fatti[k] = true
			scelto = b
			break
		if scelto == null:
			# carte ingrandite: una per passo
			var cv := _carta(gn._corpo)
			if cv and not fatti.has(chiave_passo + "|zoom"):
				fatti[chiave_passo + "|zoom"] = true
				zoom += 1
				cv.ingrandisci.emit()
				await _rispondi()
				continue
			var torna := bs.filter(func(b): return b.text.contains("TORNA ALLE STRUTTURE"))
			if not torna.is_empty():
				torna[0].pressed.emit()
				await _rispondi()
				continue
			return
		premuti += 1
		scelto.pressed.emit()
		await _rispondi()
	print("  BLOCCO: troppi pulsanti in ", gn.nave.passo())

func _carta(nd: Node) -> Node:
	for c in nd.get_children():
		if c.has_signal("ingrandisci"):
			return c
		var x := _carta(c)
		if x:
			return x
	return null

## Esplorazione finta: Ferite, un caduto, Scoperte in eccesso, Missione rimasta e Grado Superiore girato.
func _esplora(sp: Dictionary) -> void:
	var Carte = root.get_node("Carte")
	var eq := []
	var k := 0
	for m in sp.get("membri", []):
		eq.append({"nave": int(m["nave"]), "carta": m["carta"], "file": m["file"], "ferite": ["wounded", "panicked"].slice(0, k % 3), "morto": k == 1})
		k += 1
	var sc := []
	var tutte: Array = Carte.categoria("scoperte").filter(func(x): return str(x.get("campi", {}).get("rarita", "")) != "exceptional")
	for i in 7:
		var c: Dictionary = tutte[randi() % tutte.size()]
		sc.append({"tipo": str(c.get("campi", {}).get("categoria", "")), "carta": str(c["file"])})
	(root.get_node("Campagna").dati.get_or_add("esplorazioni_concluse", []) as Array).append({"pagina": sp.get("pagina", ""), "finita": "decollo", "successi": 6,
		"scoperte": sc, "eccezionali": [], "equipaggio": eq, "grado_girato": true, "missioni_rimaste": ["M01"]})
	gn.nave.vai("partenza")
	gn.aggiorna()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var giri: int = int(args[0]) if args.size() > 0 else 2
	seed(int(args[1]) if args.size() > 1 else 3)
	var campagna = root.get_node("Campagna")
	var Carte = root.get_node("Carte")
	campagna.nuova(8, "Partita nave", "campagna")
	var rep := {"AMIR ZAYNAB": "scienza", "CHO JAE-YONG": "ingegneria", "JOPPE ULRICH": "ricognizione", "RIKU HASHIMURA": "sicurezza",
		"LENA FREEMAN": "sicurezza", "PETRA SEDLÁČKOVÁ": "ricognizione", "EBE OKAFOR": "scienza", "MARK BARNES": "ingegneria"}
	var eq := []
	for c in Carte.categoria("equipaggio"):
		var n := str(c.get("nome", "")).to_upper()
		if rep.has(n) and str(c.get("lato", "fronte")) != "retro" and not eq.any(func(x): return str(x["carta"]).to_upper() == n):
			eq.append({"carta": c["nome"], "file": c["file"], "reparto": rep[n], "grado": 1, "stato": "disponibile"})
	var st := {}
	var N = load("res://scripts/core/nave.gd")
	N.new(st).inizializza(eq)
	st["pool"]["successi"] = 12
	for c in Carte.categoria("scoperte").slice(0, 40):
		st["scoperte"].append({"tipo": str(c.get("campi", {}).get("categoria", "")), "file": str(c.get("file", "")), "rarita": str(c.get("campi", {}).get("rarita", ""))})
	campagna.dati["nave"] = st
	var G = load("res://scripts/ui/gestione_nave.gd")
	gn = G.new(st)
	var cl := CanvasLayer.new()
	main.add_child(cl)
	cl.add_child(gn)
	gn.esplora.connect(_esplora)
	gn._logbook.visible = false
	await aspetta(5)
	var passi := 0
	var cicli := 0
	var ultimo := ""
	var fermo := 0
	while cicli < giri and passi < 60 * giri:
		passi += 1
		var p: String = gn.nave.passo()
		await _passo()
		if p == "lancio":
			# una persona per Reparto fra i disponibili
			var sq := []
			var r_fatti := {}
			for i in gn.nave.membri("", "disponibile"):
				var r: String = st["equipaggio"][i]["reparto"]
				if not r_fatti.has(r) and r_fatti.size() < 3:
					r_fatti[r] = true
					sq.append(i)
			gn._scelta["squadra"] = sq
			if r_fatti.size() < 2:
				print("  fine: meno di 2 Reparti con Membri disponibili (%s)" % str(gn.nave.membri().map(func(i): return st["equipaggio"][i]["stato"])))
				break
			gn._atterra()
			await aspetta(3)
		elif p == "esplorazione":
			_esplora(st.get("spedizione", {}))
		else:
			var bs := []
			_bottoni(gn._corpo, bs)
			var av := bs.filter(func(b): return _avanti(b))
			if av.is_empty():
				print("  BLOCCO: nessun pulsante per andare avanti in ", p)
				break
			av.back().pressed.emit()
			await _rispondi()
		await aspetta(3)
		var q: String = gn.nave.passo()
		var nomi := {"comando": 0, "energia": 0}
		print("%-12s → %-12s Morale %s, Comando %d, Energia %d, Successi %d, Scoperte %d, Membri vivi %d, Muro %s" % [p, q, st["morale"], int(st["pool"]["comando"]), int(st["pool"]["energia"]),
			int(st["pool"]["successi"]), (st["scoperte"] as Array).size(), gn.nave.membri().filter(func(i): return st["equipaggio"][i]["stato"] != "morto").size(), str(st.get("muro", {}))])
		if q == p:
			fermo += 1
			if fermo > 2:
				print("  BLOCCO: fermo in ", p)
				break
		else:
			fermo = 0
		if p == "salvataggio" and q != p:
			cicli += 1
	print("giri completati: %d, passi %d, pulsanti premuti %d, finestre %d, carte ingrandite %d" % [cicli, passi, premuti, finestre, zoom])
	print("diario (ultime righe):")
	for r in (st["diario"] as Array).slice(-15):
		print("  ", r)
	print("fine partita nave")
	quit()
