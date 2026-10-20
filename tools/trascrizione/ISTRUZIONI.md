# Trascrizione delle carte di ISS Vanguard in dati strutturati

Scopo: un motore di gioco (Godot) deve **automatizzare l'esplorazione planetaria** di ISS Vanguard.
Ti viene dato un lotto di immagini (carte scansionate in inglese, dal modulo Tabletop Simulator).
Per ogni immagine guardala con lo strumento Read (se serve ingrandisci ritagliando con Python/PIL:
`python3 -c "from PIL import Image; Image.open(P).crop((x0,y0,x1,y1)).resize(...).save('/tmp/x.png')"`)
e trascrivi la carta in JSON secondo lo schema del tuo tipo di carta (più sotto).

Scrivi **un solo file JSON** (il percorso è indicato nel tuo compito): un oggetto
`{"carte": [ ... ]}` con una voce per immagine, nello stesso ordine del lotto. Usa UTF-8, JSON valido
(controllalo alla fine con `python3 -c "import json;json.load(open(PERCORSO))"`).

## Regole generali
- Trascrivi **fedelmente** il testo inglese (`en`) e dai una **traduzione italiana** (`it`) con la
  terminologia ufficiale italiana (glossario sotto). Testo di regole: niente parafrasi creative.
- Le **icone** nel testo si scrivono fra parentesi quadre con il nome del vocabolario:
  "Each Crewmember who ends their turn in this Sector [spendDie]." Il foglio con tutte le icone e i
  loro nomi è `tools/trascrizione/foglio_icone.png` (guardalo prima di iniziare). Se un'icona non è
  nel foglio, inventa un nome breve camelCase e segnalalo nel campo `"dubbi"` della carta.
- Grassetti/corsivi: ignorali. Numeri di Log: scrivili come nel testo ("go to Log 379").
- Se una parte è illeggibile o incerta, scrivi la tua migliore lettura e spiega in `"dubbi"` (stringa).
- Non inventare campi non presenti sulla carta: lascia vuoti/omessi quelli che non servono.

## Vocabolario delle icone (nomi esatti)
Facce dei dadi Reparto: `basic`, `vanguard`, `accident`, `biology`, `xenology`, `scouting` (verdi),
`scienceDice` (atomo), `technology` (monitor), `construction` (chiave inglese) (blu),
`physical` (braccio), `defence` (scudo), `gathering` (piccone) (rossi).
Dadi come costo/requisito: `die` (dado di qualsiasi colore, cubo tricolore), `redDie`, `blueDie`, `greenDie`,
`spendDie`, `spendDieRed`, `spendDieBlue`, `spendDieGreen`, `sacrifaceDie`, `sacrifaceDieRed`,
`sacrifaceDieBlue`, `sacrifaceDieGreen`.
"Qualsiasi icona" (A dentro esagono): `anySameIcons` (se compare più volte = la stessa icona ripetuta).
Dado Pericolo: `dangerDieA` … `dangerDieJ`, `dangerDieT`, `dangerDieAny`, e con numero `dangerDieA1`… (lettera+numero).
Facce del dado Pericolo: `common`, `uncommon`, `rare`, `special` (cristalli neri).
Dado Ferita: `damage`, `heavyDamage`, `mental`, `special`.
Biomi: `caves`, `crystalline`, `desert`, `frigid`, `rocky`, `ruins`, `vegetation`, `volvanic`, `water`, `void`,
`hostile`, `deadly`. Altro: `finalPOI` (bandierina), `important` (V), `noSave` (dischetto barrato),
`noMovement` (barre rosse), `lander`, `success`, `energy_token`, `command`, `specialAction` (freccia doppia),
`diceCheck`, `landerArmor`, `landerSensors`, `landerAgility`, `leadRecycle`, `crewAssignment`,
`smallEquipment`, `personalEquipment`, `missionEquipment`, `missionEquipmentUpgrades`, `rank1/2/3`,
reparti `engineering`, `recon`, `science`, `security`, alieni `wayfarer`, `visitor`, `idemian`,
`crystaloids`, `anyAlien`, `anyAlienDie`, `aerugon`. Viaggio (omino che cammina): `travel`.
Tempo (clessidra): `time`. Segnalino/marker: `marker`.
Esiti: `outcomeGreen`, `outcomeYellow`, `outcomeRed` (vai subito a quel risultato);
`outcomeGreenProgress`/`outcomeYellowProgress`/`outcomeRedProgress` (avanza la traccia di quel colore);
`outcomeGreenReduction`/... (fa arretrare la traccia).

