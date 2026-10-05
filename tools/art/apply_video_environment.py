"""Apply the owner's modular village and sculpted foliage references to game assets.
Idempotent: original tree placements are retained inside each editable source.
"""
import bpy, math, json, random, sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0,str(Path(__file__).parent))
from video_reference_assets import ROOT, mat, mesh, box, tube, cylinder, ico

library={}
for name in ['tiered_pine','broadleaf_emerald','broadleaf_lime','flowering_rose','flowering_lilac','flowering_gold']:
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/f'assets/world/vegetation/video_reference/source/{name}.blend'))
    bpy.ops.object.select_all(action='SELECT'); bpy.context.view_layer.objects.active=next(o for o in bpy.context.scene.objects if o.type=='MESH')
    bpy.ops.object.convert(target='MESH'); bpy.ops.object.join(); o=bpy.context.object
    library[name]=([tuple(o.matrix_world@v.co) for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons],[(m.name,tuple(m.diffuse_color[:3])) for m in o.data.materials],[p.material_index for p in o.data.polygons])

def export(source):
    bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
    bpy.ops.object.select_all(action='DESELECT')
    objects=[o for o in bpy.context.scene.objects if o.type in ['MESH','CURVE']]
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.convert(target='MESH'); bpy.ops.object.join(); bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bpy.ops.export_scene.gltf(filepath=str(source.parent.parent/(source.stem+'.glb')),export_format='GLB',use_selection=True)

