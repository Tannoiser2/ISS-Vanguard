## Espansione Personnel Files (Fascicoli del personale): ogni Membro promosso al Grado 2 (o 3, versione
## impegnativa) riceve la sua carta Obiettivo individuale; completandolo diventa Veterano: nuovo ritratto
## e una seconda abilità di conversione (Regole abbreviate del modulo TTS, "File 1" e "File 192").
class_name Fascicoli
extends RefCounted

## Carta Veterano del Membro (dal file della sua carta Equipaggio), {} se non c'è.
static func veterano_di(file_membro: String) -> Dictionary:
	var c: Dictionary = Carte.per_file(file_membro)
	if c.get("veterano", false):
		return c
	var nome := _norm(str(c.get("nome", "")))
	var primo := _norm(str((c.get("nomi", [""]) as Array)[0] if not (c.get("nomi", []) as Array).is_empty() else ""))
	var per_nome := {}
	for v in Carte.categoria("veterani"):
		if nome != "" and _norm(str(v.get("nome", ""))) == nome:
			return v
		var pv := _norm(str((v.get("nomi", [""]) as Array)[0] if not (v.get("nomi", []) as Array).is_empty() else ""))
		per_nome[pv] = v
	return per_nome.get(primo, {})

const ACCENTI := {"Ï": "I", "Í": "I", "À": "A", "Á": "A", "Ä": "A", "Ă": "A", "Ạ": "A", "Ã": "A", "É": "E", "È": "E",
	"Ó": "O", "Ö": "O", "Ü": "U", "Ú": "U", "Ñ": "N", "Ç": "C", "Ș": "S", "Ł": "L", "Ā": "A", "Ō": "O", "Ū": "U"}

static func _norm(t: String) -> String:
	var s := t.strip_edges().to_upper()
	for k in ACCENTI:
		s = s.replace(k, ACCENTI[k])
	return s

## Abilità di conversione di una carta (una per i Membri normali, due per i Veterani): [{"colore", "a"}].
static func conversioni(c: Dictionary) -> Array:
	var cv = c.get("converti", {})
	var lista: Array = cv if cv is Array else ([cv] if cv is Dictionary and not (cv as Dictionary).is_empty() else [])
	var out := []
	for x in lista:
		if x is Dictionary and str(x.get("a", "")) != "":
			out.append({"colore": str(x.get("colore", "")).replace("Die", ""), "a": str(x.get("a", ""))})
	return out

## Testo dell'Obiettivo individuale (in italiano) della carta Veterano.
static func testo_obiettivo(v: Dictionary) -> String:
	return Carte.t(v.get("obiettivo", ""))

## Caselle della traccia dell'Obiettivo (0 = nessuna traccia: si completa con un clic).
static func caselle(v: Dictionary) -> int:
	return int(v.get("traccia", 0)) if v.get("traccia") != null else 0
