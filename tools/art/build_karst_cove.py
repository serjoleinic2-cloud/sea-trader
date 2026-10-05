"""An editable art-reference island study. Blender 5.x, metres, Z up.

This is a standalone modelling scene, not a replacement for game navigation.
"""
import bpy, math, random, json
from pathlib import Path
from mathutils import Vector, Quaternion
from mathutils.noise import noise_vector, noise

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/world/islands/karst_cove'
SOURCE = OUT / 'source'
SOURCE.mkdir(parents=True, exist_ok=True)
(SOURCE / '.gdignore').touch()
PREVIEW = ROOT / 'outputs/islands/karst_cove'
PREVIEW.mkdir(parents=True, exist_ok=True)
random.seed(9417)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for c in list(bpy.data.collections):
    if c.name != 'Collection' and c.users == 0:
        bpy.data.collections.remove(c)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1
scene['asset_notes'] = 'Mountain Cove | connected horseshoe ridge with saddles and branching spurs. Editable metre-scale terrain and linked trees. Sea and lighting are presentation only.'

def collection(name):
    c = bpy.data.collections.new(name)
    scene.collection.children.link(c)
    return c
LAND = collection('01 | Island foundation and beaches')
CLIFF = collection('02 | Sculpted limestone massifs')
FOREST = collection('03 | Tropical canopy - linked editable meshes')
DETAIL = collection('04 | Trails - quay - lighthouse - scale boat')
SEA = collection('05 | Presentation water - hide to inspect underside')
STUDIO = collection('06 | Cameras and daylight')
LIBRARY = collection('07 | Tree prototypes - hidden originals')

def move(o, c):
    for old in list(o.users_collection): old.objects.unlink(o)
    c.objects.link(o)
    return o

