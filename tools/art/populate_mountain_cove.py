"""Add a metre-scale human harbour town to the approved island, preserving it.
Run with Blender --background --python. Creates a separate populated .blend.
"""
import bpy, math, random, json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'assets/world/islands/karst_cove'
OUT=BASE/'source/karst_cove_city.blend'
PREVIEW=ROOT/'outputs/islands/karst_cove'
random.seed(442)
bpy.ops.wm.open_mainfile(filepath=str(BASE/'source/karst_cove.blend'))
scene=bpy.context.scene
land=next(o for o in scene.objects if o.name.startswith('Connected mountain range'))
bvh=BVHTree.FromPolygons([v.co for v in land.data.vertices],[list(p.vertices) for p in land.data.polygons])

def col(name):
    c=bpy.data.collections.new(name);scene.collection.children.link(c);return c
TOWN=col('08 | Human harbour town - small buildings')
QUAY=col('09 | Streets - piers - flags - market details')
LIB=col('10 | Editable building prototypes - hidden originals')
LOD=col('11 | Game LOD prototypes - hidden originals')
LIB.hide_render=True
LOD.hide_render=True

# The working forest uses genuinely low-poly geometry, including near trees.
# Each linked prototype has one material and per-face vertex colours.
forest=bpy.data.collections['03 | Tropical canopy - linked editable meshes']
highpoly_triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in forest.objects)
lowpoly_mat=bpy.data.materials.new('Low-poly forest | one vertex-colour material')
lowpoly_mat.diffuse_color=(.13,.29,.075,1);lowpoly_mat.use_nodes=True
n=lowpoly_mat.node_tree.nodes;l=lowpoly_mat.node_tree.links
vc=n.new('ShaderNodeVertexColor');vc.layer_name='FoliageTint'
l.new(vc.outputs['Color'],n.get('Principled BSDF').inputs['Base Color'])
n.get('Principled BSDF').inputs['Roughness'].default_value=.9

def lowpoly_tree(index,height):
    verts=[];faces=[];colors=[]
    palette=[(.08,.19,.055,1),(.17,.30,.075,1),(.24,.36,.10,1),(.09,.25,.15,1)]
    leaf=palette[index%4]
    def stem(points,radii):
        base=len(verts);sides=5
        for p,r in zip(points,radii):
            for i in range(sides):
                a=i*math.tau/sides;verts.append((p[0]+r*math.cos(a),p[1]+r*math.sin(a),p[2]))
        for j in range(len(points)-1):
            for i in range(sides):
                faces.append((base+j*sides+i,base+j*sides+(i+1)%sides,base+(j+1)*sides+(i+1)%sides,base+(j+1)*sides+i));colors.append((.16,.10,.045,1))
    stem([(0,0,-.35),(.22,-.13,height*.34),(-.15,.12,height*.69),(.25,.25,height*.82)],[.19,.15,.10,.04])
    phi=(1+math.sqrt(5))/2
    ico=[(-1,phi,0),(1,phi,0),(-1,-phi,0),(1,-phi,0),(0,-1,phi),(0,1,phi),(0,-1,-phi),(0,1,-phi),(phi,0,-1),(phi,0,1),(-phi,0,-1),(-phi,0,1)]
    facets=[(0,11,5),(0,5,1),(0,1,7),(0,7,10),(0,10,11),(1,5,9),(5,11,4),(11,10,2),(10,7,6),(7,1,8),(3,9,4),(3,4,2),(3,2,6),(3,6,8),(3,8,9),(4,9,5),(2,4,11),(6,2,10),(8,6,7),(9,8,1)]
    for k in range(6):
        a=k*2.399+index;spread=0 if k==0 else 1.35
        center=Vector((math.cos(a)*spread,math.sin(a)*spread,height*(.86 if k==0 else .71+random.uniform(-.06,.07))))
        scale=Vector((1.9,1.65,1.35))*random.uniform(.85,1.12)
        if k>0:stem([(0,0,height*.43),(center.x*.6,center.y*.6,height*.63),center],[.085,.05,.015])
        base=len(verts)
        for q in ico:
            v=Vector(q).normalized()*random.uniform(.88,1.10)
            verts.append(tuple(center+Vector((v.x*scale.x,v.y*scale.y,v.z*scale.z))))
        for face in facets:
            faces.append(tuple(base+i for i in face));shade=random.uniform(.84,1.10);colors.append(tuple(c*shade for c in leaf[:3])+(1,))
    data=bpy.data.meshes.new('Low-poly broadleaf %02d'%index);data.from_pydata(verts,[],faces);data.materials.append(lowpoly_mat);data.update()
    tint=data.color_attributes.new(name='FoliageTint',type='BYTE_COLOR',domain='CORNER')
    for poly,color in zip(data.polygons,colors):
        for loop in poly.loop_indices:tint.data[loop].color=color
    return data

