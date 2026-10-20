## Prova di dadi (Dice Check) di ISS Vanguard: requisiti, combinazioni, effetti speciali ed esiti.
## Logica pura, senza interfaccia: la usa la schermata dell'esplorazione e la provano i test.
##
## Un dado è un dizionario: {"id": "d3", "tipo": "physical", "colore": "red", "faccia": 2, "chi": 0}
## (dadi Ferita: "tipo": "ferita"; dadi Pericolo: "tipo": "pericolo", "lettera": "A").
## Le icone di un dado sono quelle della faccia in alto (data/dadi.json).
##
## Requisiti: stringa "biology+xenology / scouting" (vedi tools/trascrizione/ISTRUZIONI.md).
class_name Prova
extends RefCounted

const ICONE_REPARTO := ["biology", "xenology", "scouting", "scienceDice", "technology", "construction", "physical", "defence", "gathering"]
const COLORI := {"redDie": "red", "blueDie": "blue", "greenDie": "green"}

static var _defs := {}

static func defs() -> Dictionary:
	if _defs.is_empty():
		var f := FileAccess.open("res://data/dadi.json", FileAccess.READ)
		_defs = JSON.parse_string(f.get_as_text()) if f else {}
	return _defs

static func icone(d: Dictionary) -> Array:
	var D := defs()
	var t: String = d.get("tipo", "")
	var f := int(d.get("faccia", 0))
	if t == "ferita":
		return D["ferita"]["facce"][f]
	if t == "pericolo":
		return D["pericolo"]["facce"][f]
	if D["reparto"].has(t):
		return D["reparto"][t]["facce"][f]
	return []

static func colore(d: Dictionary) -> String:
	var t: String = d.get("tipo", "")
	return defs()["reparto"].get(t, {}).get("colore", "")

static func numero_facce(d: Dictionary) -> int:
	return 8 if d.get("tipo", "") == "pericolo" else 6

static func tira(d: Dictionary, rng: RandomNumberGenerator = null) -> void:
	var n := numero_facce(d)
	d["faccia"] = rng.randi_range(0, n - 1) if rng else randi() % n

# ------------------------------------------------------------------ requisiti

## "a+b / 2*c" -> [["a","b"], ["c","c"]]. Stringa vuota -> [[]] (sempre soddisfatto).
static func analizza(req: String) -> Array:
	req = req.strip_edges()
	if req == "":
		return [[]]
	var out := []
	for alt in req.split("/"):
		var lista := []
		for tok in alt.split("+"):
			tok = tok.strip_edges()
			if tok == "":
				continue
			var n := 1
			if tok.contains("*"):
				n = int(tok.get_slice("*", 0))
				tok = tok.get_slice("*", 1).strip_edges()
			for i in n:
				lista.append(tok)
		out.append(lista)
	return out

## Conversioni disponibili: [{"colore": "blue", "a": "xenology"}] (abilità del Membro attivo e della sua attrezzatura).
## Restituisce l'assegnazione {ok, dadi: [id usati], uso: [[id_dado, indice_icona, token, come]]}.
## Le icone "accident" non soddisfano mai i requisiti (salvo un requisito esplicito "accident").
static func soddisfa(alt: Array, dadi: Array, conv: Array = [], vietati := {}) -> Dictionary:
	# slot: ogni icona di ogni dado non vietato
	var slot := []
	for d in dadi:
		if vietati.has(d["id"]):
			continue
		var ic := icone(d)
		for i in ic.size():
			slot.append({"id": d["id"], "i": i, "icona": ic[i], "colore": colore(d), "tipo": d.get("tipo", "")})
	# prima i token più vincolanti: icone specifiche, poi "qualsiasi", poi dadi colorati
	var tok := alt.duplicate()
	tok.sort_custom(func(a, b): return _peso(a) < _peso(b))
	var usati := {}
	var interi := {}      # dadi consumati interi (requisito di colore)
	var uso := []
	var stessa := [""]    # valore scelto per anySameIcons
	var ok := _cerca(tok, 0, slot, conv, usati, interi, uso, stessa)
	var ids := {}
	for u in uso:
		ids[u[0]] = true
	return {"ok": ok, "dadi": ids.keys(), "uso": uso, "stessa": stessa[0]}