## Linguaggio dei requisiti (`req`)
Stringa con i nomi delle icone: `+` = servono tutte, ` / ` = alternative.
Esempi: `"biology+xenology / scouting"`, `"2*technology"` (= technology+technology), `"anySameIcons+anySameIcons"`,
`"redDie+blueDie"` (un dado rosso e uno blu, qualsiasi faccia), `""` (nessun requisito, es. riga rossa).

## Schema di un'AZIONE SPECIALE (Special Action) — usato da PDI, Condizioni Generali, Minacce, Missioni, plance
```json
{
  "nome": {"en": "STUDY THE FLORA", "it": "STUDIARE LA VEGETAZIONE"},
  "icona": "scienceDice",          // icona a sinistra del nome (tipo di prova), se c'è
  "pericolo": ["dangerDieA"],       // dadi Pericolo raffigurati a sinistra del nome (aggiunti alla prova), [] se nessuno
  "prova": true,                    // true se è una prova di dadi (Dice Check), false se è un'azione senza tiro
  "costo": "",                      // eventuale costo da pagare per eseguirla (es. "spendDie"), testo/icone
  "speciali": [                     // righe "effetto speciale" (riquadro nero: requisito = effetto)
    {"req": "biology+xenology / scouting", "effetto": "outcomeGreenProgress"}
    // "effetto" può essere un'icona-esito oppure testo {"en":..,"it":..}
  ],
  "esiti": [                        // righe colorate dall'alto in basso (se non ci sono tracce)
    {"colore": "yellow", "req": "2*scouting", "en": "Gain 1 Mineral Lead.", "it": "Ottieni 1 Indizio Minerale.", "segue": ""},
    {"colore": "green", "req": "scouting", "en": "...", "it": "..."},
    {"colore": "red", "req": "", "en": "Roll [dangerDieA].", "it": "Tira [dangerDieA]."}
  ],
  "tracce": [                       // in alternativa agli esiti: tracce con N caselle e l'esito in fondo
    {"colore": "green", "caselle": 5, "en": "Gain 2 Strange Flora Leads, go to Log 379.", "it": "..."}
  ],
  "frecce": "testo libero se un esito è collegato a un altro con una freccia (si applicano entrambi)"
}
```
Nota: in una riga d'esito il requisito può essere un'alternativa (`/`) o una somma (`+`); il colore
è quello della barra laterale (verde, giallo, rosso). La riga rossa di solito non ha requisito.

