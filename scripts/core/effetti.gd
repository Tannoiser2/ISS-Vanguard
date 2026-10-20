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
		["(?i)refresh all \\[(die|redDie|blueDie|greenDie)\\]", func(m): return {"op": "ricarica", "n": 99, "colore": COLORE_DADO[m.get_string(1)]}],
		["(?i)gain a discovery from a deck with (?:lead tokens of a total value of (\\d+)|any (\\d+) lead tokens)", func(m): return {"op": "scoperta_da_indizi", "valore": int(m.get_string(1)) if m.get_string(1) != "" else 0, "segnalini": int(m.get_string(2)) if m.get_string(2) != "" else 0}],
		["(?i)refresh (\\d+|a|an|one|two|three|four|five) \\[(die|redDie|blueDie|greenDie)\\]", func(m): return {"op": "ricarica", "n": _n(m.get_string(1)), "colore": COLORE_DADO[m.get_string(2)]}],
		["(?i)rolls? (\\d+ )?\\[(dangerDie\\w*)\\]", func(m): return {"op": "pericolo", "lettera": m.get_string(2).trim_prefix("dangerDie"), "n": _n(m.get_string(1)) if m.get_string(1) != "" else 1}],
		["(?i)gains? an? (critically wounded|wounded|burned|exhausted|panicked|freezing) injury", func(m): return {"op": "ferita", "tipo": m.get_string(1).to_lower().replace(" ", "_")}],
		["(?i)gains? an? \"?just a scratch!?\"? injury", func(m): return {"op": "ferita", "tipo": "just_a_scratch"}],
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
		["(?i)lose (\\d+|a|an|one) \\[crewHead\\]", func(m): return {"op": "perdita_testa", "n": _n(m.get_string(1))}],
		["(?i)each crewmember (?:in any sector )?draws? (\\d+|a|an|one|two|three) (?:section )?cards?", func(m): return {"op": "tutti", "sub": {"op": "pesca", "n": _n(m.get_string(1))}}],
		["(?i)each crewmember refreshes (\\d+|a|an|one|two|three|four) (?:\\[die\\]|dice|die)", func(m): return {"op": "tutti", "sub": {"op": "ricarica", "n": _n(m.get_string(1)), "colore": ""}}],
		["(?i)each crewmember gains (\\d+|a|an|one|two) charges?", func(m): return {"op": "tutti", "sub": {"op": "cariche", "n": _n(m.get_string(1))}}],
		["(?i)you may flip an incomplete rank-up card", func(m): return {"op": "grado"}],
		["(?i)flip this card", func(m): return {"op": "gira_carta"}],
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

# ------------------------------------------------------------------ istruzioni del Logbook (italiano)

const SCOPERTE_IT := {"strana vegetazione": "strange_flora", "minerale": "mineral", "minerali": "mineral", "microorganismo": "microorganism",
	"microorganismi": "microorganism", "esemplare vivo": "live_specimen", "esemplari vivi": "live_specimen",
	"tecnologia aliena": "alien_tech", "flora strana": "strange_flora"}
const NUMERI_IT := {"un": 1, "una": 1, "uno": 1, "due": 2, "tre": 3, "quattro": 4, "cinque": 5, "sei": 6}
const FERITE_IT := {"ferito": "wounded", "ferita lesione": "wounded", "lesione grave": "critically_wounded", "ustione": "burned",
	"allo stremo": "exhausted", "panico": "panicked", "congelamento": "freezing", "solo un graffio": "just_a_scratch", "niente di grave": "just_a_scratch", "lesione": "wounded"}

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
