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

const TIPI_RX := "strange flora|mineral|microorganism|live specimen|alien tech(?:nology)?"
const VERBI_ELENCO := ["gain", "gains", "lose", "loses", "discard", "discards", "draw", "draws", "refresh", "refreshes", "remove"]

## "Gain 1 [success] and 2 Alien Tech Leads" → "Gain 1 [success] and gain 2 Alien Tech Leads":
## negli elenchi il verbo vale per tutte le voci che iniziano con una quantità.
static func _espandi_elenchi(t: String) -> String:
	var verbi := RegEx.create_from_string("(?i)\\b(" + "|".join(VERBI_ELENCO) + ")\\s")
	var sep := RegEx.create_from_string("(?i)(?:,\\s*|\\s+and\\s+)(?=(?:\\d+|a|an|one|two|three|four|unique discovery)\\s)")
	var vv := verbi.search_all(t)
	var ins := []
	for m in sep.search_all(t):
		var verbo := ""
		for v in vv:
			if v.get_start() < m.get_start():
				var tra := t.substr(v.get_end(), m.get_start() - v.get_end())
				if not tra.contains(".") and not tra.contains(":") and not RegEx.create_from_string("(?<!up) to ").search(tra) and not tra.contains("[dangerDie"):
					verbo = v.get_string(1).to_lower()
				else:
					verbo = ""
		if verbo != "":
			ins.append([m.get_end(), verbo])
	ins.reverse()
	for x in ins:
		t = t.substr(0, x[0]) + x[1] + " " + t.substr(x[0])
	return t

static func _tipi(t: String) -> Array:
	var out := []
	for m in RegEx.create_from_string("(?i)(" + TIPI_RX + ")").search_all(t):
		out.append(SCOPERTE[m.get_string(1).to_lower()])
	return out

