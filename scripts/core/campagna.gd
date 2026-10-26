## Stato della campagna in corso e salvataggi.
##
## Tutto ciò che resta fra una sessione e l'altra sta in un solo dizionario `dati`:
##   - logbook: flag, scelte usate, annotazione corrente, cronologia
##   - tavolo: posizione, lato e stato di ogni componente, ordine delle carte in ogni mazzo
##   - registro: diario della campagna (annotazioni visitate, note del giocatore)
## Ogni campagna ha un codice di 6 lettere: con quel codice si riprende la partita da qualunque
## dispositivo (salvataggio su Firebase), oltre alla copia locale nel dispositivo.
extends Node

signal cambiata
signal salvata(ok: bool, dove: String)

## 2: salvataggi completati all'apertura (dati nuovi della nave e dell'esplorazione) e copie di sicurezza.
const VERSIONE := 2
const COPIE := "user://campagne/copie"
const MAX_COPIE := 8
const CARTELLA := "user://campagne"
const LETTERE := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var dati: Dictionary = {}
var motore: MotoreLogbook
var _sporco := false
var _timer: Timer

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARTELLA)
	DirAccess.make_dir_recursive_absolute(COPIE)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 4.0
	_timer.timeout.connect(_salvataggio_automatico)
	add_child(_timer)

func attiva() -> bool:
	return not dati.is_empty()

func codice() -> String:
	return dati.get("codice", "")

func id_campagna() -> int:
	return int(dati.get("camp", 8))

## Nuova campagna. modo: "campagna", "tutorial", "rapido" (Inizio Rapido) oppure "operazioni".
func nuova(camp: int, nome: String, modo: String) -> void:
	var c := ""
	for i in 6:
		c += LETTERE[randi() % LETTERE.length()]
	dati = {
		"versione": VERSIONE,
		"codice": c,
		"camp": camp,
		"nome": nome,
		"modo": modo,
		"creata": Time.get_datetime_string_from_system(),
		"aggiornata": Time.get_unix_time_from_system(),
		"logbook": {"tutorial": modo == "tutorial"},
		"tavolo": {},
		"registro": {"note": "", "eventi": []},
	}
	_prepara()
	annota("Inizio della campagna \"%s\" (%s)" % [nome, Dati.CAMPAGNE[camp]["nome"]])
	salva_subito()

func _prepara() -> void:
	motore = MotoreLogbook.new(id_campagna(), dati["logbook"])

## Diario della campagna (mostrato nel registro).
func annota(testo: String) -> void:
	var ev: Array = dati["registro"].get_or_add("eventi", [])
	ev.append([Time.get_datetime_string_from_system(false, true), testo])
	if ev.size() > 500:
		ev.pop_front()
	modificata()

## Da chiamare dopo ogni modifica: salva dopo qualche secondo di quiete.
func modificata() -> void:
	_sporco = true
	dati["aggiornata"] = Time.get_unix_time_from_system()
	cambiata.emit()
	if _timer.is_inside_tree():
		_timer.start()

func _salvataggio_automatico() -> void:
	if _sporco:
		salva_subito()

func salva_subito() -> void:
	if dati.is_empty():
		return
	_sporco = false
	dati["aggiornata"] = Time.get_unix_time_from_system()
	var ok_locale := _salva_locale()
	salvata.emit(ok_locale, "dispositivo")
	var ok_rete: bool = await Net.salva_campagna(codice(), dati)
	salvata.emit(ok_rete, "online")

func _salva_locale() -> bool:
	var f := FileAccess.open("%s/%s.json" % [CARTELLA, codice()], FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(dati))
	return true

## Elenco delle campagne salvate sul dispositivo: [{codice, nome, camp, aggiornata}].
func elenco_locale() -> Array:
	var out := []
	var d := DirAccess.open(CARTELLA)
	if d == null:
		return out
	for f in d.get_files():
		if not f.ends_with(".json"):
			continue
		var t := FileAccess.get_file_as_string(CARTELLA + "/" + f)
		var x = JSON.parse_string(t)
		if x is Dictionary and x.has("codice"):
			out.append({"codice": x["codice"], "nome": x.get("nome", ""), "camp": int(x.get("camp", 8)),
				"modo": x.get("modo", ""), "aggiornata": float(x.get("aggiornata", 0))})
	out.sort_custom(func(a, b): return a["aggiornata"] > b["aggiornata"])
	return out

func carica_locale(cod: String) -> bool:
	var t := FileAccess.get_file_as_string("%s/%s.json" % [CARTELLA, cod])
	var x = JSON.parse_string(t)
	if not (x is Dictionary):
		return false
	_usa(x)
	return true

## Carica da Firebase; se online c'è una versione più recente di quella locale, vince quella.
func carica_online(cod: String) -> bool:
	var x = await Net.carica_campagna(cod.to_upper())
	if not (x is Dictionary) or not x.has("codice"):
		return false
	var t := FileAccess.get_file_as_string("%s/%s.json" % [CARTELLA, cod.to_upper()])
	var loc = JSON.parse_string(t) if t != "" else null
	if loc is Dictionary and float(loc.get("aggiornata", 0)) > float(x.get("aggiornata", 0)):
		x = loc
	_usa(x)
	_salva_locale()
	return true

