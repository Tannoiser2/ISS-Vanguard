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

const VERSIONE := 1
const CARTELLA := "user://campagne"
const LETTERE := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var dati: Dictionary = {}
var motore: MotoreLogbook
var _sporco := false
var _timer: Timer

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARTELLA)
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
	for k in ["logbook", "tavolo", "registro"]:
		if not (dati.get(k) is Dictionary):
			dati[k] = {}
	_prepara()
	cambiata.emit()

func chiudi() -> void:
	if _sporco:
		await salva_subito()
	dati = {}
	motore = null