## Glossario italiano (dall'app ufficiale)
Lead = Indizio/Indizi · Strange Flora = Strana Vegetazione · Mineral = Minerale · Microorganism = Microorganismo ·
Live Specimen = Esemplare Vivo · Alien Tech = Tecnologia Aliena · Discovery = Scoperta · Unique Discovery = Scoperta Eccezionale ·
Sector = Settore · Crewmember = Membro dell'Equipaggio · Away Team = Squadra di Sbarco · Section = Reparto ·
Section card = carta Reparto · Dice Check = Prova (di dadi) · Roll Pool = Riserva del Tiro · Spent Pool = Riserva dei Dadi Spesi ·
Supplies = Provviste · Injury = Ferita · Wounded = Ferito · Burned = Ustione · Exhausted = Allo Stremo · Panicked = Panico ·
Freezing = Congelamento · Critically Wounded = Lesione Grave · Point of Interest (POI) = Punto di Interesse (PDI) ·
Threat = Minaccia · Time token = segnalino Tempo · Time Track = traccia del Tempo · Success token = segnalino Successo ·
Global Condition = Condizione Generale · Event = Evento · Mission = Missione · Special Action = Azione Speciale ·
Outcome = Risultato · Track = Traccia · Danger die = dado Pericolo · Injury die = dado Ferita · Assist = Assistere ·
Travel = Viaggio · Rest = Riposo · Prepare = Preparazione · Lift-Off = Decollo · Exert = Sforzo · Charge = Carica ·
Refresh = Ricarica · Spend = Spendi · Sacrifice = Sacrifica · Reroll = Ritira · Equipment = Attrezzatura ·
Lander = Lander · Ship Book = Manuale della Nave · Planet board = plancia del Pianeta · Rank-Up = Grado Superiore ·
Log = Annotazione ("go to Log 379" = "vai all'Annotazione 379") · Biome = Bioma · Charges = Cariche · Skill = Abilità.

## SCHEMI PER TIPO DI CARTA

### PDI (Points of Interest)
```json
{"file": "...", "id": "P210", "titolo": {"en": "MAPPED RAVINES", "it": "GOLE MAPPATE"},
 "icone": ["finalPOI"],            // icone in alto a destra (bandierina, biomi, important, noSave, noMovement, lander…)
 "testo_colore": {"en": "Navigating the area...", "it": "..."},   // corsivo descrittivo
 "testo": {"en": "Each Crewmember who ends their turn in this Sector [spendDie].", "it": "..."},  // regole sempre attive (se ci sono)
 "azioni": [ AZIONE SPECIALE, ... ],
 "altro": {"en": "...", "it": "..."},   // qualsiasi altro elemento (es. "Go to Log 441" stampato, segnalini, ecc.)
 "dubbi": ""}
```
Nota: alcune carte hanno solo titolo e testo (es. "NOTHING INTERESTING").

### Eventi (Events / Advanced Events / Tutorial Events) — carte verticali
```json
{"file": "...", "titolo": {"en": "MALFUNCTION", "it": "GUASTO"},
 "biomi": ["deadly","desert","ruins","void","water","frigid"],      // icone in alto
 "secondario": {"en": "If no icons match, discard this card and progress all Time Tracks by 1.", "it": "..."},  // parte alta
 "principale": {"en": "Lose 1 Supplies - OR - Roll [dangerDieG].", "it": "..."},   // parte bassa (se un bioma coincide)
 "scelta": [{"en": "Lose 1 Supplies", "it": "Perdi 1 Provviste"}, {"en": "Roll [dangerDieG]", "it": "Tira [dangerDieG]"}],  // se è "- OR -"
 "dubbi": ""}
```

### Condizioni Generali (Global Conditions)
```json
{"file":"...","id":"G23","titolo":{"en":"IONIC WATERFALLS","it":"..."},"testo_colore":{...},
 "testo": {"en":"Each Crewmember who starts their turn in a Sector with a [?] and without the Builder's Biomebot, immediately rolls [dangerDieE].","it":"..."},
 "viaggio": AZIONE SPECIALE,     // il riquadro TRAVEL (risolto quando si percorre un sentiero con l'icona travel)
 "azioni": [AZIONE SPECIALE...],   // altre azioni speciali
 "tempo": {"caselle": 2, "en": "Discard this Condition.", "it": "Scarta questa Condizione."},   // traccia del Tempo in basso (numero di caselle » e testo finale)
 "dubbi":""}
```

### Missioni
```json
{"file":"...","id":"M102","titolo":{"en":"A STRIKE AT THE HEART","it":"..."},"testo_colore":{...},
 "obiettivo":{"en":"Defend the Vanguard Core in Sector 2.","it":"..."},
 "suggerimento":{"en":"...","it":"..."},"completamento":{"en":"...","it":"..."},
 "azioni":[...], "tempo": {...} , "opzionale": false, "dubbi":""}
```

