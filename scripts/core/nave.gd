## Motore della Gestione della Nave (Ship Book). Logica pura: lo stato è un dizionario salvato
## nella campagna (Campagna.dati["nave"]); l'interfaccia (GestioneNave) mostra un passo alla volta.
##
## Ordine delle pagine del Ship Book:
##   ponte (2) → mappa stellare (5) → strutture (6: laboratorio 8, produzione 12, caserma 16,
##   sala situazioni 17) → hangar (18) → lancio (23) → [esplorazione planetaria] → partenza (25)
##   → attracco (26) → scarico (28) → infermeria (32) → memoriale (36) → debriefing (27) → salvataggio (39)
class_name Nave
extends RefCounted

const PASSI := ["ponte", "mappa", "strutture", "hangar", "lancio", "esplorazione",
	"partenza", "attracco", "scarico", "infermeria", "memoriale", "debriefing", "salvataggio"]
const NOMI_PASSI := {"avvio": "Inizio della campagna", "ponte": "Ponte di comando", "mappa": "Mappa stellare",
	"strutture": "Strutture della nave", "hangar": "Hangar", "lancio": "Procedura di lancio",
	"esplorazione": "Esplorazione planetaria", "partenza": "Lasciare il pianeta", "attracco": "Attracco",
	"scarico": "Scarico", "infermeria": "Infermeria", "memoriale": "Muro della memoria",
	"debriefing": "Debriefing", "salvataggio": "Punto di salvataggio"}
const PAGINE := {"ponte": 2, "mappa": 5, "strutture": 6, "hangar": 18, "lancio": 23, "esplorazione": 24,
	"partenza": 25, "attracco": 26, "scarico": 28, "infermeria": 32, "memoriale": 36, "debriefing": 27, "salvataggio": 39}
const MORALE := ["very_low", "low", "medium", "high"]
const NOMI_MORALE := {"very_low": "Molto basso", "low": "Basso", "medium": "Medio", "high": "Alto"}
const REPARTI := ["ingegneria", "ricognizione", "scienza", "sicurezza"]
const REP_EN := {"ingegneria": "engineering", "ricognizione": "recon", "scienza": "science", "sicurezza": "security"}
## Dadi Wild comprati dopo il tutorial (Regolamento pag. 25), poi i successivi a scelta.
const DADO_JOLLY := {"ingegneria": "jolly_rosso", "ricognizione": "jolly_verde", "scienza": "jolly_blu", "sicurezza": "jolly_rosso"}

var s: Dictionary
var rng := RandomNumberGenerator.new()

func _init(stato: Dictionary = {}) -> void:
	s = stato
	rng.randomize()

func diario(t: String) -> void:
	s.get_or_add("diario", []).append(t)
	if s["diario"].size() > 400:
		s["diario"].pop_front()

# ------------------------------------------------------------------ inizio della campagna

