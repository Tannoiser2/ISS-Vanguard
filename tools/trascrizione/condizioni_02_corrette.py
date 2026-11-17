#!/usr/bin/env python3
"""Ritrascrizione delle Condizioni Generali di data/carte/condizioni_02.json: nella prima trascrizione ogni
carta aveva i dati della carta precedente. Testi letti dalle immagini (novembre 2026)."""
import json, os

PRJ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
F = os.path.join(PRJ, "data", "carte", "condizioni_02.json")


def t(en, it):
    return {"en": en, "it": it}


MUOVI = t("Move to a connected Sector.", "Spostati in un Settore collegato.")
SCARTA = t("Discard this Condition.", "Scarta questa Condizione.")


def prova(verde_req, verde, rosso, speciale="accident", nome=("TRAVEL", "VIAGGIO")):
    esiti = [dict(colore="green", req=verde_req, segue="", **verde)]
    if rosso:
        esiti.append(dict(colore="red", req="", segue="", **rosso))
    return {"nome": t(*nome), "sentiero": "travel", "icona": "diceCheck", "pericolo": [], "prova": True, "costo": "",
            "speciali": [{"req": speciale, "effetto": "outcomeRed"}] if speciale else [], "esiti": esiti, "tracce": []}


def semplice(costo, en, it):
    return {"nome": t("TRAVEL", "VIAGGIO"), "sentiero": "travel", "icona": "", "pericolo": [], "prova": False,
            "costo": costo, "testo": t(en, it), "speciali": [], "esiti": [], "tracce": []}


def tira(d):
    return t("Roll [%s]." % d, "Tira [%s]." % d)


def gc(id_, titolo, colore=None, speciale=None, testo=None, viaggio=None, tempo=None, extra=None):
    c = {"nomi": [id_], "id": id_, "titolo": t(*titolo)}
    if colore:
        c["testo_colore"] = t(*colore)
    if speciale:
        c["effetto_speciale"] = {"req": speciale[0], "effetto": t(speciale[1], speciale[2])}
    if testo:
        c["testo"] = t(*testo)
    if viaggio:
        c["viaggio"] = viaggio
    if tempo:
        c["tempo"] = {"caselle": tempo[0], "en": tempo[1], "it": tempo[2]}
    if extra:
        c.update(extra)
    c.setdefault("azioni", [])
    c["dubbi"] = "Ritrascritta dall'immagine (la prima trascrizione aveva i dati della carta precedente)."
    c["categoria"] = "condizioni"
    c["copie"] = 1
    return c


VIAGGIO_A = semplice("spendDie / dangerDieA", "[spendDie] or roll [dangerDieA] to move to a connected Sector.",
                     "[spendDie] oppure tira [dangerDieA] per muoverti in un Settore collegato.")
VIAGGIO_1 = semplice("spendDie", "[spendDie] to move to a connected Sector.", "[spendDie] per muoverti in un Settore collegato.")

