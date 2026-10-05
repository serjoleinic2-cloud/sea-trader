"""Editable floating rainforest archipelago with rope bridges and suspended berths."""
from pathlib import Path
exec((Path(__file__).parent/'build_harbor_city.py').read_text(encoding='utf8').split('N=144; R=60.0')[0])
current.name='Floating harbor — islands bridges ropes and ladders'
islands=[(-24,-41,48,9),(0,-52,62,13),(24,-40,53,10),(-11,-65,78,7),(35,-62,73,8)]
for index,(x,y,z,r) in enumerate(islands):
    verts=[]
    for size,h in [(.16,-r*1.6),(.43,-r*.9),(.90,-r*.32),(1,0),(.92,.8)]:
        for j in range(20):
            a=j*math.tau/20; rr=r*size*(1+.08*math.sin(j*3.1+index))
            verts.append((x+math.cos(a)*rr,y+math.sin(a)*rr,z+h))
    faces=[tuple(range(80,100))]
    for k in range(4):
        for j in range(20): faces.append((k*20+j,k*20+(j+1)%20,(k+1)*20+(j+1)%20,(k+1)*20+j))
    mesh('Suspended basalt island',verts,faces,rock)
    cylinder('Floating meadow',(x,y,z+.7),r*.91,.35,grass,n=20)
    for j in range(5):
        a=j*math.tau/5; tree(x+math.cos(a)*r*.6,y+math.sin(a)*r*.6,z+.9,3+j%3)
        beam('Hanging jungle vine',(x+math.cos(a)*r*.85,y+math.sin(a)*r*.85,z),(x+math.cos(a)*r*.82,y+math.sin(a)*r*.82,z-8),.055,leaf)
    for j in range(14):box('Suspended dock plank',(x+5,y-r*.6-j*.42,z+.1),(3,.39,.16),wood)
    for dx in [-1.5,1.5]:
        beam('Sky mooring post',(x+5+dx,y-r*.6,z),(x+5+dx,y-r*.6,z+3),.12)
        beam('Suspension dock rope',(x+5+dx,y-r*.6,z+3),(x+5+dx,y-r*.6-5.5,z+.3),.035,cloth)
    if index in [0,2]:
        bottom=10 if index==0 else 14
        for dx in [-.55,.55]:beam('Descending rope ladder',(x+dx,y+r*.8,z+.8),(x+dx,y+r*.8,bottom),.045,cloth)
        for h in range(bottom,int(z),1):beam('Rope ladder rung',(x-.55,y+r*.8,h),(x+.55,y+r*.8,h),.06)
for first,second in [(0,1),(1,2),(1,3),(2,4)]:
    a=Vector(islands[first][:3]); b=Vector(islands[second][:3]); direction=(b-a).normalized()
    a+=direction*islands[first][3]*.8; b-=direction*islands[second][3]*.8
    last=None
    for j in range(25):
        t=j/24; p=a.lerp(b,t); p.z-=math.sin(t*math.pi)*3
        plank=box('Hanging bridge deck',p,(1.7,(b-a).length/24*.9,.13),wood)
        plank.rotation_euler.z=-math.atan2(direction.x,direction.y)
        side=Vector((direction.y,-direction.x,0))*.85
        for sign in [-1,1]:
            q=p+side*sign+Vector((0,0,1.1))
            if last is not None:beam('Suspended bridge hand rope',last+side*sign+Vector((0,0,1.1)),q,.035,cloth)
        last=p
source=ROOT/'assets/world/islands/sky_harbor/source/sky_harbor.blend'
source.parent.mkdir(parents=True,exist_ok=True); (source.parent/'.gdignore').write_text('')
bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
bpy.ops.object.select_all(action='DESELECT')
objects=[o for o in current.objects if o.type=='MESH']
for o in objects:o.select_set(True)
bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join()
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
path=source.parent.parent/'sky_harbor.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True)
(ROOT/'data/world/sky_harbor_visuals.json').write_text(json.dumps({'scene':'res://assets/world/islands/sky_harbor/sky_harbor.glb','islands':islands},indent=2)+'\n',encoding='utf8')
print('SKY_HARBOR_READY: five islands, four bridges, two descending ladders')