## Restituisce {"op": [...], "resto": "testo non riconosciuto"}.
static func analizza(en: String) -> Dictionary:
	var ops := []
	var t := " " + en.replace("\n", " ").replace("–", "-").replace("—", "-") + " "
	# frasi di contorno che non chiedono nulla
	t = RegEx.create_from_string("(?i)\\bhint:.*$").sub(t, " ")
	t = RegEx.create_from_string("(?i)warning:[^.]*\\.(?:[^.]*beforehand\\.)?").sub(t, " ")
	t = RegEx.create_from_string("(?i)\\(?(?:when you fulfill all of the objectives, )?you will be asked to discard this mission\\.?\\)?").sub(t, " ")
	t = RegEx.create_from_string("(?i)discard this mission when you leave the planet\\.?").sub(t, " ")
	t = RegEx.create_from_string("(?i)the mission is accomplished\\s*-?\\s*").sub(t, " ")
	t = RegEx.create_from_string("(?i)^\\s*(?:if no icons match|when you gain this (?:card|discovery)),?\\s*").sub(t, " ")
	t = RegEx.create_from_string("(?i)\\s*and place it next to your crew board").sub(t, " ")
	t = RegEx.create_from_string("(?i)\\s*-?\\s*this counts as an action\\.?").sub(t, " [azione] ", true)
	t = _espandi_elenchi(t)
	var resto := t
	var N := "(\\d+|a|an|one|two|three|four|five)"
	var regole := [
		["(?i)\\[azione\\]", func(m): return {"op": "azione"}],
		["(?i)go to log (\\d+)", func(m): return {"op": "log", "n": int(m.get_string(1))}],
		["(?i)(?:gain|draw) " + N + " leads? of (?:any|a chosen|any one) types?", func(m): return {"op": "indizi_scelta", "n": _n(m.get_string(1)), "tipi": []}],
		["(?i)(?:gain|draw) " + N + " leads? of each type", func(m): return {"op": "indizi_ogni", "n": _n(m.get_string(1))}],
		["(?i)roll (?:a )?d10 and gain " + N + " leads of the following type:[^.]*?alien tech", func(m): return {"op": "indizi_d10", "n": _n(m.get_string(1))}],
		["(?i)gain " + N + " ((?:" + TIPI_RX + ")(?:(?:,\\s*| and )(?:" + TIPI_RX + "))+) leads?", func(m): return {"op": "multi", "ops": _tipi(m.get_string(2)).map(func(x): return {"op": "indizi", "tipo": x, "n": _n(m.get_string(1))})}],
		["(?i)gain " + N + " ((?:" + TIPI_RX + ")(?: or (?:\\d+ )?(?:" + TIPI_RX + "))+) (leads?|discover(?:y|ies))", func(m): return {"op": "indizi_scelta" if m.get_string(3).to_lower().begins_with("lead") else "scoperta_scelta", "n": _n(m.get_string(1)), "tipi": _tipi(m.get_string(2))}],
		["(?i)gain " + N + " (" + TIPI_RX + ") leads?", func(m): return {"op": "indizi", "tipo": SCOPERTE[m.get_string(2).to_lower()], "n": _n(m.get_string(1))}],
		["(?i)gain (?:a|1|one) discovery of any type", func(m): return {"op": "scoperta_scelta", "n": 1, "tipi": []}],
		["(?i)gain " + N + " discover(?:y|ies) from a deck with at least (\\d+) lead tokens?", func(m): return {"op": "scoperta_da_indizi", "valore": 0, "segnalini": int(m.get_string(2))}],
		["(?i)gain " + N + " (" + TIPI_RX + ") discover(?:y|ies)", func(m): return {"op": "scoperta", "tipo": SCOPERTE[m.get_string(2).to_lower()], "n": _n(m.get_string(1))}],
		["(?i)gain (?:a |an |1 |one |the top |the )?unique discovery(?: (\\d+))?", func(m): return {"op": "scoperta_eccezionale", "n": int(m.get_string(1)) if m.get_string(1) != "" else 0}],
		["(?i)gain (\\d+|a|an|one|two|three) \\[success\\](?: tokens?)?", func(m): return {"op": "successi", "n": _n(m.get_string(1))}],
		["(?i)gain (\\d+|a|an|one|two|three) success tokens?", func(m): return {"op": "successi", "n": _n(m.get_string(1))}],
		["(?i)(?:lose|pay) (\\d+|a|an|one|two|three) supplies", func(m): return {"op": "provviste", "n": -_n(m.get_string(1))}],
		["(?i)gain (\\d+|a|an|one|two|three|four|five) supplies", func(m): return {"op": "provviste", "n": _n(m.get_string(1))}],
		["(?i)refresh (all|up to (\\d+)|(\\d+)) \\[die\\] used in this dice check", func(m): return {"op": "ricarica_prova", "n": 99 if m.get_string(1).to_lower() == "all" else int(m.get_string(2) + m.get_string(3))}],
		["(?i)refresh all \\[(die|redDie|blueDie|greenDie)\\]", func(m): return {"op": "ricarica", "n": 99, "colore": COLORE_DADO[m.get_string(1)]}],
		["(?i)gain a discovery from a deck with (?:lead tokens of a total value of (\\d+)|any (\\d+) lead tokens)", func(m): return {"op": "scoperta_da_indizi", "valore": int(m.get_string(1)) if m.get_string(1) != "" else 0, "segnalini": int(m.get_string(2)) if m.get_string(2) != "" else 0}],
		["(?i)refresh (\\d+|a|an|one|two|three|four|five) (?:\\[(die|redDie|blueDie|greenDie)\\]|dice|die)", func(m): return {"op": "ricarica", "n": _n(m.get_string(1)), "colore": COLORE_DADO.get(m.get_string(2), "")}],
		# "Each Crewmember (in this Sector / in Sectors 7 and 8 / with the X Injury card) rolls/gains/...": l'effetto vale per ciascuno
		["(?i)each crewmember( in (?:this|your) sector(?: \\(including you\\))?| in sectors? (\\d+)(?: and (\\d+))?| with the ([a-z ]+?) injury card| in any sector)? ((?:rolls?|gains?|draws?|refresh(?:es)?|loses?|\\[spendDie|\\[sacrifaceDie)[^.]*?)(?=\\.|$| to go to| - or -)", func(m): return _ciascuno(m)],
		["(?i)rolls? (\\d+ )?\\[(dangerDie\\w*)\\](?: (twice|three times))?", func(m): return {"op": "pericolo", "lettera": m.get_string(2).trim_prefix("dangerDie"), "n": {"twice": 2, "three times": 3}.get(m.get_string(3).to_lower(), _n(m.get_string(1)) if m.get_string(1) != "" else 1)}],
		["(?i)gains? (?:an? |the )?(critically wounded|wounded|burned|exhausted|panicked|freezing) injury", func(m): return {"op": "ferita", "tipo": m.get_string(1).to_lower().replace(" ", "_")}],
		["(?i)gains? an? \"?just a scratch!?\"? injury", func(m): return {"op": "ferita", "tipo": "just_a_scratch"}],
		["(?i)discard (?:up to )?" + N + " injury cards?(?: from 1 crewmember)?", func(m): return {"op": "cura_carte", "n": _n(m.get_string(1))}],
		["(?i)discard (?:up to )?" + N + " injury (?:dice|die)(?: from 1 crewmember)?", func(m): return {"op": "cura_dadi", "n": _n(m.get_string(1))}],
		["(?i)flip " + N + " injury cards?(?: facedown)?", func(m): return {"op": "cura_carte", "n": _n(m.get_string(1))}],
		["(?i)replace (?:this card |it )?with (?:a random )?(?:card )?(P\\d{3})(?: card)?", func(m): return {"op": "sostituisci_pdi", "carta": m.get_string(1).to_upper()}],
		["(?i)place (?:card )?(P\\d{3}) on top of this card", func(m): return {"op": "pdi_sopra", "carta": m.get_string(1).to_upper()}],
		["(?i)place (?:card )?(P\\d{3}) in sector (\\d+)", func(m): return {"op": "piazza_pdi", "carta": m.get_string(1).to_upper(), "settore": int(m.get_string(2))}],
		["(?i)replace this card with card (M\\d+)", func(m): return {"op": "sostituisci_missione", "carta": m.get_string(1).to_upper()}],
		["(?i)take your crewmember and any number of assisting crewmembers from this sector and place them in sector (\\d+)(?: or sector (\\d+))?", func(m): return {"op": "muovi_gruppo", "settori": [int(m.get_string(1))] + ([int(m.get_string(2))] if m.get_string(2) != "" else [])}],
		["(?i)(?:place|move) your crewmember (?:in|to|into) the lander sector", func(m): return {"op": "muovi_lander"}],
		["(?i)(?:place|move) your crewmember (?:in|to|into) sector:? (\\d+(?:(?:,\\s*|,? or )\\d+)*)", func(m): return {"op": "muovi_attivo", "settori": Array(RegEx.create_from_string("\\d+").search_all(m.get_string(1)).map(func(x): return int(x.get_string(0)))), "settore": int(RegEx.create_from_string("\\d+").search(m.get_string(1)).get_string(0))}],
		["(?i)draw (\\d+|a|an|one|two|three) (?:section )?cards?", func(m): return {"op": "pesca", "n": _n(m.get_string(1))}],
		["(?i)draw and resolve " + N + " event cards?", func(m): return {"op": "evento", "n": _n(m.get_string(1))}],
		["(?i)discard " + N + " (?:section )?cards?(?! from)", func(m): return {"op": "scarta_carte", "n": _n(m.get_string(1))}],
		["(?i)discard (?:1|a|an|one) (?:\\[(personalEquipment|missionEquipment|smallEquipment)\\]|equipment card)( from any sector)?", func(m): return {"op": "scarta_attrezzatura", "tipo": m.get_string(1)}],
		["(?i)discard " + N + " (?:(" + TIPI_RX + ") )?discover(?:y|ies)(?: from (?:the|your) lander)?", func(m): return {"op": "scarta_scoperte", "n": _n(m.get_string(1)), "tipo": SCOPERTE.get(m.get_string(2).to_lower(), "")}],
		["(?i)discard every lead token from (?:the )?discovery decks", func(m): return {"op": "indizi_scarta_tutti"}],
		["(?i)return (?:any )?" + N + " discarded leads? to the lead bag", func(m): return {"op": "indizi_sacchetto", "n": _n(m.get_string(1))}],
		["(?i)(?:take|gain) (?:1|a|one) (?:chosen )?small equipment card from (?:the )?armory", func(m): return {"op": "armeria", "tipo": "smallEquipment"}],
		["(?i)gain (?:1|a|one) chosen equipment card from (?:the )?armory", func(m): return {"op": "armeria", "tipo": ""}],
		["(?i)gain (\\d+|a|an|one|two|three) charges?", func(m): return {"op": "cariche", "n": _n(m.get_string(1))}],
		["(?i)gain charges up to your starting number", func(m): return {"op": "cariche_iniziali"}],
		["(?i)allow each crewmember to gain (\\d+|a|an|one|two) charges?", func(m): return {"op": "tutti", "sub": {"op": "cariche", "n": _n(m.get_string(1))}}],
		["(?i)(?:add|place) " + N + " markers? (?:to|on|in) the enemy advantage slot", func(m): return {"op": "segni", "dove": "slot:vantaggio nemico", "n": _n(m.get_string(1))}],
		["(?i)remove " + N + " markers? from the enemy advantage slot", func(m): return {"op": "segni", "dove": "slot:vantaggio nemico", "n": -_n(m.get_string(1))}],
		["(?i)place " + N + " markers? in this sector", func(m): return {"op": "segnalini_settore", "n": _n(m.get_string(1))}],
		["(?i)remove all markers from this sector", func(m): return {"op": "segnalini_settore", "n": -999}],
		["(?i)progress the time track on this card by " + N, func(m): return {"op": "tempo_carta", "n": _n(m.get_string(1))}],
		["(?i)reduce the time track on this card by " + N, func(m): return {"op": "tempo_carta", "n": -_n(m.get_string(1))}],
		["(?i)progress the time track on the global condition by " + N, func(m): return {"op": "tempo_condizione", "n": _n(m.get_string(1))}],
		["(?i)progress all time tracks by (\\d+|one|two)", func(m): return {"op": "tempo_tutte", "n": _n(m.get_string(1))}],
		["(?i)reset (?:all|any number of) time tracks", func(m): return {"op": "azzera_tempo"}],
		["(?i)reset (?:this|both) tracks?(?: on this card)?", func(m): return {"op": "azzera_traccia", "colore": ""}],
		["(?i)reset the (green|red|yellow|blue) track", func(m): return {"op": "azzera_traccia", "colore": m.get_string(1).to_lower()}],
		["(?i)move to (?:a|a chosen|another) connected sector", func(m): return {"op": "muovi"}],
		["(?i)discard this (?:card|condition|mission|threat)(?: card)?", func(m): return {"op": "scarta_questa"}],
		["(?i)discard " + N + " supplies", func(m): return {"op": "provviste", "n": -_n(m.get_string(1))}],
		["(?i)discard a chosen threat from this sector(?: and its threat card)?", func(m): return {"op": "scarta_minaccia_settore"}],
		["(?i)choose a threat in your sector\\. then, progress its time track and the global condition time track by " + N, func(m): return {"op": "tempo_minaccia_scelta", "n": _n(m.get_string(1)), "condizione": true}],
		["(?i)end your turn and draw 2 event cards instead of 1", func(m): return {"op": "fine_turno_2_eventi"}],
		["(?i)place " + N + " markers? on the lander board(?: \\(up to (\\d+) markers\\))?", func(m): return {"op": "segni", "dove": "carta:plancia lander", "n": _n(m.get_string(1)), "max": int(m.get_string(2)) if m.get_string(2) != "" else 99}],
		["(?i)progress all time tracks where time tokens are not in the final marker slot by " + N, func(m): return {"op": "tempo_tutte", "n": _n(m.get_string(1))}],
		["(?i)place this card in your sector", func(m): return {"op": "evento_nel_settore"}],
		["(?i)while it's in your sector, you may not perform special actions", func(m): return {"op": "niente_regola"}],
		["(?i)your crewmember dies", func(m): return {"op": "morte"}],
		["(?i)end (?:the )?planetary exploration", func(m): return {"op": "fine_esplorazione"}],
		["(?i)raise morale", func(m): return {"op": "morale", "n": 1}],
		["(?i)lower morale", func(m): return {"op": "morale", "n": -1}],
		["(?i)(?:^|[ .,;:+])\\[spendDie\\](?:\\s*\\+\\s*\\[spendDie\\])*", func(m): return {"op": "spendi", "n": m.get_string(0).count("spendDie"), "colore": ""}],
		["(?i)\\[(spendDie(?:Red|Blue|Green))\\]", func(m): return {"op": "spendi", "n": 1, "colore": m.get_string(1).trim_prefix("spendDie").to_lower()}],
		["(?i)(?:^|[ .,;:+])\\[sacrifaceDie\\](?:\\s*\\+\\s*\\[sacrifaceDie\\])*", func(m): return {"op": "sacrifica", "n": m.get_string(0).count("sacrifaceDie"), "colore": ""}],
		["(?i)\\[(sacrifaceDie(?:Red|Blue|Green))\\]", func(m): return {"op": "sacrifica", "n": 1, "colore": m.get_string(1).trim_prefix("sacrifaceDie").to_lower()}],
		["(?i)nothing happens", func(m): return {"op": "niente"}],
		["(?i)do not progress any time tracks", func(m): return {"op": "niente"}],
		["(?i)lose (\\d+|a|an|one) \\[crewHead\\]", func(m): return {"op": "perdita_testa", "n": _n(m.get_string(1))}],
		["(?i)you may flip an incomplete rank-up card", func(m): return {"op": "grado"}],
		["(?i)flip this card", func(m): return {"op": "gira_carta"}],
	]
	# l'ordine nel testo conta: raccoglie tutte le corrispondenze con la loro posizione
	var trovate := []
	for r in regole:
		var rx := RegEx.create_from_string(r[0])
		for m in rx.search_all(t):
			trovate.append([m.get_start(), m.get_end(), r[1].call(m)])
	trovate.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] > b[1]))
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
	var pulito := RegEx.create_from_string("[\\s.,;:!+\\-]+").sub(resto, " ", true).strip_edges().to_lower()
	pulito = RegEx.create_from_string("\\b(and|then|to|you may|or|also|instead|immediately)\\b").sub(pulito, " ", true)
	pulito = RegEx.create_from_string("\\s+").sub(pulito, " ", true).strip_edges()
	return {"op": ops, "resto": pulito if pulito.length() > 3 else ""}

