"""Editable racial silhouettes for every existing ship class; no gameplay changes."""
import bpy, json, math, sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
from video_reference_assets import ROOT,mat,mesh,box,cylinder,tube,ico,clear,save_asset
bpy.context.preferences.filepaths.save_version=0
catalog=json.loads((ROOT/'data/world/ship_visuals.json').read_text(encoding='utf-8'))['ships']
manifest={'version':1,'factions':{}}
for race in ['humans','nerids','surr','meridians','aery','crystari']:
    manifest['factions'][race]={}
    for identity,entry in catalog.items():
        clear(); bpy.ops.import_scene.gltf(filepath=str(ROOT/entry['scene'].removeprefix('res://')))
        L=float(entry['length']); q=L/6.15
        trim=mat('Faction brass trim',(.64,.45,.20)); wood=mat('Faction painted carved hull',(.18,.30,.32)); crystal=mat('Faction crystal facets',(.35,.70,.76))
        # Blender's longitudinal axis is Y; Z remains height after glTF roundtrip.
        if race=='humans':
            for s in [-1,1]:tube('Classic sheer rail',[(s*.9*q,-L*.35,.7*q),(s*1.0*q,0,.9*q),(s*.6*q,L*.43,1.05*q)],.035*q,trim)
        elif race=='nerids':
            for s in [-1,1]:
                mesh('Nerid swept shell fin',[(s*.75*q,-L*.3,.5*q),(s*1.5*q,-L*.15,1.0*q),(s*1.15*q,L*.15,.6*q),(s*.8*q,L*.25,.45*q)],[(0,1,2,3)],wood)
                tube('Nerid curved prow',[(s*.25*q,L*.40,.4*q),(s*.50*q,L*.49,1.1*q),(s*.15*q,L*.53,1.65*q)],.08*q,trim)
        elif race=='surr':
            for s in [-1,1]:
                for j in range(7):box('Surr armored hull rib',(s*.99*q,-L*.30+j*L*.10,.4*q),(.16*q,.22*q,.8*q),wood)
            cylinder('Surr forge funnel',(0,-L*.18,1.4*q),.3*q,1.5*q,wood,n=8)
            cylinder('Surr chimney lip',(0,-L*.18,2.17*q),.4*q,.15*q,trim,n=8)
        elif race=='meridians':
            box('Meridian stern pavilion',(0,-L*.30,1.15*q),(1.5*q,1.1*q,.8*q),wood)
            mesh('Meridian gilded pavilion roof',[(-.95*q,-L*.40,1.55*q),(.95*q,-L*.40,1.55*q),(0,-L*.40,2.05*q),(-.95*q,-L*.21,1.55*q),(.95*q,-L*.21,1.55*q),(0,-L*.21,2.05*q)],[(0,2,5,3),(2,1,4,5)],trim)
            for s in [-1,1]:tube('Meridian gilded bow scroll',[(s*.4*q,L*.4,.9*q),(s*.8*q,L*.47,1.3*q),(s*.5*q,L*.5,1.8*q)],.07*q,trim)
        elif race=='aery':
            for s in [-1,1]:
                ico('Aery slender outrigger',(s*1.5*q,0,.13*q),(.25*q,L*.32,.3*q),wood,2)
                for y in [-L*.19,L*.19]:tube('Aery outrigger spar',[(0,y,.8*q),(s*1.5*q,y,.35*q)],.055*q,trim)
                mesh('Aery wind wing',[(s*.65*q,-L*.1,2.0*q),(s*2.1*q,0,1.6*q),(s*.8*q,L*.20,2.5*q)],[(0,1,2)],crystal)
        else:
            for s in [-1,1]:
                for y,h in [(-L*.3,1.6),(L*.33,1.9)]:
                    cylinder('Crystari prism',(s*.65*q,y,h*.45*q),.24*q,h*q,crystal,.02*q,n=5)
            mesh('Crystari crystalline prow',[(-.5*q,L*.35,.5*q),(.5*q,L*.35,.5*q),(0,L*.52,1.9*q),(0,L*.48,.15*q)],[(0,1,2),(0,2,3),(1,3,2),(0,3,1)],crystal)
        folder=ROOT/f'assets/world/ships/factions/{race}'
        save_asset(folder,identity)
        manifest['factions'][race][identity]={'id':race+'_'+identity,'scene':f'res://assets/world/ships/factions/{race}/{identity}.glb','reference_size_m':L,'identities':[identity]}
(ROOT/'data/world/faction_ship_visuals.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print('FACTION_FLEET_READY',sum(len(v) for v in manifest['factions'].values()))