static func _peso(t: String) -> int:
	if t in ICONE_REPARTO or t in ["accident", "basic", "vanguard"]:
		return 0
	if t == "anySameIcons":
		return 1
	if COLORI.has(t):
		return 2
	if t == "die":
		return 3
	return 0

static func _cerca(tok: Array, k: int, slot: Array, conv: Array, usati: Dictionary, interi: Dictionary, uso: Array, stessa: Array) -> bool:
	if k >= tok.size():
		return true
	var t: String = tok[k]
	if COLORI.has(t) or t == "die":
		# serve un dado intero di quel colore, mai usato
		var visti := {}
		for s in slot:
			if visti.has(s["id"]) or interi.has(s["id"]) or _dado_toccato(s["id"], usati):
				continue
			visti[s["id"]] = true
			if s["tipo"] in ["ferita", "pericolo"]:
				continue
			if t != "die" and s["colore"] != COLORI[t]:
				continue
			interi[s["id"]] = true
			uso.append([s["id"], -1, t, "dado"])
			if _cerca(tok, k + 1, slot, conv, usati, interi, uso, stessa):
				return true
			uso.pop_back()
			interi.erase(s["id"])
		return false
	# prova prima gli slot "esatti", poi vanguard, poi le conversioni
	for fase in 3:
		for s in slot:
			var chiave := "%s#%d" % [s["id"], s["i"]]
			if usati.has(chiave) or interi.has(s["id"]) or s["tipo"] in ["ferita", "pericolo"]:
				continue
			var come := _corrisponde(t, s, fase, conv, stessa)
			if come == "":
				continue
			var vecchia: String = stessa[0]
			if t == "anySameIcons" and stessa[0] == "":
				stessa[0] = come.get_slice(":", 1) if come.begins_with("qualsiasi:") else stessa[0]
			usati[chiave] = true
			uso.append([s["id"], s["i"], t, come])
			if _cerca(tok, k + 1, slot, conv, usati, interi, uso, stessa):
				return true
			uso.pop_back()
			usati.erase(chiave)
			stessa[0] = vecchia
	return false

static func _dado_toccato(id: String, usati: Dictionary) -> bool:
	for k in usati:
		if str(k).begins_with(id + "#"):
			return true
	return false

## Come lo slot soddisfa il token nella fase data (0 esatto, 1 vanguard, 2 conversione); "" se no.
static func _corrisponde(t: String, s: Dictionary, fase: int, conv: Array, stessa: Array) -> String:
	var ic: String = s["icona"]
	if ic == "accident":
		return "esatto" if (t == "accident" and fase == 0) else ""
	if t == "anySameIcons":
		if stessa[0] != "":
			return _corrisponde(stessa[0], s, fase, conv, [""])
		if fase == 0 and ic != "vanguard":
			return "qualsiasi:" + ic
		if fase == 1 and ic == "vanguard":
			return "qualsiasi:vanguard"
		return ""
	match fase:
		0:
			return "esatto" if ic == t else ""
		1:
			return "vanguard" if (ic == "vanguard" and t in ICONE_REPARTO) else ""
		2:
			if ic == "basic":
				for c in conv:
					if c.get("colore", "") == s["colore"] and c.get("a", "") == t:
						return "convertito"
	return ""

## Prova le alternative di un requisito; restituisce la prima soddisfatta (con "alt": indice) o {"ok": false}.
static func soddisfa_req(req: String, dadi: Array, conv: Array = [], vietati := {}) -> Dictionary:
	var alts := analizza(req)
	for i in alts.size():
		var r := soddisfa(alts[i], dadi, conv, vietati)
		if r["ok"]:
			r["alt"] = i
			return r
	return {"ok": false}