## "Each Crewmember ... <effetto>": l'effetto (verbo alla terza persona) vale per ognuno dei Membri scelti.
static func _ciascuno(m: RegExMatch) -> Dictionary:
	var filtro := {}
	var dove := m.get_string(1).to_lower()
	if dove.contains("this sector") or dove.contains("your sector"):
		filtro["settore"] = "questo"
	elif m.get_string(2) != "":
		filtro["settori"] = [int(m.get_string(2))] + ([int(m.get_string(3))] if m.get_string(3) != "" else [])
	elif m.get_string(4) != "":
		filtro["ferita"] = m.get_string(4).strip_edges().to_lower().replace(" ", "_")
	var sub := m.get_string(5)
	for k in [["rolls", "roll"], ["gains", "gain"], ["draws", "draw"], ["refreshes", "refresh"], ["loses", "lose"]]:
		sub = RegEx.create_from_string("(?i)\\b" + k[0] + "\\b").sub(sub, k[1], true)
	var a := analizza(sub)
	return {"op": "tutti", "filtro": filtro, "ops": a["op"], "sub": {}}

# ------------------------------------------------------------------ istruzioni del Logbook (italiano)

const SCOPERTE_IT := {"strana vegetazione": "strange_flora", "minerale": "mineral", "minerali": "mineral", "microorganismo": "microorganism",
	"microorganismi": "microorganism", "esemplare vivo": "live_specimen", "esemplari vivi": "live_specimen",
	"tecnologia aliena": "alien_tech", "flora strana": "strange_flora"}
