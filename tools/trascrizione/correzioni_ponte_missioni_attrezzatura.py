import json
C={}
B="carte/bridge_cards/"
C[B+"b05_9304.webp"]={"BRIDGE UPGRADE":[.21,.22,.70,.06,"s",1,True,"POTENZIAMENTO DEL PONTE (VIAGGIO)"],"titolo":[.10,.32,.55,.10,"s",2,False],"The":[.10,.43,.78,.26,"s",6,False]}
C[B+"b07_9306.webp"]={"BRIDGE UPGRADE":[.21,.22,.70,.06,"s",1,True,"POTENZIAMENTO DEL PONTE (VIAGGIO)"],"titolo":[.10,.32,.74,.05,"s",1,False],"Reduce":[.10,.39,.76,.12,"s",3,False],"Utilizing":[.10,.53,.78,.12,"s",3,False]}
SIT=lambda n,s:[.42,.895,.50,.07,"s",1,True,"%d SITUAZION%s"%(n,"E" if n==1 else "I")]
C[B+"o02_11801.webp"]={"CAMPAIGN":[.24,.22,.63,.06,"s",1,True],"titolo":[.10,.32,.62,.05,"s",1,False],"OBJECTIVE":[.10,.38,.76,.29,"s",7,False],"The":[.10,.69,.76,.12,"s",3,False],"+1 SITUATION":SIT(1,"")}
C[B+"o05_9204.webp"]={"CAMPAIGN":[.24,.22,.63,.06,"s",1,True],"titolo":[.10,.32,.45,.05,"s",1,False],"OBJECTIVE":[.10,.39,.80,.21,"s",5,False],"The":[.10,.61,.76,.12,"s",3,False],"2 SITUATIONS":SIT(2,"")}
C[B+"o06_9205.webp"]={"CAMPAIGN":[.24,.22,.63,.06,"s",1,True],"titolo":[.10,.32,.79,.05,"s",1,False],"OBJECTIVE":[.10,.40,.78,.28,"s",6,False],"Two":[.10,.70,.79,.11,"s",3,False],"3 SITUATIONS":SIT(3,"")}
C[B+"o07_9206.webp"]={"CAMPAIGN":[.24,.22,.63,.06,"s",1,True],"titolo":[.10,.32,.58,.05,"s",1,False],"OBJECTIVE":[.10,.39,.78,.25,"s",6,False],"Somewhere":[.10,.66,.76,.11,"s",3,False],"3 SITUATIONS":SIT(3,"")}
p='/home/claude/iss-vanguard/tools/traduci_carte/correzioni.json'
d=json.load(open(p)); d.update(C); json.dump(d,open(p,'w'),indent=1,ensure_ascii=False); print(len(C))
import json
D=json.load(open('/home/claude/iss-vanguard/data/carte_db.json'))['per_file']
C={}
M="carte/missions/"
def mis(f, tit, pref="", **kw):
    import re as _re
    it=_re.sub(r"^MISSIONE(?: OPZIONALE)?: ","",D[M+f]['titolo']['it'])
    cod=" (%s)"%D[M+f]['id']
    if cod not in it: it+=cod
    t=list(tit)+[(pref or ("MISSIONE: " if D[M+f]['titolo']['en'].startswith("MISSION") else ""))+it]
    d={"titolo":t,"OPTIONAL MISSION":"salta"}
    for k,v in kw.items(): d[k.replace('_',' ')]=v
    C[M+f]=d
