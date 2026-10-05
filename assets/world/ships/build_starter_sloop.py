"""Blender background build: an original, mobile-sized coastal trading sloop.
Run: blender --background --python build_starter_sloop.py -- --preview path.png
Blender +Y is the bow; glTF exports it as Godot -Z. Origin is the waterline.
"""
import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

parser = argparse.ArgumentParser()
parser.add_argument('--preview', type=Path)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
out = Path(__file__).resolve().parent
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
model = bpy.data.collections.new('Sea Trader — Starter Sloop')
bpy.context.scene.collection.children.link(model)

def material(name, rgb, roughness=.65, metallic=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*rgb, 1)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    return mat

navy = material('Deep ocean painted timber', (.028, .10, .14))
wood = material('Warm teak', (.38, .20, .075))
deck_mat = material('Oiled deck planks', (.58, .36, .15))
brass = material('Weathered brass', (.63, .43, .16), .35, .6)
teal = material('Turquoise trim', (.025, .35, .38), .45)
canvas = material('Warm ivory woven canvas', (.88, .81, .62), .9)
rope_mat = material('Hemp rigging', (.24, .19, .12), .95)
dark = material('Seams and iron', (.045, .04, .025), .8)

def own(obj, name, mat):
    obj.name = name
    for col in list(obj.users_collection):
        col.objects.unlink(obj)
    model.objects.link(obj)
    obj.data.materials.append(mat)
    return obj

def mesh(name, vertices, faces, mat):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    model.objects.link(obj)
    obj.data.materials.append(mat)
    return obj

def box(name, at, size, mat, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = own(bpy.context.object, name, mat)
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new('Soft handcrafted edges', 'BEVEL')
        mod.width, mod.segments = bevel, 2
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj

def spar(name, a, b, radius, mat, sides=10):
    a, b = Vector(a), Vector(b)
    vec = b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=vec.length, location=(a+b)/2)
    obj = own(bpy.context.object, name, mat)
    obj.rotation_euler = vec.to_track_quat('Z', 'Y').to_euler()
    return obj

# Closed curved hull: sections run stern to bow; broad beam amidships, pointed bow.
stations = [(-3.0,.43),(-2.7,.72),(-2.1,.92),(-1.2,1.02),(0,1.02),(1.1,.91),(2,.70),(2.7,.40),(3.15,.035)]
section = [(-1,.45),(-.94,.02),(-.65,-.40),(0,-.63),(.65,-.40),(.94,.02),(1,.45)]
vertices = [(x*width,y,z) for y,width in stations for x,z in section]
faces = []
for i in range(len(stations)-1):
    for j in range(len(section)-1):
        a = i*len(section)+j
        faces.append((a,a+1,a+1+len(section),a+len(section)))
faces += [tuple(range(len(section)-1,-1,-1)), tuple((len(stations)-1)*len(section)+j for j in range(len(section)))]
hull = mesh('Sloop curved hull',vertices,faces,navy)
for polygon in hull.data.polygons:
    polygon.use_smooth = True

# Deck strips follow the taper rather than a rectangular block.
for i in range(len(stations)-1):
    y0,w0 = stations[i]
    y1,w1 = stations[i+1]
    for plank in range(10):
        u0,u1 = -1+plank/5+.006,-1+(plank+1)/5-.006
        mesh('Teak deck plank',[(u0*w0,y0,.455),(u1*w0,y0,.455),(u1*w1,y1,.455),(u0*w1,y1,.455)],[(0,1,2,3)],deck_mat)
for side in [-1,1]:
    for level,mat in [(.48,brass),(.16,teal),(-.12,wood)]:
        for i in range(len(stations)-1):
            y0,w0=stations[i]; y1,w1=stations[i+1]
            spar('Hull strake', (side*w0,y0,level),(side*w1,y1,level),.027,mat,6)
    for y,w in stations[1:-1]:
        spar('Bulwark stanchion',(side*w,y,.46),(side*w,y,.72),.024,brass,6)
    for i in range(len(stations)-1):
        y0,w0=stations[i]; y1,w1=stations[i+1]
        spar('Gunwale',(side*w0,y0,.72),(side*w1,y1,.72),.038,wood,8)

box('Cargo hatch',(0,-.65,.49),(1.05,1.05,.10),wood,.025)
for x in [-.38,-.19,0,.19,.38]:
    box('Hatch iron strip',(x,-.65,.555),(.027,.98,.025),dark)
box('Stern cabin',(0,-2.12,.75),(1.10,1.05,.56),teal,.045)
box('Cabin teak roof',(0,-2.12,1.07),(1.25,1.18,.10),wood,.04)
for x in [-.56,.56]:
    box('Cabin brass window frame',(x,-2.13,.81),(.025,.46,.26),brass)
    box('Cabin blue glass',(x*1.025,-2.13,.81),(.012,.37,.19),navy)