### Minacce (Threat cards: fronte e retro)
```json
{"file":"...","lato":"fronte|retro","titolo":{...},"testo_colore":{...},"icone":["noSave"],
 "regole":{"en":"...","it":"..."},         // movimento, comportamento
 "tempo":[{"casella":1,"en":"...","it":"..."}, ...],   // traccia del Tempo: per ogni casella (da sinistra) l'effetto stampato sopra (se c'è); ultima casella = effetto finale
 "azioni":[AZIONE SPECIALE...],"dubbi":""}
```

### Carte Reparto (Section cards, gradi I-III, e carte tutorial)
```json
{"file":"...","titolo":{"en":"RECOMPILING WORK","it":"..."},"reparto":"science","grado":1,
 "quando":"anytime|during_check|before_after_action|when_assisting|...",   // dalla frase iniziale
 "effetto":{"en":"Before or after an Action: Move 1 Lead token from any Discovery deck to any other Discovery deck.","it":"..."},
 "icone_sx":["science","rank1"],          // icone sul bordo sinistro (reparto, grado)
 "combo":{"req":"biology","en":"Refresh 2 [blueDie].","it":"Ricarica 2 [blueDie]."},   // combinazione di dadi in basso
 "dubbi":""}
```

### Membri dell'Equipaggio (fronte; il retro di solito ha obiettivi individuali o è il veterano)
```json
{"file":"...","lato":"fronte|retro","nome":"ABBY KNIGHT",
 "converti":{"colore":"blueDie","da":"basic","a":"xenology"},   // in alto a sinistra: [dado colore basic] = [icona]
 "abilita":{"nome":"ALPHA","en":"During a Dice Check: Spend 1 Charge to choose a Crewmember Assisting you and turn 1 [die] in their Roll Pool to any result.","it":"..."},
 "cariche":3, "reparto":"recon|science|security|engineering|?", "grado":"(icone in basso a destra se presenti)",
 "retro_testo":{"en":"...","it":"..."},"dubbi":""}
```
Il reparto si deduce dal colore/icona della carta se visibile, altrimenti "?".

### Attrezzatura (Equipment)
```json
{"file":"...","titolo":{...},"tipo":"smallEquipment|personalEquipment|missionEquipment|missionEquipmentUpgrades",
 "reparto":"(icona reparto se presente)","quando":"...","effetto":{"en":"...","it":"..."},
 "converti":{"colore":"...","da":"basic","a":"..."}, "azioni":[...], "segnalino": false, "dubbi":""}
```

### Ferite (Injury cards)
```json
{"file":"...","titolo":{...},"icone":["damage","mental"],      // icone dove si appoggiano i dadi Ferita
 "effetti":[{"icona":"damage","en":"...","it":"..."}], "testo":{...},"dubbi":""}
```

### Altre carte (Rank-Up, Modifiche del Lander, carte Atterraggio, Scoperte, Plance Lander, Condizioni del Tutorial…)
```json
{"file":"...","tipo":"rank_up|lander_mod|landing|discovery|lander_board|...","titolo":{...},
 "testo":{"en":"(tutto il testo della carta, in ordine)","it":"..."},
 "campi":{ ... valori numerici o liste utili: es. per i Lander "corazza":2,"sensori":1,"agilita":2,"provviste":6,"carico":{"personali":4,"missione":2},"scoperte_max":5, "partenza_atterraggio":... ; per le Scoperte "rarita":"common|uncommon|rare|ultra-rare","tipo":"Mineral|...","abilita_esplorazione":{...},"quando_scaricata":{...} ; per le carte Atterraggio "pianeta":"...","annotazione_briefing":...,"parti":[...] },
 "azioni":[...],"dubbi":""}
```