## Stato iniziale (Regolamento pag. 7, "Before your first game"): carte di partenza del Ship Book.
## equipaggio: [{"carta", "file", "reparto", "grado", "stato"}]
func inizializza(equipaggio: Array) -> void:
	s.clear()
	s["passo"] = "ponte"
	s["morale"] = "medium"
	s["obiettivo"] = "O01"
	s["obiettivo_secondario"] = ""
	s["tech"] = 1
	s["ponte"] = []                  # potenziamenti del Ponte (pag. 3)
	s["ponte_viaggio"] = []          # potenziamenti di viaggio (pag. 4)
	s["sistema"] = "Eye of the Void"
	s["sistemi_visitati"] = ["Eye of the Void"]
	s["pool"] = {"comando": 0, "energia": 0, "successi": 0}
	s["penalita"] = false
	s["busta"] = []                  # busta "In attesa…"
	s["ricerca"] = ["R04"]           # pag. 9
	s["produzione_pronti"] = ["C01", "C02", "C03", "C06"]   # pag. 13
	s["code"] = [[null, null, null], [null, null, null]]     # pag. 14: stadi 1-3 di due code
	s["code_attive"] = 1
	s["lander"] = [{"nome": "SPACE RANGER", "danneggiato": false}]
	s["mod_lander"] = []
	s["lander_scelto"] = "SPACE RANGER"
	s["mod_montate"] = []
	s["situazioni"] = []             # sopra il Ship Book
	s["situazioni_possibili"] = _codici("S", 1, 10)
	s["situazioni_future"] = _codici("S", 11, 26)
	s["armeria"] = []
	s["scoperte"] = []               # Scoperte raccolte: [{"tipo", "file"}]
	s["eccezionali"] = {}            # numero -> slot delle pagine 29-30
	s["infermeria"] = []
	_fila()
	s["memoriale"] = []
	s["potenziamenti"] = []          # strutture, infermeria, produzione
	s["scanner"] = {"carta": "", "rivelate": 0}
	s["pianeti_registrati"] = {}
	s["equipaggio"] = equipaggio.duplicate(true)
	s["reclute"] = []
	var usati := {}
	for m in equipaggio:
		usati[str(m.get("file", ""))] = true
	for c in Carte.categoria("equipaggio"):
		if not usati.has(str(c.get("file", ""))) and str(c.get("lato", "fronte")) != "retro":
			s["reclute"].append(str(c["file"]))
	s["dadi"] = {}
	for r in REPARTI:
		s["dadi"][r] = (Prova.defs()["iniziali"][r] as Array).duplicate()
	s["comprati"] = 0
	s["venduti_qui"] = false
	s["usate_strutture"] = []
	s["diario"] = []
	diario("Inizio della Gestione della Nave")

static func _codici(p: String, a: int, b: int) -> Array:
	var out := []
	for i in range(a, b + 1):
		out.append("%s%02d" % [p, i])
	return out

# ------------------------------------------------------------------ informazioni

func carta_obiettivo() -> Dictionary:
	return Carte.per_id(str(s["obiettivo"]))

func carta_tech() -> Dictionary:
	for c in Carte.categoria("ponte"):
		if str(c.get("tipo", "")) == "tech_level" and int(c.get("campi", {}).get("livello", -1)) == int(s["tech"]):
			return c
	return {}

func membri(reparto := "", stato := "") -> Array:
	var out := []
	for i in s["equipaggio"].size():
		var m: Dictionary = s["equipaggio"][i]
		if (reparto == "" or m["reparto"] == reparto) and (stato == "" or m["stato"] == stato):
			out.append(i)
	return out

## Un Membro disponibile si può assegnare (va a riposo) solo se non è l'ultimo disponibile del Reparto.
func assegnabile(i: int) -> bool:
	var m: Dictionary = s["equipaggio"][i]
	return m["stato"] == "disponibile" and membri(m["reparto"], "disponibile").size() > 1

func assegna(i: int, compito: String) -> bool:
	if not assegnabile(i):
		return false
	s["equipaggio"][i]["stato"] = "riposo"
	diario("%s assegnato: %s" % [s["equipaggio"][i]["carta"], compito])
	return true

## Icona di conversione di un Membro (dalla carta Equipaggio).
func conversione(i: int) -> String:
	var l := conversioni(i)
	return str(l[0]) if not l.is_empty() else ""

## Icone di conversione del Membro (due per i Veterani dei Fascicoli del personale).
func conversioni(i: int) -> Array:
	return Fascicoli.conversioni(Carte.per_file(str(s["equipaggio"][i].get("file", "")))).map(func(x): return str(x["a"]))

func n_dadi() -> int:
	return (s["dadi"]["ingegneria"] as Array).size()

# ------------------------------------------------------------------ morale e pool

func morale_su() -> void:
	var k := MORALE.find(str(s["morale"]))
	if k < MORALE.size() - 1:
		s["morale"] = MORALE[k + 1]
	diario("Morale: %s" % NOMI_MORALE[s["morale"]])

## Abbassa il Morale; se è già Molto basso, ogni Reparto perde un dado (mai sotto 4; altrimenti -2 Successi).
func morale_giu() -> String:
	var k := MORALE.find(str(s["morale"]))
	if k > 0:
		s["morale"] = MORALE[k - 1]
		diario("Morale: %s" % NOMI_MORALE[s["morale"]])
		return ""
	if n_dadi() > 4:
		for r in REPARTI:
			(s["dadi"][r] as Array).pop_back()
		diario("Morale già Molto basso: ogni Reparto perde un dado")
		return "dadi"
	s["pool"]["successi"] = max(0, int(s["pool"]["successi"]) - 2)
	diario("Morale già Molto basso: -2 Successi")
	return "successi"

