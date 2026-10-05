"""Original game meshes informed by the owner's pine/broadleaf/village videos."""
import bpy, bmesh, math, random, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]

def clear():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)

def mat(name,color,metal=0):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=.85; p.inputs['Metallic'].default_value=metal
    return m

def mesh(name,vertices,faces,material):
    d=bpy.data.meshes.new(name); d.from_pydata(vertices,[],faces); d.update(); d.materials.append(material)
    o=bpy.data.objects.new(name,d); bpy.context.collection.objects.link(o); return o

def ico(name,at,size,material,sub=2):
    d=bpy.data.meshes.new(name); bm=bmesh.new(); bmesh.ops.create_icosphere(bm,subdivisions=sub,radius=1); bm.to_mesh(d); bm.free()
    for v in d.vertices:
        v.co.x*=size[0]; v.co.y*=size[1]; v.co.z*=size[2]
        v.co*=1+.07*math.sin(v.co.x*3.5+v.co.y*4+v.co.z*2)
    o=bpy.data.objects.new(name,d); bpy.context.collection.objects.link(o); o.location=at; d.materials.append(material); return o

def box(name,at,size,material):
    v=[(at[0]+x*size[0]/2,at[1]+y*size[1]/2,at[2]+z*size[2]/2) for z in [-1,1] for y in [-1,1] for x in [-1,1]]
    return mesh(name,v,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],material)

def tube(name,points,width,material):
    d=bpy.data.curves.new(name,'CURVE'); d.dimensions='3D'; d.resolution_u=6; d.bevel_depth=width; d.bevel_resolution=1
    s=d.splines.new('BEZIER'); s.bezier_points.add(len(points)-1)
    for i,(b,p) in enumerate(zip(s.bezier_points,points)):
        b.co=p; b.handle_left_type='AUTO'; b.handle_right_type='AUTO'; b.radius=1-i*.26
    o=bpy.data.objects.new(name,d); bpy.context.collection.objects.link(o); d.materials.append(material); return o

def cylinder(name,at,radius,height,material,top=None,n=16):
    v=[]
    for r,z in [(radius,at[2]-height/2),(radius if top is None else top,at[2]+height/2)]:
        v.extend([(at[0]+r*math.cos(i*math.tau/n),at[1]+r*math.sin(i*math.tau/n),z) for i in range(n)])
    f=[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]+[tuple(reversed(range(n))),tuple(range(n,n*2))]
    return mesh(name,v,f,material)

def save_asset(folder,name):
    folder.mkdir(parents=True,exist_ok=True); (folder/'source').mkdir(exist_ok=True); (folder/'source/.gdignore').touch()
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/'source'/f'{name}.blend'),compress=True)
    bpy.ops.object.select_all(action='SELECT'); bpy.context.view_layer.objects.active=next(o for o in bpy.context.scene.objects if o.type=='MESH')
    bpy.ops.object.convert(target='MESH'); bpy.ops.object.join(); bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bpy.ops.export_scene.gltf(filepath=str(folder/f'{name}.glb'),export_format='GLB',use_selection=True)

SPECIES={'tiered_pine':(.15,.34,.19),'broadleaf_emerald':(.15,.37,.20),'broadleaf_lime':(.36,.53,.20),
         'flowering_rose':(.75,.30,.42),'flowering_lilac':(.61,.36,.72),'flowering_gold':(.72,.58,.22)}

