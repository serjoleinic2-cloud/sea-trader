"""Independent Blender kits for the six permanent Sea Trader peoples."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
catalog=json.loads((ROOT/'data/world/faction_catalog.json').read_text(encoding='utf-8-sig'))
def material(name,rgb):
    m=bpy.data.materials.new(name); m.diffuse_color=(*rgb,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*rgb,1); p.inputs['Roughness'].default_value=.6
    return m
def rgb(s): return tuple(int(s[i:i+2],16)/255 for i in [1,3,5])
def cone(name,at,r,h,m,top=0,n=8):
    bpy.ops.mesh.primitive_cone_add(vertices=n,radius1=r,radius2=top,depth=h,location=at)
    o=bpy.context.object; o.name=name; o.data.materials.append(m); return o
def beam(a,b,r,m):
    a,b=Vector(a),Vector(b); o=cone('Architectural rib',(a+b)/2,r,(b-a).length,m,r)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
def face(name,v,m):
    d=bpy.data.meshes.new(name); d.from_pydata(v,[],[tuple(range(len(v)))]); d.materials.append(m)
    o=bpy.data.objects.new(name,d); bpy.context.collection.objects.link(o)
profiles={}
for f in catalog['factions']:
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    kind=f['id']; palette=f['palette']; base=material(kind+' architectural body',rgb(palette[0])); accent=material(kind+' signature accent',rgb(palette[1])); trim=material(kind+' metallic trim',rgb(palette[2])); pale=material(kind+' pale stone',(.75,.76,.66))
    if kind=='nerids':
        for side in [-1,1]:
            face('Swept tide fin',[(side*.35,0,0),(side*1.45,0,.7),(side*.85,0,1.3),(side*.45,0,.65)],accent)
            beam((side*.35,0,0),(side*.85,0,1.3),.055,trim)
        cone('Pearl sanctuary crown',(0,0,.45),.2,.8,pale,0,10)
    elif kind=='surr':
        for x,h in [(-.65,.75),(0,1.45),(.65,.75)]:
            cone('Basalt forge pinnacle',(x,0,h/2),.22,h,base,.12,6)
            cone('Copper heat vent',(x,0,h+.08),.25,.16,trim,.25,6)
        face('Angular ember gable',[(-1,0,0),(0,0,.9),(1,0,0)],accent)
    elif kind=='meridians':
        cone('Trading-house cupola',(0,0,.3),.65,.6,pale,.65,12)
        cone('Brass cupola roof',(0,0,.9),.8,.6,trim,.15,12)
        beam((0,0,1.1),(0,0,1.9),.045,trim)
        for x in [-.9,.9]: beam((x,0,0),(x,0,.8),.06,trim)
    elif kind=='aery':
        for side in [-1,1]:
            face('Sky-clan sweeping wing',[(0,0,.25),(side*1.55,0,1.35),(side*1.25,0,.45),(side*.45,0,.1)],pale)
            beam((0,0,.25),(side*1.55,0,1.35),.035,trim)
        cone('Slender sky spire',(0,0,1.1),.1,2.2,accent,0,8)
    elif kind=='crystari':
        for x,h in [(-.65,.8),(0,1.6),(.65,1.0)]:
            cone('Faceted crystal roof crown',(x,0,h/2),.28,h,accent,0,5)
            cone('Deep-stone stepped socket',(x,0,.1),.37,.2,base,.37,6)
    else:
        cone('Harbormaster lookout',(0,0,.45),.5,.9,pale,.5,4)
        cone('Slate lookout cap',(0,0,1.1),.7,.4,base,0,4)
        beam((0,0,1.2),(0,0,1.8),.035,trim)
        beam((-.5,0,1.65),(.5,0,1.65),.035,trim)
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active=next(o for o in bpy.context.scene.objects if o.type=='MESH')
    bpy.ops.object.join()
    obj=bpy.context.object; obj.name=kind+' roof silhouette'
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    folder=ROOT/f'assets/world/buildings/styles/{kind}'
    (folder/'source').mkdir(parents=True,exist_ok=True); (folder/'source/.gdignore').write_text('')
    bpy.ops.export_scene.gltf(filepath=str(folder/'architecture.glb'),export_format='GLB',use_selection=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/'source/architecture.blend'),compress=True)
    profiles[kind]={'scene':f'res://assets/world/buildings/styles/{kind}/architecture.glb','palette':palette}
(ROOT/'data/world/faction_architecture.json').write_text(json.dumps({'version':1,'profiles':profiles},ensure_ascii=False,indent=2)+'\n',encoding='utf8')
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
cone('Brass flagpole',(0,0,2.25),.065,4.5,trim,.045,8)
cone('Stone flagpole base',(0,0,.12),.20,.24,pale,.20,8)
cone('Brass pole finial',(0,0,4.60),.10,.20,trim,0,8)
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active=bpy.context.object
bpy.ops.object.join()
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
folder=ROOT/'assets/world/props/heraldry'
(folder/'source').mkdir(parents=True,exist_ok=True); (folder/'source/.gdignore').write_text('')
bpy.ops.export_scene.gltf(filepath=str(folder/'flagpole.glb'),export_format='GLB',use_selection=True)
bpy.ops.wm.save_as_mainfile(filepath=str(folder/'source/flagpole.blend'),compress=True)
print('FACTION_ARCHITECTURE_READY',len(profiles))
