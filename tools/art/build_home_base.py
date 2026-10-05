"""Build the original Sea Trader island and all catalogued building levels.
Blender +Y faces the harbor; glTF +Y becomes Godot -Z. No gameplay writes.
"""
import bpy, math, json, sys, argparse
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--preview', type=Path)
parser.add_argument('--terrain-only', action='store_true')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
current = None

def mat(name, rgb, metallic=0, emission=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*rgb, 1)
    bs.inputs['Roughness'].default_value = .68
    bs.inputs['Metallic'].default_value = metallic
    if emission:
        bs.inputs['Emission Color'].default_value = (*rgb, 1)
        bs.inputs['Emission Strength'].default_value = emission
    return m

stone = mat('Warm weathered limestone', (.64,.62,.48))
ivory = mat('Carved pale sandstone', (.85,.80,.63))
rock = mat('Green-grey coastal basalt', (.22,.30,.28))
sand = mat('Ivory beach and submerged sand', (.73,.64,.42))
grass = mat('Tropical meadow', (.19,.36,.22))
leaf = mat('Palm canopy', (.065,.26,.16))
wood = mat('Oiled warm teak', (.38,.22,.10))
roof = mat('Maritime blue slate roof', (.055,.16,.26))
brass = mat('Restrained brass trim', (.59,.40,.15), .55)
dark = mat('Doors and shadow recesses', (.025,.055,.065))
canvas = mat('Ivory sailcloth awnings', (.88,.83,.66))
crystal = mat('Guild cyan crystal', (.06,.63,.73), .2, .7)
waterfall = mat('Waterfall pale turquoise', (.25,.65,.66), 0, .12)
shallows = mat('Clear turquoise shoals', (.04,.43,.46), .15)
foam = mat('Restrained shore foam', (.53,.76,.73))

def collection(name):
    global current
    current = bpy.data.collections.new(name)
    scene.collection.children.link(current)
    return current

def own(o, name, material):
    o.name = name
    for c in list(o.users_collection): c.objects.unlink(o)
    current.objects.link(o)
    o.data.materials.append(material)
    return o

def box(name, at, size, material, bevel=.04):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    o = own(bpy.context.object, name, material)
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = o.modifiers.new('Handcrafted edge', 'BEVEL')
        mod.width, mod.segments = bevel, 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return o

def cylinder(name, at, r, depth, material, top=None, n=12):
    bpy.ops.mesh.primitive_cone_add(vertices=n, radius1=r, radius2=r if top is None else top, depth=depth, location=at)
    return own(bpy.context.object, name, material)

def mesh(name, verts, faces, material):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    o = bpy.data.objects.new(name, data)
    current.objects.link(o)
    data.materials.append(material)
    return o

def beam(name, a, b, radius=.06, material=wood):
    a,b = Vector(a),Vector(b)
    o = cylinder(name, (a+b)/2, radius, (b-a).length, material, n=8)
    o.rotation_euler = (b-a).to_track_quat('Z','Y').to_euler()
    return o

def pitched_roof(x, y, z, w, d):
    mesh('Sweeping maritime roof',[(x-w/2,y-d/2,z),(x+w/2,y-d/2,z),(x,y-d/2,z+.85),
         (x-w/2,y+d/2,z),(x+w/2,y+d/2,z),(x,y+d/2,z+.85)],
         [(0,1,2),(3,5,4),(0,2,5,3),(2,1,4,5),(0,3,4,1)],roof)
    beam('Roof ridge', (x,y-d/2-.1,z+.87),(x,y+d/2+.1,z+.87),.045,brass)

def hall(x,y,w,d,h):
    box('Limestone foundation',(x,y,.15),(w+.3,d+.3,.3),stone)
    box('Rendered walls',(x,y,.3+h/2),(w,d,h),ivory)
    for side in [-1,1]:
        box('Teak corner frame',(x+side*(w/2+.02),y+d/2+.025,.3+h/2),(.13,.10,h),wood)
    box('Teak crossbeam',(x,y+d/2+.045,.3+h*.68),(w,.10,.11),wood)
    box('Turquoise door',(x,y+d/2+.025,.85),(w*.2,.06,1.1),dark)
    for side in [-1,1]:
        for k in [-.24,.24]:
            box('Window brass border',(x+side*w/2,y+d*k,1.2),( .07,.65,.65),brass)
            box('Window recess',(x+side*(w/2+.045),y+d*k,1.2),(.025,.52,.5),dark)
    pitched_roof(x,y,.3+h,w+.45,d+.5)