CARTE = {
    "g03_9902.webp": gc("G03", ("HATCHING SEASON", "STAGIONE DELLA SCHIUSA"),
                        speciale=("scienceDice", "Gain 1 Live Specimen Lead.", "Ottieni 1 Indizio Esemplare Vivo."),
                        viaggio=prova("die", MUOVI, tira("dangerDieA")),
                        tempo=(3, "Discard this Condition.", "Scarta questa Condizione.")),
    "g03_9903.webp": gc("G03", ("GOOD CONDITIONS", "CONDIZIONI FAVOREVOLI"),
                        colore=("We're proceeding at a good pace.", "Stiamo procedendo a buon ritmo."),
                        speciale=("vanguard", "Draw 1 Section card.", "Pesca 1 carta Reparto."),
                        viaggio=VIAGGIO_A, tempo=(2, "Discard this Condition.", "Scarta questa Condizione.")),
    "g04_9906.webp": gc("G04", ("ERUPTING VOLCANO", "VULCANO IN ERUZIONE"),
                        colore=("This area is unstable. We must evacuate!", "Quest'area è instabile. Dobbiamo evacuare!"),
                        viaggio=prova("die", MUOVI, tira("dangerDieA")),
                        tempo=(6, "Go to Log 36.", "Vai all'Annotazione 36.")),
    "g06_9908.webp": gc("G06", ("THE LONG DARK", "LA LUNGA OSCURITÀ"),
                        colore=("The sun disappears over the horizon. It won't be seen here for more than a human year.",
                                "Il sole scompare oltre l'orizzonte. Qui non si rivedrà per più di un anno umano."),
                        viaggio=dict(prova("defence / xenology", MUOVI, tira("dangerDieI"), nome=("DARK SIDE TRAVEL", "VIAGGIO SUL LATO OSCURO")),
                                     sentiero=["travel", "travel2", "travel3"]),
                        tempo=(4, "Go to Log 1102.", "Vai all'Annotazione 1102.")),
    "g07_9909.webp": gc("G07", ("FLASH FIRES", "INCENDI IMPROVVISI"),
                        speciale=("biology", "Gain 2 Strange Flora Leads, roll [dangerDieB], and add it to your Roll Pool.",
                                  "Ottieni 2 Indizi Strana Vegetazione, tira [dangerDieB] e aggiungilo alla tua Riserva del Tiro."),
                        viaggio=prova("greenDie / blueDie", MUOVI, tira("dangerDieB")),
                        tempo=(3, "Discard this Condition.", "Scarta questa Condizione.")),
    "g09_9912.webp": gc("G09", ("RAPID CURRENTS", "CORRENTI RAPIDE"),
                        colore=("It's difficult to predict how the errant water will behave.",
                                "È difficile prevedere come si comporterà l'acqua errante."),
                        speciale=("physical", "You may move Kurma by 1 Sector.", "Puoi muovere Kurma di 1 Settore."),
                        viaggio=semplice("spendDieRed / spendDie+spendDie+spendDie",
                                         "[spendDieRed] or [spendDie]+[spendDie]+[spendDie] to move to a connected Sector.",
                                         "[spendDieRed] oppure [spendDie]+[spendDie]+[spendDie] per muoverti in un Settore collegato.")),
    "g11_10000.webp": gc("G11", ("A MOMENT OF CALM", "UN MOMENTO DI CALMA"),
                         colore=("The fighting dies down for a moment, as both forces regroup and reposition.",
                                 "Gli scontri si placano per un momento, mentre entrambe le forze si riorganizzano e si riposizionano."),
                         speciale=("gathering+xenology", "Gain 2 Alien Tech Leads.", "Ottieni 2 Indizi Tecnologia Aliena."),
                         viaggio=prova("scouting / technology", t("Refresh 2 [die], move to a connected Sector.",
                                                                  "Ricarica 2 [die], spostati in un Settore collegato."), MUOVI),
                         tempo=(2, "Add 1 marker to the Enemy Advantage Slot. Discard this Condition.",
                                "Aggiungi 1 segnalino allo Spazio Vantaggio Nemico. Scarta questa Condizione.")),
    "g13_10001.webp": gc("G13", ("TWILIGHT", "CREPUSCOLO"),
                         colore=("One of the suns sets – and for a brief moment, this place is a temperate, welcoming place.",
                                 "Uno dei soli tramonta e, per un breve momento, questo luogo è temperato e accogliente."),
                         speciale=("anySameIcons+anySameIcons", "Refresh 1 [die].", "Ricarica 1 [die]."),
                         testo=("Whenever you Rest, draw 1 additional Section card and Refresh 1 [die] more.",
                                "Ogni volta che effettui un Riposo, pesca 1 carta Reparto aggiuntiva e Ricarica 1 [die] in più."),
                         viaggio=VIAGGIO_A, tempo=(2, "Discard this Condition.", "Scarta questa Condizione.")),
    "g14_10003.webp": gc("G14", ("DOUBLE NOON", "DOPPIO MEZZOGIORNO"),
                         colore=("The combined power of two suns is almost unbearable – you must be careful not to overexert yourself.",
                                 "La potenza combinata di due soli è quasi insopportabile: devi stare attento a non sforzarti troppo."),
                         testo=("Whenever you Exert, roll [dangerDieC] immediately after.\nAt the start of your Dice Check, if you have 5 or more dice in your Spent Pool, add [dangerDieC] to this Dice Check.",
                                "Ogni volta che fai uno Sforzo, tira [dangerDieC] subito dopo.\nAll'inizio della tua Prova, se hai 5 o più dadi nella tua Riserva dei Dadi Spesi, aggiungi [dangerDieC] a questa Prova."),
                         viaggio=prova("physical / defence / scouting", MUOVI, tira("dangerDieC")),
                         tempo=(2, "Discard this Condition.", "Scarta questa Condizione.")),
    "g16_10005.webp": gc("G16", ("HEAT STORM", "TEMPESTA DI CALORE"),
                         colore=("Cooling systems aren't efficient enough to fight the heatwave.",
                                 "I sistemi di raffreddamento non sono abbastanza efficienti contro l'ondata di calore."),
                         viaggio=semplice("dangerDieB", "Roll [dangerDieB] to move to a connected Sector.",
                                          "Tira [dangerDieB] per muoverti in un Settore collegato."),
                         tempo=(2, "Each Crewmember rolls [dangerDieB]. Discard this Condition.",
                                "Ogni Membro dell'Equipaggio tira [dangerDieB]. Scarta questa Condizione.")),
    "g18_10007.webp": gc("G18", ("EXTREME TEMPERATURES", "TEMPERATURE ESTREME"),
                         colore=("The temperature rapidly rises to the point that our suits cannot cope.",
                                 "La temperatura sale rapidamente fino a superare ciò che le nostre tute possono sopportare."),
                         speciale=("xenology+anySameIcons", "Gain 1 Microorganism Lead.", "Ottieni 1 Indizio Microrganismo."),
                         viaggio=prova("die+die", MUOVI, tira("dangerDieB")),
                         tempo=(2, "Each Crewmember rolls [dangerDieB]. Discard this Condition.",
                                "Ogni Membro dell'Equipaggio tira [dangerDieB]. Scarta questa Condizione.")),
    "g19_10009.webp": gc("G19", ("ARMAGEDDON", "ARMAGEDDON"),
                         colore=("A gravitational anomaly pulls another piece of the shattered moon.",
                                 "Un'anomalia gravitazionale attira un altro frammento della luna in frantumi."),
                         speciale=("defence", "Draw 2 Section cards.", "Pesca 2 carte Reparto."),
                         viaggio=prova("die+die", MUOVI, tira("dangerDieF")),
                         tempo=(3, "Each Crewmember in a Sector without a [caves] rolls [dangerDieF]. Discard this Condition.",
                                "Ogni Membro dell'Equipaggio in un Settore senza [caves] tira [dangerDieF]. Scarta questa Condizione.")),
    "g20_10011.webp": gc("G20", ("MAGNETIC DISTURBANCE", "DISTURBO MAGNETICO"),
                         colore=("A sequence of powerful electromagnetic pulses comes from inside the vault.",
                                 "Una sequenza di potenti impulsi elettromagnetici proviene dall'interno della volta."),
                         viaggio=prova("die+die", MUOVI, tira("dangerDieI"), speciale="accident / technology"),
                         tempo=(2, "Discard this Condition.", "Scarta questa Condizione.")),
    "10014.webp": gc("G22", ("FOREST OF LIGHTNING", "FORESTA DI FULMINI"),
                     testo=("Each Crewmember who starts their turn in a Sector with a [lightning] and without the Builder's Biomebot immediately rolls [dangerDieA].\nWarning: A destructive storm will break out soon!",
                            "Ogni Membro dell'Equipaggio che inizia il turno in un Settore con [lightning] e senza il Biomebot del Costruttore tira subito [dangerDieA].\nAttenzione: presto scoppierà una tempesta distruttiva!"),
                     viaggio=prova("die", MUOVI, tira("dangerDieA"), speciale="accident / construction / technology"),
                     tempo=(2, "Discard this Condition.", "Scarta questa Condizione.")),
    "10101.webp": gc("G24", ("LONELINESS", "SOLITUDINE"),
                     colore=("The lack of other intelligent beings is exhausting.", "La mancanza di altri esseri intelligenti è sfiancante."),
                     speciale=("gathering", "Gain 2 Mineral Leads.", "Ottieni 2 Indizi Minerale."),
                     testo=("Crewmembers may perform 2 Special Actions in a single turn.",
                            "I Membri dell'Equipaggio possono eseguire 2 Azioni Speciali in un solo turno."),
                     viaggio=VIAGGIO_1, tempo=(3, "Each Crewmember [spendDie]. Reset this Track.",
                                                 "Ogni Membro dell'Equipaggio [spendDie]. Azzera questa traccia.")),
    "g21_10013.webp": gc("G21", ("GATHERING STORM", "TEMPESTA IN ARRIVO"),
                         colore=("Sparks jump between the fingers of our mechasuit. Small discharges hit the Lightning Tower.",
                                 "Scintille saltano fra le dita della nostra mechatuta. Piccole scariche colpiscono la Torre dei Fulmini."),
                         viaggio=VIAGGIO_1, tempo=(3, "Discard this Condition.", "Scarta questa Condizione.")),
    "g27_10104.webp": gc("G27", ("TREMORS", "SCOSSE"),
                         colore=("These tremors portend something disastrous. We must prepare for anything!",
                                 "Queste scosse annunciano qualcosa di disastroso. Dobbiamo prepararci a tutto!"),
                         speciale=("defence / technology", "Prepare for the worst: place 1 marker on this card.",
                                   "Preparati al peggio: metti 1 segnalino su questa carta."),
                         viaggio=semplice("spendDie+dangerDieA", "[spendDie] and roll [dangerDieA] to move to a connected Sector.",
                                          "[spendDie] e tira [dangerDieA] per muoverti in un Settore collegato."),
                         tempo=(2, "Go to Log 387.", "Vai all'Annotazione 387.")),
    "g29_10106.webp": gc("G29", ("SECRETION", "SECREZIONE"),
                         colore=("Tissues of this planet are relaxed and ooze strange liquid.",
                                 "I tessuti di questo pianeta sono rilassati e trasudano uno strano liquido."),
                         speciale=("basic", "Refresh 1 [die].", "Ricarica 1 [die]."),
                         testo=("You may always browse POI and Global Conditions stacks on the Planet board.",
                                "Puoi sempre consultare le pile dei PDI e delle Condizioni Generali sulla plancia Pianeta."),
                         viaggio=VIAGGIO_1),
    "g29_10107.webp": gc("G29", ("STRESS", "TENSIONE"),
                         colore=("Tension hangs in the air. Organic parts of this plane are hard as a rock.",
                                 "La tensione è nell'aria. Le parti organiche di questo piano sono dure come la roccia."),
                         speciale=("physical+defence", "[sacrifaceDie] to gain 1 Charge.", "[sacrifaceDie] per ottenere 1 Carica."),
                         testo=("You may always browse POI and Global Conditions stacks on the Planet board.",
                                "Puoi sempre consultare le pile dei PDI e delle Condizioni Generali sulla plancia Pianeta."),
                         viaggio=prova("redDie / die+die", MUOVI, t("[sacrifaceDie]", "[sacrifaceDie]"))),
    "g34_10110.webp": gc("G34", ("GRAVITATIONAL ENGINE ON", "MOTORE GRAVITAZIONALE ACCESO"),
                         colore=("The engine stabilizes some parts of the anomaly, changing routes and allowing us access to other areas.",
                                 "Il motore stabilizza alcune parti dell'anomalia, cambiando i percorsi e permettendoci di accedere ad altre aree."),
                         tempo=(3, "Discard this card.", "Scarta questa carta."),
                         extra={"azioni": [{"nome": t("GO FURTHER", "ANDARE OLTRE"), "icona": "diceCheck", "pericolo": [], "prova": True,
                                            "costo": "", "speciali": [], "tracce": [],
                                            "testo": t("You may perform this Dice Check in any Sector with [void] – this counts as an Action.",
                                                       "Puoi eseguire questa Prova in qualsiasi Settore con [void]: conta come un'Azione."),
                                            "esiti": [{"colore": "green", "req": "scouting / redDie+greenDie", "segue": "",
                                                       "en": "Go to Log 706.", "it": "Vai all'Annotazione 706."}]}]}),
    "g36_10112.webp": gc("G36", ("ISOLATION SYSTEM RESET", "RIPRISTINO DEL SISTEMA DI ISOLAMENTO"),
                         colore=("The presence of a creature destabilizes the closing system of the compartments.",
                                 "La presenza di una creatura destabilizza il sistema di chiusura dei compartimenti."),
                         speciale=("biology", "Gain 1 Live Specimen Lead.", "Ottieni 1 Indizio Esemplare Vivo."),
                         viaggio=prova("die+die", MUOVI, tira("dangerDieH")),
                         tempo=(4, "Discard all markers from all Paths with a [travel]. Reset this Track.",
                                "Scarta tutti i segnalini da tutti i Sentieri con [travel]. Azzera questa traccia.")),
}

if __name__ == "__main__":
    d = json.load(open(F))
    fatte = 0
    for i, c in enumerate(d["carte"]):
        nome = c["file"].split("/")[-1]
        if nome in CARTE:
            nuova = dict(CARTE[nome])
            nuova = {"file": c["file"], **nuova}
            d["carte"][i] = nuova
            fatte += 1
    json.dump(d, open(F, "w"), ensure_ascii=False, indent=1)
    print("ritrascritte", fatte, "di", len(d["carte"]))
