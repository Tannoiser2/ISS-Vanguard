## Nomi italiani dei componenti (i nomi nel modulo TTS sono in inglese).
## Dove manca una traduzione resta il nome originale.
class_name Traduzioni
extends RefCounted

const NOMI := {
	"Bridge": "Ponte di comando", "Research Laboratory": "Laboratorio di ricerca", "Production Complex": "Complesso produttivo",
	"Hangar": "Hangar", "Unloading": "Area di scarico", "Medbay": "Infermeria", "Memorial Wall": "Muro della memoria",
	"Add-On Facility": "Struttura aggiuntiva", "Lander": "Lander",
	"Engineering": "Ingegneria", "Recon": "Ricognizione", "Science": "Scienza", "Security": "Sicurezza",
	"Engineering Section": "Sezione Ingegneria", "Recon Section": "Sezione Ricognizione",
	"Science Section": "Sezione Scienza", "Security Section": "Sezione Sicurezza",
	"Engineering Section Compartment": "Scomparto Ingegneria", "Recon Section Compartment": "Scomparto Ricognizione",
	"Science Section Compartment": "Scomparto Scienza", "Security Section Compartment": "Scomparto Sicurezza",
	"Armory (Engineering)": "Armeria (Ingegneria)", "Armory (Recon)": "Armeria (Ricognizione)",
	"Armory (Science)": "Armeria (Scienza)", "Armory (Security)": "Armeria (Sicurezza)", "Armory (General)": "Armeria (Generale)",
	"Armory": "Armeria", "Unavailable Equipment": "Equipaggiamento non disponibile",
	"Landing Cards": "Carte Atterraggio", "Research Projects": "Progetti di ricerca", "Production Projects": "Progetti di produzione",
	"Recruits": "Reclute", "Possible Situations": "Situazioni possibili", "Future Situations": "Situazioni future",
	"Facility Upgrades": "Potenziamenti delle strutture", "Recorded Planets": "Pianeti registrati", "Bridge Cards": "Carte Ponte",
	"Lander Mods": "Modifiche del Lander", "Gathered Discoveries": "Scoperte raccolte", "Resting Crew": "Equipaggio a riposo",
	"Planet Cards": "Carte Pianeta", "Removed From Game": "Fuori dal gioco", "Secret Envelope": "Busta segreta",
	"Personnel Files": "Fascicoli del personale", "Lander boards": "Plance Lander", "/ 6 Lander cards": "Carte Lander",
	"/ 23 Threat cards": "Carte Minaccia", "/ 22 Threat standees": "Standee delle Minacce", "/ 6 Lander standees": "Standee dei Lander",
	"/ 23 Mission Equipment Tokens": "Equipaggiamento di missione", "/ 20 Lead Tokens": "Segnalini Traccia",
	"Universal Markers": "Segnalini universali", "Recorded Planet Notecards": "Schede dei pianeti registrati",
	"Empty Boxes": "Scatole vuote", "Section Crew Organizers": "Organizer dell'equipaggio", "Awaiting... Envelope": "Busta \"In attesa…\"",
	"Enginnering Objects": "Oggetti Ingegneria", "Recon Objets": "Oggetti Ricognizione", "Science Objects": "Oggetti Scienza",
	"Security Objects": "Oggetti Sicurezza", "Energy": "Energia", "Command": "Comando", "Success": "Successo", "Time": "Tempo",
	"Injuries": "Ferite", "Discoveries": "Scoperte", "Planetary Scanner": "Scanner planetario", "Events": "Eventi",
	"Threats": "Minacce", "Ready for Production": "Pronto per la produzione", "Blue Dice": "Dadi blu", "Green Dice": "Dadi verdi",
	"Red Dice": "Dadi rossi", "Injury, Danger, and D10 Dice": "Dadi Ferita, Pericolo e D10", "Unique Discovery": "Scoperta unica",
	"Lander Mod": "Modifica del Lander", "Light Injuries": "Ferite lievi", "Moderate Injuries": "Ferite moderate",
	"Critical Injuries": "Ferite critiche", "Memorial": "Memoriale", "Security Memorial": "Memoriale Sicurezza",
	"Science Memorial": "Memoriale Scienza", "Engineering Memorial": "Memoriale Ingegneria", "Recon Memorial": "Memoriale Ricognizione",
	"Medbay Upgrades": "Potenziamenti dell'infermeria", "Production Upgrade": "Potenziamento della produzione",
	"Basic Lander": "Lander base", "Lander 2": "Lander 2", "Lander 3": "Lander 3", "Lander 4": "Lander 4",
	"Biome Icons": "Icone dei biomi", "System Maps": "Mappe dei sistemi", "Planetopedia": "Planetopedia",
	"ROUND": "ROUND", "START": "INIZIO", "ACTIONS LEFT": "AZIONI RIMASTE", "PENALTY": "PENALITÀ", "MISSION FAILED": "MISSIONE FALLITA",
	"Dice Tray": "Vassoio dei dadi", "Morale": "Morale", "Tech Level 1": "Livello tecnologico 1",
	"/ 13 Mineral Discoveries": "Scoperte: Minerali", "/ 13 Microorganism Discoveries": "Scoperte: Microrganismi",
	"/ 13 Live Specimen Discoveries": "Scoperte: Esemplari vivi", "/ 13 Strange Flora Discoveries": "Scoperte: Flora strana",
	"/ 13 Alien Tech Discoveries": "Scoperte: Tecnologia aliena", "/ 12 Wounded": "Ferito", "/ 6 Panicked": "In preda al panico",
	"/ 6 Freezing": "Congelato", "/ 12 Exhausted": "Esausto", "/ 6 Critically Wounded": "Ferito gravemente", "/ 6 Burned": "Ustionato",
	"/ 19 Rank-Ups": "Promozioni", "/ 41 Bridge Cards": "Carte Ponte", "/ 31 Lander Mods": "Modifiche del Lander",
	"/ 27 Production Projects": "Progetti di produzione", "/ 24 Research Projects": "Progetti di ricerca",
	"/ 6 Facility Upgrades": "Potenziamenti delle strutture", "/ 18 Landing Cards": "Carte Atterraggio",
	"/ 16 Future Situations": "Situazioni future", "/ 40 Unique Discoveries": "Scoperte uniche", "/ 43 Global Conditions": "Condizioni globali",
	"/ 60 Missions": "Missioni", "/ 90 Crewmembers": "Membri dell'equipaggio", "/ 4 Just a Scratch!": "Solo un graffio!",
	"/ 40 Events": "Eventi", "Points of Interest (from Tutorial Deck A)": "Punti d'interesse (tutorial A)",
	"/ 101 Unavailable Equipment": "Equipaggiamento non disponibile", "Missions (from Tutorial Deck A)": "Missioni (tutorial A)",
	"/ 5 Tutorial Events": "Eventi del tutorial", "/ 260 Points of Interest 000-533": "Punti d'interesse",
	"/ 9 War Room Planets": "Pianeti della Sala tattica", "/ 9 Embassy District Planets": "Pianeti del Distretto delle ambasciate",
	"/ 40 Advanced Events": "Eventi avanzati", "Wounded": "Ferito", "Panicked": "In preda al panico", "Freezing": "Congelato",
	"Exhausted": "Esausto", "Critically Wounded": "Ferito gravemente", "Burned": "Ustionato", "Just a Scratch!": "Solo un graffio!",
	"Stored Tokens": "Segnalini conservati", "Flex Table Control": "",
}

static func nome(n: String) -> String:
	if NOMI.has(n):
		return NOMI[n]
	if n.begins_with("Page ") and n.contains(" - "):
		var p := n.split(" - ", true, 1)
		return "Pag. %s · %s" % [p[0].substr(5), NOMI.get(p[1], p[1])]
	if n.begins_with("Rank "):
		return n.replace("Rank III", "Grado III").replace("Rank II", "Grado II").replace("Rank I", "Grado I").replace("Cards", "").replace("Engineering", "Ingegneria").replace("Recon", "Ricognizione").replace("Science", "Scienza").replace("Security", "Sicurezza").replace("/ 6 ", "").strip_edges()
	return n.trim_prefix("/ ").strip_edges()

const ICONE := {"travel": "viaggio", "time": "tempo", "marker": "segnalino", "lightning": "fulmine",
	"travelII": "viaggio II", "travelIII": "viaggio III", "travel2": "viaggio II", "travel3": "viaggio III"}

static func icona(n: String) -> String:
	return ICONE.get(n, n)
