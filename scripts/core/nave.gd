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
	var c := Carte.per_file(str(s["equipaggio"][i].get("file", "")))
	var cv = c.get("converti", {})
	return str(cv.get("a", "")) if cv is Dictionary else ""

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
	var facce := []
	for k in 3:
		var d := {"tipo": "ferita", "faccia": 0}
		Prova.tira(d, rng)
		facce.append_array(Prova.icone(d))
	var pesanti := facce.count("heavyDamage")
	var morto: bool = (pesanti >= 1 and facce.count("damage") >= 1) or pesanti >= 2
	if morto:
		muori(i)
	return {"facce": facce, "morto": morto}

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
