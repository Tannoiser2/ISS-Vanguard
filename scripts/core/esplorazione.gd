## Motore dell'esplorazione planetaria di ISS Vanguard (regolamento pagg. 12-27, Ship Book pag. 24).
## Logica pura: lo stato è un dizionario (salvato nella campagna), l'interfaccia chiama i metodi
## e mostra ciò che restituiscono. Le scelte del giocatore (quale dado, quale sentiero…) arrivano
## come parametri; dove una regola dipende da un testo non riconosciuto il motore lo segnala come
## istruzione da eseguire a mano.
class_name Esplorazione
extends RefCounted

signal registro(testo: String)

const LIMITE_MANO := {1: 2, 2: 3, 3: 4}
const MAZZO_FERITE := {"wounded": 12, "panicked": 6, "freezing": 6, "exhausted": 12, "critically_wounded": 6, "burned": 6, "just_a_scratch": 4}
const TIPI_SCOPERTA := ["mineral", "microorganism", "live_specimen", "strange_flora", "alien_tech"]
const MAX_FERITE := 3

var s: Dictionary
var rng := RandomNumberGenerator.new()
var _id_dado := 0

func _init(stato: Dictionary = {}) -> void:
	s = stato
	rng.randomize()
	_id_dado = int(s.get("n_dadi", 0))

func diario(t: String) -> void:
	s.get_or_add("diario", []).append(t)
	registro.emit(t)

# ------------------------------------------------------------------ preparazione

## squadra: [{"carta": nome, "reparto": "scienza", "grado": 1, "dadi": [tipi], "mazzo": [id carte reparto], "conv": {...}, "cariche": n}]
## pianeta: dati della plancia (Carte.pianeta(pagina)); lander: {"nome", "provviste", "settore"(opz.)}
func prepara(pagina: String, pianeta: Dictionary, squadra: Array, lander: Dictionary, mazzi: Dictionary) -> void:
	s.clear()
	s["pagina"] = pagina
	s["round"] = 1
	s["settori"] = {}
	for st in pianeta.get("settori", []):
		var n := str(int(st.get("n", 0)))
		var pdi := []
		if str(st.get("pdi", "")) != "":
			pdi.append(str(st["pdi"]))
		s["settori"][n] = {"pdi": pdi, "tempo": 0, "segnalini": 0, "tracce": {}, "finito": false, "visitato": false,
			"log": int(st["log"]) if st.get("log") != null else 0}
	var sett_lander := int(lander.get("settore", 0))
	if sett_lander == 0:
		for st in pianeta.get("settori", []):
			if "lander" in st.get("icone", []):
				sett_lander = int(st["n"])
				break
	# senza icona Lander (es. il tutorial, dove il Lander è precipitato) non c'è un settore di decollo
	s["lander"] = {"nome": lander.get("nome", "Lander"), "settore": sett_lander, "provviste": int(lander.get("provviste", 6)),
		"max_scoperte": int(lander.get("scoperte_max", 5))}
	s["equipaggio"] = []
	for m in squadra:
		var c := {"carta": m.get("carta", ""), "file": m.get("file", ""), "nave": int(m.get("nave", -1)), "reparto": m.get("reparto", ""), "grado": int(m.get("grado", 1)),
			"settore": int(m.get("settore", sett_lander if sett_lander > 0 else 1)), "dadi": [], "dadi_ferita": 0, "ferite": [],
			"mano": [], "mazzo": (m.get("mazzo", []) as Array).duplicate(), "scarti": [], "cariche": int(m.get("cariche", 0)),
			"conv": m.get("conv", {}), "turno_fatto": false, "morto": false, "attrezzatura": (m.get("attrezzatura", []) as Array).duplicate()}
		for t in m.get("dadi", []):
			c["dadi"].append(_nuovo_dado(t))
		_mescola(c["mazzo"])
		s["equipaggio"].append(c)
	for i in s["equipaggio"].size():
		for k in int(squadra[i].get("mano_iniziale", 2)):
			pesca_carta(i)
	s["primo"] = 0
	s["attivo"] = 0
	s["azioni"] = 2
	s["speciale_usata"] = false
	s["eventi"] = (mazzi.get("eventi", []) as Array).duplicate()
	_mescola(s["eventi"])
	s["scarti_eventi"] = []
	s["condizione"] = {"carta": str(mazzi.get("condizione", "")), "tempo": 0}
	s["missioni"] = (mazzi.get("missioni", []) as Array).duplicate()
	s["minacce"] = []
	s["mazzi_scoperte"] = {}
	for t in TIPI_SCOPERTA:
		var m: Array = (mazzi.get("scoperte", {}).get(t, []) as Array).duplicate()
		_mescola(m)
		s["mazzi_scoperte"][t] = m
	s["indizi"] = {}
	for t in TIPI_SCOPERTA:
		s["indizi"][t] = []
	s["sacchetto"] = (mazzi.get("indizi", []) as Array).duplicate()   # [{"v": 1, "carta": false, "carica": false, "riciclo": false}]
	s["fuori_sacchetto"] = []
	s["scoperte"] = []
	s["eccezionali"] = []
	s["successi"] = 0
	s["ferite_mazzo"] = MAZZO_FERITE.duplicate()
	s["grado_superiore"] = str(mazzi.get("grado_superiore", ""))
	s["finita"] = ""
	s["provviste_illimitate"] = bool(mazzi.get("provviste_illimitate", false))
	# Tutorial (Regolamento pagg. 20-22): solo Ferite "Solo un graffio!" (una per Membro)
	# e niente Eventi a fine turno finché non si rivela la Missione M02
	s["tutorial"] = bool(mazzi.get("tutorial", false))
	s["eventi_sospesi"] = s["tutorial"]
	s["morale"] = 0
	s["diario"] = []
	diario("Inizio dell'esplorazione: %s" % str(pianeta.get("pianeta", pagina)))