func elimina_locale(cod: String) -> void:
	DirAccess.remove_absolute("%s/%s.json" % [CARTELLA, cod])

func _usa(x: Dictionary) -> void:
	dati = x
	# copia di sicurezza della campagna così com'era prima di aprirla con questa versione del programma
	copia_di_sicurezza()
	for k in ["logbook", "tavolo", "registro"]:
		if not (dati.get(k) is Dictionary):
			dati[k] = {}
	_aggiorna_salvataggio()
	_prepara()
	cambiata.emit()

## Completa i dati di un salvataggio fatto con una versione precedente del programma.
func _aggiorna_salvataggio() -> void:
	var aggiunti := []
	if dati.get("nave") is Dictionary and not (dati["nave"] as Dictionary).is_empty():
		aggiunti += Nave.completa(dati["nave"]).map(func(k): return "nave." + str(k))
	if dati.get("esplorazione") is Dictionary and not (dati["esplorazione"] as Dictionary).is_empty():
		aggiunti += Esplorazione.completa(dati["esplorazione"]).map(func(k): return "esplorazione." + str(k))
	var v := int(dati.get("versione", 1))
	if v < VERSIONE or not aggiunti.is_empty():
		dati["versione"] = VERSIONE
		if not dati["registro"].has("eventi"):
			dati["registro"]["eventi"] = []
		annota("Salvataggio aggiornato alla versione %d del programma%s" % [VERSIONE, (" (aggiunti: " + ", ".join(aggiunti) + ")") if not aggiunti.is_empty() else ""])
		_sporco = true
		if _timer:
			_timer.start()

# ------------------------------------------------------------------ copie di sicurezza e file

## Salva una copia della campagna (una per apertura, le ultime MAX_COPIE per campagna).
func copia_di_sicurezza() -> void:
	if dati.is_empty() or codice() == "":
		return
	_copia_testo(codice(), JSON.stringify(dati))

func _copia_testo(cod: String, testo: String) -> void:
	if testo == "":
		return
	var copie := elenco_copie(cod)
	if not copie.is_empty() and FileAccess.get_file_as_string(copie[0]["file"]) == testo:
		return
	var quando := int(Time.get_unix_time_from_system())
	if not copie.is_empty() and int(copie[0]["quando"]) >= quando:
		quando = int(copie[0]["quando"]) + 1
	var f := FileAccess.open("%s/%s_%d.json" % [COPIE, cod, quando], FileAccess.WRITE)
	if f:
		f.store_string(testo)
		f.close()
	copie = elenco_copie(cod)
	for k in range(MAX_COPIE, copie.size()):
		DirAccess.remove_absolute(copie[k]["file"])

## Copie di sicurezza di una campagna, dalla più recente: [{file, quando}].
func elenco_copie(cod: String) -> Array:
	var out := []
	var d := DirAccess.open(COPIE)
	if d == null:
		return out
	for f in d.get_files():
		if f.begins_with(cod + "_") and f.ends_with(".json"):
			out.append({"file": COPIE + "/" + f, "quando": int(f.trim_prefix(cod + "_").trim_suffix(".json"))})
	out.sort_custom(func(a, b): return a["quando"] > b["quando"])
	return out

## Riprende una campagna da una copia di sicurezza (la versione attuale resta fra le copie).
func ripristina_copia(file: String) -> bool:
	var x = JSON.parse_string(FileAccess.get_file_as_string(file))
	if not (x is Dictionary) or not x.has("codice"):
		return false
	# anche la versione attuale resta fra le copie, così si può tornare indietro
	_copia_testo(str(x["codice"]), FileAccess.get_file_as_string("%s/%s.json" % [CARTELLA, str(x["codice"])]))
	x["aggiornata"] = Time.get_unix_time_from_system()
	_usa(x)
	salva_subito()
	return true

## Testo del salvataggio (per scaricarlo in un file).
func esporta(cod: String) -> String:
	if cod == codice() and not dati.is_empty():
		return JSON.stringify(dati, "  ")
	return FileAccess.get_file_as_string("%s/%s.json" % [CARTELLA, cod])

## Carica una campagna da un file scaricato prima (diventa la versione più recente, anche online).
func importa(testo: String) -> bool:
	var x = JSON.parse_string(testo)
	if not (x is Dictionary) or not x.has("codice") or not x.has("logbook"):
		return false
	_copia_testo(str(x["codice"]), FileAccess.get_file_as_string("%s/%s.json" % [CARTELLA, str(x["codice"])]))
	x["aggiornata"] = Time.get_unix_time_from_system()
	_usa(x)
	salva_subito()
	return true

func chiudi() -> void:
	if _sporco:
		await salva_subito()
	dati = {}
	motore = null