def build_tree(species):
    random.seed(species)
    green=mat('Illustrated '+species,SPECIES[species]); bark=mat('Illustrated forked tree bark',(.30,.21,.12))
    soil=mat('Illustrated tree soil',(.27,.24,.14)); moss=mat('Illustrated tree ground moss',(.22,.40,.16))
    tube('VR Bezier trunk',[(0,0,-.08),(.23,-.13,1.5),(-.10,.12,3.2),(.24,.08,5.5)],.40,bark)
    if species=='tiered_pine':
        for tier in range(5):
            r=1.85-tier*.30; z=1.65+tier*.88; n=16; v=[]
            for row in range(3):
                for i in range(n):
                    a=i*math.tau/n+.12*tier
                    radius=r*(1 if row==0 else .47 if row==1 else .025)*(1 if i%2 else .84)
                    zz=z+(0 if row==0 else 1.10 if row==1 else 1.95)+(.16 if i%2 and row==0 else 0)
                    v.append((radius*math.cos(a)+.10*tier,radius*math.sin(a),zz))
            f=[(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(2) for i in range(n)]
            f.append(tuple(reversed(range(n))))
            o=mesh('VR scalloped pine tier',v,f,green)
            lighter=mat('Illustrated pine sunlit tips',(.26,.43,.24)); o.data.materials.append(lighter)
            for p in o.data.polygons:p.material_index=1 if p.index%7==0 else 0
    else:
        for sign in [-1,1]:tube('VR forked bough',[(.02,0,2.6),(sign*.65,.15,3.9),(sign*1.15,.20,5.1)],.20,bark)
        for i,(x,y,z,r) in enumerate([(-.85,0,5.05,1.7),(.75,.35,5.55,1.85),(.15,-.85,5.0,1.35),(1.65,.18,4.65,.9)]):
            ico('VR faceted leaf cluster',(x,y,z),(r,r*.88,r*1.03),green)
        if species.startswith('flowering'):
            bud=mat('Illustrated blossom highlights',tuple(min(.92,c*1.22+.08) for c in SPECIES[species]))
            for i in range(14):
                a=i*2.399; ico('VR blossom cluster',(math.cos(a)*1.6,math.sin(a)*1.25,5.25+(i%3)*.55),(.18,.18,.15),bud,1)
    n=20; v=[(0,0,.14)]
    for i in range(n):
        a=i*math.tau/n; r=1.15*(1+.12*math.sin(i*3.1)); v.append((r*math.cos(a),r*math.sin(a),-.04))
    patch=mesh('VR ground around trunk',v,[(0,i+1,(i+1)%n+1) for i in range(n)],soil)
    patch.data.materials.append(moss)
    for p in patch.data.polygons:p.material_index=1 if p.index%3 else 0
    rock=mat('Illustrated tree pebbles',(.37,.43,.36))
    for x,y in [(-.85,.65),(.80,-.65)]:ico('VR ground pebble',(x,y,.1),(.26,.21,.18),rock,1)
    for i in range(8):
        a=i*2.399; x,y=math.cos(a)*.95,math.sin(a)*.95
        mesh('VR grass tuft',[(x-.10,y,0),(x+.10,y,0),(x+.08,y,.42),(x,y-.12,0),(x,y+.12,0),(x+.05,y,.35)],[(0,1,2),(3,4,5)],moss)

def build_lighthouse():
    white=mat('Pale lighthouse limestone',(.77,.76,.63)); paint=mat('Deep ocean painted lighthouse bands',(.13,.28,.33)); brass=mat('Maritime brass',(.58,.40,.16),.45)
    dark=mat('Oiled lighthouse teak',(.20,.13,.07)); roof=mat('Faction lighthouse roof',(.08,.19,.25))
    cylinder('Stepped lighthouse foundation',(0,0,.35),2.1,.8,white,1.8)
    for j in range(8):
        z=.95+j*.69; r=1.35-j*.065
        cylinder('Tapered striped masonry tower',(0,0,z),r,.69,white if j%2==0 else paint,r-.065)
    for z,r in [(1,1.4),(6.3,1.05),(6.65,1.55)]:cylinder('Lighthouse stone cornice',(0,0,z),r,.17,brass,r)
    cylinder('Gallery deck',(0,0,6.67),1.55,.18,dark)
    for i in range(16):
        a=i*math.tau/16; x,y=1.45*math.cos(a),1.45*math.sin(a)
        cylinder('Gallery turned baluster',(x,y,7.0),.035,.62,brass,n=8)
    for i in range(16):
        a=i*math.tau/16; b=(i+1)*math.tau/16
        tube('Gallery handrail',[(1.45*math.cos(a),1.45*math.sin(a),7.31),(1.45*math.cos(b),1.45*math.sin(b),7.31)],.035,brass)
    for i in range(8):
        a=i*math.tau/8; cylinder('Lantern chamber mullion',(.84*math.cos(a),.84*math.sin(a),7.55),.035,1.35,brass,n=8)
    cylinder('Octagonal lantern canopy',(0,0,8.33),1.22,.55,roof,.15,n=8)
    cylinder('Lighthouse finial',(0,0,8.8),.07,.65,brass,.025)
    box('Lighthouse carved door',(0,-1.35,1.12),(.65,.12,1.35),dark)
    for j in range(5):box('Lighthouse entry steps',(0,-1.4-j*.32,.15+(5-j)*.1),(1.2,.36,.18+(5-j)*.2),white)
    for z in [2.5,4.5]:box('Small lighthouse window',(0,-1.20,z),(.28,.08,.55),dark)

def build_lamppost():
    wood=mat('Oiled harbor teak',(.27,.18,.09)); brass=mat('Maritime brass',(.60,.43,.17),.4)
    cylinder('Stone lantern foot',(0,0,.12),.23,.24,brass)
    tube('Curved kerosene lamp post',[(0,0,.2),(0,0,2.1),(.12,0,2.8),(.58,0,2.6)],.06,wood)
    for z in [2.32,2.75]:cylinder('Kerosene lantern cap',(.58,0,z),.18,.10,brass,.13,n=8)
    for i in range(4):
        a=i*math.tau/4; cylinder('Kerosene lantern cage',(.58+.13*math.cos(a),.13*math.sin(a),2.54),.014,.4,brass,n=6)

if __name__=='__main__':
    for species in SPECIES:
        clear(); build_tree(species); save_asset(ROOT/'assets/world/vegetation/video_reference',species)
    clear(); build_lighthouse(); save_asset(ROOT/'assets/world/props/lighthouse','stylized_lighthouse')
    clear(); build_lamppost(); save_asset(ROOT/'assets/world/props/lamps','kerosene_post')
    print('VIDEO_REFERENCE_TREE_AND_LIGHT_MODELS_READY')