box('Rudder',(0,-3.12,-.25),(.12,.40,.78),wood,.03)
spar('Bowsprit',(0,2.55,.52),(0,4.05,.88),.055,wood)
spar('Mainmast',(0,.33,.48),(0,.33,4.7),.065,wood,12)
spar('Mast brass foot',(0,.33,.45),(0,.33,.72),.09,brass)
spar('Main boom',(0,.33,1.03),(0,-2.70,1.12),.04,wood)
spar('Gaff',(0,.33,4.40),(0,-2.05,3.64),.037,wood)

def sail_quad(name, corners, mat, nx=10, nz=10):
    verts=[]
    for j in range(nz+1):
        v=j/nz
        for i in range(nx+1):
            u=i/nx
            p=Vector(corners[0]).lerp(Vector(corners[1]),u).lerp(Vector(corners[3]).lerp(Vector(corners[2]),u),v)
            p.x += .30*math.sin(math.pi*u)*math.sin(math.pi*v)
            verts.append(tuple(p))
    faces=[]
    for j in range(nz):
        for i in range(nx):
            a=j*(nx+1)+i
            faces.append((a,a+1,a+nx+2,a+nx+1))
    obj=mesh(name,verts,faces,mat)
    for poly in obj.data.polygons:
        poly.use_smooth=True
    return obj

main_corners=[(0,.25,1.12),(0,-2.62,1.20),(0,-1.98,3.60),(0,.25,4.34)]
sail_quad('Wind-filled gaff mainsail',main_corners,canvas)
jib=[(0,3.92,.94),(0,1.13,1.15),(0,.35,4.10),(0,.35,4.10)]
sail_quad('Curved triangular jib',jib,canvas,10,8)
for name,corners in [('Main',main_corners),('Jib',jib)]:
    for i in range(4):
        if (Vector(corners[i]) - Vector(corners[(i+1)%4])).length>.01:
            spar(name+' sail reinforced edge',corners[i],corners[(i+1)%4],.017,teal,6)
for tip in [(0,4.05,.88),(0,-2.90,.72),(-.95,.1,.72),(.95,.1,.72)]:
    spar('Standing rigging',tip,(0,.33,4.62),.011,rope_mat,5)
for x,y in [(-.60,-1.36),(.57,1.30)]:
    box('Merchant cargo crate',(x,y,.70),(.48,.52,.48),deck_mat,.02)
    for dx in [-.17,.17]:
        box('Crate binding',(x+dx,y,.70),(.025,.54,.50),dark)
for y in [.94,1.65]:
    bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.19,depth=.44,location=(-.48,y,.69))
    own(bpy.context.object,'Supply barrel',wood)
    for z in [.53,.85]:
        bpy.ops.mesh.primitive_torus_add(major_radius=.193,minor_radius=.016,major_segments=12,minor_segments=4,location=(-.48,y,z))
        own(bpy.context.object,'Barrel hoop',brass)
spar('Stern lantern post',(.45,-2.64,.7),(.45,-2.64,1.42),.02,brass,6)
box('Navigation lantern',(.45,-2.64,1.38),(.15,.15,.22),teal,.02)

# Apply mesh transforms and recalculate outward normals before glTF export.
for obj in model.objects:
    if obj.type=='MESH':
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='DESELECT')
for obj in model.objects:
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(out/'starter_sloop.glb'),export_format='GLB',use_selection=True,export_apply=True,export_yup=True)
triangles=sum(sum(len(p.vertices)-2 for p in obj.data.polygons) for obj in model.objects if obj.type=='MESH')
(out/'starter_sloop_metrics.json').write_text(json.dumps({'triangles':triangles,'objects':len(model.objects),'hull_length_m':6.15,'reference_length_m':6.15,'bow_axis_blender':'+Y','bow_axis_godot':'-Z'},indent=2)+'\n',encoding='utf8')

# A separate preview studio is not exported to the game.
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=32
scene.cycles.use_denoising=True
scene.render.resolution_x=1200
scene.render.resolution_y=900
scene.render.resolution_percentage=100
scene.world.color=(.20,.27,.31)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.62))
floor=bpy.context.object
floor.name='Preview studio floor — not exported'
floor.data.materials.append(material('Studio ocean slate',(.06,.13,.16),.42))
for at,power,size in [((4,-4,8),1200,6),((-5,1,6),900,5),((1,6,7),1400,4)]:
    bpy.ops.object.light_add(type='AREA',location=at)
    light=bpy.context.object
    light.data.energy=power
    light.data.shape='DISK'
    light.data.size=size
    light.rotation_euler=(Vector((0,0,1.5))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(10,-12,8))
camera=bpy.context.object
camera.rotation_euler=(Vector((0,.35,1.65))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO'
camera.data.ortho_scale=10.4
scene.camera=camera
scene.view_settings.view_transform='AgX'
(out/'source').mkdir(exist_ok=True)
(out/'source'/'.gdignore').write_text('',encoding='utf8')
bpy.ops.wm.save_as_mainfile(filepath=str(out/'source'/'starter_sloop.blend'))
if args.preview:
    args.preview.parent.mkdir(parents=True,exist_ok=True)
    scene.render.filepath=str(args.preview)
    bpy.ops.render.render(write_still=True)
print('SEA_TRADER_SLOOP_BUILD',triangles,'triangles')