def crane(x,y,z=0, size=1):
    beam('Crane mast',(x,y,z),(x,y,z+3*size),.12)
    beam('Crane boom',(x,y,z+2.7*size),(x-2*size,y,z+3.1*size),.10)
    beam('Crane brace',(x,y,z+1.5*size),(x-1.6*size,y,z+3.02*size),.045,brass)
    beam('Hoist rope',(x-1.8*size,y,z+3.05*size),(x-1.8*size,y,z+.6),.018,dark)

def make_building(kind, level):
    tier = (level-1)//6
    growth = 1 + .008*(level-1)
    height = 1.7 + tier*.25 + (level-1)%6*.045
    if kind in ['dock','fishing_wharf']:
        length = (6 if kind=='dock' else 4.6) + .055*level
        width = 2.0 + tier*.19
        box('Stone quay head',(0,-1,.35),(width+1.1,2,.7),stone)
        for i in range(12):
            box('Pier teak boards',(0,i*length/12,.26),(width,length/12-.025,.18),wood,.015)
        for y in [0,length*.45,length*.88]:
            for x in [-width/2,width/2]:
                cylinder('Mooring piling',(x,y,-.1),.12,1.5,wood,n=8)
                cylinder('Brass piling cap',(x,y,.68),.15,.1,brass,n=8)
        if kind=='fishing_wharf':
            hall(-.1,-1.1,2.3,1.6,1.35)
            for i in range(2+tier):
                cylinder('Fish baskets',(.6,-.4+i*.5,.65),.22,.48,wood,n=8)
        if tier>=1: crane(-width/2,-.4,.6,.65+tier*.06)
        if tier>=3: box('Cargo staging shelter',(0,length*.6,1.7),(width,1.4,.12),canvas)
    elif kind=='mage_guild':
        cylinder('Guild stepped podium',(0,0,.2),2.6,.4,stone,n=12)
        cylinder('Guild sanctuary',(0,0,1.3),2.05,2.2,ivory,n=12)
        cylinder('Guild roof',(0,0,2.8),2.4,.85,roof,top=.8,n=12)
        cylinder('Crystal crown',(0,0,3.8+tier*.13),.5,1.5+tier*.26,crystal,top=0,n=6)
        for i in range(4+tier):
            a=i*math.tau/(4+tier)
            cylinder('Guild colonnade',(2.25*math.cos(a),2.25*math.sin(a),1.6),.12,2.7,ivory,n=8)
        box('Guild entrance',(0,2.055,.9),(1.0,.12,1.5),dark)
    else:
        w,d = {'warehouse':(4.4,3.6),'workshop':(3.4,3.3),'market':(3.6,3.4),
               'shipyard':(4.8,4.5),'timber_yard':(3.4,3.2)}[kind]
        hall(0,0,w*growth,d,height)
        if kind=='warehouse':
            for i in range(2+tier): box('Cargo crate',(w/2+.4,-1.3+i*.55,.42),(.6,.48,.65),wood)
        if kind=='workshop':
            cylinder('Workshop chimney',(-w*.27,-d*.22,height+.8),.23,1.5,stone,n=8)
            box('Repair bench',(0,d*.68,.55),(2,.8,.8),wood)
        if kind=='market':
            for side in [-1,1]:
                box('Market counter',(side*2.65,.3,.55),(1.3,3,.9),wood)
                box('Sailcloth market awning',(side*2.65,.3,2.15),(1.6,3.3,.1),canvas)
                for y in [-1,1.6]: beam('Awning post',(side*3.3,y,0),(side*3.3,y,2.2))
        if kind=='shipyard':
            crane(-3.25,1.5,.2,1+tier*.08)
            for i in range(6):
                y=3+i*.6
                beam('Dry dock hull rib',(-1.2,y,.35),(0,y,.08),.10)
                beam('Dry dock hull rib',(0,y,.08),(1.2,y,.35),.10)
        if kind=='timber_yard':
            for i in range(3+tier):
                beam('Stacked timber',(-2.7,-1.2+i*.3,.5),(-2.7,1.5+i*.3,.5),.20)
        if tier>=1:
            hall(w*.5+.8,-d*.24,1.6,2.0,1.2+tier*.15)
        if tier>=3:
            for x in [-w*.36,w*.36]: cylinder('Ceremonial entry column',(x,d*.65,1.3),.13,2.6,ivory,n=8)
    # Each of the 30 levels has a distinct trim, plus architectural stages every six.
    cylinder('Level brass finial',(.2,-.4,height+1.03),.065,.2+level*.014,brass,n=8)
    for i in range(tier):
        box('Stone terrace step',(0,-2.2-i*.16,.1+i*.05),(4+i*.18,.28,.2),stone)

