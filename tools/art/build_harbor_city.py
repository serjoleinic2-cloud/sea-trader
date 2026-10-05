"""A monumental horseshoe harbor, editable city quarters and a shared coastline."""
import bpy, math, json, random
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
random.seed(41)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene
def mat(name,rgb,metal=0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*rgb,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*rgb,1)
    p.inputs['Roughness'].default_value=.78; p.inputs['Metallic'].default_value=metal
    return m
rock=mat('Weathered blue basalt',(.13,.22,.23)); grass=mat('Lush jungle meadow',(.13,.30,.12))
leaf=mat('Emerald broadleaf canopy',(.09,.33,.14)); leaf2=mat('Sunlit jade leaves',(.18,.44,.18))
wood=mat('Oiled harbor teak',(.29,.16,.075)); stone=mat('Pale monumental limestone',(.58,.62,.50))
ivory=mat('City plaster',(.79,.75,.58)); roof=mat('Faction slate roof',(.06,.20,.25))
brass=mat('Maritime brass',(.63,.42,.17),.4); sand=mat('Pale sand and reef shelf',(.55,.57,.34))
water=mat('Waterfall white turquoise',(.40,.75,.75)); dark=mat('Deep arcade shadows',(.035,.11,.14))
cloth=mat('Market sailcloth',(.76,.64,.42)); coral=mat('Reef coral',(.30,.46,.39))
def collection(name):
    c=bpy.data.collections.new(name); scene.collection.children.link(c); return c
current=collection('City island — cliffs jungle coves and reefs')
def own(o,name,m):
    o.name=name
    for c in list(o.users_collection): c.objects.unlink(o)
    current.objects.link(o); o.data.materials.append(m); return o
def box(name,p,size,m):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p); o=own(bpy.context.object,name,m); o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); return o
def mesh(name,v,f,m):
    d=bpy.data.meshes.new(name); d.from_pydata(v,[],f); d.update()
    o=bpy.data.objects.new(name,d); current.objects.link(o); d.materials.append(m); return o
def cylinder(name,p,r,h,m,top=None,n=10):
    bpy.ops.mesh.primitive_cone_add(vertices=n,radius1=r,radius2=r if top is None else top,depth=h,location=p)
    return own(bpy.context.object,name,m)
def beam(name,a,b,r,m=wood):
    a,b=Vector(a),Vector(b); o=cylinder(name,(a+b)/2,r,(a-b).length,m)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler(); return o
def crown(x,y,z,r,m):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=(x,y,z))
    o=own(bpy.context.object,'Layered broadleaf canopy',m); o.scale=(r,r*.85,r*.58)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
def tree(x,y,z=1.1,h=7):
    beam('Rooted rainforest trunk',(x,y,z),(x+.35,y,z+h),.20)
    for k in range(3):
        a=k*math.tau/3
        beam('Buttress root',(x+math.cos(a)*1.1,y+math.sin(a)*1.1,z),(x,y,z+1.6),.15)
    for dx,dy,dz,r in [(0,0,0,2.4),(1.8,.3,-.6,1.8),(-1.4,-.6,-.3,1.8)]:
        crown(x+dx,y+dy,z+h+dz,r,leaf if int(x+y)%2 else leaf2)
def palm(x,y,z=1.1,h=8):
    beam('Tall coastal palm',(x,y,z),(x+.6,y,z+h),.18)
    for k in range(9):
        a=k*math.tau/9
        mesh('Curved palm frond',[(x+.6,y,z+h),(x+.6+2.9*math.cos(a),y+2.9*math.sin(a),z+h+.3),
            (x+.6+4*math.cos(a),y+4*math.sin(a),z+h-1.6),(x+.6+2.7*math.cos(a+.19),y+2.7*math.sin(a+.19),z+h-.5)],[(0,1,3),(1,2,3)],leaf2)
