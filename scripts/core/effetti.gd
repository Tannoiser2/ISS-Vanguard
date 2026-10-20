## Traduce il testo inglese degli effetti delle carte in operazioni eseguibili dal motore.
## Quello che non si riconosce resta come istruzione da eseguire a mano (con il testo italiano).
##
## Ogni operazione: {"op": nome, ...parametri}. Esempi:
##   "Gain 2 Strange Flora Leads, go to Log 379." -> [{op:indizi, tipo:"strange_flora", n:2}, {op:log, n:379}]
class_name Effetti
extends RefCounted

const NUMERI := {"a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6}
const SCOPERTE := {
	"strange flora": "strange_flora", "mineral": "mineral", "microorganism": "microorganism",
	"live specimen": "live_specimen", "alien tech": "alien_tech", "alien technology": "alien_tech",
}
const FERITE := ["critically wounded", "wounded", "burned", "exhausted", "panicked", "freezing"]
const COLORE_DADO := {"die": "", "redDie": "red", "blueDie": "blue", "greenDie": "green"}

static func _n(s: String) -> int:
	s = s.strip_edges().to_lower()
	if s.is_valid_int():
		return int(s)
	return int(NUMERI.get(s, 1))

## Restituisce {"op": [...], "resto": "testo non riconosciuto"}.
static func analizza(en: String) -> Dictionary:
	var ops := []
	var t := " " + en.replace("\n", " ") + " "
	var resto := t
	var regole := [
		["(?i)go to log (\\d+)", func(m): return {"op": "log", "n": int(m.get_string(1))}],
		["(?i)gain (\\d+|a|an|one|two|three|four) (strange flora|mineral|microorganism|live specimen|alien tech(?:nology)?) leads?", func(m): return {"op": "indizi", "tipo": SCOPERTE[m.get_string(2).to_lower()], "n": _n(m.get_string(1))}],
		["(?i)gain (\\d+|a|an|one|two) (strange flora|mineral|microorganism|live specimen|alien tech(?:nology)?) discover(?:y|ies)", func(m): return {"op": "scoperta", "tipo": SCOPERTE[m.get_string(2).to_lower()], "n": _n(m.get_string(1))}],
		["(?i)gain (?:the top )?unique discovery(?: (\\d+))?", func(m): return {"op": "scoperta_eccezionale", "n": int(m.get_string(1)) if m.get_string(1) != "" else 0}],
		["(?i)gain (\\d+|a|an|one|two|three) \\[success\\](?: tokens?)?", func(m): return {"op": "successi", "n": _n(m.get_string(1))}],
		["(?i)gain (\\d+|a|an|one|two|three) success tokens?", func(m): return {"op": "successi", "n": _n(m.get_string(1))}],
		["(?i)lose (\\d+|a|an|one|two|three) supplies", func(m): return {"op": "provviste", "n": -_n(m.get_string(1))}],
		["(?i)gain (\\d+|a|an|one|two|three) supplies", func(m): return {"op": "provviste", "n": _n(m.get_string(1))}],
		["(?i)refresh (\\d+|a|an|one|two|three|four|five) \\[(die|redDie|blueDie|greenDie)\\]", func(m): return {"op": "ricarica", "n": _n(m.get_string(1)), "colore": COLORE_DADO[m.get_string(2)]}],
		["(?i)roll (\\d+ )?\\[(dangerDie\\w*)\\]", func(m): return {"op": "pericolo", "lettera": m.get_string(2).trim_prefix("dangerDie"), "n": _n(m.get_string(1)) if m.get_string(1) != "" else 1}],
		["(?i)gain an? (critically wounded|wounded|burned|exhausted|panicked|freezing) injury", func(m): return {"op": "ferita", "tipo": m.get_string(1).to_lower().replace(" ", "_")}],
		["(?i)gain an? \"?just a scratch!?\"? injury", func(m): return {"op": "ferita", "tipo": "just_a_scratch"}],
		["(?i)replace (?:this card |it )?with (?:card )?(P\\d{3})", func(m): return {"op": "sostituisci_pdi", "carta": m.get_string(1).to_upper()}],
		["(?i)place (?:card )?(P\\d{3}) in sector (\\d+)", func(m): return {"op": "piazza_pdi", "carta": m.get_string(1).to_upper(), "settore": int(m.get_string(2))}],
		["(?i)draw (\\d+|a|an|one|two|three) section cards?", func(m): return {"op": "pesca", "n": _n(m.get_string(1))}],
		["(?i)gain (\\d+|a|an|one|two|three) charges?", func(m): return {"op": "cariche", "n": _n(m.get_string(1))}],
		["(?i)progress all time tracks by (\\d+|one|two)", func(m): return {"op": "tempo_tutte", "n": _n(m.get_string(1))}],
		["(?i)reset all time tracks", func(m): return {"op": "azzera_tempo"}],
		["(?i)move to a connected sector", func(m): return {"op": "muovi"}],
		["(?i)discard this (?:card|condition|mission|threat)", func(m): return {"op": "scarta_questa"}],
		["(?i)end (?:the )?planetary exploration", func(m): return {"op": "fine_esplorazione"}],
		["(?i)raise morale", func(m): return {"op": "morale", "n": 1}],
		["(?i)lower morale", func(m): return {"op": "morale", "n": -1}],
		["(?i)(?:^|[ .,;])\\[spendDie\\](?:\\s*\\+\\s*\\[spendDie\\])*", func(m): return {"op": "spendi", "n": m.get_string(0).count("spendDie"), "colore": ""}],
		["(?i)\\[(spendDie(?:Red|Blue|Green))\\]", func(m): return {"op": "spendi", "n": 1, "colore": m.get_string(1).trim_prefix("spendDie").to_lower()}],
		["(?i)(?:^|[ .,;])\\[sacrifaceDie\\](?:\\s*\\+\\s*\\[sacrifaceDie\\])*", func(m): return {"op": "sacrifica", "n": m.get_string(0).count("sacrifaceDie"), "colore": ""}],
		["(?i)nothing happens", func(m): return {"op": "niente"}],
	]
	# l'ordine nel testo conta: raccoglie tutte le corrispondenze con la loro posizione
	var trovate := []
	for r in regole:
		var rx := RegEx.create_from_string(r[0])
		for m in rx.search_all(t):
			trovate.append([m.get_start(), m.get_end(), r[1].call(m)])
	trovate.sort_custom(func(a, b): return a[0] < b[0])
	var occupato := []
	for x in trovate:
		var sovrapp := false
		for o in occupato:
			if x[0] < o[1] and x[1] > o[0]:
				sovrapp = true
				break
		if sovrapp:
			continue
		occupato.append([x[0], x[1]])
		ops.append(x[2])
	# testo residuo (senza le parti riconosciute)
	occupato.sort_custom(func(a, b): return a[0] > b[0])
	for o in occupato:
		resto = resto.substr(0, o[0]) + " " + resto.substr(o[1])
	var pulito := RegEx.create_from_string("[\\s.,;:!]+").sub(resto, " ", true).strip_edges()
	pulito = pulito.replace(" and ", " ").replace("and", "").replace(" then ", " ").strip_edges()
	return {"op": ops, "resto": pulito if pulito.length() > 3 else ""}