def merge_export(col, path):
    path.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    objs=[o for o in col.objects if o.type=='MESH']
    for o in objs: o.hide_set(False); o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]
    bpy.ops.object.join()
    o=bpy.context.object
    o.name=col.name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True)
    return o

def source_dir(path):
    path.mkdir(parents=True,exist_ok=True)
    (path/'.gdignore').write_text('',encoding='utf8')
    return path

catalog=json.loads((ROOT/'data/ports/building_catalog.json').read_text(encoding='utf-8-sig'))
manifest={'version':1,'reference_radius_m':30,'terrain':'res://assets/world/islands/home_island/home_island.glb','buildings':{},
          'placements':{'dock':[-9,17,0,.82],'warehouse':[-11,8,0,1.8],'workshop':[-16,0,0,2.8],
          'market':[0,3,0,1.8],'shipyard':[9,14,0,.82],'mage_guild':[0,-8,0,4.1],
          'fishing_wharf':[16,16,0,.82],'timber_yard':[14,0,0,2.4]},'tower_positions':[[-16,17],[20,16]]}
maximum=[]
for definition in catalog['buildings']:
    kind=definition['building_id']
    entries=[]
    for level in range(1,definition['max_level']+1):
        if args.terrain_only:
            rel=f'assets/world/buildings/{kind}/levels/level_{level:02d}.glb'
            entries.append({'level':level,'scene':'res://'+rel})
            if level==30:
                path=ROOT/f'assets/world/buildings/{kind}/source/{kind}_levels.blend'
                with bpy.data.libraries.load(str(path),link=False) as (src,dst):
                    dst.collections=[n for n in src.collections if n.startswith(kind+' — level 30')]
                col=dst.collections[0]
                maximum.append((kind,next(o for o in col.objects if o.type=='MESH')))
            continue
        col=collection(f'{kind} — level {level:02d}')
        make_building(kind,level)
        rel=f'assets/world/buildings/{kind}/levels/level_{level:02d}.glb'
        obj=merge_export(col,ROOT/rel)
        entries.append({'level':level,'scene':'res://'+rel})
        if level==30: maximum.append((kind,obj))
        obj.hide_render=True
        obj.hide_set(True)
    manifest['buildings'][kind]=entries
    if args.terrain_only: continue
    obj.hide_render=False
    obj.hide_set(False)
    source=source_dir(ROOT/f'assets/world/buildings/{kind}/source')
    # Sources contain the current and prior libraries; retain only this type in its file.
    for col in list(scene.collection.children):
        if not col.name.startswith(kind+' —'): scene.collection.children.unlink(col)
    bpy.ops.wm.save_as_mainfile(filepath=str(source/f'{kind}_levels.blend'))
    obj.hide_render=True
    obj.hide_set(True)
    for col in list(scene.collection.children): scene.collection.children.unlink(col)

col=collection('Island tower — universal crystal socket')
cylinder('Tower stepped footing',(0,0,.2),1.6,.4,stone,n=12)
cylinder('Tower shaft',(0,0,2.9),1.05,5.4,ivory,top=.78,n=12)
for z in [1.2,3.2,5.1]: cylinder('Tower brass ring',(0,0,z),1.07,.10,brass,n=12)
cylinder('Tower lookout platform',(0,0,5.55),1.45,.4,stone,n=12)
for i in range(8):
    a=i*math.tau/8
    box('Tower merlon',(1.2*math.cos(a),1.2*math.sin(a),6.0),(.4,.4,.6),ivory)
cylinder('Empty crystal socket',(0,0,5.9),.38,.3,brass,n=8)
tower=merge_export(col,ROOT/'assets/world/buildings/island_tower/island_tower.glb')
manifest['tower']='res://assets/world/buildings/island_tower/island_tower.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(source_dir(ROOT/'assets/world/buildings/island_tower/source')/'island_tower.blend'))
tower.hide_render=True
scene.collection.children.unlink(col)

terrain=collection('Home island — shore cliffs shallows vegetation')
N=96
def coast(a):
    gap=abs((a-math.pi/2+math.pi)%math.tau-math.pi)
    return 30*(1+.048*math.sin(a*5)+.030*math.sin(a*11)-.60*math.exp(-(gap/.62)**2))
