import json
C={}
BOOST={"BOOST:":[.035,.03,.19,.07,"c",2,True],"PRODUCTION PROJECT":[.24,.03,.52,.07,"s",1,True],"DO NOT REVEAL":[.19,.58,.54,.14,"c",3,False],"STARTING STAGE":[.28,.82,.44,.05,"c",1,False]}
def pj(f, extra, tech=False, any_icon=False):
    d=dict(BOOST); d.update(extra)
    if tech:
        d["REQUIRED TECH LEVEL"]=[.26,.79,.48,.045,"c",1,False]; d["STARTING STAGE"]=[.28,.835,.44,.045,"c",1,False]
    if any_icon: d["ANY ICON"]=[.04,.12,.18,.08,"c",2,True]
    C[f]=d
pj("carte/c01/c01_15600.webp",{"titolo":[.25,.13,.45,.055,"s",1,False],"ISS":[.25,.18,.67,.16,"s",5,False],"GRANTS:":[.25,.35,.2,.045,"s",1,False],"Lander":[.25,.40,.67,.075,"s",2,False]},any_icon=True)
pj("carte/c02/c02_15601.webp",{"titolo":[.25,.13,.67,.09,"s",2,False],"Our":[.25,.22,.7,.095,"s",3,False],"GRANTS:":[.25,.33,.2,.045,"s",1,False],"Bridge":[.25,.38,.67,.075,"s",2,False]})
C["carte/facility_upgrades/f05_15904.webp"]={"PRODUCTION UPGRADE":[.05,.03,.55,.06,"s",1,True],"titolo":[.05,.12,.6,.055,"s",1,False],"These":[.05,.17,.8,.12,"s",3,False],"Once":[.05,.30,.88,.30,"s",8,False]}
P="carte/production_projects/"
pj(P+"c04_15603.webp",{"titolo":[.25,.13,.67,.09,"s",2,False],"Too":[.25,.22,.7,.16,"s",5,False],"GRANTS:":[.25,.39,.2,.045,"s",1,False],"Production Project":[.25,.44,.67,.045,"s",1,False]})
pj(P+"c07_15606.webp",{"titolo":[.25,.13,.5,.055,"s",1,False],"Now":[.25,.18,.62,.095,"s",3,False],"GRANTS:":[.25,.29,.2,.045,"s",1,False],"Lander":[.25,.33,.4,.045,"s",1,False]})
pj(P+"c09_15608.webp",{"titolo":[.25,.12,.5,.055,"s",1,False],"Replicating":[.25,.17,.69,.10,"s",3,False],"GRANTS:":[.25,.28,.2,.045,"s",1,False],"Lander":[.25,.33,.4,.045,"s",1,False]})
pj(P+"c12_15611.webp",{"titolo":[.25,.13,.42,.05,"s",1,False],"After":[.25,.17,.67,.17,"s",5,False],"GRANTS:":[.25,.35,.2,.045,"s",1,False],"Equipment":[.25,.39,.3,.05,"s",1,False]},tech=True)
pj(P+"c13_15612.webp",{"titolo":[.25,.13,.67,.055,"s",1,False],"Our":[.25,.18,.66,.16,"s",5,False],"GRANTS:":[.25,.35,.2,.045,"s",1,False],"Equipment":[.25,.40,.3,.045,"s",1,False]},tech=True)
pj(P+"c14_15613.webp",{"titolo":[.25,.13,.65,.055,"s",1,False],"Thanks":[.25,.18,.70,.13,"s",4,False],"GRANTS:":[.25,.32,.2,.045,"s",1,False],"Equipment":[.25,.36,.3,.045,"s",1,False]})
pj(P+"c22_15621.webp",{"titolo":[.25,.13,.67,.09,"s",2,False],"We":[.25,.22,.68,.165,"s",5,False],"GRANTS:":[.25,.39,.2,.045,"s",1,False],"Lander":[.25,.44,.67,.075,"s",2,False]})
pj(P+"c25_15624.webp",{"titolo":[.25,.13,.42,.055,"s",1,False],"We":[.25,.18,.65,.16,"s",5,False],"GRANTS:":[.25,.35,.2,.045,"s",1,False]},tech=True)
C["carte/research_projects/r24_35700.webp"]={"RESEARCH PROJECT":[.05,.03,.48,.06,"s",1,True],"MATERIALS":[.55,.03,.28,.06,"c",1,True],"COST":[.05,.10,.86,.075,"s",2,True],"titolo":[.05,.25,.9,.05,"s",1,False],"Some":[.05,.30,.9,.16,"s",4,False],"GRANTS:":[.05,.47,.2,.045,"s",1,False],"Lander":[.05,.52,.35,.045,"s",1,False],"DO NOT REVEAL":[.19,.69,.54,.14,"c",3,False]}
p='/home/claude/iss-vanguard/tools/traduci_carte/correzioni.json'
d=json.load(open(p)); d.update(C); json.dump(d,open(p,'w'),indent=1,ensure_ascii=False); print(len(C))