OBJ1=[.03,.69,.93,.06,"s",1,False]; COMPL=[.03,.83,.90,.11,"s",2,False]
mis("m10_12305.webp",[.15,.015,.70,.07,"c",1,False],If=[.05,.53,.92,.11,"s",2,False],OBJECTIVE=[.03,.68,.93,.06,"s",1,False],COMPLETION=COMPL,Orbital=[.15,.11,.70,.08,"c",2,False])
mis("m123_18710.webp",[.15,.02,.70,.065,"c",1,False],"MISSIONE OPZIONALE: ",The=[.10,.11,.80,.09,"c",2,False],OBJECTIVE=[.03,.55,.93,.12,"s",2,False],HINT=[.05,.73,.85,.06,"s",1,False],COMPLETION=COMPL)
mis("m133_18714.webp",[.12,.025,.76,.06,"c",1,False],"MISSIONE: ",The=[.08,.12,.84,.09,"c",2,False],OBJECTIVE=[.03,.55,.93,.06,"s",1,False],COMPLETION=[.03,.69,.9,.11,"s",2,False],Go=[.42,.88,.30,.07,"s",1,False])
mis("m134_18715.webp",[.15,.015,.70,.135,"c",2,False],We=[.07,.16,.86,.05,"c",1,False],OBJECTIVE=[.03,.56,.93,.06,"s",1,False],COMPLETION=[.03,.69,.9,.11,"s",2,False],Go=[.53,.88,.25,.07,"s",1,False])
mis("m161_18719.webp",[.15,.02,.70,.12,"c",2,False],There_s=[.15,.16,.70,.10,"c",2,False],OBJECTIVE=[.03,.69,.80,.11,"s",2,False],COMPLETION=[.03,.88,.90,.06,"s",1,False])
mis("m162_18720.webp",[.15,.02,.70,.12,"c",2,False],"MISSIONE OPZIONALE: ",The=[.20,.16,.60,.10,"c",2,False],OBJECTIVE=[.03,.71,.6,.06,"s",1,False],COMPLETION=COMPL)
mis("m23_12408.webp",[.15,.025,.70,.06,"c",1,False],"MISSIONE OPZIONALE: ",Vanguard_s=[.08,.11,.84,.16,"c",3,False],OBJECTIVE=[.03,.62,.93,.11,"s",2,False],COMPLETION=COMPL)
mis("m50_12502.webp",[.20,.015,.60,.07,"c",1,False],"MISSIONE: ",We=[.04,.11,.92,.20,"c",4,False],OBJECTIVE=OBJ1,COMPLETION=COMPL)
mis("m51_12503.webp",[.25,.025,.50,.06,"c",1,False],"MISSIONE: ",The=[.04,.11,.92,.14,"c",3,False],OBJECTIVE=[.03,.69,.6,.06,"s",1,False],COMPLETION=COMPL)
mis("m73_12507.webp",[.18,.025,.66,.06,"c",1,False],"MISSIONE: ",We=[.10,.11,.80,.14,"c",3,False],OBJECTIVE=[.03,.55,.93,.12,"s",2,False],HINT=[.05,.73,.75,.06,"s",1,False],COMPLETION=COMPL)
it80=D[M+"m80_12509.webp"]['titolo']['it']
C[M+"m80_12509.webp"]={"titolo":[[.18,.025,.64,.06,"c",1,False,"MISSIONE: "+it80+" (M80)"],[.62,.58,.34,.06,"d",1,True,it80.split(" (")[0]]],"OPTIONAL MISSION":"salta",
  "While":[.04,.12,.92,.14,"c",3,False],"OBJECTIVE":[.03,.37,.93,.11,"s",2,False],"You may":[.25,.63,.71,.06,"d",1,False],"Gain 1":[.55,.80,.40,.17,"s",3,False]}
for k,v in C.items():
    for kk in list(v):
        if kk in ("There s","Vanguard s"): v[kk.replace(' s',"'s")]=v.pop(kk)
p='/home/claude/iss-vanguard/tools/traduci_carte/correzioni.json'
d=json.load(open(p)); d.update(C); json.dump(d,open(p,'w'),indent=1,ensure_ascii=False); print(len(C))
import json
C={}
E_="carte/unavailable_equipment/"
def eq(f, t, p, **kw):
    d={"titolo":t, "[spend" if p[0]=="S" else p[0]:p[1]}
    d.update(kw); C[E_+f]=d
C[E_+"e14_17005.webp"]={"titolo":[.25,.07,.5,.06,"c",1,False],"[spendDieRed]":[.03,.46,.94,.50,"c",10,False]}
C[E_+"e35_7917.webp"]={"titolo":[.22,.07,.56,.06,"c",1,False],"[spendDieBlue]":[.03,.60,.94,.36,"c",7,False]}
C[E_+"e53_18307.webp"]={"titolo":[.30,.07,.40,.06,"c",1,False],"During":[.10,.70,.80,.27,"c",5,False]}
C[E_+"e57_18311.webp"]={"titolo":[.20,.07,.60,.10,"c",2,False],"[spendDieGreen]":[.04,.41,.92,.43,"c",9,False],"If there are":"salta","Each Crewmember draws":"salta","Activation":[.65,.88,.20,.08,"s",2,False]}
C[E_+"e58_18312.webp"]={"titolo":[.22,.07,.56,.10,"c",2,False],"[spendDieRed]":[.04,.64,.92,.33,"c",6,False]}
C[E_+"e59_18313.webp"]={"titolo":[.18,.07,.64,.10,"c",2,False],"[spendDieBlue]":[.04,.43,.92,.40,"c",8,False],"If there are":"salta","Activation":[.75,.88,.20,.08,"s",2,False]}
C[E_+"e60_18314.webp"]={"titolo":[.18,.07,.64,.10,"c",2,False],"[spendDieBlue]":[.03,.41,.94,.43,"c",9,False],"If there are":"salta","Gain 1 Mineral":"salta","Activation":[.75,.88,.20,.08,"s",2,False]}
C[E_+"e73_18325.webp"]={"titolo":[.25,.07,.50,.10,"c",2,False],"Take":[.12,.81,.78,.16,"c",3,False]}
C[E_+"e75_18327.webp"]={"titolo":[.25,.07,.50,.10,"c",2,False],"Treat":[.08,.85,.84,.11,"c",2,False]}
C[E_+"e76_18328.webp"]={"titolo":[.25,.07,.50,.10,"c",2,False],"You may":[.03,.57,.94,.40,"c",8,False]}
C[E_+"e77_18329.webp"]={"titolo":[.25,.07,.50,.10,"c",2,False],"You may":[.05,.57,.90,.40,"c",8,False]}
p='/home/claude/iss-vanguard/tools/traduci_carte/correzioni.json'
d=json.load(open(p)); d.update(C); json.dump(d,open(p,'w'),indent=1,ensure_ascii=False); print(len(C))
