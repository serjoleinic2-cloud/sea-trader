"""Export the approved connected ridge as six playable harbors and two wild islands.
Metres in Blender; GLB uses Godot X/Y/Z. Collision outlines come from the same terrain.
"""
import bpy, math, json, random, sys
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/world/islands/faction_harbors'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/world/islands/karst_cove/source/karst_cove_city.blend'))
source=bpy.context.scene
terrain=bpy.data.objects['Terrain | LOD1']
forest=list(bpy.data.collections['03 | Tropical canopy - linked editable meshes'].objects)
town=list(bpy.data.collections['08 | Human harbour town - small buildings'].objects)
quays=[o for o in bpy.data.collections['09 | Streets - piers - flags - market details'].objects if 'flag' not in o.name.lower()]
details=[o for o in bpy.data.collections['04 | Trails - quay - lighthouse - scale boat'].objects if o.type=='MESH' and ('beacon' in o.name.lower() or 'trail' in o.name.lower())]
beacon=bpy.data.objects['Beacon | lantern glazing'].location.copy()
profiles=json.loads((ROOT/'data/world/faction_architecture.json').read_text(encoding='utf-8'))['profiles']
variants={'humans':(1.,1.,1.,0.),'nerids':(1.08,.9,.84,.045),'surr':(.94,1.08,1.08,-.05),'meridians':(1.12,.96,.93,.025),'aery':(.88,1.08,1.28,.04),'crystari':(1.04,1.04,1.14,-.025)}

def deform(p,v,scale=1):
    sx,sy,sz,shear=v
    return Vector(((p.x*sx+shear*p.y)*scale,p.y*sy*scale,p.z*sz*scale))

def coast(a,t):
    ix=105+6*math.sin(a*4+.8)+3*math.sin(a*9); iy=77+4*math.cos(a*5)
    ox=325+21*math.sin(a*5+1)+8*math.cos(a*11); oy=250+17*math.sin(a*4-.8)
    return Vector((math.sin(a)*(ix+(ox-ix)*t),math.cos(a)*(iy+(oy-iy)*t),0))

def copy_mesh(o,scene,v,scale=1,detail_gain=1):
    n=bpy.data.objects.new(o.name,o.data.copy());scene.collection.objects.link(n)
    for vert in n.data.vertices:vert.co=deform(o.matrix_world@(vert.co*detail_gain),v,scale)
    # GLB cannot export Blender's procedural rock nodes; UVs are explicit.
    if not n.data.uv_layers:
        uv=n.data.uv_layers.new(name='SurfaceUV')
        for loop in n.data.loops:
            p=n.data.vertices[loop.vertex_index].co;uv.data[loop.index].uv=(p.x*.04,p.y*.04)
    return n

def merge(objects,name):
    if not objects:return
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join();objects[0].name=name
    return objects[0]

# Make export-friendly materials with existing game textures.
for m in bpy.data.materials:
    if m.name.startswith(('Limestone |','Terrace turf')):
        m.node_tree.nodes.clear();p=m.node_tree.nodes.new('ShaderNodeBsdfPrincipled');out=m.node_tree.nodes.new('ShaderNodeOutputMaterial');m.node_tree.links.new(p.outputs['BSDF'],out.inputs['Surface'])
        p.inputs['Base Color'].default_value=m.diffuse_color;p.inputs['Roughness'].default_value=.88
        tx=m.node_tree.nodes.new('ShaderNodeTexImage');tx.image=bpy.data.images.load(str(ROOT/'assets/world/materials/textures'/('basalt_game_albedo.png' if m.name.startswith('Limestone') else 'foliage_game_albedo.png')),check_existing=True)
        m.node_tree.links.new(tx.outputs['Color'],p.inputs['Base Color'])