const NUMERI_IT := {"un": 1, "una": 1, "uno": 1, "due": 2, "tre": 3, "quattro": 4, "cinque": 5, "sei": 6}
const FERITE_IT := {"ferito": "wounded", "ferita lesione": "wounded", "lesione grave": "critically_wounded", "ustione": "burned",
	"allo stremo": "exhausted", "panico": "panicked", "congelamento": "freezing", "solo un graffio": "just_a_scratch", "niente di grave": "just_a_scratch", "lesione": "wounded"}

## Chiave di un gruppo di segnaposto: "carta:m21", "carta:vigilanza", "riserva:potere diplomatico", "slot:conoscenza".
static func chiave_segni(t: String) -> String:
	var x := t.to_lower().strip_edges().replace("’", "'")
	x = RegEx.create_from_string("\\(.*?\\)").sub(x, "", true)
	for pre in ["sulla ", "dalla ", "alla ", "allo ", "dallo ", "nello ", "nella "]:
		x = x.trim_prefix(pre)
	var tipo := "carta"
	for k in ["riserva", "slot", "carta"]:
		if x.begins_with(k + " "):
			tipo = k
			x = x.substr(k.length() + 1)
			break
	for k in ["missione opzionale ", "missione ", "condizione generale ", "condizione globale ", "pdi ", "minaccia "]:
		x = x.trim_prefix(k)
	x = x.get_slice(" sulla ", 0).get_slice(" nel settore", 0).strip_edges().trim_suffix(".")
	return tipo + ":" + x

