"""Replaceable architectural relief: carved portals, shutters, cornices and roof tiles."""
from pathlib import Path
exec((Path(__file__).parent/'build_harbor_city.py').read_text(encoding='utf8').split('N=144; R=60.0')[0])
glazing=mat('Deep azure arcade window glass',(.045,.13,.16),.15)
terracotta=mat('Muted clay market pottery',(.45,.22,.12))
def rectangle(name,center,size,material):
    x,y,z=center; w,d,h=size
    return mesh(name,[(x+sx*w/2,y+sy*d/2,z+sz*h/2) for sx,sy,sz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],material)
def arch(x,y,z,r):
    for side in [-1,1]:rectangle('Carved portal jamb',(x+side*(r+.09),y,z-.48),(.18,.22,.96),stone)
    for j in range(16):
        a=j*math.pi/16; b=(j+1)*math.pi/16
        vertices=[]
        for depth in [-.11,.11]:
            for radius,angle in [(r,a),(r,b),(r+.18,b),(r+.18,a)]:vertices.append((x+math.cos(angle)*radius,y+depth,z+math.sin(angle)*radius))
        mesh('Hand carved arch voussoir',vertices,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6)],stone)
def window(x,y,z):
    rectangle('Recessed azure arcade glazing',(x,y,z),(.58,.10,.96),glazing)
    for dx in [-.35,.35]:
        rectangle('Window carved surround',(x+dx,y+.06,z),(.10,.16,1.15),stone)
        rectangle('Wooden louvered shutter',(x+dx*1.8,y+.01,z),(.42,.09,1.0),wood)
        for j in range(7):rectangle('Individual shutter louver',(x+dx*1.8,y+.07,z-.40+j*.13),(.38,.07,.065),wood)
    for dz in [-.58,.58]:rectangle('Window limestone lintel',(x,y+.04,z+dz),(.82,.20,.12),stone)
    rectangle('Window vertical mullion',(x,y+.12,z),(.045,.06,1.0),brass)
    rectangle('Window cross mullion',(x,y+.12,z),(.62,.06,.045),brass)
    rectangle('Projecting carved sill',(x,y+.15,z-.65),(.96,.36,.12),stone)
def export(col,name):
    folder=ROOT/'assets/world/buildings/details'; folder.mkdir(parents=True,exist_ok=True)
    source=folder/'source'; source.mkdir(exist_ok=True); (source/'.gdignore').write_text('')
    bpy.ops.wm.save_as_mainfile(filepath=str(source/(name+'.blend')),compress=True)
    bpy.ops.object.select_all(action='DESELECT')
    objects=[o for o in col.objects if o.type=='MESH']
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join(); bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bpy.ops.export_scene.gltf(filepath=str(folder/(name+'.glb')),export_format='GLB',use_selection=True)
    for o in col.objects:o.hide_set(True); o.hide_render=True
    scene.collection.children.unlink(col)
for kind,w,d in [('warehouse',4.4,3.6),('workshop',3.4,3.3),('market',3.6,3.4),('shipyard',4.8,4.5),('timber_yard',3.4,3.2)]:
    current=collection(kind+' detailed carved facade and roof')
    front=d/2+.10; roof_z=3.225
    for x in [-w*.32,w*.32]:window(x,front,1.75)
    arch(0,front+.02,1.35,.54)
    for j in range(6):rectangle('Portal teak door board',(-.44+j*.175,front+.07,.85),(.16,.08,1.02),wood)
    for z in [.65,1.1]:rectangle('Forged door crossbrace',(0,front+.13,z),(1.0,.06,.06),brass)
    for x in [-.16,.16]:
        bpy.ops.mesh.primitive_torus_add(major_segments=20,minor_segments=8,location=(x,front+.17,.95),major_radius=.06,minor_radius=.012,rotation=(math.pi/2,0,0))
        own(bpy.context.object,'Portal bronze ring handle',brass)
    for x in [-w/2,w/2]:
        for y in [-d/2,d/2]:
            rectangle('Carved corner pilaster',(x,y,1.55),(.18,.18,2.6),stone)
            for z in [.34,2.84]:rectangle('Pilaster sculpted capital',(x,y,z),(.34,.34,.16),stone)
    for z in [.38,2.92]:
        for y in [-d/2,d/2]:rectangle('Limestone facade cornice',(0,y,z),(w+.25,.20,.12),stone)
        for x in [-w/2,w/2]:rectangle('Side wall carved cornice',(x,0,z),(.20,d,.12),stone)
    for side in [-1,1]:
        for row in range(7):
            x=side*(row+.5)*(w+.45)/14; z=roof_z+.85*(1-abs(x)/((w+.45)/2))+.045
            for j in range(14):
                y=-d/2-.22+(j+.5)*(d+.45)/14
                tile=rectangle('Individual curved slate roof tile',(x,y,z),((w+.45)/14*.98,(d+.45)/14*.96,.045),roof)
                tile.rotation_euler.y=side*math.atan2(.85,(w+.45)/2)
    for x in [-w*.34,w*.34]:
        rectangle('Window balcony decking',(x,front+.42,.95),(.96,.65,.08),wood)
        for dx in [-.42,-.21,0,.21,.42]:rectangle('Turned balcony baluster',(x+dx,front+.70,1.20),(.045,.045,.46),brass)
        rectangle('Balcony carved handrail',(x,front+.70,1.45),(1.02,.08,.08),wood)
    export(current,kind)
current=collection('Guild detailed classical sanctuary')
for j in range(12):
    a=j*math.tau/12; x,y=math.cos(a)*2.14,math.sin(a)*2.14
    column=cylinder('Guild fluted limestone column',(x,y,1.45),.115,2.3,stone,n=24)
    for z in [.3,2.65]:cylinder('Guild carved column capital',(x,y,z),.19,.17,stone,n=24)
    if j%2==0:
        obj=rectangle('Guild recessed arcade glazing',(x*.96,y*.96,1.35),(.65,.12,1.4),glazing); obj.rotation_euler.z=a-math.pi/2
for z,r in [(.4,2.12),(2.42,2.16),(2.62,2.27)]:
    bpy.ops.mesh.primitive_torus_add(major_segments=96,minor_segments=8,location=(0,0,z),major_radius=r,minor_radius=.065)
    own(bpy.context.object,'Continuous sanctuary carved cornice',stone)
export(current,'mage_guild')
print('CIVIC_DETAIL_KITS_READY: six independent editable architecture sets')