def waterfall(x,y,z,drop,width):
    water=mat('VR flowing water',(.34,.73,.78)); foam=mat('VR waterfall foam',(.79,.94,.88))
    for strip in range(5):
        w=width/5; xx=x-width/2+strip*w; vertices=[]
        for j in range(17):
            t=j/16; yy=y+t*.7+math.sin(t*5)*.12
            vertices.extend([(xx,yy,z-t*drop),(xx+w*.97,yy,z-t*drop)])
        o=mesh('VR waterfall ribbon',vertices,[(j*2,j*2+1,j*2+3,j*2+2) for j in range(16)],foam if strip in [0,4] else water)
        uv=o.data.uv_layers.new(name='FlowUV')
        for p in o.data.polygons:
            for li in p.loop_indices:
                vi=o.data.loops[li].vertex_index; uv.data[li].uv=(vi%2,(vi//2)/16)
    ico('VR waterfall mist',(x,y+.7,z-drop),(width*.8,.7,.35),foam,2)

coast=json.loads((ROOT/'data/world/home_base_visuals.json').read_text(encoding='utf-8'))['coastline']
def inside(x,y):
    hit=False
    for a,b in zip(coast,coast[1:]+coast[:1]):
        if (a[1]>y)!=(b[1]>y) and x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:hit=not hit
    return hit
def ground(x,y):
    if y>16 or abs(x)<23 and y>-15:return 1.075
    hills=sum(h*math.exp(-((x-a)**2+(y-b)**2)/(w*w)) for a,b,h,w in [(-35,-24,4.0,16),(34,-23,5.0,15),(0,-33,4.0,12)])
    # Broad town platforms and existing streets keep sensible walking grades.
    flat=min(1,max(0,(-y+15)/12)) if abs(x)<23 else min(1,max(0,(16-y)/12))
    return 1.075+hills*flat

sources=[ROOT/'assets/world/islands/home_island/source/home_island.blend',ROOT/'assets/world/islands/sky_harbor/source/sky_harbor.blend',ROOT/'assets/world/ports/home_base/source/city_quarter.blend']
sources+=list((ROOT/'assets/world/islands/route_islands/source').glob('green_*.blend'))
for source in sources:
    if not source.exists():continue
    bpy.ops.wm.open_mainfile(filepath=str(source)); random.seed(source.stem)
    scene=bpy.context.scene
    if 'video_tree_layout' not in scene:
        locations=[]
        for o in scene.objects:
            if o.type=='CURVE' and any(s in o.name for s in ['Bezier curved tree trunk','Curved trunk']):
                points=[o.matrix_world@p.co for s in o.data.splines for p in s.bezier_points]
                if points:
                    a=min(points,key=lambda p:p.z); h=max(p.z for p in points)-a.z
                    locations.append([*a,max(.35,min(1.65,h/5.5))])
        scene['video_tree_layout']=json.dumps(locations)
    for o in list(scene.objects):
        if any(s in o.name for s in ['Bezier curved tree trunk','Illustrated sculpted crown','Curved trunk','Tiered jade foliage','VR forest','VR village','VR waterfall','VR rolling ground','VR alpine mountain','Waterfall veil','Terraced runnel','Harbor beacon column','Beacon brass','Beacon lantern','Beacon shelter','Port ancillary shed','Shed pitched tiled roof','Fishing rack rail']):
            bpy.data.objects.remove(o,do_unlink=True)
    prototypes={}
    for name,(verts,faces,mats,indices) in library.items():
        d=bpy.data.meshes.new('VR '+name); d.from_pydata(verts,[],faces)
        for mn,c in mats:d.materials.append(mat(mn,c))
        for p,i in zip(d.polygons,indices):p.material_index=i
        prototypes[name]=d
    choices=list(library); weights=[45,18,16,7,8,6]
    for x,y,z,s in json.loads(scene['video_tree_layout']):
        name=random.choices(choices,weights)[0]; o=bpy.data.objects.new('VR forest '+name,prototypes[name]); bpy.context.collection.objects.link(o)
        o.location=(x,y,max(z+.10,ground(x,y)) if source.stem=='home_island' else z+.10); o.scale=(s,s,s); o.rotation_euler.z=random.uniform(0,math.tau)
    if source.stem=='home_island':
        timber=mat('Oiled village teak',(.28,.18,.10)); roof=mat('Faction village tiled roof',(.32,.39,.28)); stone=mat('Illustrated mountain rock',(.31,.40,.37))
        vertices=[]; indices={}; faces=[]
        for j in range(81):
            for i in range(81):
                x,y=-60+i*1.5,-60+j*1.5
                if inside(x/.93,y/.93):indices[i,j]=len(vertices); vertices.append((x,y,ground(x,y)))
        for i,j in indices:
            if all(p in indices for p in [(i+1,j),(i+1,j+1),(i,j+1)]):
                a,b,c,d=[indices[p] for p in [(i,j),(i+1,j),(i+1,j+1),(i,j+1)]]; faces.extend([(a,b,c),(a,c,d)])
        mesh('VR rolling ground',vertices,faces,mat('Illustrated rolling meadow',(.25,.43,.26)))
        for o in scene.objects:
            if o.type=='MESH' and o.name.startswith(('Pale shore strip','Basalt waterfront','Submerged reef shelf')):
                beach=mat('Illustrated warm tropical sand',(.76,.68,.46))
                o.data.materials.clear(); o.data.materials.append(beach)
                for p in o.data.polygons:p.material_index=0
            if o.type=='MESH' and o.name.startswith('Pale shore strip'):
                for v in o.data.vertices:
                    if v.co.z>.9:v.co.x*=.93/.947; v.co.y*=.93/.947
        # Refit street strips onto the rolling land instead of hiding them below it.
        for o in scene.objects:
            if o.type=='MESH' and o.name.startswith('Harbor neighborhood footpath'):
                for v in o.data.vertices:
                    p=o.matrix_world@v.co; p.z=ground(p.x,p.y)+.11; v.co=o.matrix_world.inverted()@p
        cliffs=[o for o in scene.objects if o.type=='MESH' and 'Stratified monumental cliff' in o.name]
        specs=[(-43,-25,15,22),(-23,-42,18,30),(0,-47,17,35),(26,-40,16,26),(44,-23,13,19),(-47,16,8,13),(48,18,8,14)]
        for o,(x,y,r,h) in zip(cliffs,specs):
            n=28; rows=10; v=[]; f=[]
            for j in range(rows):
                t=j/(rows-1); rr=r*(1-.38*t-.035*(j%2))
                for i in range(n):
                    a=i*math.tau/n; rad=rr*(1+.06*math.sin(a*5)+.03*math.cos(a*9))
                    v.append((x+rad*math.cos(a),y+rad*math.sin(a),-5+(h+5)*t))
            for j in range(rows-1):
                for i in range(n):f.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
            f.extend([tuple(reversed(range(n))),tuple(range((rows-1)*n,rows*n))])
            d=bpy.data.meshes.new('Layered faceted cliff'); d.from_pydata(v,[],f); d.materials.append(stone); d.materials.append(mat('Illustrated cliff meadow',(.23,.43,.25))); o.data=d
            d.polygons[-1].material_index=1
        # Existing mountain trails are projected horizontally onto the new cliffs.
        bpy.context.view_layer.update()
        surfaces=[BVHTree.FromObject(o,bpy.context.evaluated_depsgraph_get()) for o in cliffs]
        trails=[o for o in scene.objects if o.type=='MESH' and o.name.startswith('Mountain switchback footpath')]
        for o,(x,y,r,h),surface in zip(trails,specs,surfaces):
            for v in o.data.vertices:
                p=o.matrix_world@v.co; radial=Vector((p.x-x,p.y-y,0)).normalized()
                hit,_,_,_=surface.ray_cast(Vector((x,y,p.z))+radial*r*2,-radial,r*3)
                if hit is not None:v.co=o.matrix_world.inverted()@(hit+radial*.20+Vector((0,0,.08)))
        # Small waterfront livelihoods, individually editable boardwork and rails.
        for i in range(8):
            x=(-1 if i%2 else 1)*(23+(i%3)*7); y=-15+(i//2)*10; z=ground(x,y)+.07
            box('VR village cottage',(x,y,z+.95),(2.5,2,1.9),timber)
            for board in range(10):
                xx=x-1.7+board*.36
                mesh('VR village roof board',[(xx,y-1.4,z+1.8),(xx,y,z+2.65),(xx+.32,y,z+2.65),(xx+.32,y-1.4,z+1.8),(xx,y+1.4,z+1.8),(xx+.32,y+1.4,z+1.8)],[(0,1,2,3),(1,4,5,2)],roof)
            for j in range(11):box('VR village deck plank',(x-1.8+j*.36,y+1.7,z),( .33,1.15,.13),timber)
            for xx in [x-1.8,x+1.8]:
                for yy in [y+1.2,y+2.2]:box('VR village rail post',(xx,yy,z+.5),(.09,.09,1),timber)
                tube('VR village deck rail',[(xx,y+1.2,z+.95),(xx,y+2.2,z+.95)],.04,timber)
            box('VR village shuttered window',(x-.6,y+1.01,z+1.25),(.65,.10,.65),roof)
            box('VR village carved door',(x+.6,y+1.02,z+.68),(.65,.1,1.3),stone)
        for x,y,z in [(-37,-4,8),(35,-16,10)]:
            ico('VR waterfall outcrop',(x,y,z/2),(3.5,2.4,z/2),stone,2)
            waterfall(x,y+2,z,z-1.3,1.1)
        # Asymmetric mountain silhouettes, white caps above the tree line.
        for x,y,z,h,r in [(-23,-42,29,24,10),(0,-47,34,28,11),(26,-40,25,22,9)]:
            n=12; verts=[]
            for rr,zz in [(r,z),(r*.48,z+h*.68),(r*.14,z+h*.94)]:
                verts += [(x+rr*(1+.13*math.sin(i*3))*math.cos(i*math.tau/n),y+rr*math.sin(i*math.tau/n),zz+math.sin(i*2)*1.5) for i in range(n)]
            verts.append((x+1.7,y-1,z+h))
            faces=[(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(2) for i in range(n)]+[(24+i,24+(i+1)%n,36) for i in range(n)]
            o=mesh('VR alpine mountain',verts,faces,stone); o.data.materials.append(mat('Illustrated mountain snow',(.88,.92,.89)))
            for p in o.data.polygons:p.material_index=1 if p.index>=12 else 0
    if source.stem=='sky_harbor':
        shift=45 if scene.get('sky_above_peaks',False) else 0
        for x,y,z,r in [(-24,-41,48,9),(0,-52,62,13),(24,-40,53,10),(-11,-65,78,7),(35,-62,73,8)]:waterfall(x,y+r*.7,z+.2+shift,min(35,z-15),1.2)
        if not shift:
            # Raise the flying harbour above the snowy peaks; hanging ropes keep
            # their low anchors and grow in length rather than moving off ground.
            for o in scene.objects:
                if o.name.startswith('VR forest'):
                    o.location.z+=45
                elif o.type=='MESH':
                    for v in o.data.vertices:
                        p=o.matrix_world@v.co; p.z+=45*max(0,min(1,(p.z-12)/25)); v.co=o.matrix_world.inverted()@p
                elif o.type=='CURVE':
                    for spline in o.data.splines:
                        for p in spline.bezier_points:
                            old=o.matrix_world@p.co; old.z+=45*max(0,min(1,(old.z-12)/25)); p.co=o.matrix_world.inverted()@old
            at=json.loads(scene['video_tree_layout'])
            for p in at:p[2]+=45
            scene['video_tree_layout']=json.dumps(at); scene['sky_above_peaks']=True
            path=ROOT/'data/world/sky_harbor_visuals.json'; metadata=json.loads(path.read_text(encoding='utf-8'))
            if not metadata.get('above_peaks',False):
                for p in metadata['islands']:p[2]+=45
                metadata['above_peaks']=True; path.write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
    export(source)
    print('VIDEO_ENVIRONMENT_READY',source.stem,len(json.loads(scene.get('video_tree_layout','[]'))))
# Districts on the inland slopes follow terrain height; quays stay flat.
manifest_path=ROOT/'data/world/home_base_visuals.json'
manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
for at in manifest.get('city_quarters',[]):at[3]=ground(at[0],at[1])+.05
manifest_path.write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