replacement={}
for index,data in enumerate(sorted({o.data for o in forest.objects},key=lambda d:d.name)):
    height=max(v.co.z for v in data.vertices)
    replacement[data]=lowpoly_tree(index,height)
for o in forest.objects:o.data=replacement[o.data]
old_library=bpy.data.collections.get('07 | Tree prototypes - hidden originals')
if old_library:
    for o in list(old_library.objects):bpy.data.objects.remove(o,do_unlink=True)
    for index,data in enumerate(replacement.values()):
        o=bpy.data.objects.new('Low-poly editable tree %02d'%index,data);old_library.objects.link(o)
print('LOW_POLY_FOREST_READY',len(forest.objects),'instances',flush=True)
# Keep thousands of linked trees out of the dependency graph during modelling
# operations; reattach the same collection before saving/rendering.
scene.collection.children.unlink(forest)

def move(o,c):
    for old in list(o.users_collection):old.objects.unlink(o)
    c.objects.link(o);return o
def mat(name,color,rough=.8,metal=0,texture=None):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    if texture:
        n=m.node_tree.nodes;l=m.node_tree.links
        tc=n.new('ShaderNodeTexCoord');mapping=n.new('ShaderNodeVectorMath');mapping.operation='MULTIPLY';mapping.inputs[1].default_value=(.25,.25,.25);l.new(tc.outputs['Object'],mapping.inputs[0])
        tx=n.new('ShaderNodeTexImage');tx.image=bpy.data.images.load(str(ROOT/'assets/world/materials/textures'/texture),check_existing=True);tx.projection='BOX';tx.projection_blend=.18;l.new(mapping.outputs[0],tx.inputs[0])
        mix=n.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=.55;mix.inputs[2].default_value=(*color,1);l.new(tx.outputs['Color'],mix.inputs[1]);l.new(mix.outputs[0],p.inputs['Base Color'])
        bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.22;bump.inputs['Distance'].default_value=.055;l.new(tx.outputs['Color'],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal'])
    return m
plaster=mat('Human town | warm lime plaster',(.72,.65,.48),texture='plaster_albedo.png')
plaster2=mat('Human town | pale seafoam plaster',(.43,.58,.53),texture='plaster_albedo.png')
roof=mat('Human town | navy slate roof',(.045,.11,.16),.66,texture='slate_albedo.png')
roof2=mat('Human town | weathered teal roof',(.12,.28,.28),.6,texture='slate_albedo.png')
timber=mat('Human town | dark carved timber',(.20,.12,.065),texture='timber_game_albedo.png')
stone=mat('Human town | masonry foundations',(.54,.51,.42),texture='limestone_game_albedo.png')
metal=mat('Human town | brass trim',(.55,.34,.10),.38,.7)
glass=mat('Human town | blue glass',(.045,.12,.145),.23,.25)
canvas=mat('Human town | cream canvas awnings',(.78,.67,.46),texture='canvas_albedo.png')
turquoise=mat('Human town | navigation light',(.06,.45,.49),.3,.2)
p=turquoise.node_tree.nodes.get('Principled BSDF');p.inputs['Emission Color'].default_value=(.06,.38,.42,1);p.inputs['Emission Strength'].default_value=.7

def box(name,position,dimensions,material,c=LIB,bevel=.03):
    bpy.ops.mesh.primitive_cube_add(size=1,location=position)
    o=move(bpy.context.object,c);o.name=name;o.scale=dimensions;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(material)
    if bevel:
        mod=o.modifiers.new('Soft worn edges','BEVEL');mod.width=bevel;mod.segments=1
    return o
def mesh(name,v,f,materials,c=LIB):
    d=bpy.data.meshes.new(name);d.from_pydata(v,[],f);d.update()
    for m in materials:d.materials.append(m)
    o=bpy.data.objects.new(name,d);c.objects.link(o);return o
def cylinder(name,pos,r,depth,material,c=LIB,vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=pos)
    o=move(bpy.context.object,c);o.name=name;o.data.materials.append(material);return o
def join(parts,name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    bpy.ops.object.convert(target='MESH');bpy.ops.object.join()
    o=bpy.context.object;o.name=name
    scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');return o

def build_house(index,w=6.2,d=5.2,h=5.3):
    parts=[];wall=plaster if index%2==0 else plaster2;rm=roof if index%3 else roof2
    parts.append(box('Lime plaster body',(0,0,h*.5),(w,d,h),wall))
    parts.append(box('Stone plinth',(0,0,.32),(w+.16,d+.16,.65),stone))
    for z in [.8,2.85,h-.1]:parts.append(box('Timber belt',(0,0,z),(w+.13,d+.13,.13),timber))
    for x in [-w*.5,w*.5]:
        for y in [-d*.5,d*.5]:parts.append(box('Corner pilaster',(x,y,h*.5),(.15,.15,h),timber))
    e=.40;rise=1.75 if index<4 else 2.1
    # Gabled roofs have an overhang, solid edge, ridge cap and tiled surface.
    rv=[(-w/2-e,-d/2-e,h),(w/2+e,-d/2-e,h),(-w/2-e,0,h+rise),(w/2+e,0,h+rise),(-w/2-e,d/2+e,h),(w/2+e,d/2+e,h)]
    parts.append(mesh('Pitched slate roof',rv,[(0,1,3,2),(2,3,5,4),(0,2,4),(1,5,3),(0,4,5,1)],[rm]))
    parts.append(box('Copper ridge cap',(0,0,h+rise),(w+.95,.18,.14),metal))
    for y in [-d/2-.40,d/2+.40]:parts.append(box('Rain gutter',(0,y,h),(w+.95,.13,.16),metal))
    for floor in range(2):
        z=1.5+floor*2.65
        for x in [-w*.30,w*.30]:
            parts.append(box('Window glass',(x,-d/2-.025,z),(.86,.055,1.12),glass,bevel=0))
            for dx in [-.52,.52]:parts.append(box('Wooden shutter',(x+dx,-d/2-.07,z),(.18,.10,1.25),timber))
            parts.append(box('Window lintel',(x,-d/2-.12,z+.65),(1.24,.18,.12),stone))
            parts.append(box('Window sill',(x,-d/2-.14,z-.63),(1.24,.24,.14),stone))
            parts.append(box('Window mullion',(x,-d/2-.07,z),(.045,.07,1.1),metal,bevel=0))
        for side in [-1,1]:
            parts.append(box('Side window',(side*(w/2+.03),.35,z),(.05,.9,1.1),glass,bevel=0))
    parts.append(box('Front door',(0,-d/2-.06,1.1),(1.05,.12,2.2),timber))
    parts.append(box('Door step',(0,-d/2-.48,.16),(1.5,.85,.3),stone))
    parts.append(box('Porch awning',(0,-d/2-.74,2.55),(2.2,1.5,.15),rm))
    for x in [-.95,.95]:parts.append(box('Porch post',(x,-d/2-1.3,1.3),(.10,.10,2.5),timber))
    parts.append(box('Chimney',(w*.31,d*.21,h+rise*.45),(.6,.65,2.35),stone))
    parts.append(box('Chimney cap',(w*.31,d*.21,h+rise*.45+1.18),(.8,.84,.18),stone))
    parts.append(box('Navigation beacon',(w*.5-.5,-d*.5-.18,h-.55),(.20,.2,.5),turquoise))
    if index%2:
        parts.append(box('Upper balcony',(0,-d/2-.55,3.6),(2.7,1.1,.14),timber))
        for x in [-1.25,0,1.25]:parts.append(box('Balcony railing',(x,-d/2-1.0,4.05),(.08,.08,.95),metal))
        parts.append(box('Balcony rail',(0,-d/2-1.0,4.52),(2.7,.08,.08),metal))
    return join(parts,'Human townhouse %02d | %.1fm roof'%(index+1,h+rise))

houses=[build_house(i,5.5+i*.35,4.6+(i%3)*.4,5.0+(i%2)*.5) for i in range(4)]
houses.append(build_house(4,9.5,7.3,5.8)) # warehouse
houses[-1].name='Human warehouse | 9.5m frontage'
houses.append(build_house(5,8.6,6.7,7.7)) # civic office
houses[-1].name='Human harbour office | 9.8m roof'
print('HOUSE_PROTOTYPES_READY',len(houses),flush=True)

def xy(a,t):
    ix=105+6*math.sin(a*4+.8)+3*math.sin(a*9);iy=77+4*math.cos(a*5)
    ox=325+21*math.sin(a*5+1)+8*math.cos(a*11);oy=250+17*math.sin(a*4-.8)
    return Vector((math.sin(a)*(ix+(ox-ix)*t),math.cos(a)*(iy+(oy-iy)*t),0))
def ground(x,y):
    hit,normal,_,_=bvh.ray_cast(Vector((x,y,800)),Vector((0,0,-1)))
    return (hit,normal) if hit else (None,None)
def rotate_xy(p,angle):
    return Vector((p.x*math.cos(angle)-p.y*math.sin(angle),p.x*math.sin(angle)+p.y*math.cos(angle),p.z))

lots=[]
for row,t in enumerate([.112,.179]):
    for slot in range(43):
        deg=-122+slot*5.7+(2.8 if row else 0)
        if slot%11 in [0,1]:continue # green corridors and views towards mountain gullies
        a=math.radians(deg);p=xy(a,t);hit,normal=ground(p.x,p.y)
        if hit is None or hit.z<.4 or normal.z<.68:continue
        index=slot%4;proto=houses[index];rot=-a
        footprint=Vector((3.3,2.9,0));zs=[]
        for dx in [-1,1]:
            for dy in [-1,1]:
                offset=rotate_xy(Vector((footprint.x*dx,footprint.y*dy,0)),rot)
                q,_=ground(p.x+offset.x,p.y+offset.y)
                if q:zs.append(q.z)
        if len(zs)<4 or max(zs)-min(zs)>4.2:continue
        z=max(zs)+.05
        o=bpy.data.objects.new('House %02d | coastal quarter %d'%(len(lots)+1,row+1),proto.data);TOWN.objects.link(o);o.location=(p.x,p.y,z);o.rotation_euler.z=rot
        o['height_m']=round(proto.dimensions.z,2);o['faction']='humans';o['prototype']=proto.name
        basement=box('Fitted masonry foundation',(p.x,p.y,(z+min(zs)-.3)/2),(6.7,5.9,z-min(zs)+.3),stone,TOWN,bevel=.04);basement.rotation_euler.z=rot
        lots.append({'position':[p.x,p.y,z],'rotation':rot,'prototype':index,'radius':5.7})

# Civic destinations are only modestly larger than surrounding homes.
for name,deg,t,index in [('Harbour office',-7,.132,5),('Market hall',54,.12,4),('Warehouse',-64,.12,4),('Ship supplies',105,.122,4)]:
    a=math.radians(deg);p=xy(a,t);hit,normal=ground(p.x,p.y)
    if hit is None:continue
    # Clear any accidental overlap with ordinary houses at civic squares.
    for o in list(TOWN.objects):
        if (o.location-p).to_2d().length<10:bpy.data.objects.remove(o,do_unlink=True)
    z=hit.z+2.0;proto=houses[index]
    o=bpy.data.objects.new(name+' | Humans',proto.data);TOWN.objects.link(o);o.location=(p.x,p.y,z);o.rotation_euler.z=-a
    basement=box(name+' retaining terrace',(p.x,p.y,z-2.0),(11,8.8,4.4),stone,TOWN);basement.rotation_euler.z=-a
    lots.append({'position':[p.x,p.y,z],'rotation':-a,'prototype':index,'radius':9.0})

# Remove trees only from building footprints and the coastal streets.
print('TOWN_PLACED',len(lots),'sites',flush=True)
removed=0
for tree in list(forest.objects):
    if any((tree.location-Vector(site['position'])).to_2d().length<site['radius']+2.1 for site in lots):
        bpy.data.objects.remove(tree,do_unlink=True);removed+=1

def street(t,width,name):
    verts=[];faces=[]
    for i in range(280):
        a=math.radians(-124+248*i/279);p=xy(a,t);tangent=Vector((math.cos(a),-math.sin(a),0));out=Vector((math.sin(a),math.cos(a),0))
        for side in [-1,1]:
            q=p+out*width*.5*side;hit,_=ground(q.x,q.y)
            verts.append((q.x,q.y,(hit.z if hit else -.2)+.16))
    for i in range(279):faces.append((i*2,i*2+1,i*2+3,i*2+2))
    return mesh(name,verts,faces,[stone],QUAY)
street(.142,2.5,'Main coastal street | 2.5m wide')
street(.088,2.7,'Waterfront promenade | 2.7m wide')

def quay(deg):
    a=math.radians(deg);p=xy(a,.081);axis=Vector((-math.sin(a),-math.cos(a),0));side=Vector((math.cos(a),-math.sin(a),0));rot=-a
    for i in range(34):
        q=p+axis*i*.65
        o=box('Pier | individual planks',(q.x,q.y,1.65),(4.0,.59,.22),timber,QUAY,bevel=.025);o.rotation_euler.z=rot
        if i%6==0:
            for s in [-1,1]:
                pile=q+side*s*1.65;cylinder('Pier | pile',(pile.x,pile.y,-.8),.17,5.9,timber,QUAY)
    for d in [4,15]:
        q=p+axis*d+side*1.3
        box('Pier cargo crate',(q.x,q.y,2.1),(.85,.85,.85),timber,QUAY)
    return p
for deg in [-91,-35,34,90]:quay(deg)

flagmat=mat('Humans | fixed heraldic flag',(.055,.13,.20))
n=flagmat.node_tree.nodes;l=flagmat.node_tree.links;p=n.get('Principled BSDF')
tx=n.new('ShaderNodeTexImage');tx.image=bpy.data.images.load(str(ROOT/'assets/ui/emblems/humans.png'),check_existing=True)
mix=n.new('ShaderNodeMixRGB');mix.inputs[1].default_value=(.025,.08,.14,1);l.new(tx.outputs['Alpha'],mix.inputs[0]);l.new(tx.outputs['Color'],mix.inputs[2]);l.new(mix.outputs[0],p.inputs['Base Color'])
for deg in [-95,-38,0,43,92]:
    a=math.radians(deg);pos=xy(a,.09);hit,_=ground(pos.x,pos.y);z=max(.8,hit.z if hit else .8)
    cylinder('Heraldic flagstaff',(pos.x,pos.y,z+4.1),.075,8.2,metal,QUAY)
    verts=[];faces=[]
    for j in range(2):
        for i in range(13):
            u=i/12;verts.append((pos.x+u*1.5,pos.y+.13*math.sin(u*8),z+7.9-j*2.0))
    for i in range(12):faces.append((i,i+1,i+14,i+13))
    o=mesh('Human flag | existing emblem',verts,faces,[flagmat],QUAY);uv=o.data.uv_layers.new()
    for poly in o.data.polygons:
        for loop in poly.loop_indices:
            vi=o.data.loops[loop].vertex_index;uv.data[loop].uv=(vi%13/12,1-vi//13)

# Simple small stalls and planted civic squares at the waterfront.
for index,deg in enumerate([-76,-20,15,67]):
    a=math.radians(deg);pos=xy(a,.10);hit,_=ground(pos.x,pos.y)
    if not hit:continue
    for k in range(3):
        q=pos+Vector((math.cos(a),-math.sin(a),0))*k*3.4;z=hit.z
        o=box('Market | canvas shade',(q.x,q.y,z+2.8),(2.7,2.2,.13),canvas,QUAY);o.rotation_euler.z=-a
        o=box('Market | timber counter',(q.x,q.y,z+.85),(2.4,1.0,.18),timber,QUAY);o.rotation_euler.z=-a
        for dx in [-1.1,1.1]:
            offset=rotate_xy(Vector((dx,.8,0)),-a);cylinder('Market | post',(q.x+offset.x,q.y+offset.y,z+1.35),.06,2.7,timber,QUAY,8)

def triangles(m):return sum(len(p.vertices)-2 for p in m.polygons)
print('QUAYS_AND_FLAGS_READY',flush=True)
tree_data=list({o.data for o in forest.objects})
before=sum(triangles(o.data) for o in forest.objects)
lod_counts={};tree_lods={}
for index,data in enumerate(tree_data):
    entries=[]
    for level,target in [(1,100),(2,36)]:
        o=bpy.data.objects.new('Tree %02d | LOD%d'%(index,level),data.copy());LOD.objects.link(o)
        bpy.context.view_layer.objects.active=o
        dec=o.modifiers.new('Preserve canopy silhouette','DECIMATE');dec.ratio=min(1,target/max(1,triangles(data)));dec.use_collapse_triangulate=True
        bpy.ops.object.modifier_apply(modifier=dec.name)
        entries.append(triangles(o.data))
    tree_lods[data.name]=entries
for index,ratio in [(1,.34),(2,.09)]:
    o=bpy.data.objects.new('Terrain | LOD%d'%index,land.data.copy());LOD.objects.link(o)
    bpy.context.view_layer.objects.active=o
    dec=o.modifiers.new('Ridge preserving reduction','DECIMATE');dec.ratio=ratio;dec.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=dec.name)
    lod_counts['terrain_lod%d'%index]=triangles(o.data)
LOD.hide_viewport=True;LIB.hide_viewport=True
scene.collection.children.link(forest)
stats={'original_highpoly_tree_triangles':highpoly_triangles,'source_tree_instances':len(forest.objects),'source_tree_triangles':before,'source_terrain_triangles':triangles(land.data),'unique_tree_meshes':len(tree_data),'tree_lod_triangles_by_mesh':tree_lods,'all_trees_at_lod1_triangles':sum(tree_lods[o.data.name][0] for o in forest.objects),'all_trees_at_lod2_triangles':sum(tree_lods[o.data.name][1] for o in forest.objects),'terrain_lods':lod_counts,'house_instances':sum(o.data in [h.data for h in houses] for o in TOWN.objects),'town_triangles':sum(triangles(o.data) for o in TOWN.objects if o.type=='MESH'),'cleared_trees_for_town':removed,'house_roof_heights_m':[round(o.dimensions.z,2) for o in houses],'measured_fps':None,'runtime_note':'These are geometry counts, not frame-rate measurements. LOD selection, spatial batches, culling, shaders and collisions still need Godot integration.'}
(BASE/'performance_geometry.json').write_text(json.dumps(stats,indent=2,ensure_ascii=False),encoding='utf-8')
scene['town_faction']='humans';scene['town_scale']='Ordinary houses 6.8-7.3m roof, civic buildings up to 9.8m; mountain about 187m above water.'
scene['game_performance']='Visible foliage is low-poly, one vertex-colour material per tree. Hidden collection 11 contains further reduced tree and terrain meshes; runtime LOD switching and batching are not yet connected.'
for image in bpy.data.images:
    if image.source=='FILE':
        try:image.pack()
        except Exception:pass
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_distance=1020
            area.spaces.active.region_3d.view_location=(0,35,70)
scene.render.filepath=str(PREVIEW/'karst_cove_city_overview.png')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT),compress=True)
print('CITY_SAVED',str(OUT),flush=True)
print('GEOMETRY_STATS',json.dumps(stats),flush=True)
bpy.ops.render.render(write_still=True)
cam=scene.camera
cam.location=(230,-365,190);cam.rotation_euler=(Vector((0,40,21))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=48
scene.render.resolution_x=1440;scene.render.resolution_y=960;scene.render.filepath=str(PREVIEW/'karst_cove_city_harbour.png')
bpy.ops.render.render(write_still=True)
print('CITY_RENDERS_READY',flush=True)