# ------------------------------------------------------------------ effetti speciali ed esiti

## Effetti speciali (passo 7): ognuno si applica quante più volte possibile; le icone di un dado
## si contano separatamente, ma un dado usato da un effetto non serve per un altro.
## Restituisce [{"riga": i, "volte": n, "dadi": [...]}] e aggiorna 'vietati'.
static func risolvi_speciali(speciali: Array, dadi: Array, conv: Array, vietati: Dictionary) -> Array:
	var out := []
	for i in speciali.size():
		var req: String = str(speciali[i].get("req", ""))
		if req == "":
			continue
		var volte := 0
		var usati_qui := {}
		var icone_usate := {}
		while volte < 20:
			# dadi ammessi: non vietati da altri effetti; dei dadi già usati qui restano le icone libere
			var r := _soddisfa_parziale(req, dadi, conv, vietati, icone_usate)
			if not r["ok"]:
				break
			volte += 1
			for u in r["uso"]:
				usati_qui[u[0]] = true
				if u[1] >= 0:
					icone_usate["%s#%d" % [u[0], u[1]]] = true
				else:
					for j in 4:
						icone_usate["%s#%d" % [u[0], j]] = true
		if volte > 0:
			for id in usati_qui:
				vietati[id] = true
			out.append({"riga": i, "volte": volte, "dadi": usati_qui.keys()})
	return out

static func _soddisfa_parziale(req: String, dadi: Array, conv: Array, vietati: Dictionary, icone_usate: Dictionary) -> Dictionary:
	# costruisce dadi "ridotti" senza le icone già usate
	var ridotti := []
	for d in dadi:
		if vietati.has(d["id"]):
			continue
		ridotti.append(d)
	var alts := analizza(req)
	for alt in alts:
		var r := _soddisfa_escludendo(alt, ridotti, conv, icone_usate)
		if r["ok"]:
			return r
	return {"ok": false}

static func _soddisfa_escludendo(alt: Array, dadi: Array, conv: Array, icone_usate: Dictionary) -> Dictionary:
	var slot := []
	for d in dadi:
		var ic := icone(d)
		for i in ic.size():
			if icone_usate.has("%s#%d" % [d["id"], i]):
				continue
			slot.append({"id": d["id"], "i": i, "icona": ic[i], "colore": colore(d), "tipo": d.get("tipo", "")})
	var tok := alt.duplicate()
	tok.sort_custom(func(a, b): return _peso(a) < _peso(b))
	var uso := []
	var ok := _cerca(tok, 0, slot, conv, {}, {}, uso, [""])
	return {"ok": ok, "uso": uso}

## Esito (passo 8): dall'alto, la prima riga il cui requisito è soddisfatto dai dadi rimasti; la riga rossa
## senza requisito vale sempre. Restituisce {"riga": i, "dadi": [...]} (riga -1 se nessuna).
static func scegli_esito(esiti: Array, dadi: Array, conv: Array, vietati: Dictionary) -> Dictionary:
	for i in esiti.size():
		var req: String = str(esiti[i].get("req", ""))
		if req == "":
			return {"riga": i, "dadi": []}
		var r := soddisfa_req(req, dadi, conv, vietati)
		if r["ok"]:
			for id in r["dadi"]:
				vietati[id] = true
			return {"riga": i, "dadi": r["dadi"]}
	return {"riga": -1, "dadi": []}

## Effetto di un dado Pericolo con la lettera data (tabelle A-D della carta di riferimento).
static func effetto_pericolo(lettera: String, d: Dictionary) -> String:
	var ic := icone(d)
	if ic.is_empty():
		return ""
	var t: Dictionary = defs()["tabelle_pericolo"].get(lettera.substr(0, 1), {})
	return str(t.get(ic[0], ""))
