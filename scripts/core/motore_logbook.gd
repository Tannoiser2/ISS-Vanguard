## Motore del Logbook: segue la stessa logica dell'app ufficiale.
##
## Struttura dei dati (vedi tools/esporta_logbook.py):
##   annotazione (log) -> versi (sotto-paragrafi) -> elementi (testo o scelta) -> scelte condizionali
## Ogni elemento "scelta" (pulsante) contiene una o più alternative, provate in ordine:
##   - "req": condizione sui flag (es. flag 455 non ancora segnato)
##   - "q":   domanda Sì/No al giocatore (es. "il tuo Lander ha almeno 4 Sensori?")
##   - "r":   istruzioni da eseguire sul tavolo prima di proseguire
##   - "set": flag da segnare
##   - "l"/"v": annotazione e verso di destinazione (assenti = fine dell'annotazione)
## I versi di tipo 2 (rinvio automatico) scelgono da soli la prima alternativa valida non ancora usata.
## I versi di tipo 14 mostrano le scelte come immagini (es. il risultato del dado Pericolo).
class_name MotoreLogbook
extends RefCounted

const TIPO_SEMPLICE := 1
const TIPO_AUTO := 2
const TIPO_SCELTA := 3
const TIPO_GRAFO := 4
const TIPO_MULTIPLA := 5
const TIPO_VIDEO := 12
const TIPO_IMMAGINI := 14

const EL_TESTO := 0
const EL_SCELTA := 6
const EL_GRAFO := 7
const EL_VIDEO := 13
const EL_TITOLO_IMMAGINI := 15

var camp := 8
## Stato salvato nella campagna: {"flag": {id: 0/1}, "usate": {id_scelta: n}, "pos": {"l": id, "v": id},
##  "storia": [[id_log, id_verso], ...], "tutorial": bool, "visitate": {numero: true}}
var stato: Dictionary

func _init(camp_: int, stato_: Dictionary) -> void:
	camp = camp_
	stato = stato_
	for k in ["flag", "usate", "visitate"]:
		if not stato.has(k) or not (stato[k] is Dictionary):
			stato[k] = {}
	if not stato.has("storia"):
		stato["storia"] = []
	if not stato.has("pos"):
		stato["pos"] = {}

# ------------------------------------------------------------------ flag

func flag(id: int) -> int:
	return int(stato["flag"].get(str(id), 0))

func imposta_flag(id: int, v: int) -> void:
	stato["flag"][str(id)] = v

## Valuta una condizione {"op": "and"/"or", "f": [[id, valore], ...]} oppure {"op":"mix","expr":...}.
func condizione(req) -> bool:
	if req == null or not (req is Dictionary):
		return true
	var op: String = req.get("op", "and")
	if op == "mix":
		return _valuta_espressione(str(req.get("expr", "")))
	var lista: Array = req.get("f", [])
	if lista.is_empty():
		return true
	if op == "or":
		for c in lista:
			if flag(int(c[0])) == int(c[1]):
				return true
		return false
	for c in lista:
		if flag(int(c[0])) != int(c[1]):
			return false
	return true

## "0.712#AND#1.713#OR#1.714": da sinistra a destra, come nell'app.
func _valuta_espressione(e: String) -> bool:
	var parti := e.replace("#AND#", "#&#").replace("#OR#", "#|#").split("#", false)
	var ris := true
	var op := "&"
	for p in parti:
		if p == "&" or p == "|":
			op = p
			continue
		var v := p.split(".")
		var ok := flag(int(v[1])) == int(v[0])
		ris = (ris and ok) if op == "&" else (ris or ok)
	return ris

## Applica i flag di una scelta: [[id, valore], ...].
func applica_flag(set_) -> void:
	if set_ is Array:
		for c in set_:
			imposta_flag(int(c[0]), int(c[1]))
	elif set_ is Dictionary and set_.has("f"):
		applica_flag(set_["f"])

# ------------------------------------------------------------------ navigazione

func annotazione(id_log: int) -> Dictionary:
	return Dati.annotazione(camp, id_log)

func verso(id_log: int, id_verso: int) -> Dictionary:
	return annotazione(id_log).get("verses", {}).get(str(id_verso), {})

## Cerca un'annotazione per numero. Restituisce l'id interno o -1.
## blocco: true se l'annotazione non è raggiungibile digitando il numero (solo da un'altra annotazione).
func trova_numero(numero: int, anche_bloccate := false) -> int:
	var ids: Array = Dati.cerca_numero(camp, numero)
	for id in ids:
		var a := annotazione(int(id))
		if a.is_empty():
			continue
		if a.get("block", 0) and not anche_bloccate:
			continue
		# le annotazioni delle Operazioni hanno numeri propri (1000+): nella campagna si entra da quelle normali
		return int(id)
	return -1

## Entra in un'annotazione: restituisce [id_log, id_verso] di partenza (rispettando la versione tutorial).
func entra(id_log: int, id_verso := -1) -> Array:
	var a := annotazione(id_log)
	if a.is_empty():
		return []
	if stato.get("tutorial", false) and a.has("tut") and id_verso < 0:
		var t := annotazione(int(a["tut"]))
		if not t.is_empty():
			id_log = int(a["tut"])
			a = t
	if id_verso < 0 or not a.get("verses", {}).has(str(id_verso)):
		var st0 = a.get("start")
		id_verso = int(st0) if st0 != null else -1  # annotazioni fatte solo di caselle
	stato["pos"] = {"l": id_log, "v": id_verso}
	stato["visitate"][str(int(a.get("n", 0)))] = true
	var st: Array = stato["storia"]
	if st.is_empty() or st[-1] != [id_log, id_verso]:
		st.append([id_log, id_verso])
		if st.size() > 400:
			st.pop_front()
	return [id_log, id_verso]