N=144; R=60.0
def coast(a):
    gap=abs((a-math.pi/2+math.pi)%math.tau-math.pi)
    return R*(1+.035*math.sin(a*5)+.018*math.sin(a*13)-.70*math.exp(-(gap/.72)**4))
outline=[(math.cos(i*math.tau/N)*coast(i*math.tau/N),math.sin(i*math.tau/N)*coast(i*math.tau/N)) for i in range(N)]
def rings(name,levels,m):
    v=[(x*f,y*f,z) for f,z in levels for x,y in outline]
    f=[(j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i) for j in range(len(levels)-1) for i in range(N)]
    mesh(name,v,f,m)
rings('Submerged reef shelf',[(1.04,-.75),(1,-.18)],sand)
rings('Basalt waterfront',[(1,-.18),(.975,.7)],rock)
rings('Pale shore strip',[(.975,.7),(.947,1.05)],sand)
rings('Continuous lush island ground',[(.947,1.05),(0,1.05)],grass)
# Horseshoe arms frame a deep, wide harbor. Cliffs rise behind the city.
for k,(x,y,r,h) in enumerate([(-43,-25,15,22),(-23,-42,18,30),(0,-47,17,35),(26,-40,16,26),(44,-23,13,19),(-47,16,8,13),(48,18,8,14)]):
    v=[]; count=24
    for j,(scale,z) in enumerate([(1,.8),(.97,h*.22),(.80,h*.44),(.83,h*.69),(.62,h*.88),(.51,h)]):
        for i in range(count):
            a=i*math.tau/count; jitter=1+.09*math.sin(i*7+k+j)
            v.append((x+math.cos(a)*r*scale*jitter,y+math.sin(a)*r*scale*jitter,z+.4*math.sin(i*3+k)))
    f=[]
    for j in range(5):
        for i in range(count):
            n=(i+1)%count; f.extend([(j*count+i,j*count+n,(j+1)*count+i),(j*count+n,(j+1)*count+n,(j+1)*count+i)])
    mesh('Stratified monumental cliff',v,f,rock)
    mesh('Rainforest cliff crown',v[-count:],[tuple(range(count))],grass)
    for i in range(7):
        a=i*math.tau/7; tree(x+math.cos(a)*r*.30,y+math.sin(a)*r*.30,h+.4,4+i%3)
    for i in range(4):
        a=i*1.7
        crown(x+math.cos(a)*r*.65,y+math.sin(a)*r*.65,h*.63,2.4,leaf)
    # Vegetation follows ledges down the rock face, with long hanging vines.
    for i in range(16):
        a=i*math.tau/16; level=.36+.22*(i%3)
        px=x+math.cos(a)*r*(.85 if level<.65 else .70)
        py=y+math.sin(a)*r*(.85 if level<.65 else .70)
        pz=h*level
        crown(px,py,pz,1.7+(i%3)*.3,leaf if i%2 else leaf2)
        if i%2==0:beam('Hanging rainforest vine',(px,py,pz),(px+.25,py,pz-3.0-i%3),.08,leaf)
# Dense grove masses and tall palms, kept off the civic plazas.
for i in range(92):
    a=i*2.399963; r=32+(i%7)*3.4; x,y=math.cos(a)*r,math.sin(a)*r
    if y>0 and abs(x)<32: continue
    if (x/15)**2+((y+4)/14)**2<1: continue
    if r>coast(a)*.88: continue
    tree(x,y,h=5+(i%4))
for x,y in [(-34,24),(-36,35),(-38,42),(35,24),(37,36),(39,43),(-19,4),(18,4),(-10,-4),(10,-5),(-30,-12),(29,-12)]: palm(x,y,h=7.5)
for x,y,z,h in [(-10,-27,18,17),(31,-23,12,11)]:
    box('Waterfall veil',(x,y,z/2+1),(1.4,.12,h),water)
    crown(x,y,1.5,2.1,water)
    for i in range(7): box('Waterfall terraced runnel',(x,y+2+i*1.1,1.1-i*.12),(1.4,1.1,.1),water)
