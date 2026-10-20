# ISS Vanguard — adattamento digitale (Godot 4)

Versione digitale per uso personale di **ISS Vanguard** (Awaken Realms), campagna in **solitario**.
Componenti, illustrazioni, regole e testi © Awaken Realms: i paragrafi del Logbook vengono dall'app
ufficiale *ISS Vanguard Companion* (database `appData.sqlite`), i componenti dal modulo Tabletop Simulator.

**Gioca nel browser:** https://tannoiser2.github.io/ISS-Vanguard/

## Avvio
1. Apri Godot 4 (testato su 4.7) → *Importa* → seleziona `project.godot`.
2. Premi **F5**. F11 alterna schermo intero e finestra.

## Cosa c'è
- **Logbook completo in italiano** delle tre campagne (ISS Vanguard, Deadly Frontier, Lost Fleet):
  2.322 annotazioni con tutte le scelte, le condizioni e i flag dell'app ufficiale.
  - le **domande Sì/No** ("il tuo Lander ha almeno 4 Sensori?") e le condizioni sui flag si risolvono
    come nell'app; i **rinvii automatici** scelgono da soli la prima opzione non ancora usata;
  - le scelte **a immagini** (risultato del dado Pericolo) si fanno con un clic sull'immagine;
  - le **istruzioni** da eseguire sul tavolo compaiono in un riquadro a parte; le carte citate
    (P107, M02, S05…) si portano sul tavolo con un clic, prese da qualunque mazzo o scatola;
  - modalità **Tutorial** (le annotazioni seguono la versione tutorial), **Inizio rapido**, **Operazioni**;
  - lo **schema del progetto "Diritto di Nascita"** (annotazione 55) è interattivo;
  - le annotazioni fatte solo di caselle mostrano le caselle da segnare;
  - **registro di bordo**: flag segnati (correggibili a mano), annotazioni visitate, diario, note.
  - Dove la traduzione italiana dell'app manca (7 testi brevi) si usa l'inglese.
- **Tavolo 3D** con tutti i componenti del modulo TTS nella stessa disposizione: Planetopedia con le
  sue 21 pagine, mappe dei sistemi, Ship Book (vassoi con le strutture), plance delle Sezioni, mazzi
  (1.264 carte), segnalini, 74 dadi, standee delle Minacce e dei Lander, le quattro **miniature 3D**
  dell'equipaggio, scatole e sacchetti.
- **Salvataggio della campagna**: automatico dopo ogni modifica, sul dispositivo e su Firebase.
  Si salva *tutto*: posizione, lato e stato di ogni pezzo, l'ordine delle carte in ogni mazzo,
  il contenuto di scatole e sacchetti, i flag e la cronologia del Logbook, il diario e le note.
  Ogni campagna ha un **codice di 6 caratteri** (in alto e nel registro): dal menu *Riprendi con un
  codice* la si riapre da qualunque dispositivo.
