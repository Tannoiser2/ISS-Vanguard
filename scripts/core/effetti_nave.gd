## Effetti dei testi delle carte della nave (Situazioni, Progetti, Obiettivi, destinazioni delle mappe):
## riconosce le operazioni più comuni; il resto resta da fare a mano. "OR" separa le alternative.
class_name EffettiNave
extends RefCounted

const NUMERI := {"a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5}

static func _n(s: String) -> int:
	s = s.strip_edges().to_lower()
	return int(s) if s.is_valid_int() else int(NUMERI.get(s, 1))

## {"alternative": [[op...], ...], "resto": testo non riconosciuto}
static func analizza(en: String) -> Dictionary:
	var parti := Array(en.split(" OR ")) if en.contains(" OR ") else [en]
	var alt := []
	var resto := []
	for p in parti:
		var r := _ops(str(p))
		alt.append(r["op"])
		if str(r["resto"]) != "":
			resto.append(str(r["resto"]))
	return {"alternative": alt, "resto": " / ".join(resto)}

static func _ops(t: String) -> Dictionary:
	var testo := " " + t.replace("\n", " ") + " "
	var regole := [
		["(?i)(lose|discard|spend|pay) (\\d+|a|an|one|two|three) \\[(command|energy_token|energyCost|success)\\](?: tokens?)?", func(m): return {"op": "pool", "pool": _pool(m.get_string(3)), "n": -_n(m.get_string(2))}],
		["(?i)(gain|add|receive|get) (\\d+|a|an|one|two|three|four|five) (?:additional )?\\[(command|energy_token|energyCost|success)\\](?: tokens?)?", func(m): return {"op": "pool", "pool": _pool(m.get_string(3)), "n": _n(m.get_string(2))}],
		["(?i)(lose|discard) (\\d+|a|an|one|two|three) (command|energy|success) tokens?", func(m): return {"op": "pool", "pool": _pool(m.get_string(3)), "n": -_n(m.get_string(2))}],
		["(?i)(gain|add) (\\d+|a|an|one|two|three|four|five) (command|energy|success) tokens?", func(m): return {"op": "pool", "pool": _pool(m.get_string(3)), "n": _n(m.get_string(2))}],
		["(?i)raise (?:the )?morale", func(m): return {"op": "morale", "n": 1}],
		["(?i)lower (?:the |your )?morale", func(m): return {"op": "morale", "n": -1}],
		["(?i)go to log (\\d+)", func(m): return {"op": "log", "n": int(m.get_string(1))}],
		["(?i)shuffle this card (?:back )?into \"?possible situations\"?", func(m): return {"op": "situazione", "dove": "possibili"}],
		["(?i)remove this card from the game", func(m): return {"op": "situazione", "dove": "rimossa"}],
		["(?i)place the penalty token in the command pool", func(m): return {"op": "penalita"}],
	]
	var trovate := []
	for r in regole:
		var rx := RegEx.create_from_string(r[0])
		for m in rx.search_all(testo):
			trovate.append([m.get_start(), m.get_end(), r[1].call(m)])
	trovate.sort_custom(func(a, b): return a[0] < b[0])
	var occ := []
	var ops := []
	for x in trovate:
		var sovr := false
		for o in occ:
			if x[0] < o[1] and x[1] > o[0]:
				sovr = true
		if sovr:
			continue
		occ.append([x[0], x[1]])
		ops.append(x[2])
	var resto := testo
	occ.sort_custom(func(a, b): return a[0] > b[0])
	for o in occ:
		resto = resto.substr(0, o[0]) + " " + resto.substr(o[1])
	var pulito := RegEx.create_from_string("[\\s.,;:!]+").sub(resto, " ", true).strip_edges()
	pulito = pulito.replace(" and ", " ").trim_prefix("and ").trim_suffix(" and").strip_edges()
	if pulito.to_lower() in ["and", "then", "to", "and then", ""]:
		pulito = ""
	return {"op": ops, "resto": pulito if pulito.length() > 3 else ""}

static func _pool(n: String) -> String:
	n = n.to_lower()
	if n.begins_with("command"):
		return "comando"
	if n.begins_with("energy"):
		return "energia"
	return "successi"

## Codici di carte citati in un testo (B05, R07, C23, E38, A12, S11, F02, L4…).
static func codici(t: String) -> Array:
	var out := []
	var rx := RegEx.create_from_string("\\b([ABCEFLMORSG]\\d{1,3})\\b")
	for m in rx.search_all(t):
		if not m.get_string(1) in out:
			out.append(m.get_string(1))
	return out