func _nuovo_dado(tipo: String) -> Dictionary:
	_id_dado += 1
	s["n_dadi"] = _id_dado
	return {"id": "d%d" % _id_dado, "tipo": tipo, "faccia": 0, "stato": "disponibile"}

func _mescola(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

# ------------------------------------------------------------------ informazioni

func membro(i: int) -> Dictionary:
	return s["equipaggio"][i]

func vivi() -> Array:
	var out := []
	for i in s["equipaggio"].size():
		if not s["equipaggio"][i]["morto"]:
			out.append(i)
	return out

func nel_settore(n: int) -> Array:
	return vivi().filter(func(i): return int(s["equipaggio"][i]["settore"]) == n)

func dadi_disponibili(i: int) -> Array:
	return membro(i)["dadi"].filter(func(d): return d["stato"] == "disponibile")

func dadi_spesi(i: int) -> Array:
	return membro(i)["dadi"].filter(func(d): return d["stato"] == "speso")

func limite_mano(i: int) -> int:
	return LIMITE_MANO.get(int(membro(i)["grado"]), 2)

## Sentieri che partono dal settore n: [{"a": settore, "icone": [...]}] (rispetta i sensi unici).
func sentieri(pianeta: Dictionary, n: int) -> Array:
	var out := []
	for p in pianeta.get("sentieri", []):
		var da := int(p.get("da", 0))
		var a := int(p.get("a", 0))
		var senso := str(p.get("senso", "doppio"))
		if da == n:
			out.append({"a": a, "icone": p.get("icone", [])})
		elif a == n and senso == "doppio":
			out.append({"a": da, "icone": p.get("icone", [])})
	return out

## Icone visibili nel settore (della plancia e del PDI in cima).
func icone_settore(pianeta: Dictionary, n: int, carte_pdi: Dictionary) -> Array:
	var out := []
	var pila: Array = s["settori"].get(str(n), {}).get("pdi", [])
	for st in pianeta.get("settori", []):
		if int(st.get("n", 0)) == n:
			# un PDI piazzato copre il PDI stampato sulla plancia (e le sue icone)
			if pila.is_empty() or not st.get("stampato") is Dictionary:
				out.append_array(st.get("icone", []))
	if not pila.is_empty():
		out.append_array(carte_pdi.get(pila[-1], {}).get("icone", []))
	return out

# ------------------------------------------------------------------ turni

func inizio_round() -> void:
	for i in vivi():
		s["equipaggio"][i]["turno_fatto"] = false
	s["attivo"] = int(s.get("primo", 0))
	if s["equipaggio"][s["attivo"]]["morto"]:
		s["attivo"] = vivi()[0]
	s["azioni"] = 2
	s["speciale_usata"] = false

func scegli_attivo(i: int) -> void:
	if membro(i)["turno_fatto"] or membro(i)["morto"]:
		return
	s["attivo"] = i
	s["azioni"] = 2
	s["speciale_usata"] = false

func usa_azione(speciale := false) -> bool:
	if int(s["azioni"]) <= 0:
		return false
	if speciale and s["speciale_usata"]:
		return false
	s["azioni"] = int(s["azioni"]) - 1
	if speciale:
		s["speciale_usata"] = true
	return true

## Fine del turno: gira il segnalino e pesca un Evento (restituisce l'id dell'evento pescato).
func fine_turno() -> String:
	var i := int(s["attivo"])
	membro(i)["turno_fatto"] = true
	var ev := "" if s.get("eventi_sospesi", false) else pesca_evento()
	diario("%s termina il turno" % membro(i)["carta"])
	return ev

func pesca_evento() -> String:
	if s["eventi"].is_empty():
		s["eventi"] = s["scarti_eventi"].duplicate()
		s["scarti_eventi"] = []
		_mescola(s["eventi"])
	if s["eventi"].is_empty():
		return ""
	var e: String = s["eventi"].pop_back()
	s["scarti_eventi"].append(e)
	return e

## L'Evento colpisce con l'effetto principale se un suo bioma è nel settore del Membro, altrimenti il secondario.
func evento_principale(biomi_evento: Array, icone_sett: Array) -> bool:
	for b in biomi_evento:
		if b in icone_sett:
			return true
	return false

func round_finito() -> bool:
	for i in vivi():
		if not membro(i)["turno_fatto"]:
			return false
	return true

func prossimo_round(primo: int) -> void:
	s["round"] = int(s["round"]) + 1
	s["primo"] = primo
	inizio_round()
	diario("— Round %d —" % int(s["round"]))

# ------------------------------------------------------------------ azioni

func viaggia(i: int, a: int) -> void:
	membro(i)["settore"] = a
	diario("%s viaggia nel Settore %d" % [membro(i)["carta"], a])

## Riposo: -1 Provviste, ricarica metà dei dadi (per eccesso), pesca 1 carta. false se senza Provviste.
func riposa(i: int) -> bool:
	if not s.get("provviste_illimitate", false):
		if int(s["lander"]["provviste"]) <= 0:
			return false
		s["lander"]["provviste"] = int(s["lander"]["provviste"]) - 1
	# metà del totale dei dadi (disponibili e spesi), per eccesso
	var tot: int = membro(i)["dadi"].filter(func(d): return d["stato"] != "sacrificato").size()
	ricarica(i, int(ceil(tot / 2.0)), "")
	pesca_carta(i)
	diario("%s riposa (Provviste %d)" % [membro(i)["carta"], int(s["lander"]["provviste"])])
	return true

## Sforzo: sacrifica 1 dado e ricarica 5 dadi; con 3 dadi o meno in gioco si subisce Allo Stremo.
func sforzo(i: int, id_dado := "") -> void:
	var in_gioco: Array = membro(i)["dadi"].filter(func(d): return d["stato"] != "sacrificato")
	if in_gioco.size() <= 3:
		ferita(i, "exhausted")
	else:
		sacrifica_dado(i, id_dado)
	ricarica(i, 5, "")
	diario("%s fa uno Sforzo" % membro(i)["carta"])

func pesca_carta(i: int) -> String:
	var m := membro(i)
	if m["mazzo"].is_empty():
		m["mazzo"] = m["scarti"].duplicate()
		m["scarti"] = []
		_mescola(m["mazzo"])
	if m["mazzo"].is_empty():
		return ""
	var c: String = m["mazzo"].pop_back()
	m["mano"].append(c)
	return c

## Carte in eccesso rispetto al limite (l'interfaccia chiede quali scartare).
func eccesso_mano(i: int) -> int:
	return max(0, membro(i)["mano"].size() - limite_mano(i))

func scarta_carta(i: int, c: String) -> void:
	var m := membro(i)
	var k: int = m["mano"].find(c)
	if k >= 0:
		m["mano"].remove_at(k)
		m["scarti"].append(c)

# ------------------------------------------------------------------ dadi

func ricarica(i: int, n: int, colore: String) -> int:
	var fatti := 0
	for d in membro(i)["dadi"]:
		if fatti >= n:
			break
		if d["stato"] == "speso" and (colore == "" or Prova.colore(d) == colore):
			d["stato"] = "disponibile"
			fatti += 1
	return fatti

## Spendi: un dado disponibile va nei Dadi Spesi; se non ce ne sono, si sacrifica.
func spendi_dado(i: int, colore := "", id_dado := "") -> void:
	var cand := dadi_disponibili(i).filter(func(d): return colore == "" or Prova.colore(d) == colore)
	if id_dado != "":
		cand = cand.filter(func(d): return d["id"] == id_dado)
	if cand.is_empty():
		sacrifica_dado(i, "", colore)
		return
	cand[0]["stato"] = "speso"

func sacrifica_dado(i: int, id_dado := "", colore := "") -> void:
	var lista: Array = membro(i)["dadi"].filter(func(d): return d["stato"] != "sacrificato" and (colore == "" or Prova.colore(d) == colore))
	if id_dado != "":
		lista = lista.filter(func(d): return d["id"] == id_dado)
	if lista.is_empty():
		return
	# di preferenza un dado già speso, poi il più "povero" (base)
	lista.sort_custom(func(a, b): return _valore_dado(a) < _valore_dado(b))
	lista[0]["stato"] = "sacrificato"
	diario("%s sacrifica un dado" % membro(i)["carta"])

func _valore_dado(d: Dictionary) -> int:
	var v := 0 if d["stato"] == "speso" else 10
	var t: String = Prova.defs()["reparto"].get(d["tipo"], {}).get("tipo", "basic")
	v += {"basic": 0, "specialized": 2, "universal": 4, "expert": 6, "wild": 3}.get(t, 0)
	return v

# ------------------------------------------------------------------ ferite

## Subisce una Ferita: carta nello spazio libero più a sinistra e un dado Ferita sulla plancia.
## Alla quarta ferita: evacuazione d'emergenza (restituisce "evac").
func ferita(i: int, tipo: String) -> String:
	var m := membro(i)
	if s.get("tutorial", false):
		if "just_a_scratch" in m["ferite"]:
			diario("%s ha già una Ferita: si ignora" % m["carta"])
			return ""
		tipo = "just_a_scratch"
	if m["ferite"].size() >= MAX_FERITE:
		s["finita"] = "evac"
		diario("%s subirebbe la quarta Ferita: evacuazione d'emergenza!" % m["carta"])
		return "evac"
	if int(s["ferite_mazzo"].get(tipo, 0)) <= 0:
		tipo = "wounded"
	s["ferite_mazzo"][tipo] = int(s["ferite_mazzo"].get(tipo, 0)) - 1
	m["ferite"].append(tipo)
	m["dadi_ferita"] = int(m["dadi_ferita"]) + 1
	diario("%s subisce una Ferita (%s)" % [m["carta"], tipo])
	return tipo

func cura(i: int, tipo := "") -> void:
	var m := membro(i)
	if m["ferite"].is_empty():
		return
	var k: int = m["ferite"].find(tipo) if tipo != "" else m["ferite"].size() - 1
	if k < 0:
		k = m["ferite"].size() - 1
	var t: String = m["ferite"][k]
	m["ferite"].remove_at(k)
	s["ferite_mazzo"][t] = int(s["ferite_mazzo"].get(t, 0)) + 1

# ------------------------------------------------------------------ indizi e scoperte

## Pesca n segnalini Indizio dal sacchetto e li mette sul mazzo Scoperte del tipo dato.
## Quando sul mazzo il valore arriva a 3 si ottiene la Scoperta in cima. Restituisce le scoperte ottenute.
func indizi(tipo: String, n: int) -> Array:
	var ottenute := []
	for k in n:
		if s["sacchetto"].is_empty():
			diario("Il sacchetto degli Indizi è vuoto")
			break
		var j := rng.randi_range(0, s["sacchetto"].size() - 1)
		var tok: Dictionary = s["sacchetto"][j]
		s["sacchetto"].remove_at(j)
		s["indizi"][tipo].append(tok)
		var tot := 0
		for t in s["indizi"][tipo]:
			tot += int(t.get("v", 1))
		if tot >= 3:
			for t in s["indizi"][tipo]:
				if t.get("riciclo", false):
					s["sacchetto"].append(t)
				else:
					s["fuori_sacchetto"].append(t)
			s["indizi"][tipo] = []
			var sc := scoperta(tipo)
			if sc != "":
				ottenute.append(sc)
	diario("Indizi %s: %d" % [tipo, n])
	return ottenute

func scoperta(tipo: String) -> String:
	# i segnalini sul mazzo tornano accanto al sacchetto prima di pescare
	for t in s["indizi"].get(tipo, []):
		(s["sacchetto"] if t.get("riciclo", false) else s["fuori_sacchetto"]).append(t)
	s["indizi"][tipo] = []
	var m: Array = s["mazzi_scoperte"].get(tipo, [])
	if m.is_empty():
		return ""
	var c: String = m.pop_back()
	s["scoperte"].append({"tipo": tipo, "carta": c})
	diario("Scoperta ottenuta: %s" % tipo)
	return c

# ------------------------------------------------------------------ settori, tempo, minacce

func pdi_in_cima(n: int) -> String:
	var p: Array = s["settori"].get(str(n), {}).get("pdi", [])
	return "" if p.is_empty() else str(p[-1])

## Un nuovo PDI in un settore: si tolgono segnalini Tempo e marker del PDI precedente.
func piazza_pdi(n: int, carta: String) -> void:
	var st: Dictionary = s["settori"].get_or_add(str(n), {"pdi": [], "tempo": 0, "segnalini": 0, "tracce": {}, "finito": false})
	st["pdi"] = [carta]
	st["tempo"] = 0
	st["tracce"] = {}
	diario("Settore %d: %s" % [n, carta if carta != "P000" else "nessun PDI"])

func traccia(chiave: String, n: int) -> int:
	return int(_tracce_di(n).get(chiave, 0))

func _tracce_di(n: int) -> Dictionary:
	return s["settori"].get(str(n), {}).get("tracce", {})

## Avanza (o arretra) una traccia di un'azione; restituisce il nuovo valore.
func avanza_traccia(n: int, chiave: String, delta: int, caselle: int) -> int:
	var t := _tracce_di(n)
	var v := clampi(int(t.get(chiave, 0)) + delta, 0, caselle)
	if v == 0:
		t.erase(chiave)
	else:
		t[chiave] = v
	return v

## Fa avanzare tutte le tracce del Tempo (Condizione Generale, Minacce, settori).
func tempo_tutte(delta: int) -> void:
	avanza_tempo_condizione(delta)
	avanza_tempo_minacce(delta)
	for k in s["settori"]:
		if not s["settori"][k]["pdi"].is_empty():
			s["settori"][k]["tempo"] = max(0, int(s["settori"][k]["tempo"]) + delta)

func azzera_tempo() -> void:
	s["condizione"]["tempo"] = 0
	for m in s["minacce"]:
		m["tempo"] = 0
	for k in s["settori"]:
		s["settori"][k]["tempo"] = 0

func avanza_tempo_condizione(delta: int) -> int:
	s["condizione"]["tempo"] = max(0, int(s["condizione"]["tempo"]) + delta)
	return int(s["condizione"]["tempo"])

func avanza_tempo_minacce(delta: int) -> void:
	for m in s["minacce"]:
		m["tempo"] = max(0, int(m["tempo"]) + delta)

# ------------------------------------------------------------------ fine

func decollo() -> void:
	s["finita"] = "decollo"
	for i in vivi():
		if int(membro(i)["settore"]) != int(s["lander"]["settore"]):
			membro(i)["morto"] = true
			diario("%s resta sul pianeta…" % membro(i)["carta"])
	diario("Decollo")

func fine(motivo: String) -> void:
	s["finita"] = motivo
	diario("Fine dell'esplorazione (%s)" % motivo)