- **Esplorazione planetaria automatizzata** (pulsante ESPLORAZIONE): durante la missione si vede solo
  la plancia del pianeta, a tutto schermo, senza l'astronave. Interfaccia a passi: in basso il Membro
  di turno (dadi, Ferite, carte in mano) e solo le azioni possibili in quel momento; le destinazioni
  si scelgono cliccando sulla mappa; Settore, Squadra, Missione, Diario e Logbook si aprono a richiesta
  in un cassetto laterale (Esc lo chiude).
  - preparazione guidata: pianeta del Planetopedia, Squadra di Sbarco (Membro, Reparto, Grado),
    Lander, Missioni e Condizione Generale, mazzi Reparto/Eventi/Scoperte e sacchetto degli Indizi;
    con il tutorial è già tutto pronto (Amir nel Settore 1, Provviste illimitate, solo "Solo un graffio!",
    niente Eventi finché non arriva la Missione M02);
  - turni e round, due azioni per turno: Viaggio (icone del sentiero e azione Viaggio della Condizione
    Generale), Riposo, Preparazione, Azione Speciale (una per turno), Decollo; Sforzo in ogni momento;
  - **prove di dadi** complete: scelta dei dadi e assistenza, tiro, ritiri e modifiche, Combinazioni
    delle carte Reparto, dadi Ferita e Pericolo (tutte le tabelle A–I e T), effetti speciali,
    esiti collegati dalle frecce, tracce di avanzamento salvate nel settore;
  - gli **effetti delle carte** si applicano da soli (Indizi e Scoperte, Successi, Provviste, ricariche,
    dadi spesi/sacrificati, Ferite, sostituzione dei PDI, carte pescate, tracce del Tempo, movimento,
    annotazioni del Logbook); quello che il programma non riconosce viene elencato da fare a mano,
    con il pulsante CORREZIONI per sistemare qualunque cosa;
  - fine del turno con limite di carte e Evento (effetto principale o secondario secondo i biomi),
    annotazioni lette entrando nei settori, carte chieste dal Logbook piazzate nel settore giusto;
  - **atterraggio**: all'inizio si apre il briefing; il contatore dell'Atterraggio, i danni al Lander,
    le Provviste "meno Corazza/Agilità", i dadi e le Ferite della squadra si applicano da soli, e le
    domande del Logbook sul Lander ("la Corazza è 4 o più?", "il segnaposto è su Atterraggio
    riuscito?") hanno risposta automatica; le scelte a immagini del dado Pericolo si tirano con un clic;
  - **Minacce**: piazzate dal Logbook nel settore scelto; quando le tracce del Tempo avanzano si
    risolvono gli effetti della carta (movimento verso il Membro più vicino, D10, settore successivo,
    effetti sui Membri nel settore, carta girata, scarto); la loro Azione Speciale compare nel settore;
  - molte istruzioni del Logbook in italiano si eseguono da sole (Successi, Scoperte, Indizi, PDI,
    Missioni, spostamenti, dadi Pericolo, Ship Book a pagina 25…), e il riquadro dice cosa è stato fatto;
  - tutto lo stato dell'esplorazione è salvato nella campagna e si riprende da dove si era rimasti.
- **Gestione della Nave automatizzata** (pulsante GESTIONE NAVE): il Ship Book una pagina alla volta,
  con a sinistra i passi e al centro solo quello corrente.
  - inizio della campagna dopo il tutorial o con l'inizio rapido (reclute a scelta per ogni Reparto);
  - Ponte: installazione delle carte dalla busta "In attesa…", segnalini Comando ed Energia da Obiettivo
    e Livello tecnologico, effetti delle Situazioni in sospeso, nuove Situazioni (in base al Morale);
  - Mappa stellare: rotte con costo in Energia e potenziamenti richiesti, destinazioni, carta Atterraggio
    nello scanner e scansione delle sue parti (con i Membri in ricognizione);
  - Strutture (1 Comando ciascuna): Laboratorio (costi in Scoperte, parole chiave, retro dei progetti con
    gli spostamenti di carte), Complesso produttivo (code a 3 stadi, avvio, potenziamento con le icone di
    conversione), Caserma (reclute in base al Morale, addestramento, trasferimenti), Sala situazioni;
  - Hangar e Procedura di lancio: scelta del Lander e delle modifiche, Squadra di Sbarco con i dadi
    sistemati secondo la plancia del Reparto, attrezzatura, briefing e passaggio all'esplorazione;
  - rientro: Missione fallita, Scoperte in eccesso, scarico, infermeria (recupero, terapisti, prove di
    sopravvivenza), Muro della memoria, promozioni, compravendita dei dadi, Punto di salvataggio;
  - le carte citate dal Logbook si mettono nella busta, nell'Armeria o fra le Situazioni con un clic.
- **Regolamento** e riassunto delle regole (inglese, dai PDF del modulo) consultabili in gioco.

## Comandi del tavolo
- Tasto destro trascinato: ruota la vista · rotella o pizzico: zoom · trascina sul vuoto: sposta la vista.
- Viste rapide: **1** Pianeta, **2** Nave, **3** Equipaggio, **4** Mazzi, **5** Scoperte, **0** tutto.
- Trascina un pezzo per spostarlo. Carta su carta = mazzo; carta su mazzo = in cima; qualunque pezzo su
  un sacchetto o una scatola = dentro. **Maiusc + trascina** su un mazzo prende la prima carta.
- Sul pezzo sotto il mouse: **F** gira, **Q/E** ruota (Maiusc: 15°), **R** tira il dado / mescola,
  **D** pesca, **T** pagina o stato successivo, **L** blocca, **Z** inquadra.
- Doppio clic: gira una carta, cambia pagina, pesca, tira, apre un sacchetto. Tasto destro: menu con
  tutte le azioni, compreso *Sfoglia* per cercare una carta per nome in un mazzo.

## Firebase
Stesso progetto degli altri giochi della ludoteca, radice `issvanguard/campagne/<codice>`. La campagna
è salvata come un unico testo JSON (così Firebase non altera i dizionari dei flag).
**Da fare una volta:** nella console di Firebase (Realtime Database → Regole) aggiungere al blocco
`"rules"` il contenuto di `firebase/regole_issvanguard.json`, accanto alle sezioni degli altri giochi.
Senza questo passaggio il gioco salva solo sul dispositivo (in alto compare "solo in locale").

## Struttura
```
tools/esporta_logbook.py   database dell'app -> data/logbook/c8.json, c12.json, c14.json
tools/estrai_tts.py        modulo TTS -> web/img (immagini webp) e data/componenti.json (catalogo)
scripts/core/              motore del Logbook, stato e salvataggi della campagna
scripts/tavolo/            tavolo 3D e pezzi
scripts/ui/                menu, Logbook, registro, regole, tema grafico
scripts/net/net.gd         Firebase (REST, accesso anonimo)
web/img/                   carte, plance e pagine delle regole: non entrano nel .pck, il gioco
                           le scarica a richiesta da GitHub Pages (nell'editor le legge dal disco)
assets/                    icone e immagini dell'app, miniature 3D, font (Orbitron, Exo 2, Share Tech Mono: SIL OFL)
tests/prova_logbook.gd     godot --headless --path . -s res://tests/prova_logbook.gd
tests/prova_tavolo.gd      godot --headless --path . -s res://tests/prova_tavolo.gd
tests/foto.gd              ISS_PROVA=1 xvfb-run godot --path . -s res://tests/foto.gd
tests/prova_dadi.gd        prove del motore dei dadi
tests/prova_missione.gd    partita simulata a caso dell'esplorazione (-- p.18-19 500)
tests/foto_missione.gd     screenshot della preparazione e dell'esplorazione
tests/prova_nave.gd        giro completo della Gestione della Nave (-- foto per gli screenshot)
tests/prova_atterraggio.gd atterraggio, risposte automatiche del Logbook e Minacce
tools/unisci_carte.py      trascrizioni delle carte (data/carte) -> data/carte_db.json
```

## Da fare / limiti attuali
- Le carte sono quelle **inglesi** del modulo TTS: le scansioni italiane si sostituiscono rigenerando
  `web/img/carte` (stessi nomi file) senza toccare il codice.
- Automatizzati: Logbook, esplorazione planetaria e Gestione della Nave. Vedi sotto cosa resta a mano.
- Dado Pericolo: "Perdi 1 [testa]" (tabelle F, G, H) resta da applicare a mano, il significato
  dell'icona è da verificare.
- Deadly Frontier e Lost Fleet: paragrafi completi, componenti solo del gioco base.