func posizione() -> Array:
	var p: Dictionary = stato.get("pos", {})
	if p.has("l"):
		return [int(p["l"]), int(p["v"])]
	return []

## Torna al verso precedente nella cronologia (non annulla i flag: come "Passo indietro" nell'app).
func indietro() -> Array:
	var st: Array = stato["storia"]
	if st.size() < 2:
		return posizione()
	st.pop_back()
	var p: Array = st[-1]
	stato["pos"] = {"l": int(p[0]), "v": int(p[1])}
	return [int(p[0]), int(p[1])]

func esci() -> void:
	stato["pos"] = {}

# ------------------------------------------------------------------ scelte

## Alternative valide di un elemento-scelta (solo i flag; le domande Sì/No le pone l'interfaccia).
## Restituisce la lista nell'ordine originale; l'ultima senza domanda è quella "altrimenti".
func alternative(el: Dictionary, tipo_verso: int) -> Array:
	var out := []
	var lista: Array = el.get("c", [])
	for i in lista.size():
		var c: Dictionary = lista[i]
		if not condizione(c.get("req")):
			continue
		out.append(c)
	if tipo_verso == TIPO_AUTO and out.size() > 1:
		# rinvio automatico: la prima non ancora usata (se tutte usate, l'ultima)
		var nuove := out.filter(func(c): return not stato["usate"].has(str(int(c["id"]))) or c.has("q"))
		if not nuove.is_empty():
			out = nuove
	return out

## Un pulsante è disponibile se almeno un'alternativa supera i flag.
func elemento_disponibile(el: Dictionary) -> bool:
	for c in el.get("c", []):
		if condizione(c.get("req")):
			return true
	return el.get("c", []).is_empty()

## Registra la scelta fatta e applica i flag. Restituisce la destinazione [id_log, id_verso] o [] (fine).
func scegli(c: Dictionary) -> Array:
	var k := str(int(c.get("id", 0)))
	stato["usate"][k] = int(stato["usate"].get(k, 0)) + 1
	applica_flag(c.get("set"))
	if c.has("l"):
		return entra(int(c["l"]), int(c.get("v", -1)))
	esci()
	return []

## Elenco dei flag "di annotazione" (le caselle A, B, C… del Logbook) segnati, per il registro.
func flag_segnati() -> Array:
	var out := []
	for k in stato["flag"]:
		if int(stato["flag"][k]) == 1:
			out.append(int(k))
	out.sort()
	return out

# ------------------------------------------------------------------ schema ad albero (annotazione 55)

## Lo schema del progetto "Diritto di Nascita": righe "#livello#Nome#posizione#collegamenti…#FN.flag#F1.flag#destinazione#".
## I collegamenti "L|k" indicano il k-esimo nodo del livello L. Destinazione: numero di annotazione, oppure "55.2" (annotazione.verso).
func grafo(testo: String) -> Array:
	var nodi := []
	var per_livello := {}
	for riga in testo.split("\n", false):
		var c := riga.strip_edges().split("#", false)
		if c.size() < 4:
			continue
		var n := {"liv": int(c[0]), "nome": c[1], "pos": int(c[2]), "link": [], "req": -1, "set": -1, "dest": ""}
		for k in range(3, c.size()):
			var x: String = c[k]
			if x.contains("|"):
				n["link"].append([int(x.get_slice("|", 0)), int(x.get_slice("|", 1))])
			elif x.begins_with("FN."):
				n["req"] = int(x.substr(3))
			elif x.begins_with("F1."):
				n["set"] = int(x.substr(3))
			else:
				n["dest"] = x
		per_livello.get_or_add(n["liv"], []).append(n)
		n["k"] = per_livello[n["liv"]].size()
		nodi.append(n)
	# collegamenti come indici
	for n in nodi:
		var vicini := []
		for l in n["link"]:
			var lista: Array = per_livello.get(l[0], [])
			if l[1] - 1 < lista.size():
				vicini.append(nodi.find(lista[l[1] - 1]))
		n["vicini"] = vicini
	return nodi

func nodo_segnato(n: Dictionary) -> bool:
	if n["liv"] == 1:
		return true
	var f: int = n["set"] if n["set"] >= 0 else n["req"]
	return f >= 0 and flag(f) == 1

## Nodi che si possono segnare adesso: non segnati e collegati a un nodo già segnato.
func nodi_disponibili(nodi: Array) -> Array:
	var out := []
	for i in nodi.size():
		var n: Dictionary = nodi[i]
		if nodo_segnato(n):
			continue
		var ok := false
		for j in nodi.size():
			if nodo_segnato(nodi[j]) and (i in nodi[j]["vicini"] or j in n["vicini"]):
				ok = true
				break
		if ok:
			out.append(n)
	return out

## Segna il nodo e restituisce la destinazione [id_log, id_verso] (o [] se non trovata).
func scegli_nodo(n: Dictionary, id_log_corrente: int) -> Array:
	if n["set"] >= 0:
		imposta_flag(n["set"], 1)
	var d: String = n["dest"]
	if d.contains("."):
		var num := int(d.get_slice(".", 0))
		var dv := int(d.get_slice(".", 1))
		var id := trova_numero(num, true)
		if id < 0:
			id = id_log_corrente
		for vid in annotazione(id).get("verses", {}):
			if int(annotazione(id)["verses"][vid].get("d", -1)) == dv:
				return entra(id, int(vid))
		return entra(id)
	var id2 := trova_numero(int(d), true)
	return entra(id2) if id2 >= 0 else []