## Ponte, passo 2: segnalini Comando (dall'Obiettivo) ed Energia (dal Livello tecnologico).
func genera_pool() -> Dictionary:
	var ob := carta_obiettivo()
	var com := int(ob.get("campi", {}).get("comando", 3))
	var en := int(carta_tech().get("campi", {}).get("energia", 3))
	for id in s["ponte"]:
		var c := Carte.per_id(str(id))
		com += int(c.get("campi", {}).get("modifica_comando", 0))
		en += int(c.get("campi", {}).get("modifica_energia", 0))
	if str(s.get("morale", "")) == "high":
		com += 1
	if s.get("penalita", false):
		com = 1
	s["pool"]["comando"] = com
	s["pool"]["energia"] = en
	diario("Segnalini: %d Comando, %d Energia" % [com, en])
	return {"comando": com, "energia": en}

func spendi(pool: String, n: int) -> bool:
	if int(s["pool"].get(pool, 0)) < n:
		return false
	s["pool"][pool] = int(s["pool"][pool]) - n
	return true

# ------------------------------------------------------------------ busta "In attesa…" e installazioni

## Carte nella busta di un certo prefisso (B, O, R, C, S, F, A, L, E…), rimosse dalla busta.
func dalla_busta(prefissi: Array) -> Array:
	var out := []
	for id in s["busta"].duplicate():
		for p in prefissi:
			if str(id).begins_with(p):
				out.append(id)
				s["busta"].erase(id)
				break
	return out

# ------------------------------------------------------------------ Fascicoli del personale

## Grado da cui si riceve l'Obiettivo individuale: 2 (versione standard), 3 (impegnativa), 0 = espansione spenta.
func grado_fascicoli() -> int:
	if not s.has("fascicoli"):
		# l'espansione si gioca con la campagna base e con Lost Fleet
		return 0 if Campagna.id_campagna() == 12 else 2
	return int(s["fascicoli"])

## Se il Membro ha raggiunto il Grado richiesto e non è già Veterano, riceve la sua carta Obiettivo individuale.
## Restituisce il file della carta assegnata ("" se niente).
func controlla_fascicolo(i: int) -> String:
	var m: Dictionary = s["equipaggio"][i]
	var g := grado_fascicoli()
	if g <= 0 or int(m["grado"]) < g or m.get("veterano", false) or m.get("obiettivo") is Dictionary or m["stato"] == "morto":
		return ""
	var v := Fascicoli.veterano_di(str(m.get("file", "")))
	if v.is_empty():
		return ""
	m["obiettivo"] = {"file": str(v["file"]), "traccia": 0}
	diario("Fascicoli del personale: %s riceve il suo Obiettivo individuale" % m["carta"])
	return str(v["file"])

func controlla_fascicoli() -> Array:
	var out := []
	for i in s["equipaggio"].size():
		if controlla_fascicolo(i) != "":
			out.append(i)
	return out

## Obiettivo completato (File 1): la carta Veterano sostituisce quella del Membro; Cariche e plancia restano.
func diventa_veterano(i: int) -> void:
	var m: Dictionary = s["equipaggio"][i]
	var ob = m.get("obiettivo")
	if not ob is Dictionary:
		return
	m["file"] = str(ob["file"])
	m["veterano"] = true
	m.erase("obiettivo")
	diario("%s è ora un Veterano" % m["carta"])

# ------------------------------------------------------------------ potenziamenti del Ponte

func ha_ponte(id: String) -> bool:
	return id in s.get("ponte", []) or id in s.get("ponte_viaggio", [])

