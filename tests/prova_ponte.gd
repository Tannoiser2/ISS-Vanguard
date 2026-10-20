extends SceneTree
## Potenziamenti del Ponte e delle strutture, carte spostate dal Logbook.
## ISS_PROVA=1 ISS_DB_URL=off godot --headless --path . -s res://tests/prova_ponte.gd

var errori := 0

func ok(c: bool, msg: String) -> void:
	print(("ok   " if c else "ERRORE ") + msg)
	if not c:
		errori += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var N = load("res://scripts/core/nave.gd")
	var n = N.new({})
	n.inizializza([{"carta": "A", "file": "", "reparto": "ingegneria", "grado": 1, "stato": "disponibile"},
		{"carta": "B", "file": "", "reparto": "ingegneria", "grado": 1, "stato": "disponibile"}])
	var p0 = n.genera_pool()
	n.s["morale"] = "high"
	ok(int(n.genera_pool()["comando"]) == int(p0["comando"]) + 1, "Morale Alto: +1 Comando")
	n.s["morale"] = "medium"
	ok(n.costo_rotta(3) == 3 and n.costo_destinazione(2) == 2 and n.costo_scansione(0, 2) == 2, "senza potenziamenti i costi restano")
	n.s["ponte_viaggio"] += ["B07", "B15"]
	n.s["ponte"] += ["B13", "B08", "B14", "B16", "B11", "B12"]
	ok(n.costo_rotta(3) == 2 and n.costo_rotta(1) == 1 and n.costo_rotta(0) == 0, "B07: -1 al volo, minimo 1")
	ok(n.costo_destinazione(2) == 1 and n.costo_destinazione(1) == 1, "B15: -1 alla destinazione, minimo 1")
	ok(n.costo_scansione(0, 2) == 0 and n.costo_scansione(1, 2) == 2, "B13: prima parte della scansione gratis")
	n.s["pool"] = {"comando": 2, "energia": 4, "successi": 1}
	ok(n.converti("B08") and int(n.s["pool"]["energia"]) == 6 and int(n.s["pool"]["comando"]) == 1, "B08: 1 Comando → 2 Energia")
	ok(n.converti("B14") and int(n.s["pool"]["comando"]) == 2 and int(n.s["pool"]["energia"]) == 2, "B14: 4 Energia → 1 Comando")
	ok(n.converti("B16") and int(n.s["pool"]["successi"]) == 4, "B16: 1 Comando → 3 Successi")
	ok(not n.converti("B14"), "conversione rifiutata senza segnalini")
	n.s["pool"]["successi"] = 3
	n.s["morale"] = "very_low"
	var f = n.inizio_ponte()
	ok(int(n.s["pool"]["successi"]) == 4 and str(n.s["morale"]) == "low" and f.size() == 2, "B11 e B12 all'inizio del Ponte")
	n.s["busta"] = ["B18"]
	n.installa_ponte()
	ok(n.s.get("log_da_leggere", []) == [55], "B18: Annotazione 55 da leggere all'installazione")
	n.aggiungi_potenziamento("F04")
	ok(int(n.s["code_attive"]) == 2, "F04: coda di produzione 2 sbloccata")
	# Logbook: carte spostate
	n.s["situazioni_future"] = ["S14", "S15"]
	var t := "● Sposta la carta [b]S14[/b] da “Situazioni Future” all’interno della busta “In attesa…”.\n● Sposta la carta [b]E31[/b] da “Attrezzatura non Disponibile” all’“Inventario”.\n● Se possiedi la carta [b]B05[/b], sposta la carta [b]S15[/b] nella busta “In attesa…”."
	var r = n.istruzione_carte(t)
	ok("S14" in n.s["busta"] and not "S14" in n.s["situazioni_future"], "Logbook: S14 nella busta")
	ok("E31" in n.s["armeria"], "Logbook: E31 nell'Inventario")
	ok(not "S15" in n.s["busta"] and r.size() == 2, "Logbook: le istruzioni condizionali restano al giocatore")
	n.istruzione_carte(t)
	ok(n.s["busta"].count("S14") == 1, "Logbook: rilette, le carte non si duplicano")
	n.istruzione_carte("Rimuovi la carta [b]B16[/b] dal raccoglitore per le carte [i]Ponte di Comando[/i] dal gioco.")
	ok(not n.ha_ponte("B16"), "Logbook: B16 rimossa dal gioco")
	ok(N.domanda_carte("Possiedi la carta [b]B12[/b] nel raccoglitore per le carte [i]Ponte di Comando[/i]?", n) == 1, "domanda: possiedi B12 → sì")
	ok(N.domanda_carte("Possiedi la carta[b]B06[/b] oppure [b]B12[/b] nel raccoglitore?", n) == 1, "domanda: B06 oppure B12 → sì")
	ok(N.domanda_carte("Possiedi la carta [b]B10[/b] nel raccoglitore?", n) == 0, "domanda: B10 → no")
	ok(N.domanda_carte("Possiedi la Scoperta Eccezionale 12?", n) == -1, "domanda sulle Scoperte: non è di questo tipo")
	# infermeria
	n.ricovera(0, 3)
	n.aggiungi_potenziamento("F01")
	var morti := 0
	for k in 40:
		var n2 = N.new(JSON.parse_string(JSON.stringify(n.s)))
		var p = n2.prova_sopravvivenza(0)
		if p["morto"]:
			morti += 1
	ok(morti < 40, "F01: prove di sopravvivenza con il ritiro (%d morti su 40)" % morti)
	var n3 = N.new(JSON.parse_string(JSON.stringify(n.s)))
	var lv = n3.livello_infermeria(0)
	n3.sposta_destra(0)
	ok(n3.livello_infermeria(0) != lv or n3.s["equipaggio"][0]["stato"] == "disponibile" or n3._fila().find(0) >= 0, "F02: avanza di una casella")
	n3.dimetti(0)
	ok(n3.s["equipaggio"][0]["stato"] == "riposo" and n3._fila().find(0) < 0, "F03: dall'infermeria a riposo")
	print("errori: ", errori)
	quit()
