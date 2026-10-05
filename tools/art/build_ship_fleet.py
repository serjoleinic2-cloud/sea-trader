"""Blender ship catalog: separate hulls, sources and transparent UI portraits."""
import bpy, math, json, sys, argparse
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
bpy.context.preferences.filepaths.save_version=0
parser=argparse.ArgumentParser(); parser.add_argument('--icons',action='store_true')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
def material(name,rgb,metal=0,emission=0):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color=(*rgb,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*rgb,1)
    p.inputs['Roughness'].default_value=.6; p.inputs['Metallic'].default_value=metal
    if emission:
        p.inputs['Emission Color'].default_value=(*rgb,1)
        p.inputs['Emission Strength'].default_value=emission
    return m
def box(name,at,size,m):
    bpy.ops.mesh.primitive_cube_add(size=1,location=at)
    o=bpy.context.object; o.name=name; o.scale=size; o.data.materials.append(m)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    mod=o.modifiers.new('Crafted edges','BEVEL'); mod.width=.035; mod.segments=1
    bpy.ops.object.modifier_apply(modifier=mod.name); return o
def mesh(name,v,f,m):
    d=bpy.data.meshes.new(name); d.from_pydata(v,[],f); d.materials.append(m)
    o=bpy.data.objects.new(name,d); bpy.context.collection.objects.link(o); return o
def cylinder(name,at,r,h,m,top=None):
    bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=r,radius2=r if top is None else top,depth=h,location=at)
    o=bpy.context.object; o.name=name; o.data.materials.append(m); return o
def beam(name,a,b,r,m):
    a,b=Vector(a),Vector(b); o=cylinder(name,(a+b)/2,r,(b-a).length,m)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler(); return o
def sail(y,z,w,h,m,triangle=False):
    verts=[]; faces=[]; n=10
    for j in range(n+1):
        t=j/n
        for i in range(n+1):
            u=i/n; span=w*(1-t if triangle else .80+.2*math.sin(t*math.pi))
            verts.append((.25*math.sin(u*math.pi)*math.sin(t*math.pi),y+u*span,z+t*h))
    for j in range(n):
        for i in range(n):
            k=j*(n+1)+i; faces.append((k,k+1,k+n+2,k+n+1))
    mesh('Wind-shaped canvas',verts,faces,m)
    beam('Sail boom',(0,y,z),(0,y+w,z),.045,wood)