## Inizio del passo del Ponte: B11 (+1 Successo con 3 o meno) e B12 (Morale Molto basso → sale).
func inizio_ponte() -> Array:
	var fatti := []
	if ha_ponte("B11") and int(s["pool"].get("successi", 0)) <= 3:
		s["pool"]["successi"] = int(s["pool"]["successi"]) + 1
		fatti.append("B11: +1 Successo (ne avevi 3 o meno)")
	if ha_ponte("B12") and str(s["morale"]) == "very_low":
		morale_su()
		fatti.append("B12: il Morale sale da Molto basso")
	for f in fatti:
		diario(f)
	return fatti

## Costo in Energia di un volo verso un altro sistema (B07: -1, minimo 1).
func costo_rotta(base: int) -> int:
	return max(min(base, 1), base - 1) if ha_ponte("B07") else base

## Costo in Energia di una destinazione del sistema (B15: -1, minimo 1).
func costo_destinazione(base: int) -> int:
	return max(min(base, 1), base - 1) if ha_ponte("B15") else base

## Costo di una parte della scansione (B13: la prima è gratis).
func costo_scansione(k: int, base: int) -> int:
	return 0 if k == 0 and ha_ponte("B13") else base

## Conversioni dei potenziamenti (B08, B14, B16): [id, da, quanti, a, quanti].
const CONVERSIONI := [["B08", "comando", 1, "energia", 2], ["B14", "energia", 4, "comando", 1], ["B16", "comando", 1, "successi", 3]]

func converti(id: String) -> bool:
	for c in CONVERSIONI:
		if c[0] == id and ha_ponte(id) and spendi(c[1], c[2]):
			s["pool"][c[3]] = int(s["pool"].get(c[3], 0)) + int(c[4])
			diario("%s: %d %s → %d %s" % [id, c[2], c[1], c[4], c[3]])
			return true
	return false

## Potenziamenti delle strutture (F…): alcuni hanno effetto subito.
func aggiungi_potenziamento(id: String) -> void:
	if not id in s["potenziamenti"]:
		s["potenziamenti"].append(id)
	if id == "F04":
		s["code_attive"] = 2
		diario("F04: si sblocca la coda di produzione 2")

func ha_potenziamento(id: String) -> bool:
	return id in s.get("potenziamenti", [])

## Una carta è in possesso della nave (Ponte, potenziamenti, Armeria, progetti, Situazioni)?
func ha_carta(id: String) -> bool:
	id = id.to_upper()
	for k in ["ponte", "ponte_viaggio", "potenziamenti", "armeria", "situazioni", "ricerca", "produzione_pronti", "mod_lander"]:
		if id in s.get(k, []):
			return true
	for q in s.get("code", []):
		if id in q:
			return true
	return id == str(s.get("obiettivo", "")) or id == str(s.get("obiettivo_secondario", ""))

## Domande del Logbook "Possiedi la carta X (oppure Y) nel raccoglitore…": 1 sì, 0 no, -1 non è una di queste.
static func domanda_carte(q: String, n: Nave) -> int:
	var t := RegEx.create_from_string("\\[/?[bi]\\]").sub(q, "", true)
	if not RegEx.create_from_string("(?i)possiedi (?:la|le) cart[ae]|possiedi il potenziamento|hai (?:la carta|il potenziamento)").search(t):
		return -1
	if t.to_lower().contains("scoperta"):
		return -1
	var cod := []
	for m in RegEx.create_from_string("\\b([BCEFLORS]\\d{2})\\b").search_all(t):
		cod.append(m.get_string(1))
	if cod.is_empty():
		return -1
	var tutte := t.to_lower().contains(" e ") and not t.to_lower().contains("oppure")
	var ok := cod.map(func(x): return n.ha_carta(x))
	if tutte:
		return 1 if not ok.has(false) else 0
	return 1 if ok.has(true) else 0

## Requisito di una destinazione della mappa ("requires Ship Upgrade B05", "requires Objectives O06 – O11"):
## "" se soddisfatto, altrimenti il testo del requisito mancante.
func requisito_destinazione(en: String) -> String:
	var m := RegEx.create_from_string("(?i)requires (?:ship|bridge) upgrade (B\\d{2})").search(en)
	if m and not ha_ponte(m.get_string(1)):
		return m.get_string(1)
	var m2 := RegEx.create_from_string("(?i)requires objectives? O(\\d{2})(?:\\s*[–-]\\s*O(\\d{2}))?").search(en)
	if m2:
		var da := int(m2.get_string(1))
		var a := int(m2.get_string(2)) if m2.get_string(2) != "" else da
		var ob := str(s.get("obiettivo", ""))
		var n := int(ob.substr(1)) if ob.begins_with("O") and ob.substr(1).is_valid_int() else -1
		if n < da or n > a:
			return "Obiettivo O%02d–O%02d" % [da, a]
	return ""

