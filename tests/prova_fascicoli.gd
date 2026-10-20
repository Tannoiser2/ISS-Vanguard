extends SceneTree
## Espansione Fascicoli del personale: Obiettivo individuale alla promozione, Veterani con due conversioni.
## ISS_PROVA=1 ISS_DB_URL=off godot --headless --path . -s res://tests/prova_fascicoli.gd

var errori := 0

func ok(c: bool, msg: String) -> void:
	print(("ok   " if c else "ERRORE ") + msg)
	if not c:
		errori += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var Carte = root.get_node("Carte")
	var F = load("res://scripts/core/fascicoli.gd")
	var N = load("res://scripts/core/nave.gd")
	var base := []
	for c in Carte.categoria("equipaggio"):
		if str(c.get("lato", "fronte")) != "retro":
			base.append(c)
	var trovati := 0
	for c in base:
		if not F.veterano_di(str(c["file"])).is_empty():
			trovati += 1
	ok(trovati == base.size(), "ogni Membro ha la sua carta Veterano (%d/%d)" % [trovati, base.size()])
	var mark: Dictionary = {}
	for c in base:
		if str(c.get("nome", "")).begins_with("MARK"):
			mark = c
	var n = N.new({})
	n.inizializza([{"carta": "Mark", "file": str(mark["file"]), "reparto": "scienza", "grado": 1, "stato": "disponibile"},
		{"carta": "B", "file": str(base[1]["file"]), "reparto": "scienza", "grado": 1, "stato": "disponibile"}])
	n.s["fascicoli"] = 2
	ok(n.controlla_fascicolo(0) == "", "Grado 1: nessun Obiettivo individuale")
	n.s["equipaggio"][0]["grado"] = 2
	var f: String = n.controlla_fascicolo(0)
	ok(f != "" and n.s["equipaggio"][0]["obiettivo"]["traccia"] == 0, "Grado 2: Obiettivo individuale di Mark")
	ok(n.controlla_fascicolo(0) == "", "l'Obiettivo non si assegna due volte")
	var v: Dictionary = Carte.per_file(f)
	ok(F.caselle(v) == 2 and F.testo_obiettivo(v) != "", "carta di Mark: traccia di 2 caselle e testo dell'Obiettivo")
	ok(n.conversioni(0).size() == 1, "prima: una conversione")
	n.diventa_veterano(0)
	ok(n.s["equipaggio"][0].get("veterano", false) and n.conversioni(0).size() == 2 and not n.s["equipaggio"][0].has("obiettivo"), "Veterano: due conversioni, Obiettivo concluso")
	n.s["equipaggio"][1]["grado"] = 2
	n.s["fascicoli"] = 3
	ok(n.controlla_fascicoli().is_empty(), "versione impegnativa: serve il Grado 3")
	n.s["fascicoli"] = 0
	n.s["equipaggio"][1]["grado"] = 3
	ok(n.controlla_fascicoli().is_empty(), "espansione spenta: niente Obiettivi")
	print("errori: ", errori)
	quit()