regular=json.loads((ROOT/'data/ships/ship_catalog.json').read_text(encoding='utf-8-sig'))
premium=json.loads((ROOT/'data/ships/premium_ship_pool.json').read_text(encoding='utf-8-sig'))
models={}
for definition in regular['ships']+premium['ships']:
    sid=definition['id']; tier=definition['tier']
    if sid=='ship_sloop':
        if (ROOT/'assets/ui/ships/ship_sloop.png').exists():
            definition['ui_icon']='res://assets/ui/ships/ship_sloop.png'
        models[sid]={'scene':'res://assets/world/ships/starter_sloop.glb','length':6.15,'display_length':3.48,'flag_at':[0,1.3,2.6],'lamps':[[.45,1.38,2.64],[-.58,.94,-1.9]]}
        continue
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    length={2:8.5,3:12,4:16,5:21}[tier]
    if sid=='ship_combat_cutter': length=8.5
    industrial=sid in ['ship_freighter','ship_tanker','premium_steam_freighter','premium_trade_giant']
    if sid=='premium_golden_clipper': length=14
    if sid=='premium_imperial_yacht': length=13.5
    if sid=='premium_ghost_frigate': length=15
    width=length*(.25 if industrial else .24)
    navy=material('Deep ocean painted hull',(.025,.09,.14))
    wood=material('Oiled warm teak',(.38,.22,.10))
    deck=material('Deck planking',(.57,.39,.19))
    ivory=material('Ivory woven sailcloth',(.88,.82,.66))
    brass=material('Maritime brass',(.59,.40,.15),.6)
    teal=material('Turquoise trim',(.045,.28,.32))
    dark=material('Iron and recesses',(.035,.055,.06))
    lumen=material('Turquoise trim — crystal inlay',(.025,.58,.68),.35,1.7)
    stone=material('Ivory wheelhouse',(.76,.75,.65))
    if sid=='premium_ghost_frigate': ivory=material('Pearl-grey ghost sails',(.48,.63,.66))
    if sid=='ship_combat_cutter':
        navy=material('Deep ocean painted war hull',(.018,.055,.095))
        teal=material('Turquoise trim — war cutter enamel',(.52,.105,.045))
        ivory=material('Turquoise trim — war cutter sailcloth',(.08,.46,.59))
    if sid=='premium_golden_clipper': teal=brass
    if sid=='premium_royal_schooner': teal=material('Royal blue trim',(.07,.15,.26))
    vertices=[]; sections=15
    for i in range(sections):
        t=i/(sections-1); y=(t-.5)*length
        half=width*.5*max(.07,math.sin(math.pi*(t*.94+.03))**.60)
        for x,z in [(-half,.5),(-half*.92,-.15),(-half*.55,-.75),(0,-1.0),(half*.55,-.75),(half*.92,-.15),(half,.5)]:
            vertices.append((x,y,z))
    faces=[]
    for i in range(sections-1):
        for j in range(6): faces.append((i*7+j,i*7+j+1,(i+1)*7+j+1,(i+1)*7+j))
    faces.extend([tuple(range(6,-1,-1)),tuple((sections-1)*7+j for j in range(7))])
    hull=mesh('Curved ship hull',vertices,faces,navy)
    for p in hull.data.polygons: p.use_smooth=True
    for i in range(sections-1):
        a,b=vertices[i*7],vertices[(i+1)*7]
        left0,right0=a[0],vertices[i*7+6][0]
        left1,right1=b[0],vertices[(i+1)*7+6][0]
        mesh('Fitted timber deck',[(left0,a[1],.51),(right0,a[1],.51),(right1,b[1],.51),(left1,b[1],.51)],[(0,1,2,3)],deck)
        for side in [-1,1]:
            beam('Gunwale',(side*right0,a[1],.65),(side*right1,b[1],.65),.06,brass)
            beam('Hull paint strake',(side*right0*.94,a[1],.12),(side*right1*.94,b[1],.12),.035,teal)
        cabin_positions=[0] if sid=='ship_combat_cutter' else [-width*.34,width*.34]
        for x in cabin_positions:
            box('Stern cabin',(x,-length*.33,.94),(width*.28,length*.15,.85),stone if industrial else wood)
        box('Cabin roof',(x,-length*.33,1.40),(width*.31,length*.17,.12),teal)
        box('Cabin window',(x,-length*.24,1.03),(width*.16,.05,.35),dark)
    if industrial:
        box('Bridge',(0,-length*.30,2.0),(width*.75,2.0,1.8),stone)
        box('Bridge roof',(0,-length*.30,2.98),(width*.85,2.2,.15),teal)
        for x in [-.8,0,.8]: box('Bridge glazing',(x,-length*.23,2.3),(.5,.06,.5),dark)
        cylinder('Steam funnel',(0,-length*.10,2.25),.35,2.6,dark)
        cylinder('Funnel brass band',(0,-length*.10,3.15),.37,.18,brass)
        if tier==5:
            for y in [-1.2,1.2,3.6]:
                cylinder('Cargo tank',(0,y,1.3),width*.33,1.5,teal,top=width*.3)
                beam('Tank pipeline',(-width*.38,y,1),(width*.38,y,1),.10,brass)
            beam('Longitudinal manifold',(width*.38,-2.3,1),(width*.38,4.2,1),.08,brass)
        else:
            for x in [-width*.22,width*.22]:
                for y in [0,1.8,3.6]: box('Cargo hatch',(x,y,.85),(width*.34,1.45,.65),wood)
        for y in [-.4,3.5]:
            beam('Deck crane',(width*.33,y,.55),(width*.33,y,3.8),.10,brass)
            beam('Crane boom',(width*.33,y,3.5),(-width*.20,y,4.3),.07,brass)
            beam('Hoist',(-width*.20,y,4.3),(-width*.20,y,1.3),.02,dark)
    else:
        masts=2 if tier>=3 else 1
        if sid=='premium_ghost_frigate': masts=3
        for index in range(masts):
            y=-length*.22+index*length*.30 if masts>1 else -.4
            h=length*(.55 if index==0 else .49)
            beam('Mast',(0,y,.5),(0,y,h),.09,wood)
            sail(y,.95,length*.28,h*.7,ivory)
            if sid=='ship_combat_cutter':
                for rib in range(1,4):
                    z=.95+h*.7*rib/4
                    sail_span=length*.28*(.80+.2*math.sin(math.pi*rib/4))
                    beam('Luminous segmented sail spar',(0,y,z),(0,y+sail_span,z),.026,lumen)
            for side in [-1,1]: beam('Standing rigging',(side*width*.4,y+.8,.6),(0,y,h*.9),.022,dark)
        sail(length*.13,.8,length*.30,length*.37,ivory,True)
        beam('Bowsprit',(0,length*.40,.7),(0,length*.62,1.0),.07,wood)
        for x in [-width*.27,width*.27]:
            for y in [-.7,.7]: box('Trading cargo',(x,y,.85),(.65,.7,.6),wood)
        if sid=='premium_salvage_schooner':
            beam('Salvage gantry',(-width*.3,-2,.5),(-width*.3,-2,3),.09,brass)
            beam('Salvage jib',(-width*.3,-2,3),(width*.3,-2,3.5),.06,brass)
        if sid=='premium_imperial_yacht':
            box('Passenger promenade',(0,-1,1.65),(width*.65,3,.12),ivory)
    if sid=='premium_ghost_frigate':
        for side in [-1,1]:
            for y in [-3,-1,1,3]:
                beam('Frigate cannon',(side*width*.35,y,.7),(side*width*.55,y,.7),.12,dark)
    # Fine deck seams and continuous rails give each hull a crafted scale in the
    # sailing camera, rather than leaving broad featureless surfaces.
    plank_count=max(14,int(length*1.25))
    for index in range(1,plank_count):
        t=index/plank_count
        y=(t-.5)*length
        half=width*.5*max(.07,math.sin(math.pi*(t*.94+.03))**.60)*.91
        beam('Deck plank end-grain seam',(-half,y,.535),(half,y,.535),.009,wood)
    for side in [-1,1]:
        rail_samples=18
        for index in range(rail_samples):
            t0=index/rail_samples; t1=(index+1)/rail_samples
            y0=(t0-.5)*length; y1=(t1-.5)*length
            half0=width*.5*max(.07,math.sin(math.pi*(t0*.94+.03))**.60)*.91
            half1=width*.5*max(.07,math.sin(math.pi*(t1*.94+.03))**.60)*.91
            beam('Gunwale cap rail',(side*half0,y0,1.03),(side*half1,y1,1.03),.036,brass)
            beam('Gunwale baluster',(side*half0,y0,.58),(side*half0,y0,1.02),.026,wood)
        # Brass-rimmed dark portholes repeat along the topsides.
        for index in range(1,9):
            t=.08+index*.105
            y=(t-.5)*length
            half=width*.5*max(.07,math.sin(math.pi*(t*.94+.03))**.60)
            x=side*half*.92
            for mat,radius,depth,offset in [(brass,.105,.07,0),(dark,.070,.075,side*.012)]:
                bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=radius,depth=depth,location=(x+offset,y,-.12),rotation=(0,math.pi/2,0))
                porthole=bpy.context.object; porthole.name='Brass-rimmed porthole' if mat==brass else 'Dark porthole glass'; porthole.data.materials.append(mat)
        # Subtle luminous conduits make the vessels feel designed for the
        # game's futuristic hero cultures, while following each faction palette.
        for index in range(10):
            t0=.08+index*.084; t1=t0+.084
            y0=(t0-.5)*length; y1=(t1-.5)*length
            half0=width*.5*max(.07,math.sin(math.pi*(t0*.94+.03))**.60)
            half1=width*.5*max(.07,math.sin(math.pi*(t1*.94+.03))**.60)
            beam('Futuristic crystal energy inlay',(side*half0*1.005,y0,.50),(side*half1*1.005,y1,.50),.038,lumen)
    # Every paid/player hull carries working deck fittings and anchor hardware.
    box('Helm pedestal',(0,-length*.37,.78),(.30,.34,.44),wood)
    cylinder('Brass binnacle',(0,-length*.37,1.12),.12,.28,brass)
    bpy.ops.mesh.primitive_torus_add(major_radius=.30,minor_radius=.025,major_segments=16,minor_segments=6,location=(0,-length*.37,1.38))
    helm=bpy.context.object; helm.name='Ship steering wheel'; helm.data.materials.append(wood)
    for spoke in range(8):
        angle=math.tau*spoke/8
        beam('Helm spoke',(0,-length*.37,1.38),(math.cos(angle)*.30,-length*.37+math.sin(angle)*.30,1.38),.018,wood)
    for side in [-1,1]:
        beam('Anchor stock',(side*width*.48,length*.43,.08),(side*width*.64,length*.43,.08),.055,dark)
        beam('Anchor shank',(side*width*.57,length*.43,.08),(side*width*.57,length*.34,-.48),.045,dark)
        beam('Anchor fluke',(side*width*.57-width*.10,length*.34,-.45),(side*width*.57+width*.10,length*.34,-.45),.045,dark)
    # Faceted stern core: a bright crystal/nav-drive fitting integrated into
    # every vessel, picked out by the faction-colored inlays.
    box('Crystal drive housing',(0,-length*.44,.84),(width*.29,.44,.32),dark)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.18,location=(0,-length*.44,1.04))
    drive=bpy.context.object; drive.name='Futuristic crystal drive'; drive.scale=(.72,.72,1.55); drive.data.materials.append(lumen)
    if sid in ['ship_combat_cutter','premium_ghost_frigate']:
        gun_positions=[-length*.27,-length*.09,length*.10,length*.28] if sid=='premium_ghost_frigate' else [-length*.25,0,length*.25]
        for side in [-1,1]:
            for y in gun_positions:
                half=width*.5*max(.07,math.sin(math.pi*((y/length+.5)*.94+.03))**.60)
                x=side*half*.35
                carriage_z=.88 if sid=='ship_combat_cutter' else .77
                barrel_z=1.30 if sid=='ship_combat_cutter' else .92
                box('Cannon carriage',(x,y,carriage_z),(width*.20,.52,.20),wood)
                if sid=='ship_combat_cutter':
                    for bracket_y in [y-.14,y+.14]:
                        beam('Raised cannon pivot',(x,bracket_y,.96),(x,bracket_y,barrel_z),.045,brass)
                beam('Iron cannon barrel',(x,y,barrel_z),(side*(half*1.38),y,barrel_z),.14 if sid=='ship_combat_cutter' else .12,dark)
                for wheel_offset in [-.16,.16]:
                    bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.105,depth=.055,location=(x,y+wheel_offset,.66),rotation=(0,math.pi/2,0))
                    wheel=bpy.context.object; wheel.name='Cannon carriage wheel'; wheel.data.materials.append(brass)
                bpy.ops.mesh.primitive_torus_add(major_radius=.10 if sid=='ship_combat_cutter' else .082,minor_radius=.024,major_segments=12,minor_segments=5,location=(side*half*1.38,y,barrel_z),rotation=(0,math.pi/2,0))
                muzzle=bpy.context.object; muzzle.name='Cannon muzzle ring'; muzzle.data.materials.append(lumen if sid=='ship_combat_cutter' else brass)
    folder=ROOT/f'assets/world/ships/{sid}'
    (folder/'source').mkdir(parents=True,exist_ok=True); (folder/'source/.gdignore').write_text('')
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/'source'/f'{sid}.blend'),compress=True)
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active=hull
    bpy.ops.object.join(); obj=bpy.context.object; obj.name=sid
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
    folder=ROOT/f'assets/world/ships/{sid}'
    (folder/'source').mkdir(parents=True,exist_ok=True); (folder/'source/.gdignore').write_text('')
    bpy.ops.export_scene.gltf(filepath=str(folder/f'{sid}.glb'),export_format='GLB',use_selection=True)
    models[sid]={'scene':f'res://assets/world/ships/{sid}/{sid}.glb','length':length,'display_length':3.48*(length/6.15)**.65,
                 'flag_at':[0,1.45,-(-length*.38)],'lamps':[[width*.33,1.25,length*.35],[-width*.33,.90,-length*.32]]}
    if args.icons:
        scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=16; scene.cycles.use_denoising=True
        scene.render.resolution_x=480; scene.render.resolution_y=360; scene.render.resolution_percentage=100; scene.render.film_transparent=True
        scene.world.color=(.25,.32,.38)
        bpy.ops.object.light_add(type='AREA',location=(length,-length,length))
        light=bpy.context.object; light.data.energy=length*length*30; light.data.size=length
        light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
        bpy.ops.object.camera_add(location=(length,-length*1.3,length*.8))
        camera=bpy.context.object; camera.rotation_euler=(Vector((0,0,length*.2))-camera.location).to_track_quat('-Z','Y').to_euler()
        camera.data.type='ORTHO'; camera.data.ortho_scale=length*1.55; scene.camera=camera
        icon=ROOT/f'assets/ui/ships/{sid}.png'; icon.parent.mkdir(parents=True,exist_ok=True)
        scene.render.filepath=str(icon); bpy.ops.render.render(write_still=True)
        definition['ui_icon']=f'res://assets/ui/ships/{sid}.png'
for file,data in [('ship_catalog.json',regular),('premium_ship_pool.json',premium)]:
    (ROOT/'data/ships'/file).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
(ROOT/'data/world/ship_visuals.json').write_text(json.dumps({'version':1,'ships':models},ensure_ascii=False,indent=2)+'\n',encoding='utf8')
catalog_path=ROOT/'data/world/world_asset_catalog.json'
catalog=json.loads(catalog_path.read_text(encoding='utf-8-sig'))
old=[e for e in catalog['categories']['ships'] if e.get('id')=='starter_sloop']
for sid,model in models.items():
    if sid=='ship_sloop': continue
    old.append({'id':sid,'scene':model['scene'],'identities':[sid],'reference_size_m':model['length']})
catalog['categories']['ships']=old
catalog_path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('SHIP_FLEET_READY',len(models))