### Plancia del Pianeta (pagina doppia del Planetopedia) — schema dedicato
```json
{"file":"...","pagine":"18-19","pianeta":"COUSIN","nome_in_codice":"HR 5730 C",
 "decollo_log": 395, "evac_log": 310, "descrizione":{"en":"...","it":"..."},
 "settori":[
   {"n":1, "x":0.62, "y":0.86,      // centro del riquadro del settore, coordinate 0..1 sull'immagine (x da sinistra, y dall'alto)
    "w":0.17, "h":0.24,              // larghezza/altezza del riquadro (frazione dell'immagine)
    "icone":["lander","travel"],     // icone del settore (lander, biomi, noMovement, …)
    "pdi":"P107",                    // carta PDI stampata/indicata nel settore all'inizio (se il riquadro mostra una carta stampata, il suo titolo)
    "stampato": {"titolo":"SOGGY CLEARING","azioni":[AZIONE SPECIALE...]},   // se nel settore è STAMPATA una carta (non vuoto), trascrivila
    "log": 441                       // se il settore dice "Go to Log N"
   }],
 "sentieri":[
   {"da":1,"a":2,"senso":"doppio|da->a","icone":["travel"]}   // collegamenti fra settori e icone sul sentiero (travel, dadi colorati, ecc.)
 ],
 "colonna_destra":{"scoperta_eccezionale":"17, 34","missione":"","missione_opzionale":"","condizione":"G27 o testo"},
 "altro":{"en":"...","it":"..."},"dubbi":""}
```
Per la plancia usa l'immagine ad alta risoluzione indicata e ritaglia le zone per leggere i dettagli.

### Note aggiuntive
- Carte Reparto: aggiungi `"barra_bianca": true` se accanto all'icona del grado c'è la barra bianca (carte del mazzo iniziale).
  Il reparto si riconosce dall'icona sul bordo sinistro (engineering = esagono giallo, recon = ali rosa, science = cerchi viola, security = rombi azzurri).
- Membri dell'Equipaggio: il reparto si riconosce dal colore della striscia/del numero e dalle icone; il numero grande in basso
  a destra sono le Cariche iniziali.