def material(name, color, rough=.8, metal=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
    return m

rock = material('Limestone | weathered strata and mineral texture', (.39,.42,.36))
n, l = rock.node_tree.nodes, rock.node_tree.links
p = n.get('Principled BSDF')
coord = n.new('ShaderNodeTexCoord')
mapping = n.new('ShaderNodeVectorMath'); mapping.operation='MULTIPLY'; mapping.inputs[1].default_value=(.055,.055,.04)
l.new(coord.outputs['Object'], mapping.inputs[0])
tex = n.new('ShaderNodeTexImage'); tex.image=bpy.data.images.load(str(ROOT/'assets/world/materials/textures/basalt_game_albedo.png')); tex.projection='BOX'; tex.projection_blend=.3
l.new(mapping.outputs[0],tex.inputs['Vector'])
tint = n.new('ShaderNodeMixRGB'); tint.blend_type='MULTIPLY'; tint.inputs[0].default_value=.5; tint.inputs[2].default_value=(.69,.75,.64,1)
l.new(tex.outputs['Color'],tint.inputs[1]); l.new(tint.outputs[0],p.inputs['Base Color'])
fine=n.new('ShaderNodeTexNoise'); fine.inputs['Scale'].default_value=2.1; fine.inputs['Detail'].default_value=4; fine.inputs['Roughness'].default_value=.75
l.new(coord.outputs['Object'],fine.inputs['Vector'])
bump=n.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.55; bump.inputs['Distance'].default_value=.65
l.new(fine.outputs['Fac'],bump.inputs['Height']); l.new(bump.outputs[0],p.inputs['Normal'])

moss=material('Terrace turf | mottled fern green',(.18,.28,.075))
n,l=moss.node_tree.nodes,moss.node_tree.links
ns=n.new('ShaderNodeTexNoise'); ns.inputs['Scale'].default_value=4.5; ns.inputs['Detail'].default_value=3
tc=n.new('ShaderNodeTexCoord'); l.new(tc.outputs['Object'],ns.inputs['Vector'])
ramp=n.new('ShaderNodeValToRGB'); ramp.color_ramp.elements[0].color=(.045,.095,.018,1); ramp.color_ramp.elements[1].color=(.31,.40,.09,1)
l.new(ns.outputs['Fac'],ramp.inputs[0]); l.new(ramp.outputs[0],n.get('Principled BSDF').inputs['Base Color'])
sand=material('Warm coral sand',(.66,.55,.34))
wood=material('Weathered pier planks',(.22,.115,.047))
stone=material('Lighthouse | ivory limestone',(.61,.56,.42))
brass=material('Patinated copper',(.15,.29,.25),.42,.55)
bark=material('Curved tropical branches',(.13,.095,.043))
leaves=[]
for idx, col in enumerate([(.13,.25,.055),(.22,.34,.075),(.065,.19,.075),(.29,.38,.11),(.085,.23,.16),(.24,.18,.27)]):
    m=material('Canopy %02d | leaf relief'%idx,col,.88)
    ns=m.node_tree.nodes.new('ShaderNodeTexNoise'); ns.inputs['Scale'].default_value=17; ns.inputs['Detail'].default_value=2
    bump=m.node_tree.nodes.new('ShaderNodeBump'); bump.inputs['Distance'].default_value=.08; bump.inputs['Strength'].default_value=.4
    m.node_tree.links.new(ns.outputs['Fac'],bump.inputs['Height']); m.node_tree.links.new(bump.outputs[0],m.node_tree.nodes.get('Principled BSDF').inputs['Normal'])
    leaves.append(m)

def mesh(name, vertices, faces, mats, col, smooth=True):
    d=bpy.data.meshes.new(name); d.from_pydata(vertices,[],faces); d.update()
    for m in mats: d.materials.append(m)
    o=bpy.data.objects.new(name,d); col.objects.link(o)
    if smooth:
        for p in d.polygons: p.use_smooth=True
    return o

LIMIT=math.radians(137)
def coast(a,t):
    innerx=105+6*math.sin(a*4+.8)+3*math.sin(a*9)
    innery=77+4*math.cos(a*5)
    outerx=325+21*math.sin(a*5+1)+8*math.cos(a*11)
    outery=250+17*math.sin(a*4-.8)
    x=math.sin(a)*(innerx+(outerx-innerx)*t)
    y=math.cos(a)*(innery+(outery-innery)*t)
    taper=min(1,max(0,(LIMIT-abs(a))/.22))
    ridge=math.sin(math.pi*t)**1.8
    z=(-3+52*ridge*(.90+.16*math.cos(a*3))) * taper - 5*(1-taper)
    z+=noise(Vector((x*.038,y*.038,4)))*3.2*ridge*taper
    return Vector((x,y,z))

def terrain(a,t):
    """Connected ridgeline with saddles and branching eroded spurs."""
    p=coast(a,t)
    end=max(0,min(1,(LIMIT-abs(a))/.45))
    edge=max(0,math.sin(math.pi*t))
    crest_t=.57+.055*math.sin(a*2.7)+.02*math.sin(a*7)
    peaks=[(-1.43,70,.33),(-.62,133,.32),(.43,104,.39),(1.29,66,.3)]
    summit=45+sum(h*math.exp(-((a-center)/width)**2) for center,h,width in peaks)
    summit+=8*math.sin(a*29)+4*math.sin(a*63+.7)
    cross=max(0,1-abs(t-crest_t)/(.42 if t<crest_t else .44))
    main=summit*cross**1.18
    # Diagonal secondary ridges spread towards the shore and divide real valleys.
    for center,height,_ in peaks:
        for side in [-1,1]:
            dt=t-crest_t
            if dt*side<0:continue
            spine_a=center+dt*(.65 if side<0 else -.48)
            length=max(0,1-abs(dt)/.46)
            shoulder=(height+36)*length**1.30*max(0,1-abs(a-spine_a)/.25)**1.55
            main=max(main,shoulder)
    erosion=(noise(Vector((p.x*.05,p.y*.05,8)))*7.5+noise(Vector((p.x*.17,p.y*.17,2)))*2.1)
    p.z+=max(0,main*.77+erosion*cross)*end*edge
    return p

# One continuous, closed horseshoe foundation: both ends and the seabed are sealed.
NA, NT=481,129
v=[terrain(-LIMIT+2*LIMIT*i/(NA-1),j/(NT-1)) for i in range(NA) for j in range(NT)]
f=[]
for i in range(NA-1):
    for j in range(NT-1):
        k=i*NT+j; f.append((k,k+NT,k+NT+1,k+1))
boundary=[i*NT for i in range(NA)]+[(NA-1)*NT+j for j in range(1,NT)]+[i*NT+NT-1 for i in range(NA-2,-1,-1)]+[j for j in range(NT-2,0,-1)]
low=[]
for idx in boundary:
    low.append(len(v)); v.append((v[idx].x,v[idx].y,-18))
for i in range(len(boundary)):
    j=(i+1)%len(boundary); f.append((boundary[j],boundary[i],low[i],low[j]))
f.append(tuple(reversed(low)))
land=mesh('Connected mountain range | ridgeline, saddles, spurs and submerged base',v,f,[rock,moss,sand],LAND)
for p in land.data.polygons:
    p.material_index=2 if -1.5<p.center.z<4.0 else (1 if p.normal.z>.49 and 4<p.center.z<132 else 0)

cliffs=[]
def lerp_profile(t):
    points=[(0,1.13),(.13,1.0),(.19,.81),(.32,.83),(.38,.66),(.57,.71),(.63,.54),(.78,.56),(.84,.34),(.94,.30),(1,.025)]
    for (a,r),(b,s) in zip(points,points[1:]):
        if t<=b:
            q=(t-a)/(b-a); q=q*q*(3-2*q)
            return r+(s-r)*q
    return .025

def pinnacle(name, position, radius, height, phase, aspect=.75, radial=104, rings=94):
    vs=[]; fs=[]
    for j in range(rings):
        t=j/(rings-1)
        profile=max(.018,(1-t)**.34) * (1.02+.13*math.sin(t*17+phase)-.055*math.sin(t*35-phase))
        for i in range(radial):
            a=math.tau*i/radial
            grooves=(.105*math.cos(a*11+phase)+.19*math.sin(a*5+phase)+.035*math.cos(a*23))
            strata=.025*math.sin(t*62+phase+a)+.017*math.sin(t*137+a*2)
            r=radius*profile*(1+grooves+strata)
            px=position.x+r*math.cos(a)+math.sin(t*2+phase)*radius*.16*t
            py=position.y+r*math.sin(a)*aspect+math.sin(t*3+phase)*radius*.12*t
            pz=position.z-4+height*t+height*.016*math.sin(a*3+phase)*math.sin(math.pi*t)
            dis=noise_vector(Vector((px*.14,py*.14,pz*.048)))
            vs.append((px+dis.x*1.9,py+dis.y*1.9,pz+dis.z*.9))
    for j in range(rings-1):
        for i in range(radial):
            k=j*radial+i; kn=j*radial+(i+1)%radial
            fs.append((k,kn,kn+radial,k+radial))
    fs.append(tuple(reversed(range(radial))))
    fs.append(tuple((rings-1)*radial+i for i in range(radial)))
    o=mesh(name,vs,fs,[rock,moss],CLIFF)
    for p in o.data.polygons:
        p.material_index=1 if p.normal.z>.57 and p.center.z>position.z+12 else 0
    cliffs.append(o)
    return o

print('CONNECTED_RIDGE_READY',len(land.data.vertices),'vertices',flush=True)

def tube(name, points, radius, mat, col, radii=None):
    d=bpy.data.curves.new(name,'CURVE'); d.dimensions='3D'; d.resolution_u=5; d.bevel_depth=radius; d.bevel_resolution=2
    s=d.splines.new('BEZIER'); s.bezier_points.add(len(points)-1)
    for i,(b,p) in enumerate(zip(s.bezier_points,points)):
        b.co=p; b.handle_left_type='AUTO'; b.handle_right_type='AUTO'; b.radius=radii[i] if radii else 1
    d.materials.append(mat); o=bpy.data.objects.new(name,d); col.objects.link(o); return o

def ico(name, pos, scale, mat, col, subdivisions=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions,radius=1,location=pos)
    o=move(bpy.context.object,col); o.name=name
    # Every crown has a lobed silhouette and leaf-scale relief, not a smooth ball.
    for v in o.data.vertices:
        q=v.co.copy(); v.co*=1+.17*noise(q*5.1+Vector((2,7,1)))
    o.scale=scale; o.data.materials.append(mat)
    for p in o.data.polygons:p.use_smooth=True
    return o

prototypes=[]
for variant in range(8):
    parts=[]; h=random.uniform(4.8,7.7)
    parts.append(tube('Curved trunk',[(0,0,-.45),(.28,-.1,h*.32),(-.32,.2,h*.7),(.2,.35,h)],.18,bark,LIBRARY,[1.25,1,.7,.3]))
    for branch in range(7):
        a=branch*2.399+variant; r=random.uniform(1.2,2.8)
        end=Vector((math.cos(a)*r,math.sin(a)*r,h-random.uniform(0,1.6)))
        parts.append(tube('Spreading branch',[(0,0,h*.5),(end.x*.6,end.y*.6,h*.80),end],.085,bark,LIBRARY,[1,.65,.16]))
        for k in range(2):
            pos=end+Vector((random.uniform(-.6,.6),random.uniform(-.6,.6),k*.46))
            leafmat=leaves[(variant+branch//3)%5] if variant<7 else leaves[5]
            parts.append(ico('Fine broadleaf crown',pos,(random.uniform(1.3,1.8),random.uniform(1.1,1.7),random.uniform(.7,1.1)),leafmat,LIBRARY))
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    bpy.ops.object.convert(target='MESH'); bpy.ops.object.join()
    o=bpy.context.object; o.name='Tree prototype %02d | bent trunk and fourteen crowns'%variant
    prototypes.append(o)

def plant(point, scale, index):
    proto=prototypes[index%8]
    o=bpy.data.objects.new('Canopy | terrace tree',proto.data); FOREST.objects.link(o)
    o.location=point; o.rotation_euler.z=random.uniform(0,math.tau)
    o.scale=(scale,scale,scale*random.uniform(.85,1.15))
    return o

# Trees on the shoulder terrain. Peaks occlude trees inside their mass naturally.
for i in range(5700):
    a=random.uniform(-LIMIT+.09,LIMIT-.09); t=random.uniform(.13,.87)
    p=terrain(a,t)
    if p.z<5:continue
    normal=(terrain(a+.001,t)-p).cross(terrain(a,t+.001)-p).normalized()
    if normal.z<.44 or p.z>137:continue
    plant(p,random.uniform(.85,1.9),random.randrange(7))

# Plant by actual ledge normals; never attach trees halfway up a vertical wall.
for cliff in cliffs:
    candidates=[p for p in cliff.data.polygons if p.normal.z>.48 and p.center.z>40 and p.area>0]
    if not candidates:continue
    weights=[p.area for p in candidates]
    count=min(280,max(10,int(sum(weights)/18)))
    for poly in random.choices(candidates,weights=weights,k=count):
        p=poly.center+poly.normal*.10
        plant(p,random.uniform(.65,1.55),random.randrange(7))
LIBRARY.hide_render=True; LIBRARY.hide_viewport=True
print('FOREST_READY',len(FOREST.objects),flush=True)

# The footpath follows the inner green shoulder; occasional handrails expose scale.
path=[]
for i in range(270):
    a=math.radians(-125+250*i/269); t=.17+.018*math.sin(a*7)
    for dt in [-.006,.006]:
        p=terrain(a,t+dt); p.z+=.18; path.append(p)
mesh('Continuous winding coastal trail',path,[(i*2,i*2+1,i*2+3,i*2+2) for i in range(269)],[sand],DETAIL)

def box(name,pos,scale,mat,col=DETAIL,bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos)
    o=move(bpy.context.object,col); o.name=name; o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(mat)
    if bevel:
        mod=o.modifiers.new('Worn edges','BEVEL'); mod.width=bevel; mod.segments=2
        o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
    return o

def cone(name,pos,r1,r2,depth,mat,col=DETAIL,segments=48):
    bpy.ops.mesh.primitive_cone_add(vertices=segments,radius1=r1,radius2=r2,depth=depth,location=pos)
    o=move(bpy.context.object,col);o.name=name;o.data.materials.append(mat)
    for p in o.data.polygons:p.use_smooth=len(p.vertices)==4
    return o

# A small lighthouse, deliberately dwarfed by the geological formations.
lp=terrain(math.radians(122),.24)
cone('Beacon | stepped masonry foundation',lp+Vector((0,0,1)),5.7,5.3,2,stone)
cone('Beacon | tapered tower',lp+Vector((0,0,12)),3.3,2.35,22,stone)
for z in [3,10,18,23]:cone('Beacon | stone string course',lp+Vector((0,0,z)),3.6-z*.047,3.6-z*.047,.45,stone)
cone('Beacon | copper gallery',lp+Vector((0,0,24)),3.7,3.7,.65,brass)
glass=material('Beacon glass',(.30,.55,.52),.2,.2)
cone('Beacon | lantern glazing',lp+Vector((0,0,26)),2.15,2.15,3.3,glass)
cone('Beacon | copper roof',lp+Vector((0,0,28.6)),3.0,.1,2.7,brass)
for i in range(12):
    a=i*math.tau/12
    p=lp+Vector((3.35*math.cos(a),3.35*math.sin(a),25.0))
    cone('Beacon | gallery railing',p,.055,.055,1.8,brass,segments=8)
for z in [5.8,13.5,20]:
    for a in [-math.pi*.5,0,math.pi*.5]:
        r=3.35-z*.045
        q=lp+Vector((r*math.cos(a),r*math.sin(a),z))
        w=box('Beacon | narrow inset window',q,(.65,.18,1.6),brass);w.rotation_euler.z=a+math.pi/2

# Quay entering the water on the sheltered eastern inner shore.
dock=coast(math.radians(112),.025)
for i in range(30):
    box('Quay | individual weathered plank',(dock.x-1-i*.7,dock.y,1.8),(.64,4.8,.23),wood,bevel=.035)
for i in range(0,30,5):
    for side in [-1,1]:
        cone('Quay | submerged pile',(dock.x-1-i*.7,dock.y+side*1.9,-.6),.23,.20,6.2,wood,segments=12)
for i in range(9):
    box('Quay | coastal stone stair',(dock.x+1+i*.60,dock.y,1.4+i*.34),(.75,3,1+i*.68),stone,bevel=.05)
for i in range(5):
    box('Quay | cargo crate',(dock.x-3-i*1.1,dock.y+1.3,2.35),(.85,.8,.85),wood,bevel=.05)

# Existing detailed starter sloop provides a familiar, honest size reference.
ship_path=ROOT/'assets/world/ships/starter_sloop.glb'
if ship_path.exists():
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(ship_path))
    added=set(bpy.data.objects)-before
    root=bpy.data.objects.new('Scale reference | 16 metre trader',None);DETAIL.objects.link(root)
    for o in added:
        move(o,DETAIL)
        if o.parent not in added:o.parent=root
    root.location=(12,-62,.25);root.scale=(2.5,2.5,2.5);root.rotation_euler.z=-.48

sea=material('Lagoon | teal depth, wind ripples and reflection',(.035,.23,.26),.21)
n,l=sea.node_tree.nodes,sea.node_tree.links;p=n.get('Principled BSDF')
p.inputs['IOR'].default_value=1.333;p.inputs['Metallic'].default_value=.18
tc=n.new('ShaderNodeTexCoord')
scale=n.new('ShaderNodeVectorMath');scale.operation='MULTIPLY';scale.inputs[1].default_value=(.16,.31,.2);l.new(tc.outputs['Object'],scale.inputs[0])
ns=n.new('ShaderNodeTexNoise');ns.inputs['Scale'].default_value=1;ns.inputs['Detail'].default_value=3;ns.inputs['Roughness'].default_value=.6;l.new(scale.outputs[0],ns.inputs[0])
bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.28;bump.inputs['Distance'].default_value=.16;l.new(ns.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal'])
dist=n.new('ShaderNodeVectorMath');dist.operation='LENGTH';l.new(tc.outputs['Object'],dist.inputs[0])
div=n.new('ShaderNodeMath');div.operation='DIVIDE';div.inputs[1].default_value=440;l.new(dist.outputs['Value'],div.inputs[0])
r=n.new('ShaderNodeValToRGB');r.color_ramp.elements[0].position=.27;r.color_ramp.elements[0].color=(.035,.32,.27,1);r.color_ramp.elements[1].position=1;r.color_ramp.elements[1].color=(.012,.078,.12,1)
l.new(div.outputs[0],r.inputs[0]);l.new(r.outputs[0],p.inputs['Base Color'])
water=mesh('Presentation ocean | separate from island', [(-12000,-12000,-.7),(12000,-12000,-.7),(12000,12000,-.7),(-12000,12000,-.7)],[(0,1,2,3)],[sea],SEA)
foam=material('Thin broken shoreline wash',(.72,.85,.74),.35)
for edge in [.016,.984]:
    for segment in range(32):
        start=-LIMIT+(2*LIMIT)*segment/32
        pts=[]
        for k in range(8):
            a=start+(2*LIMIT)/32*k/9
            p=coast(a,edge);p.z=-.48+random.uniform(-.04,.04);pts.append(p)
        tube('Broken surf line',pts,random.uniform(.10,.21),foam,SEA)

# Two views: harbour approach and an elevated editable modelling overview.
def camera(name,pos,target,lens):
    d=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,d);STUDIO.objects.link(o);o.location=pos
    o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();d.lens=lens;d.clip_end=10000;return o
cam=camera('01 | Cove approach', (570,-930,540), (0,36,87), 47)
camera('02 | Harbour eye level', (320,-760,150), (0,40,124), 42)
scene.camera=cam
sun_data=bpy.data.lights.new('Warm high sun','SUN');sun_data.energy=2.2;sun_data.angle=.18
sun=bpy.data.objects.new('Warm high sun',sun_data);STUDIO.objects.link(sun);sun.rotation_euler=(math.radians(29),math.radians(-24),math.radians(-32))
world=bpy.data.worlds.new('Clear coastal sky');scene.world=world;world.use_nodes=True
n=world.node_tree.nodes;n.get('Background').inputs['Color'].default_value=(.32,.45,.62,1);n.get('Background').inputs['Strength'].default_value=.45

scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.cycles.max_bounces=5;scene.cycles.diffuse_bounces=2;scene.cycles.glossy_bounces=2
scene.render.resolution_x=1280;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(PREVIEW/'karst_cove_approach.png')
scene.render.threads_mode='FIXED';scene.render.threads=8
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'

# Save an immediately usable viewport: centred model, textured material colours,
# no huge light/camera gizmos or grid crossing the island.
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            s=area.spaces.active;s.clip_end=10000;s.lens=47
            s.overlay.show_floor=False;s.overlay.show_axis_x=False;s.overlay.show_axis_y=False
            s.overlay.show_extras=False
            s.shading.type='SOLID';s.shading.color_type='MATERIAL';s.shading.light='STUDIO'
            s.shading.show_cavity=True;s.shading.cavity_type='BOTH';s.shading.curvature_ridge_factor=1.25;s.shading.curvature_valley_factor=1.05
            s.region_3d.view_distance=710;s.region_3d.view_location=(0,30,75)
            s.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
            s.region_3d.view_perspective='PERSP'
bpy.ops.object.select_all(action='DESELECT')
bpy.context.view_layer.objects.active=land
for img in bpy.data.images:
    if img.source=='FILE':
        try:img.pack()
        except Exception:pass
scene['reference_art']='assets/ui/concepts/main_hud_concept_v1.png'
scene['vegetation_instances']=len(FOREST.objects)
scene['cliff_meshes']=len(cliffs)
blend=SOURCE/'karst_cove.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
print('BLEND_SAVED',blend,flush=True)
bpy.ops.render.render(write_still=True)
print('RENDER_SAVED',scene.render.filepath,flush=True)