static func _ni(s: String) -> int:
	s = s.strip_edges().to_lower()
	return int(s) if s.is_valid_int() else int(NUMERI_IT.get(s, 1))

## Istruzioni del Logbook in italiano -> operazioni (come analizza). Le icone sono {i:nome}.
## Operazioni in più: muovi_tutti, muovi_attivo, scarta_missione, minaccia, ricarica_tutti, pericolo_tutti,
## nave_pagina, planetopedia.
static func analizza_it(testo: String) -> Dictionary:
	var t := " " + RegEx.create_from_string("\\{i:(\\w+)\\}").sub(testo, "[$1]", true) + " "
	t = RegEx.create_from_string("\\[/?[bi]\\]").sub(t, "", true).replace("\n", " ").replace("’", "'")
	var N := "(\\d+|un|una|uno|due|tre|quattro|cinque|sei)"
	var regole := [
		["(?i)ottien[ie] " + N + " \\[success\\]", func(m): return {"op": "successi", "n": _ni(m.get_string(1))}],
		["(?i)(?:ottien[ie] (?:anche )?|e )la scoperta eccezionale (\\d+)", func(m): return {"op": "scoperta_eccezionale", "n": int(m.get_string(1))}],
		["(?i)ottien[ie] " + N + " indizi[o]? (strana vegetazione|minerale|microorganismo|esemplare vivo|tecnologia aliena|flora strana)", func(m): return {"op": "indizi", "tipo": SCOPERTE_IT[m.get_string(2).to_lower()], "n": _ni(m.get_string(1))}],
		["(?i)ottien[ie] " + N + " scopert[ae] (strana vegetazione|minerale|microorganismo|esemplare vivo|tecnologia aliena|flora strana)", func(m): return {"op": "scoperta", "tipo": SCOPERTE_IT[m.get_string(2).to_lower()], "n": _ni(m.get_string(1))}],
		["(?i)ottien[ie] " + N + " provvist[ae]", func(m): return {"op": "provviste", "n": _ni(m.get_string(1))}],
		["(?i)perd[ie] " + N + " provvist[ae](?! meno)", func(m): return {"op": "provviste", "n": -_ni(m.get_string(1))}],
		["(?i)sostituisci (?:il pdi|la carta|questa carta(?: pdi)?|eventuali carte|la carta pdi) (?:in questo settore |nel tuo settore )?con la carta (P\\d{3})", func(m): return {"op": "sostituisci_pdi", "carta": m.get_string(1).to_upper()}],
		["(?i)sostituisci (?:il pdi|la carta|eventuali carte|la carta pdi) nel settore (\\d+) con la carta (P\\d{3})", func(m): return {"op": "piazza_pdi", "carta": m.get_string(2).to_upper(), "settore": int(m.get_string(1))}],
		["(?i)posiziona la carta (P\\d{3})[^.•]{0,40}? nel settore (\\d+)", func(m): return {"op": "piazza_pdi", "carta": m.get_string(1).to_upper(), "settore": int(m.get_string(2))}],
		["(?i)scarta la (?:carta )?missione (M\\d+)", func(m): return {"op": "scarta_missione", "carta": m.get_string(1).to_upper()}],
		["(?i)posiziona tutti i membri dell'equipaggio[^.]{0,40}? nel settore (\\d+)", func(m): return {"op": "muovi_tutti", "settore": int(m.get_string(1))}],
		["(?i)posiziona il tuo membro(?: dell'equipaggio)? nel settore (\\d+)", func(m): return {"op": "muovi_attivo", "settore": int(m.get_string(1))}],
		["(?i)ciascun membro dell'equipaggio ricarica " + N + " \\[(die|redDie|blueDie|greenDie)\\]", func(m): return {"op": "ricarica_tutti", "n": _ni(m.get_string(1)), "colore": COLORE_DADO[m.get_string(2)]}],
		["(?i)ciascun membro dell'equipaggio tira \\[(dangerDie\\w*)\\]", func(m): return {"op": "pericolo_tutti", "lettera": m.get_string(1).trim_prefix("dangerDie")}],
		["(?i)(?<!ciascun membro dell'equipaggio )tira (?:un |il )?(?:dado )?\\[(dangerDie\\w*)\\]", func(m): return {"op": "pericolo", "lettera": m.get_string(1).trim_prefix("dangerDie"), "n": 1}],
		["(?i)(?:subisci|ottieni) una ferita (ferito|lesione grave|lesione|ustione|allo stremo|panico|congelamento|solo un graffio|niente di grave)", func(m): return {"op": "ferita", "tipo": FERITE_IT[m.get_string(1).to_lower()]}],
		["(?i)fai avanzare tutte le tracce del tempo di " + N, func(m): return {"op": "tempo_tutte", "n": _ni(m.get_string(1))}],
		["(?i)apri il manuale della nave a pagina (\\d+)", func(m): return {"op": "nave_pagina", "n": int(m.get_string(1))}],
		["(?i)apri la planetopedia alle pagine (\\d+)\\s*[-–]\\s*(\\d+)", func(m): return {"op": "planetopedia", "pagina": "p.%d-%d" % [int(m.get_string(1)), int(m.get_string(2))]}],
		["(?i)non (?:succede|accade) nulla", func(m): return {"op": "niente"}],
		# segnaposto su carte, riserve e slot; Piaghe nei settori (le domande del Logbook li controllano)
		["(?i)(?:posiziona|aggiungi|metti) " + N + " segnaposto (?:universal[ei] )?(sulla carta [^.,;•]+?|alla riserva [^.,;•]+?|allo slot [^.,;•]+?|nello slot [^.,;•]+?)(?=[.,;•]| e | se | su di| oppure|$)", func(m): return {"op": "segni", "dove": chiave_segni(m.get_string(2)), "n": _ni(m.get_string(1))}],
		["(?i)(?:scarta|rimuovi|togli) " + N + " segnaposto (dalla carta [^.,;•]+?|dalla riserva [^.,;•]+?|dallo slot [^.,;•]+?)(?=[.,;•]| e | se |$)", func(m): return {"op": "segni", "dove": chiave_segni(m.get_string(2)), "n": -_ni(m.get_string(1))}],
		["(?i)(?:scarta|rimuovi) tutti i segnaposto (dalla carta [^.,;•]+?|dalla riserva [^.,;•]+?|dallo slot [^.,;•]+?)(?=[.,;•]| e | se |$)", func(m): return {"op": "segni", "dove": chiave_segni(m.get_string(1)), "n": -999}],
		["(?i)(?:posiziona|aggiungi) " + N + " piag(?:a|he) nel (?:settore (\\d+)|tuo settore|relativo settore)", func(m): return {"op": "piaghe", "n": _ni(m.get_string(1)), "settore": int(m.get_string(2)) if m.get_string(2) != "" else 0}],
		["(?i)(?:rimuovi|scarta) " + N + " piag(?:a|he) dal (?:settore (\\d+)|tuo settore)", func(m): return {"op": "piaghe", "n": -_ni(m.get_string(1)), "settore": int(m.get_string(2)) if m.get_string(2) != "" else 0}],
		["(?i)(?:rimuovi|scarta) tutte le piaghe dal (?:settore (\\d+)|tuo settore)", func(m): return {"op": "piaghe", "n": -999, "settore": int(m.get_string(1)) if m.get_string(1) != "" else 0}],
		# atterraggio
		["(?i)posiziona un segnaposto nella casella iniziale", func(m): return {"op": "atterraggio_inizio"}],
		["(?i)fai avanzare il contatore dell'atterraggio(?: di (due|tre|\\d+))?", func(m): return {"op": "atterraggio", "n": _ni(m.get_string(1)) if m.get_string(1) != "" else 1}],
		["(?i)(?:sposta|muovi) il segnaposto (?:sul contatore dell'atterraggio )?di (\\d+) casell[ae] verso sinistra", func(m): return {"op": "atterraggio", "n": -int(m.get_string(1))}],
		["(?i)perd[ie] " + N + " provvist[ae] meno ?\\[(landerArmor|landerSensors|landerAgility)\\]", func(m): return {"op": "provviste_meno", "n": _ni(m.get_string(1)), "stat": m.get_string(2)}],
		["(?i)ciascun membro dell'equipaggio " + N + " \\[(sacrifaceDie|spendDie)\\] meno ?\\[(landerArmor|landerSensors|landerAgility)\\]", func(m): return {"op": "dadi_meno", "n": _ni(m.get_string(1)), "dado": m.get_string(2), "stat": m.get_string(3)}],
		["(?i)ciascun membro dell'equipaggio (?:ottiene|subisce) una ferita (ferito|lesione grave|ustione|allo stremo|panico|congelamento|lesione|solo un graffio|niente di grave)", func(m): return {"op": "ferita_tutti", "tipo": FERITE_IT.get(m.get_string(1).to_lower(), "wounded")}],
		["(?i)posiziona " + N + " segnaposto(?: danno)? sulla plancia lander,? meno\\.? ?\\[(landerArmor|landerSensors|landerAgility)\\]", func(m): return {"op": "danni_meno", "n": _ni(m.get_string(1)), "stat": m.get_string(2)}],
		["(?i)tira un dado pericolo " + N + " volte,? meno ?\\[(landerArmor|landerSensors|landerAgility)\\]\\.? per ciascun \\[(common|uncommon|rare|special)\\]", func(m): return {"op": "danni_tiro", "n": _ni(m.get_string(1)), "stat": m.get_string(2), "faccia": m.get_string(3)}],
	]
	var trovate := []
	for r in regole:
		var rx := RegEx.create_from_string(r[0])
		for m in rx.search_all(t):
			trovate.append([m.get_start(), m.get_end(), r[1].call(m)])
	trovate.sort_custom(func(a, b): return a[0] < b[0])
	var occ := []
	var ops := []
	for x in trovate:
		var sov := false
		for o in occ:
			if x[0] < o[1] and x[1] > o[0]:
				sov = true
		if sov:
			continue
		occ.append([x[0], x[1]])
		ops.append(x[2])
	return {"op": ops}