## Toglie una carta da ovunque si trovi sulla nave.
func togli_carta(id: String) -> void:
	for k in ["busta", "ponte", "ponte_viaggio", "potenziamenti", "armeria", "situazioni", "situazioni_possibili", "situazioni_future", "ricerca", "produzione_pronti", "mod_lander"]:
		if s.has(k):
			(s[k] as Array).erase(id)
	for q in s.get("code", []):
		for k in (q as Array).size():
			if q[k] == id:
				q[k] = null

## Istruzioni del Logbook che spostano le carte della nave: "Sposta la carta X da … all'interno della
## busta In attesa…", "… all'Inventario", "Rimuovi la carta X dal gioco". Restituisce le righe fatte.
func istruzione_carte(t: String) -> Array:
	var fatti := []
	var pulito := RegEx.create_from_string("\\[/?[bi]\\]").sub(t, "", true).replace("’", "'").replace("“", "\"").replace("”", "\"").replace("''", "\"")
	var rx_cod := RegEx.create_from_string("\\b([A-Z]\\d{1,3})\\b")
	for frase in RegEx.create_from_string("[.\\n●•]").sub(pulito, "§", true).split("§"):
		var f := str(frase).strip_edges()
		var fl := f.to_lower()
		if f == "" or fl.begins_with("se ") or fl.contains(" se ") or fl.contains(" o ") or fl.contains(" oppure "):
			continue
		if not RegEx.create_from_string("^(sposta|prendi|rimuovi) (la|le) cart").search(fl):
			continue
		var codici := []
		var testa := f.substr(0, f.find(" da ") if f.find(" da ") > 0 else f.length())
		if fl.begins_with("rimuovi"):
			testa = f.substr(0, f.find(" dal ") if f.find(" dal ") > 0 else f.length())
		for m in rx_cod.search_all(testa):
			codici.append(m.get_string(1))
		if codici.is_empty() or testa.contains("-"):
			continue
		for id in codici:
			if fl.contains("dalla busta") and fl.contains("rimuovila dal gioco"):
				(s["busta"] as Array).erase(id)
				fatti.append("%s tolta dalla busta e rimossa dal gioco" % id)
			elif fl.contains("busta") and fl.contains("in attesa"):
				if id in s["busta"]:
					continue
				togli_carta(id)
				s["busta"].append(id)
				fatti.append("%s nella busta \"In attesa…\"" % id)
			elif fl.contains("inventario"):
				togli_carta(id)
				s["armeria"].append(id)
				fatti.append("%s nell'Inventario (Armeria)" % id)
			elif fl.begins_with("rimuovi") and fl.contains("dal gioco"):
				togli_carta(id)
				fatti.append("%s rimossa dal gioco" % id)
	for x in fatti:
		diario("Logbook: " + x)
	return fatti

## Ponte, passo 1: installa le carte del Ponte (obiettivi, livello, potenziamenti).
func installa_ponte() -> Array:
	var fatti := []
	for id in dalla_busta(["B", "O", "T"]):
		var c := Carte.per_id(str(id))
		match str(c.get("tipo", "")):
			"objective":
				s["obiettivo"] = id
				fatti.append("Nuovo Obiettivo: %s" % Carte.titolo(c))
			"secondary_objective":
				s["obiettivo_secondario"] = id
				fatti.append("Obiettivo secondario: %s" % Carte.titolo(c))
			"tech_level":
				var lv := int(c.get("campi", {}).get("livello", 0))
				if lv > int(s["tech"]):
					s["tech"] = lv
					fatti.append("Livello tecnologico %d" % lv)
			"bridge_upgrade_travel":
				s["ponte_viaggio"].append(id)
				fatti.append("Potenziamento di viaggio: %s" % Carte.titolo(c))
			_:
				s["ponte"].append(id)
				fatti.append("Potenziamento del Ponte: %s" % Carte.titolo(c))
		var lg = c.get("campi", {}).get("log_installazione")
		if lg != null and (lg is float or lg is int or str(lg).is_valid_int()):
			s.get_or_add("log_da_leggere", []).append(int(lg) if not lg is String else int(lg))
			fatti.append("%s: leggi l'Annotazione %d" % [id, int(lg) if not lg is String else int(lg)])
	return fatti

