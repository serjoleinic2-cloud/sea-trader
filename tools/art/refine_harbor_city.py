"""Refine the editable capital: smooth geology, curved foliage and working-port props."""
from pathlib import Path
exec((Path(__file__).parent/'build_harbor_city.py').read_text(encoding='utf8').split('N=144; R=60.0')[0])
source=ROOT/'assets/world/islands/home_island/source/home_island.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
scene=bpy.context.scene; current=next(c for c in scene.collection.children if c.name.startswith('City island'))
wood=bpy.data.materials['Oiled harbor teak']; stone=bpy.data.materials['Pale monumental limestone']; rock=bpy.data.materials['Weathered blue basalt']; leaf=bpy.data.materials['Emerald broadleaf canopy']; cloth=mat('Market sailcloth',(.76,.64,.42)); brass=bpy.data.materials['Maritime brass']
for o in list(current.objects):
    if o.type!='MESH':continue
    if o.name.startswith('Finger pier teak planks'):o.location.z=.42
    if o.name.startswith('Layered broadleaf canopy'):
        for polygon in o.data.polygons:polygon.use_smooth=True
    elif o.name.startswith('Stratified monumental cliff'):
        bpy.context.view_layer.objects.active=o
        mod=o.modifiers.new('Sculpted smooth geology' if 'cliff' in o.name else 'Rounded layered foliage','SUBSURF'); mod.levels=2 if 'cliff' in o.name else 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
        texture=bpy.data.textures.new('Organic surface variation',type='CLOUDS'); texture.noise_scale=1.8 if 'cliff' in o.name else .55
        mod=o.modifiers.new('Eroded organic contours','DISPLACE'); mod.texture=texture; mod.strength=.65 if 'cliff' in o.name else .35; mod.mid_level=.5
        bpy.ops.object.modifier_apply(modifier=mod.name)
        for polygon in o.data.polygons:polygon.use_smooth=True
    elif o.name.startswith(('Quay foundation','Pale promenade','Civic raised','Terrace stone','Gateway')):
        bpy.context.view_layer.objects.active=o
        mod=o.modifiers.new('Worn stone edge','BEVEL'); mod.width=.10; mod.segments=3
        bpy.ops.object.modifier_apply(modifier=mod.name)
    elif 'trunk' in o.name.lower() or 'piling' in o.name.lower():
        for polygon in o.data.polygons:polygon.use_smooth=True
def barrel(x,y,z):
    cylinder('Coopered dock barrel',(x,y,z+.43),.32,.82,wood,n=24)
    for h in [.12,.66]:
        bpy.ops.mesh.primitive_torus_add(major_segments=24,minor_segments=8,location=(x,y,z+h),major_radius=.325,minor_radius=.024)
        own(bpy.context.object,'Forged barrel hoop',brass)
def pot(x,y,z):
    cylinder('Terracotta provisioning jar',(x,y,z+.25),.24,.50,cloth,top=.17,n=24)
    cylinder('Jar neck',(x,y,z+.53),.12,.15,cloth,n=20)
def bench(x,y,z):
    for dy in [-.2,0,.2]:box('Timber bench slat',(x,y+dy,z+.46),(1.6,.16,.08),wood)
    for dx in [-.6,.6]:box('Bench carved footing',(x+dx,y,z+.24),(.12,.55,.48),stone)
def rope(x,y,z):
    for j in range(4):
        bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=8,location=(x,y,z+.025+j*.028),major_radius=.16+j*.036,minor_radius=.018)
        own(bpy.context.object,'Coiled mooring rope',cloth)
for side in [-1,1]:
    for y in [24,34,44]:
        x=side*(31 if y<40 else 36)
        for j in range(4):barrel(x+side*2,y-2+j*.7,1.09)
        rope(x-side*3,y+.5,.53); rope(x-side*6,y-.5,.53)
        for j in range(3):
            px=x+side*1.3; py=y-1+j*.85
            box('Braced merchant packing crate',(px,py,1.5),(.75,.75,.75),wood)
            for dx in [-.28,.28]:box('Crate iron strap',(px+dx,py,1.5),(.045,.79,.79),brass)
        bench(x+side*2.5,y+2,1.09)
        for py in [y-.9,y+.9]:
            cylinder('Iron mooring bollard',(x-side*5,py,.61),.11,.32,brass,n=24)
            cylinder('Bollard crosshead',(x-side*5,py,.80),.17,.07,brass,n=24)
for x,y in [(-22,-8),(22,-8),(-36,-19),(35,-19),(-16,-26),(16,-26),(-42,7),(44,7)]:
    bench(x,y+2,1.1)
    for j in range(5):pot(x+j*.5-1,y-2,1.1)
    barrel(x-2,y,1.1); barrel(x-2,y+.8,1.1)
    box('Street stall counter',(x,y,1.65),(2.7,1.2,1.1),wood)
    for dx in [-1.4,1.4]:beam('Awning carved upright',(x+dx,y,1.1),(x+dx,y,3.8),.07,wood)
    for j in range(8):
        mesh('Curved merchant awning',[(x-1.5+j*.4,y-.8,3.9),(x-1.5+(j+1)*.4,y-.8,3.9),(x-1.5+(j+1)*.4,y+1.2,3.4),(x-1.5+j*.4,y+1.2,3.4)],[(0,1,2,3)],cloth)
    for j in range(3):box('Market stacked wares',(x-1+j*.7,y,2.35),(.50,.40,.32),cloth)
for x in [-12,12]:
    for y in [-12,-6,0,6]:
        bench(x,y,1.1); cylinder('Planter stone rim',(x+2,y,1.4),.55,.55,stone,n=24)
        for j in range(5):
            a=j*math.tau/5; crown(x+2+math.cos(a)*.25,y+math.sin(a)*.25,2,.4,leaf)
source.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
bpy.ops.object.select_all(action='DESELECT')
objects=[o for o in current.objects if o.type=='MESH']
for o in objects:o.select_set(True)
bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join(); bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.export_scene.gltf(filepath=str(source.parent.parent/'home_island.glb'),export_format='GLB',use_selection=True)
p=ROOT/'data/world/home_base_visuals.json'; data=json.loads(p.read_text(encoding='utf8'))
data['placements']['dock'][3]=.22; data['placements']['fishing_wharf'][3]=.22
data['building_scales']['dock']=1.15; data['building_scales']['fishing_wharf']=1.15
data['building_scales'].update(warehouse=1.7,workshop=1.6,market=1.8,shipyard=1.8,mage_guild=2.2,timber_yard=1.6)
data['city_quarters'] += [[-8,-10,0,1.1],[9,-10,180,1.1],[-25,-23,0,1.1],[25,-23,180,1.1],[-8,-34,0,2.0],[9,-34,180,2.0],[-44,-12,0,1.1],[44,-12,180,1.1]]
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('DETAILED_HARBOR_READY: rounded cliffs, lower piers, market wares and dock fittings')