# Reefs surround the island except the one marked entrance facing +Y.
for i in range(74):
    a=i*math.tau/74
    if abs((a-math.pi/2+math.pi)%math.tau-math.pi)<.36: continue
    r=R*(1.07+.025*math.sin(i*2.6)); x,y=r*math.cos(a),r*math.sin(a)
    cylinder('Broken outer reef',(x,y,-.4),1.9,.9,coral,top=1.5,n=8)
    if i%3==0: cylinder('Emergent reef pinnacle',(x,y,.30),1.2,1.3,rock,top=.55,n=7)
    for j in range(2):
        cylinder('Broken coral reef cluster',(x+math.sin(i+j)*1.8,y+math.cos(i*2+j)*1.5,-.28),.9,.48,coral,top=.55,n=7)
# A harbor for six or more vessels: paved waterfront and several finger piers.
for side in [-1,1]:
    for y in [24,34,44]:
        x=side*(31 if y<40 else 36)
        box('Quay foundation',(x,y,.5),(7.2,7,.9),rock)
        box('Pale promenade paving',(x,y,1.02),(7.5,7.2,.14),stone)
        for j in range(14):
            px=x-side*(3.6+j*.45)
            box('Finger pier teak planks',(px,y,.75),(.43,2.3,.20),wood)
        for j in [0,6,12]:
            for py in [y-1,y+1]: cylinder('Pier piling',(x-side*(3.7+j*.45),py,.30),.16,1.6,wood,n=8)
        for j in range(3): box('Cargo quay crates',(x+side*1.5,y-2+j*.8,1.5),(.65,.7,.8),wood)
        for j in range(2): cylinder('Dock barrels',(x-side*1.8,y+1.6+j*.8,1.4),.32,.7,wood,n=10)
        beam('Loading crane mast',(x,y,1.1),(x,y,5.2),.16)
        beam('Loading crane jib',(x,y,5.2),(x-side*3,y,5.7),.13)
        beam('Loading crane tackle',(x-side*2.8,y,5.6),(x-side*2.8,y,2.2),.025,dark)
for side in [-1,1]:
    x=side*27
    box('Gateway bastion',(x,49,1.4),(6,6,2.8),rock)
    cylinder('Harbor beacon column',(x,49,4.5),1.1,4,stone,top=.8,n=12)
    cylinder('Beacon brass platform',(x,49,6.7),1.65,.35,brass,n=12)
    cylinder('Beacon lantern',(x,49,7.5),.7,1.4,dark,n=8)
    cylinder('Beacon shelter',(x,49,8.5),1.2,.7,roof,top=.3,n=12)
# Civic terraces form a rising skyline instead of eight objects on a flat disk.
placements={'dock':[-30,25,90,1.1],'warehouse':[-29,9,0,3.4],'workshop':[-42,-7,0,5.0],
 'market':[0,1,0,3.0],'shipyard':[31,19,0,2.1],'mage_guild':[0,-22,0,9.4],
 'fishing_wharf':[37,38,-90,1.1],'timber_yard':[40,-7,0,4.8]}
scales={'dock':1.4,'warehouse':2.8,'workshop':2.3,'market':2.5,'shipyard':2.6,'mage_guild':3.2,'fishing_wharf':1.4,'timber_yard':2.3}
for kind,(x,y,angle,z) in placements.items():
    if kind in ['dock','fishing_wharf']: continue
    s=scales[kind]; w,d=(14,12) if kind!='mage_guild' else (22,19)
    box('Civic raised basalt terrace',(x,y,(z+1.1)/2),(w,d,z-1.1),rock)
    box('Terrace stone coping',(x,y,z-.10),(w+.3,d+.3,.2),stone)
    steps=int((z-1.1)/.28)
    for step in range(steps):
        height=z-1.1-step*.28
        box('Processional broad stair',(x,y+d/2+step*.42,1.1+height/2),(4.2,.46,height),stone)