def ring_layer(name,factors,heights,material):
    verts=[]
    for factor,z in zip(factors,heights):
        for i in range(N):
            a=i*math.tau/N
            r=coast(a)*factor
            verts.append((math.cos(a)*r,math.sin(a)*r,z))
    faces=[]
    for j in range(len(factors)-1):
        for i in range(N):
            k=(i+1)%N
            faces.append((j*N+i,j*N+k,(j+1)*N+k,(j+1)*N+i))
    mesh(name,verts,faces,material)
ring_layer('Submerged shelf',[1.11,1.025],[-.7,-.2],sand)
ring_layer('Turquoise shoal water',[1.15,1.005],[-.04,.01],shallows)
ring_layer('Fine shore wash',[1.008,.998],[.015,.02],foam)
ring_layer('Rock shore',[1.025,.96],[-.2,.48],rock)
ring_layer('Broad pale beach',[.96,.88],[.48,.70],sand)
ring_layer('Flat buildable meadow',[.88,0],[.70,.70],grass)
for i,(x,y,r,h) in enumerate([(-13,-15,7,12),(-4,-20,8,17),(9,-18,6,13),(18,-10,5,8),(-24,7,3.5,4),(24,7,3.2,3.5)]):
    verts=[]
    for j,(factor,z) in enumerate([(1,.5),(.97,h*.20),(.80,h*.38),(.86,h*.64),(.70,h*.82),(.50,h)]):
        for k in range(18):
            a=k*math.tau/18
            jitter=1+.16*math.sin(k*7+i*3+j)+.07*math.sin(k*3-j)
            verts.append((x+math.cos(a)*r*factor*jitter,y+math.sin(a)*r*factor*jitter,z+.7*math.sin(k*5+i)))
    faces=[]
    for j in range(5):
        for k in range(18):
            n=(k+1)%18
            faces.extend([(j*18+k,j*18+n,(j+1)*18+k),(j*18+n,(j+1)*18+n,(j+1)*18+k)])
    mesh('Weather-eroded cliff faces',verts,faces,rock)
    mesh('Uneven green cliff crown',verts[90:], [tuple(range(18))],grass)
    for k in range(3):
        a=k*2.1+i
        tx,ty=x+math.cos(a)*r*.24,y+math.sin(a)*r*.24
        beam('Cliff-top tree trunk',(tx,ty,h+.4),(tx,ty,h+2.0),.10)
        cylinder('Cliff-top pine crown',(tx,ty,h+2.1),.85,2.0,leaf,top=0,n=9)
    for k in range(3):
        a=k*2.1+i
        cylinder('Crag facet',(x+r*.6*math.cos(a),y+r*.6*math.sin(a),h*.48),r*.35,h*.75,rock,top=r*.15,n=6)
box('Narrow cascading waterfall',(-7,-13,6),(.4,.12,10),waterfall,.01)
for x,y in [(-21,-3),(-20,7),(-18,14),(20,4),(20,-2),(9,-9),(-10,-5),(-5,-3),(5,-2),(17,9)]:
    beam('Palm trunk',(x,y,.7),(x+.3,y,4.3),.14)
    for k in range(7):
        a=k*math.tau/7
        mesh('Sweeping palm frond',[(x+.3,y,4.3),(x+.3+2*math.cos(a),y+2*math.sin(a),4.0),
             (x+.3+1.6*math.cos(a+.25),y+1.6*math.sin(a+.25),3.65)],[(0,1,2)],leaf)
for x,y in [(-23,2),(-19,-7),(-15,-8),(19,-5),(17,-9),(-12,-17),(1,-20),(12,-17),(-18,9),(20,7)]:
    beam('Coastal tree trunk',(x,y,.7),(x,y,3.2),.14)
    for dx,dy,z,r in [(0,0,3.7,1.6),(.9,0,3.3,1.1),(-.6,.5,3.1,1.2)]:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=r,location=(x+dx,y+dy,z))
        own(bpy.context.object,'Broadleaf coastal canopy',leaf)
for i in range(12):
    a=math.tau*i/12
    if abs((a-math.pi/2+math.pi)%math.tau-math.pi)<.7: continue
    cylinder('Reef boulder',(32*math.cos(a),32*math.sin(a),-.45),.8,.65,rock,top=.5,n=7)
for kind,(x,y,angle,z) in manifest['placements'].items():
    if kind in ['dock','fishing_wharf']: continue
    base_h=z-.72
    box('Raised rock terrace',(x,y,.7+base_h/2),(8.0,7.4,base_h),rock,.16)
    box('Terrace coping',(x,y,z-.06),(8.15,7.55,.12),stone,.04)
    for step in range(max(1,int(base_h/.22))):
        box('Wide stone stair',(x,y+4.0+step*.26,.72+(base_h-step*.22)/2),(1.5,.29,max(.12,base_h-step*.22)),stone,.02)