- Ogni voce deve avere `"file"` (percorso dell'immagine) e `"nomi"` copiato dal lotto.

## CARTE DELLA NAVE (Gestione della Nave, Ship Book)
Scopo aggiuntivo: automatizzare anche la **Gestione della Nave**. Campi comuni a tutte queste carte:
`"file"`, `"nomi"` (dal lotto), `"id"` (codice stampato: B01, O02, R05, C04, S11, F01…), `"tipo"`,
`"titolo":{en,it}`, `"testo_colore":{en,it}` (testo narrativo in corsivo), `"testo":{en,it}` (regole),
`"concede":["Bridge Upgrade","Research Project"]` (riga GRANTS: copiata in inglese), `"dubbi":""`.
Se nel lotto una voce ha `"retro"`, guarda **anche** quell'immagine e trascrivila nel campo `"retro"`
(`{"titolo":{en,it},"testo":{en,it}}`): sul retro dei progetti c'è l'effetto che si applica quando si completano.

### Ponte (Bridge cards: potenziamenti, obiettivi, livello tecnologico, morale)
```json
{"id":"B01","tipo":"bridge_upgrade|bridge_upgrade_travel|objective|secondary_objective|tech_level|morale",
 "titolo":{...},"testo":{...},"testo_colore":{...},
 "campi":{"comando":3,            // segnalini Comando ottenuti (carte Obiettivo)
          "situazioni":2,         // carte Situazione da pescare (carte Obiettivo)
          "energia":4,            // segnalini Energia (carte Livello tecnologico)
          "livello":1,            // numero del livello tecnologico
          "obiettivo":{"en":"Explore the nearest world ...","it":"..."},  // OBJECTIVE:
          "modifica_comando":0, "modifica_energia":0},   // se il testo modifica i segnalini ricevuti
 "livelli_morale":[{"livello":"high|normal|low|very low","en":"...","it":"..."}],  // solo carta Morale: ogni lato/orientamento
 "dubbi":""}
```
Metti in `campi` tutti i numeri utili che vedi (anche icone [command] / [energy_token] con numeri).

### Progetti di ricerca (Research Projects, fronte + retro)
```json
{"id":"R02","tipo":"research_project","parola_chiave":"BUILDERS","titolo":{...},"testo_colore":{...},
 "costo":{"en":"Free","it":"Gratis"},
 "costo_scoperte":[{"tipo":"mineral|microorganism|live_specimen|strange_flora|alien_tech|any","n":1,"rarita":"|rare|ultra-rare"}],
 "concede":["Bridge Upgrade","Research Project"],
 "retro":{"titolo":{...},"testo":{"en":"... Go to Log 100.","it":"..."}}, "dubbi":""}
```

### Progetti di produzione (Production Projects, fronte + retro)
```json
{"id":"C04","tipo":"production_project","titolo":{...},"testo_colore":{...},
 "icone_potenziamento":["technology","scienceDice"],   // riquadro BOOST: icone di conversione (alternative, "OR")
 "stadio_iniziale":3,                                   // STARTING STAGE
 "concede":["Production Project","Equipment"],
 "retro":{"titolo":{...},"testo":{...}}, "dubbi":""}
```

### Situazioni (Possible / Future Situations)
```json
{"id":"S01","tipo":"situation","titolo":{...},"testo_colore":{...},
 "effetto":{"en":"Lose 1 [command] and shuffle this card into \"Possible Situations\". OR Lose 1 [success] and ...","it":"..."},
 "risolta":{"en":"Remove this card from the game.","it":"..."},        // WHEN SOLVED
 "icone_risolta":["construction","scienceDice"],                       // icone accanto a WHEN SOLVED (alternative)
 "dubbi":""}
```
Icone della nave: `command` (stella), `energy_token` (fulmine nel pentagono), `success`, `crewAssignment`.

### Strutture e altre plance (potenziamenti di strutture, infermeria, memoriale, laboratorio, armeria…)
Per le carte (Facility/Medbay/Production upgrade) usa i campi comuni con `"tipo":"facility_upgrade|medbay_upgrade|production_upgrade"`.
Per le immagini di plance/pagine (laboratorio, infermeria, muro della memoria, armeria, scanner, pool…) usa:
```json
{"tipo":"pagina","nome":"Medbay","testo":{en,it},
 "spazi":[{"nome":"Light Injuries 1","tipo":"light|moderate|critical|research|memorial|...","icone":["construction"],
           "reparto":"engineering|...|","bonus":{"en":"...","it":"..."}}],
 "dubbi":""}
```
Descrivi tutti gli spazi (slot) visibili con le loro icone, eventuali bonus stampati e numeri.

### Mappe dei sistemi (System Maps, una pagina per sistema)
Ogni pagina descrive un sistema stellare: in alto le rotte verso altri sistemi (Outbound), in basso le
destinazioni del sistema (pianeti, stazioni…). Ritaglia e ingrandisci: i testi sono piccoli.
```json
{"tipo":"sistema","nome":"TOI-2","pagina":"(numero di pagina del libretto, se stampato)",
 "testo":{"en":"(testo descrittivo)","it":"..."},
 "rotte":[{"verso":"81 INF","pagina":"(pagina del sistema di arrivo)","energia":2,
           "log":(numero di Log se indicato, altrimenti null),"richiede":"(potenziamento del Ponte richiesto, es. icona/colore giallo)",
           "colore":"(colore della rotta se significativo, es. yellow)"}],
 "destinazioni":[{"nome":"PELLUCID","energia":1,"atterraggio":"L01 (carta Atterraggio se c'è l'icona di atterraggio)",
                  "log":null,"testo":{"en":"(istruzioni accanto alla destinazione)","it":"..."}}],
 "dubbi":""}
```