for x in [-15,15]:
    box('Colonnaded avenue paving',(x,-10,1.12),(4,22,.16),stone)
    for y in [-16,-10,-4,2]:
        cylinder('Ceremonial avenue column',(x+2.2,y,3),.25,3.8,ivory,n=10)
        cylinder('Brass column capital',(x+2.2,y,5.05),.4,.25,brass,n=10)
box('Civic plaza paving',(0,7,1.12),(18,8,.16),stone)
def save_export(col,path,source):
    source.parent.mkdir(parents=True,exist_ok=True); (source.parent/'.gdignore').write_text('')
    bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
    bpy.ops.object.select_all(action='DESELECT')
    objects=[o for o in col.objects if o.type=='MESH']
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True)
    for o in col.objects:o.hide_set(True); o.hide_render=True
    scene.collection.children.unlink(col)
save_export(current,ROOT/'assets/world/islands/home_island/home_island.glb',ROOT/'assets/world/islands/home_island/source/home_island.blend')
# One separately replaceable civilian quarter, instanced around the civic buildings.
current=collection('Living city quarter — homes market arcades and harbor work')
for x,y,h in [(-3,-2,3.0),(2,-1,4.1),(-1,3,2.6),(4,3,3.0)]:
    box('Limestone residential footing',(x,y,.15),(3.3,2.9,.3),stone)
    box('Warm city residence',(x,y,h/2+.3),(3,2.6,h),ivory)
    mesh('Faction roof',[(x-1.8,y-1.6,h+.3),(x+1.8,y-1.6,h+.3),(x,y-1.6,h+1.5),
        (x-1.8,y+1.6,h+.3),(x+1.8,y+1.6,h+.3),(x,y+1.6,h+1.5)],[(0,1,2),(3,5,4),(0,2,5,3),(2,1,4,5)],roof)
    for j in range(2):
        box('Recessed city window',(x-0.7+j*1.4,y+1.31,h*.63),(.65,.05,.85),dark)
    box('Arcade entry',(x,y+1.32,.9),(.7,.08,1.3),dark)
    box('Shaded city balcony',(x,y+1.8,2.0),(2.6,.7,.13),wood)
    for dx in [-1,1]:beam('Balcony support',(x+dx,y+1.6,.3),(x+dx,y+1.6,2.0),.07)
for x,y in [(-4,2),(2,5)]:
    box('Street market stall',(x,y,.6),(2,1.2,1.2),wood)
    box('Street market awning',(x,y,2.2),(2.6,1.6,.12),cloth)
    for side in [-1,1]:beam('Street stall post',(x+side,y,0),(x+side,y,2.2),.07)
for x,y in [(-5,-4),(5,-3)]:tree(x,y,h=4)
for j in range(5):
    box('Neighborhood cargo',(j*.65-1,-4,.4),(.6,.6,.8),wood)
save_export(current,ROOT/'assets/world/ports/home_base/city_quarter.glb',ROOT/'assets/world/ports/home_base/source/city_quarter.blend')
p=ROOT/'data/world/home_base_visuals.json'; data=json.loads(p.read_text(encoding='utf-8-sig'))
data.update(version=2,reference_radius_m=R,coastline=outline,placements=placements,building_scales=scales,
 tower_positions=[[-34,44],[35,44]],tower_scale=2.1,
 city_quarter='res://assets/world/ports/home_base/city_quarter.glb',
 city_quarters=[[-23,-9,0,1.1],[23,-8,180,1.1],[-35,-22,0,1.1],[35,-22,180,1.1],[-17,-30,90,2.0],[17,-30,-90,2.0],[-42,8,0,1.1],[45,7,180,1.1]],
 flag_positions=[[-27,49,2.8],[27,49,2.8],[-15,7,1.2],[15,7,1.2],[0,-17,9.4],[-30,31,1.1],[32,31,1.1]])
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('MONUMENTAL_HARBOR_CITY_READY',len(outline),'coast vertices; 6 berths; 8 quarters')
