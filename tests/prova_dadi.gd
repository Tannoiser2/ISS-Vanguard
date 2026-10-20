extends SceneTree
## Prove del motore delle prove di dadi.  godot --headless --path . -s res://tests/prova_dadi.gd
var P
var errori := 0
func _initialize() -> void:
	P = load("res://scripts/core/prova.gd")
	_run.call_deferred()
func d(id, tipo, faccia):
	return {"id": id, "tipo": tipo, "faccia": faccia}
func ok(cond, msg):
	if not cond:
		errori += 1
		print("ERRORE: ", msg)
	else:
		print("ok  ", msg)
func _run() -> void:
	# biology + xenology / scouting
	var dadi = [d("a", "biology", 0), d("b", "xenology", 0)]
	ok(P.soddisfa_req("biology+xenology / scouting", dadi)["ok"], "bio+xeno con due dadi")
	ok(not P.soddisfa_req("biology+xenology", [d("a", "biology", 0)])["ok"], "manca xeno")
	ok(P.soddisfa_req("biology+xenology", [d("a", "biology", 0), d("v", "base_verde", 1)])["ok"], "vanguard vale xeno")
	ok(not P.soddisfa_req("scouting", [d("a", "base_verde", 4)])["ok"], "accident non vale")
	ok(P.soddisfa_req("xenology", [d("a", "base_blu", 0)], [{"colore": "blue", "a": "xenology"}])["ok"], "conversione blu basic->xeno")
	ok(not P.soddisfa_req("xenology", [d("a", "base_rosso", 0)], [{"colore": "blue", "a": "xenology"}])["ok"], "conversione colore sbagliato")
	ok(P.soddisfa_req("2*scouting", [d("a", "esperto_verde", 3)])["ok"], "doppia icona su un dado")
	ok(P.soddisfa_req("redDie+blueDie", [d("a", "base_rosso", 4), d("b", "base_blu", 0)])["ok"], "dadi colorati")
	ok(P.soddisfa_req("anySameIcons+anySameIcons", [d("a", "physical", 0), d("b", "physical", 2)])["ok"], "due icone uguali")
	ok(not P.soddisfa_req("anySameIcons+anySameIcons", [d("a", "physical", 0), d("b", "defence", 0)])["ok"], "due icone diverse")
	ok(P.soddisfa_req("anySameIcons+anySameIcons", [d("a", "physical", 0), d("b", "base_rosso", 1)])["ok"], "uguale + vanguard")
	# speciali: scouting -> progress; un dado esperto con 2 scouting conta 2 volte
	var v = {}
	var s = P.risolvi_speciali([{"req": "scouting", "effetto": "outcomeGreenProgress"}], [d("a", "esperto_verde", 3), d("b", "scouting", 0)], [], v)
	ok(s.size() == 1 and s[0]["volte"] == 3, "speciale applicato 3 volte (%s)" % str(s))
	# esiti: giallo 2 scouting, verde scouting, rosso
	var es = [{"colore": "yellow", "req": "2*scouting"}, {"colore": "green", "req": "scouting"}, {"colore": "red", "req": ""}]
	var v2 = {}
	ok(P.scegli_esito(es, [d("a", "scouting", 0)], [], v2)["riga"] == 1, "esito verde")
	ok(P.scegli_esito(es, [d("a", "scouting", 4)], [], {})["riga"] == 2, "esito rosso")
	ok(P.scegli_esito(es, [d("a", "scouting", 0), d("b", "scouting", 2)], [], {})["riga"] == 0, "esito giallo")
	# pericolo
	ok(P.effetto_pericolo("B", {"tipo": "pericolo", "faccia": 1}) == "Lose 1 Supplies", "tabella pericolo B")
	print("ERRORI: ", errori)
	quit(errori)
