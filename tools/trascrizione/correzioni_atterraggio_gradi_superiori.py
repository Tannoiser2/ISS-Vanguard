import json
D=json.load(open('/home/claude/iss-vanguard/data/carte_db.json'))['per_file']
C={}
def b(x,y,w,h,it,n=1,a="c"): return [x,y,w,h,a,n,True,it]
FREQ=lambda y=.43: b(.10,y,.33,.09,"PROVE FREQUENTI:",2)
BIOMI=lambda y=.47: b(.58,y,.30,.05,"BIOMI:")
ATT=b(.25,.163,.50,.06,"ATTERRAGGIO:")
def land(f, brief, items, by=.065):
    rel="carte/landing_cards/"+f
    d={"titolo":"salta","Briefing":"salta","OPTIONAL MISSION":"salta","+B0":b(.08,by,.84,.05,"Briefing (non leggere finché non viene indicato): %s"%brief)}
    for k,v in enumerate(items):
        v=list(v); v[1]=round(v[1]+.035,3); v[3]=round(v[3]+.01,3); d["+B%d"%(k+1)]=v
    C[rel]=d
land("retro_12102.webp",267,[ATT,b(.30,.235,.40,.075,"Detriti orbitali – consigliata [landerArmor].",2),FREQ(),BIOMI(),b(.10,.75,.30,.05,"METEO:"),b(.08,.80,.36,.05,"Minaccia errante."),b(.52,.71,.40,.09,"CURIOSITÀ BIOLOGICA:",2),b(.50,.79,.44,.06,"Consigliati [biology] e [xenology].")])
land("retro_9508.webp",354,[b(.25,.148,.50,.06,"ATTERRAGGIO:"),b(.20,.22,.60,.10,"Buone condizioni. Rare anomalie gravitazionali – consigliati [landerSensors].",3),FREQ(),BIOMI(),b(.15,.71,.70,.05,"PROVE IMPORTANTI:")])
land("retro_9509.webp",875,[ATT,b(.10,.235,.80,.075,"Turbolenze e brillamenti solari. Difficoltà moderata, ma consigliati [landerAgility] e [landerSensors].",2),FREQ(),BIOMI(),b(.12,.71,.30,.05,"PERICOLO:"),b(.03,.76,.48,.08,"Fenomeni meteorologici estremi – preparatevi a tiri di [dangerDieC] e [dangerDieE].",2),b(.58,.71,.30,.05,"MINACCE:"),b(.55,.76,.36,.05,"Minaccia errante.")])
land("retro_9510.webp",1000,[b(.20,.10,.60,.065,"TIPO DI MISSIONE:"),b(.06,.165,.88,.19,"Un'Operazione impegnativa per 1 Membro dell'Equipaggio. Non è necessario completarla per terminare la campagna. Il Lander e le Modifiche del Lander non hanno effetto in questa missione. Nella Procedura di Lancio della Missione, saltate i passi 2 e 3.",5),b(.30,.45,.40,.05,"DIFFICOLTÀ:"),b(.15,.50,.70,.075,"Missione pericolosa con Provviste limitate. Il vostro Membro dell'Equipaggio potrebbe morire.",2)])
land("retro_9511.webp",477,[ATT,b(.20,.235,.60,.075,"Atterraggio molto pericoloso – consigliati Attributi del Lander elevati.",2),b(.10,.43,.33,.09,"PROVE IMPORTANTI:",2),BIOMI(),b(.12,.69,.30,.05,"PERICOLI:"),b(.06,.75,.40,.11,"Preparatevi a tiri di [dangerDieB] e [dangerDieG]. Consigliata un'elevata mobilità.",3),b(.58,.71,.30,.05,"MINACCE:"),b(.50,.76,.46,.08,"Sono possibili Minacce aggressive. Siate preparati.",2)])
land("retro_9513.webp",575,[ATT,b(.10,.235,.80,.075,"Forze estreme e nubi di plasma surriscaldato – consigliati [landerArmor] e [landerAgility] molto elevati.",2),b(.10,.44,.38,.05,"DIFFICOLTÀ:"),b(.05,.49,.46,.12,"Una missione lunga e pericolosa, con molti effetti e regole che causano Ferite.",3),b(.58,.44,.30,.05,"BIOMI:"),FREQ(.70),b(.58,.73,.30,.05,"MINACCE:"),b(.54,.78,.42,.08,"Diverse Minacce aggressive o erranti.",2)],by=.055)
land("retro_9514.webp",579,[ATT,b(.20,.235,.60,.075,"Turbolenza estrema – consigliati [landerSensors] e [landerAgility] molto elevati.",2),FREQ(),BIOMI(),b(.12,.75,.30,.05,"PERICOLI:"),b(.08,.80,.36,.05,"Alta probabilità di Ferite."),b(.50,.71,.46,.09,"AMBIENTE VARIO:",2),b(.52,.80,.42,.05,"Consigliata un'elevata mobilità.")])
land("retro_9516.webp",572,[ATT,b(.10,.235,.80,.075,"Perimetro difensivo – consigliata [landerArmor] molto elevata oppure [landerAgility] e [landerSensors] elevati.",2),FREQ(),BIOMI(),b(.30,.71,.40,.05,"PERICOLO:"),b(.15,.76,.70,.08,"Alta probabilità di Minacce aggressive e ambiente ostile.",2)],by=.055)
land("retro_9517.webp",1050,[b(.25,.145,.50,.075,"ATTERRAGGIO:"),b(.10,.235,.80,.075,"Possibili attacchi della popolazione indigena – consigliati [landerArmor] e [landerAgility] elevati.",2),b(.10,.46,.33,.05,"PERICOLI:"),b(.05,.51,.46,.08,"Le condizioni sul pianeta peggiorano col passare del tempo.",2),b(.58,.46,.30,.05,"BIOMI:"),FREQ(.70),b(.58,.73,.30,.05,"MINACCE:"),b(.56,.78,.34,.05,"Minaccia mobile.")])
for f in ["34303","34304","34313","34314","34315","34318"]:
    rel="carte/rank_ups/%s.webp"%f; c=D[rel]; a=c["azioni"][0]
    C[rel]={"titolo":b(.05,.025,.62,.115,"GRADO SUPERIORE INCOMPLETO",2,"s"),"ANYTIME":b(.05,.165,.75,.10,"IN QUALSIASI MOMENTO DURANTE L'ESPLORAZIONE PLANETARIA:",2,"s"),
      a["nome"]["en"]:b(.24,.295,.72,.085,a["nome"]["it"],2,"d"),"Only in":[.38,.39,.56,.11,"c",2,False],"Flip":[.50,.515,.42,.065,"c",1,False]}
p='/home/claude/iss-vanguard/tools/traduci_carte/correzioni.json'
d=json.load(open(p)); d.update(C); json.dump(d,open(p,'w'),indent=1,ensure_ascii=False); print(len(C))
