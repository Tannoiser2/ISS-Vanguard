extends SceneTree
## Salvataggi: aggiornamento dei salvataggi vecchi (dati mancanti aggiunti), copie di sicurezza,
## esporta / importa da file, ritorno a una copia.
## ISS_PROVA=1 ISS_DB_URL=off godot --headless --path . -s res://tests/prova_salvataggi.gd

var main
var errori := 0

func _initialize() -> void:
	root.size = Vector2i(1280, 800)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func ok(cond: bool, t: String) -> void:
	print(("ok   " if cond else "ERRORE ") + t)
	if not cond:
		errori += 1

func _run() -> void:
	var campagna = root.get_node("Campagna")
	var Carte = root.get_node("Carte")
	campagna.nuova(8, "Prova salvataggi", "campagna")
	var cod: String = campagna.codice()
	# nave e esplorazione "vecchie": senza alcuni dati che le versioni nuove usano
	var nv := {}
	load("res://scripts/core/nave.gd").new(nv).inizializza([{"carta": "AMIR ZAYNAB", "file": "x", "reparto": "scienza", "grado": 2, "stato": "riposo"}])
	nv.erase("code_attive")
	nv.erase("usate_strutture")
	(nv["pool"] as Dictionary).erase("successi")
	nv["equipaggio"][0].erase("stato")
	var E = load("res://scripts/core/esplorazione.gd")
	var e = E.new()
	e.prepara("p.4-5", Carte.pianeta("p.4-5"), [{"nave": 0, "carta": "AMIR ZAYNAB", "file": "", "reparto": "scienza", "grado": 1, "dadi": ["base_rosso"], "mazzo": []}], {"nome": "SPACE RANGER", "provviste": 6}, {})
	var es: Dictionary = e.s
	es.erase("eccezionali_pianeta")
	es.erase("fuori_sacchetto")
	(es["settori"].values()[0] as Dictionary).erase("segnalini")
	(es["equipaggio"][0] as Dictionary).erase("conv_extra")
	(es["lander"] as Dictionary).erase("danni")
	campagna.dati["nave"] = nv
	campagna.dati["esplorazione"] = es
	campagna.dati["versione"] = 1
	campagna._salva_locale()
	var n_copie0: int = campagna.elenco_copie(cod).size()
	# riapertura: si aggiorna
	ok(campagna.carica_locale(cod), "la campagna vecchia si apre")
	var d: Dictionary = campagna.dati
	ok(int(d["versione"]) == campagna.VERSIONE, "versione aggiornata a %d" % campagna.VERSIONE)
	ok(d["nave"].has("code_attive") and d["nave"].has("usate_strutture") and d["nave"]["pool"].has("successi"), "nave: aggiunti i dati mancanti")
	ok(str(d["nave"]["equipaggio"][0].get("stato", "")) == "riposo" and int(d["nave"]["equipaggio"][0]["grado"]) == 2, "nave: il Membro ha di nuovo uno stato, il Grado non cambia")
	ok(d["esplorazione"].has("eccezionali_pianeta") and d["esplorazione"].has("fuori_sacchetto"), "esplorazione: aggiunti i dati mancanti")
	ok((d["esplorazione"]["settori"].values()[0] as Dictionary).has("segnalini"), "esplorazione: settori completati")
	ok((d["esplorazione"]["equipaggio"][0] as Dictionary).has("conv_extra") and (d["esplorazione"]["lander"] as Dictionary).has("danni"), "esplorazione: Membri e Lander completati")
	ok(JSON.stringify(d["registro"]["eventi"]).contains("Salvataggio aggiornato"), "il diario della campagna registra l'aggiornamento")
	var copie: Array = campagna.elenco_copie(cod)
	ok(copie.size() == n_copie0 + 1, "copia di sicurezza fatta all'apertura (%d copie)" % copie.size())
	var vecchia = JSON.parse_string(FileAccess.get_file_as_string(copie[0]["file"]))
	ok(vecchia is Dictionary and int(vecchia.get("versione", 0)) == 1, "la copia è il salvataggio di prima dell'aggiornamento")
	# riaprire due volte senza cambiare nulla non crea copie doppie
	campagna._salva_locale()
	campagna.carica_locale(cod)
	ok(campagna.elenco_copie(cod).size() <= copie.size() + 1, "nessuna copia doppia")
	# esporta / importa
	campagna.dati["nave"]["pool"]["comando"] = 7
	var testo: String = campagna.esporta(cod)
	campagna.dati["nave"]["pool"]["comando"] = 0
	ok(campagna.importa(testo) and int(campagna.dati["nave"]["pool"]["comando"]) == 7, "importa dal file: si riprende il salvataggio scaricato")
	ok(not campagna.importa("{\"nome\": \"altro\"}"), "un file che non è un salvataggio viene rifiutato")
	# ritorno alla copia di prima dell'aggiornamento
	var c0: String = campagna.elenco_copie(cod).back()["file"]
	ok(campagna.ripristina_copia(c0), "si torna a una copia di sicurezza")
	ok(campagna.dati.has("nave"), "dopo il ritorno la campagna è leggibile (e di nuovo aggiornata)")
	ok(campagna.elenco_copie(cod).size() <= campagna.MAX_COPIE, "al massimo %d copie per campagna" % campagna.MAX_COPIE)
	print("errori: %d" % errori)
	quit()