# ------------------------------------------------------------------ situazioni

func pesca_situazioni(n: int) -> Array:
	var out := []
	for k in n:
		if s["situazioni_possibili"].is_empty():
			break
		var j := rng.randi_range(0, s["situazioni_possibili"].size() - 1)
		var id: String = s["situazioni_possibili"][j]
		s["situazioni_possibili"].remove_at(j)
		s["situazioni"].append(id)
		out.append(id)
	diario("Nuove Situazioni: %s" % ", ".join(out))
	return out

func n_situazioni() -> int:
	var n := int(carta_obiettivo().get("campi", {}).get("situazioni", 1))
	if s["morale"] == "very_low":
		n += 1
	return n

# ------------------------------------------------------------------ laboratorio di ricerca

## Scoperte raccolte che pagano un costo: [{"tipo","n","rarita"}] -> indici in s["scoperte"] o [] se non basta.
func paga_scoperte(costo: Array) -> Array:
	var usati := []
	for req in costo:
		var tipo := str(req.get("tipo", "any"))
		var rar := str(req.get("rarita", ""))
		for k in int(req.get("n", 1)):
			var trovato := -1
			for i in s["scoperte"].size():
				if i in usati:
					continue
				var sc: Dictionary = s["scoperte"][i]
				if tipo != "any" and str(sc.get("tipo", "")) != tipo:
					continue
				if rar != "" and not _rarita_ok(str(sc.get("rarita", "")), rar):
					continue
				trovato = i
				break
			if trovato < 0:
				return []
			usati.append(trovato)
	return usati

static func _rarita_ok(ha: String, serve: String) -> bool:
	if serve == "rare":
		return ha in ["rare", "ultra-rare"]
	if serve == "ultra-rare":
		return ha == "ultra-rare"
	return true

func togli_scoperte(indici: Array) -> void:
	indici.sort()
	indici.reverse()
	for i in indici:
		s["scoperte"].remove_at(int(i))

func completa_ricerca(id: String) -> bool:
	var c := Carte.per_id(id)
	var costo: Array = c.get("costo_scoperte", []) if c.get("costo_scoperte") is Array else []
	var idx := paga_scoperte(costo)
	if idx.is_empty() and not costo.is_empty():
		return false
	togli_scoperte(idx)
	s["ricerca"].erase(id)
	diario("Ricerca completata: %s" % Carte.titolo(c))
	return true

# ------------------------------------------------------------------ complesso produttivo

## Avanza i progetti nelle code (passo 3); restituisce i progetti completati.
func avanza_produzione() -> Array:
	var finiti := []
	for q in int(s["code_attive"]):
		var coda: Array = s["code"][q]
		for k in range(coda.size() - 1, -1, -1):
			if coda[k] == null:
				continue
			if k == coda.size() - 1:
				finiti.append(coda[k])
				coda[k] = null
			elif coda[k + 1] == null:
				coda[k + 1] = coda[k]
				coda[k] = null
	for f in finiti:
		diario("Produzione completata: %s" % Carte.titolo(Carte.per_id(str(f))))
	return finiti

## Avvia un progetto nella coda q: nello stadio indicato o in uno libero più a sinistra.
func avvia_progetto(id: String, q: int) -> bool:
	var st := int(Carte.per_id(id).get("stadio_iniziale", 1))
	var coda: Array = s["code"][q]
	for k in range(clampi(st, 1, 3) - 1, -1, -1):
		if coda[k] == null:
			coda[k] = id
			s["produzione_pronti"].erase(id)
			diario("Avviato %s (stadio %d)" % [id, k + 1])
			return true
	return false