manifest={'version':1,'opening_axis':'+Z','anchor_forward_ratio':.12,'variants':{},'route_islands':[]}
mini_only='--only-mini' in sys.argv
if mini_only:manifest=json.loads((ROOT/'data/world/faction_harbors.json').read_text(encoding='utf-8'))
for index,(race,v) in enumerate(variants.items()):
    for mini in [False,True]:
        if mini_only and not mini:continue
        ident=race+('_outpost' if mini else '')
        scene=bpy.data.scenes.new(ident);bpy.context.window.scene=scene
        scale=.48 if mini else 1.
        land=copy_mesh(terrain,scene,v,scale);land.name='ContinuousRidgeAndSubmergedShore'
        if mini:
            d=land.modifiers.new('Outpost ridge budget','DECIMATE');d.ratio=.5
            bpy.context.view_layer.objects.active=land;bpy.ops.object.modifier_apply(modifier=d.name)
        # Spatial forest batches: cull independently; no thousands of runtime nodes.
        rng=random.Random(918+index)
        chosen=rng.sample(forest, min(len(forest),180 if mini else 1350))
        groups={}
        for tree in chosen:
            n=copy_mesh(tree,scene,v,scale,2.5 if mini else 1)
            key=(int(tree.location.x//100),int(tree.location.y//100))
            groups.setdefault(key,[]).append(n)
        for key,trees in groups.items():merge(trees,'ForestBatch_%s_%s'%key)
        buildings=[];flags=[]
        selected=[o for o in town if not mini or (o.name.startswith('House') and int(o.name.split()[1])%4==0)]
        for o in selected:
            buildings.append(copy_mesh(o,scene,v,scale,2.5 if mini else 1))
            if o.name.startswith('House') or ' | Humans' in o.name:
                q=deform(o.location,v,scale);flags.append([round(q.x,3),round(q.z,3),round(-q.y,3)])
        merge(buildings,'TerracedTown')
        if not mini:
            merge([copy_mesh(o,scene,v,scale) for o in quays+details],'QuaysPathsAndMarket')
        # Architecture is genuine per-race geometry from the existing model library.
        path=ROOT/profiles[race]['scene'].replace('res://','')
        before=set(scene.objects);bpy.ops.import_scene.gltf(filepath=str(path))
        crowns=[o for o in scene.objects if o not in before and o.type=='MESH']
        for o in [o for o in scene.objects if o not in before and o.type!='MESH']:
            for child in list(o.children):mat=child.matrix_world.copy();child.parent=None;child.matrix_world=mat
            bpy.data.objects.remove(o,do_unlink=True)
        all_crowns=[]
        for num,loc in enumerate(flags[::2][:4 if mini else 10]):
            for proto in crowns:
                n=bpy.data.objects.new('FactionRoof',proto.data.copy());scene.collection.objects.link(n)
                for vert in n.data.vertices:
                    p=proto.matrix_world@vert.co
                    gain=2.5 if mini else 1
                    vert.co=p*scale*1.4*gain+Vector((loc[0],-loc[2],loc[1]+6.6*scale*gain))
                all_crowns.append(n)
        for o in crowns:bpy.data.objects.remove(o,do_unlink=True)
        merge(all_crowns,'FactionLandmarks')
        # Coasts below water at both edges; use a small inland offset for shoreline.
        limit=math.radians(137)
        outline=[coast(-limit+2*limit*i/96,.026) for i in range(97)]
        outline += [coast(limit-2*limit*i/96,.974) for i in range(97)]
        coords=[deform(p,v,scale) for p in outline]
        reference=max(math.hypot(p.x,p.y) for p in coords)
        piers=[]
        for deg in ([-75,75] if mini else [-91,-35,34,90]):
            a=math.radians(deg);p=coast(a,.081);axis=Vector((-math.sin(a),-math.cos(a),0));side=Vector((math.cos(a),-math.sin(a),0))
            length,width=(50,6) if mini else (22,2)
            corners=[deform(p+axis*d+side*w,v,scale) for d,w in [(0,-width),(length,-width),(length,width),(0,width)]]
            piers.append([[round(q.x,3),round(-q.y,3)] for q in corners])
            if mini:
                verts=[(q.x,q.y,1.65*scale) for q in corners]
                mesh=bpy.data.meshes.new('OutpostPier');mesh.from_pydata(verts,[],[(0,1,2,3)]);mesh.materials.append(bpy.data.materials.get('Weathered pier planks'))
                o=bpy.data.objects.new('OutpostPier',mesh);scene.collection.objects.link(o)
        folder=OUT/ident;folder.mkdir(exist_ok=True)
        bpy.ops.export_scene.gltf(filepath=str(folder/'island.glb'),export_format='GLB',use_active_scene=True,export_apply=True,export_cameras=False,export_lights=False)
        bp=deform(beacon,v,scale)
        manifest['variants'][ident]={'faction':race,'mini':mini,'scene':'res://'+str((folder/'island.glb').relative_to(ROOT)).replace('\\','/'),'reference_radius':round(reference,4),'coastline':[[round(q.x,3),round(-q.y,3)] for q in coords],'piers':piers,'flags':flags[::3][:3 if mini else 6],'lighthouse':[] if mini else [round(bp.x,3),round(bp.z,3),round(-bp.y,3)],'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in scene.objects if o.type=='MESH')}
        print('EXPORTED',ident,manifest['variants'][ident]['triangles'],flush=True)
        bpy.context.window.scene=source
        for o in list(scene.objects):bpy.data.objects.remove(o,do_unlink=True)
        bpy.data.scenes.remove(scene)

# Two deliberately portless obstacles: dense green ridge and a narrow steep ridge.
for number,v in enumerate([] if mini_only else [(1,.72,.92,.16),(.66,1.1,1.22,-.13)]):
    scene=bpy.data.scenes.new('WildIsland');bpy.context.window.scene=scene
    land=copy_mesh(terrain,scene,v);land.name='WildRidge'
    # Close the central hollow with a broad submerged foundation and green saddle.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=24,location=(0,0,-8))
    saddle=bpy.context.object;saddle.name='ClosedWildIslandSaddle';saddle.scale=(125*v[0],125*v[1],45*v[2])
    saddle.data.materials.append(next(m for m in bpy.data.materials if m.name.startswith('Terrace turf')))
    rng=random.Random(311+number)
    merge([copy_mesh(o,scene,v) for o in rng.sample(forest,700)],'WildLowPolyForest')
    path=OUT/('route_%d.glb'%number)
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_active_scene=True,export_apply=True,export_cameras=False,export_lights=False)
    manifest['route_islands'].append({'scene':'res://'+str(path.relative_to(ROOT)).replace('\\','/'),'reference_radius':370.0})
    bpy.context.window.scene=source
    for o in list(scene.objects):bpy.data.objects.remove(o,do_unlink=True)
    bpy.data.scenes.remove(scene)
(ROOT/'data/world/faction_harbors.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print('HARBOR_EXPORT_COMPLETE',flush=True)