island_obj=merge_export(terrain,ROOT/'assets/world/islands/home_island/home_island.glb')
bpy.ops.wm.save_as_mainfile(filepath=str(source_dir(ROOT/'assets/world/islands/home_island/source')/'home_island.blend'))

# Assemble a maximum-development art scene from independently editable models.
show=collection('Maximum development — eight level-30 buildings and two towers')
for kind,obj in maximum:
    copy=obj.copy(); copy.data=obj.data
    show.objects.link(copy)
    copy.hide_render=False; copy.hide_set(False)
    x,y,_,z=manifest['placements'][kind]
    copy.location=(x,y,z)
    style_path=ROOT/'assets/world/buildings/styles/humans/architecture.glb'
    if style_path.exists():
        before=set(scene.objects)
        bpy.ops.import_scene.gltf(filepath=str(style_path))
        for part in set(scene.objects)-before:
            if part.parent is None:
                part.location=(x,y,z+(2.8 if kind=='mage_guild' else .72 if kind in ['dock','fishing_wharf'] else 4.1))
                part.scale=(.89,.89,.89)
    # Canonical human crest for the Blender overview; Godot switches all six.
    flag_mat=bpy.data.materials.get('Canonical humans banner')
    if flag_mat is None:
        flag_mat=mat('Canonical humans banner',(.075,.16,.23))
        image=bpy.data.images.load(str(ROOT/'assets/ui/emblems/humans.png'))
        image.pack()
        nodes=flag_mat.node_tree.nodes
        tex=nodes.new('ShaderNodeTexImage'); tex.image=image
        mix=nodes.new('ShaderNodeMixRGB'); mix.inputs[1].default_value=(.075,.16,.23,1)
        links=flag_mat.node_tree.links
        links.new(tex.outputs['Alpha'],mix.inputs[0]); links.new(tex.outputs['Color'],mix.inputs[2])
        links.new(mix.outputs[0],nodes.get('Principled BSDF').inputs['Base Color'])
    cylinder('Editable heraldic flagpole',(x-2.8,y-2,z+2.25),.06,4.5,brass,n=8)
    banner=mesh('Fixed human crest banner',[(x-2.8,y-2,z+4.4),(x-1.3,y-2,z+4.4),
          (x-1.3,y-2,z+3.2),(x-2.8,y-2,z+3.2)],[(0,1,2,3)],flag_mat)
    uv=banner.data.uv_layers.new()
    for loop,coord in zip(banner.data.polygons[0].loop_indices,[(0,1),(1,1),(1,0),(0,0)]): uv.data[loop].uv=coord
for x,y in manifest['tower_positions']:
    copy=tower.copy(); copy.data=tower.data
    show.objects.link(copy)
    copy.hide_render=False; copy.hide_set(False)
    copy.location=(x,y,.8)
    cylinder('Installed showcase crystal',(x,y,7.45),.30,1.2,crystal,top=0,n=6)

studio=collection('Preview studio — excluded from game terrain')
sea=mat('Preview turquoise ocean',(.025,.28,.34),.2)
box('Ocean',(0,0,-.12),(2000,2000,.15),sea,0)
scene.render.engine='CYCLES'
scene.cycles.samples=40
scene.cycles.use_denoising=True
scene.render.resolution_x=1600
scene.render.resolution_y=1100
scene.render.resolution_percentage=100
scene.world.color=(.25,.35,.42)
for at,power,size in [((15,15,65),42000,45),((-30,-20,45),18000,35)]:
    bpy.ops.object.light_add(type='AREA',location=at)
    lamp=bpy.context.object; lamp.data.energy=power; lamp.data.shape='DISK'; lamp.data.size=size
    lamp.rotation_euler=(Vector((0,0,0))-lamp.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(61,82,61))
camera=bpy.context.object
camera.rotation_euler=(Vector((0,0,3))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO'; camera.data.ortho_scale=85
scene.camera=camera
scene.view_settings.view_transform='AgX'
source=source_dir(ROOT/'assets/world/ports/home_base/source')
bpy.ops.wm.save_as_mainfile(filepath=str(source/'home_base_maximum.blend'))
(ROOT/'data/world/home_base_visuals.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
if args.preview:
    args.preview.parent.mkdir(parents=True,exist_ok=True)
    scene.render.filepath=str(args.preview)
    bpy.ops.render.render(write_still=True)
print('SEA_TRADER_HOME_BASE_COMPLETE',sum(len(v) for v in manifest['buildings'].values()),'building levels')