## Potenzia (sposta di 1 a destra) un progetto; true se completato.
func potenzia_progetto(q: int, k: int) -> String:
	var coda: Array = s["code"][q]
	if coda[k] == null:
		return ""
	var id: String = coda[k]
	if k == coda.size() - 1:
		coda[k] = null
		diario("Produzione completata: %s" % id)
		return id
	if coda[k + 1] == null:
		coda[k + 1] = id
		coda[k] = null
	return ""

# ------------------------------------------------------------------ caserma

## Reclute pescate: 5 (6 con morale alto, 4 con morale basso o molto basso).
func pesca_reclute() -> Array:
	var n := 5
	if s["morale"] == "high":
		n = 6
	elif s["morale"] in ["low", "very_low"]:
		n = 4
	var out := []
	var pool: Array = s["reclute"].duplicate()
	for k in min(n, pool.size()):
		var j := rng.randi_range(0, pool.size() - 1)
		out.append(pool[j])
		pool.remove_at(j)
	return out

func recluta(file: String, reparto: String, stato := "disponibile") -> void:
	s["reclute"].erase(file)
	var c := Carte.per_file(file)
	s["equipaggio"].append({"carta": str(c.get("nome", "?")), "file": file, "reparto": reparto, "grado": 1, "stato": stato})
	diario("Nuovo Membro: %s (%s)" % [c.get("nome", "?"), reparto])

# ------------------------------------------------------------------ dadi (debriefing)

func costo_dado() -> int:
	return n_dadi()

## Compra un dado per ogni Reparto (tipi: reparto -> tipo di dado).
func compra_dadi(tipi: Dictionary, sconto := 0) -> bool:
	var costo: int = max(0, costo_dado() - sconto)
	if not spendi("successi", costo):
		return false
	for r in REPARTI:
		s["dadi"][r].append(str(tipi.get(r, DADO_JOLLY[r])))
	s["comprati"] = int(s.get("comprati", 0)) + 1
	diario("Comprati dadi per tutti i Reparti (%d Successi)" % costo)
	return true

func vendi_dadi() -> bool:
	if s.get("venduti_qui", false) or n_dadi() <= 4:
		return false
	for r in REPARTI:
		(s["dadi"][r] as Array).pop_back()
	s["pool"]["successi"] = int(s["pool"]["successi"]) + 4
	s["venduti_qui"] = true
	diario("Venduto un dado per Reparto (+4 Successi)")
	return true

# ------------------------------------------------------------------ rientro dall'esplorazione

## Infermeria: una fila di caselle da sinistra a destra, critiche → moderate → lievi (3 ciascuna,
## Ship Book pagg. 33-34). Chi esce a destra dalle lievi è guarito.
const FILA := ["critical", "critical", "critical", "moderate", "moderate", "moderate", "light", "light", "light"]

func _fila() -> Array:
	var f = s.get("infermeria")
	if not f is Array:
		f = []
		s["infermeria"] = f
	if (f as Array).size() != FILA.size():
		(f as Array).resize(FILA.size())
	# dopo un salvataggio JSON gli indici tornano come numeri decimali
	for k in (f as Array).size():
		if f[k] is float:
			f[k] = int(f[k])
	return f

## Ricovera un Membro ferito nella casella libera più a destra del suo livello (1 Ferita: lievi,
## 2: moderate, 3: critiche); se è pieno si usa un livello più grave; se non c'è posto il Membro muore.
func ricovera(i: int, n_ferite: int) -> String:
	var f := _fila()
	var tipi := ["light", "moderate", "critical"]
	var k: int = clampi(n_ferite, 1, 3) - 1
	while k < 3:
		for j in range(FILA.size() - 1, -1, -1):
			if FILA[j] == tipi[k] and f[j] == null:
				f[j] = i
				s["equipaggio"][i]["stato"] = "infermeria"
				diario("%s in infermeria (%s)" % [s["equipaggio"][i]["carta"], tipi[k]])
				return tipi[k]
		k += 1
	muori(i)
	return "morto"

func in_infermeria() -> Array:
	return _fila().filter(func(x): return x != null)

func livello_infermeria(i: int) -> String:
	var f := _fila()
	var j := f.find(i)
	return FILA[j] if j >= 0 else ""

## Ogni ricoverato avanza di una casella (se libera); i terapisti danno passi in più.
## Restituisce i guariti.
func recupero(extra: Array = []) -> Array:
	var f := _fila()
	var guariti := []
	var passi := {}
	for x in f:
		if x != null:
			passi[x] = 1 + extra.count(x)
	var mosso := true
	while mosso:
		mosso = false
		for j in range(f.size() - 1, -1, -1):
			var x = f[j]
			if x == null or int(passi.get(x, 0)) <= 0:
				continue
			if j == f.size() - 1:
				f[j] = null
				guariti.append(x)
				passi[x] = 0
				s["equipaggio"][int(x)]["stato"] = "disponibile"
				diario("%s è guarito" % s["equipaggio"][int(x)]["carta"])
				mosso = true
			elif f[j + 1] == null:
				f[j + 1] = x
				f[j] = null
				passi[x] = int(passi[x]) - 1
				mosso = true
	return guariti

## Prova di sopravvivenza (chi è nelle caselle critiche): 3 dadi Ferita; si muore con
## 1 [heavyDamage] e 1 [damage], oppure con 2 [heavyDamage] (Ship Book pag. 34).
func prova_sopravvivenza(i: int) -> Dictionary:
	var dadi := []
	for k in 3:
		var d := {"tipo": "ferita", "faccia": 0}
		Prova.tira(d, rng)
		dadi.append(d)
	var facce := _facce(dadi)
	var morto := _morte(facce)
	# F01: si può ritirare un risultato [damage]
	var ritirato := false
	if morto and ha_potenziamento("F01"):
		for d in dadi:
			if "damage" in Prova.icone(d):
				Prova.tira(d, rng)
				ritirato = true
				break
		facce = _facce(dadi)
		morto = _morte(facce)
		if ritirato:
			diario("F01: ritirato un risultato Danno")
	if morto:
		muori(i)
	return {"facce": facce, "morto": morto, "ritirato": ritirato}

static func _facce(dadi: Array) -> Array:
	var out := []
	for d in dadi:
		out.append_array(Prova.icone(d))
	return out

static func _morte(facce: Array) -> bool:
	var pesanti := facce.count("heavyDamage")
	return (pesanti >= 1 and facce.count("damage") >= 1) or pesanti >= 2

## F02: dopo una Prova di sopravvivenza superata il Membro avanza di una casella verso la guarigione.
func sposta_destra(i: int) -> bool:
	var f := _fila()
	var j := f.find(i)
	if j < 0:
		return false
	if j == f.size() - 1:
		f[j] = null
		s["equipaggio"][i]["stato"] = "disponibile"
		diario("%s è guarito" % s["equipaggio"][i]["carta"])
		return true
	if f[j + 1] == null:
		f[j + 1] = i
		f[j] = null
		return true
	return false

## F03: torna nell'Equipaggio a riposo (dall'infermeria).
func dimetti(i: int) -> void:
	var f := _fila()
	var j := f.find(i)
	if j >= 0:
		f[j] = null
	s["equipaggio"][i]["stato"] = "riposo"
	diario("%s lascia l'infermeria e va a riposo" % s["equipaggio"][i]["carta"])

func muori(i: int) -> void:
	var m: Dictionary = s["equipaggio"][i]
	m["stato"] = "morto"
	var f := _fila()
	var j := f.find(i)
	if j >= 0:
		f[j] = null
	s["memoriale"].append({"carta": m["carta"], "reparto": m["reparto"]})
	diario("%s è morto. Il suo nome va sul Muro della memoria" % m["carta"])

# ------------------------------------------------------------------ passi

func passo() -> String:
	return str(s.get("passo", "ponte"))

func vai(p: String) -> void:
	s["passo"] = p
	diario("— %s —" % NOMI_PASSI.get(p, p))

func prossimo() -> void:
	var k := PASSI.find(passo())
	vai(PASSI[(k + 1) % PASSI.size()])
