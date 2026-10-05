"""Reference 2/3 environmental revision. Run after existing harbor builders."""
import bpy, bmesh, math, random
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
random.seed(203)
CLIFFS=[(-43,-25,15,22),(-23,-42,18,30),(0,-47,17,35),(26,-40,16,26),(44,-23,13,19),(-47,16,8,13),(48,18,8,14)]

def material(name,color):
    existing=bpy.data.materials.get('Illustrated '+name)
    if existing:return existing
    m=bpy.data.materials.new('Illustrated '+name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Roughness'].default_value=.9
    return m

def mesh(name,v,f,m):
    d=bpy.data.meshes.new(name); d.from_pydata(v,[],f); d.update(); d.materials.append(m)
    o=bpy.data.objects.new(name,d); bpy.context.collection.objects.link(o); return o

def curve(name,points,width,m):
    d=bpy.data.curves.new(name,'CURVE'); d.dimensions='3D'; d.resolution_u=8; d.bevel_depth=width; d.bevel_resolution=2
    s=d.splines.new('BEZIER'); s.bezier_points.add(len(points)-1)
    for i,(b,p) in enumerate(zip(s.bezier_points,points)):
        b.co=p; b.handle_left_type='AUTO'; b.handle_right_type='AUTO'; b.radius=1-i*.18
    o=bpy.data.objects.new(name,d); bpy.context.collection.objects.link(o); d.materials.append(m)
    return o

def foliage(center,dimensions,m,name='Illustrated sculpted crown'):
    d=bpy.data.meshes.new(name); bm=bmesh.new(); bmesh.ops.create_icosphere(bm,subdivisions=2,radius=1); bm.to_mesh(d); bm.free()
    o=bpy.data.objects.new(name,d); bpy.context.collection.objects.link(o); o.location=center; o.scale=Vector(dimensions)*.5
    for v in o.data.vertices:
        v.co*=1+.055*math.sin(v.co.x*8+v.co.y*5+v.co.z*11)
    o.data.materials.append(m)
    for p in o.data.polygons:p.use_smooth=True
    o.select_set(False)

def path(points,width,m,name='Mountain switchback footpath'):
    v=[]
    for i,p in enumerate(points):
        tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
        side=Vector((-tangent.y,tangent.x,0)).normalized()*width*.5
        v.extend([tuple(Vector(p)+side),tuple(Vector(p)-side)])
    return mesh(name,v,[(i*2,i*2+1,i*2+3,i*2+2) for i in range(len(points)-1)],m)

def export(source,target):
    bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
    bpy.ops.object.select_all(action='DESELECT')
    for o in bpy.context.scene.objects:
        if o.type in ['MESH','CURVE']:o.select_set(True)

    bpy.context.view_layer.objects.active=next(o for o in bpy.context.scene.objects if o.type=='MESH')
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True)

for rel in ['islands/home_island','islands/sky_harbor','ports/home_base']:
    name={'islands/home_island':'home_island','islands/sky_harbor':'sky_harbor','ports/home_base':'city_quarter'}[rel]
    source=ROOT/'assets/world'/rel/'source'/f'{name}.blend'
    bpy.ops.wm.open_mainfile(filepath=str(source)); bpy.ops.object.select_all(action='DESELECT')
    jade=material('jade foliage',(.12,.36,.26)); sun=material('sunlit foliage',(.30,.47,.20)); bark=material('curved bark',(.25,.17,.10)); paving=material('path sandstone',(.56,.57,.40))
    cliff_index=0
    for o in list(bpy.context.scene.objects):
        if any(o.name.startswith(n) for n in ['Mountain switchback footpath','Harbor neighborhood footpath','Port ancillary shed','Shed pitched tiled roof','Fishing rack rail']):bpy.data.objects.remove(o,do_unlink=True)
    for o in list(bpy.context.scene.objects):
        if 'Buttress root' in o.name:
            bpy.data.objects.remove(o,do_unlink=True); continue
        if o.type!='MESH':continue
        for slot in o.material_slots:
            if slot.material and 'meadow' in slot.material.name.lower():slot.material=material('terrace meadow',(.24,.40,.22))
        if any(t in o.name for t in ['Textured broadleaf crown','Layered broadleaf canopy']):
            bounds=[o.matrix_world@Vector(c) for c in o.bound_box]
            lo=Vector(tuple(min(p[k] for p in bounds) for k in range(3))); hi=Vector(tuple(max(p[k] for p in bounds) for k in range(3)))
            foliage((lo+hi)*.5,hi-lo,jade if random.random()<.7 else sun)
            bpy.data.objects.remove(o,do_unlink=True)
        elif any(t in o.name for t in ['Rooted rainforest trunk','Tall coastal palm']):
            z=[v.co.z for v in o.data.vertices]; a=o.matrix_world@Vector((0,0,min(z))); b=o.matrix_world@Vector((0,0,max(z)))
            h=(b-a).length; bend=Vector((math.sin(a.x)*h*.09,math.cos(a.y)*h*.06,0))
            curve('Bezier curved tree trunk',[a,a.lerp(b,.35)+bend,a.lerp(b,.72)+bend*.8,b],.18,bark)
            bpy.data.objects.remove(o,do_unlink=True)
        elif 'Stratified monumental cliff' in o.name:
            x,y,r,h=CLIFFS[cliff_index]; cliff_index+=1
            verts=[]; faces=[]; count=64; rows=13
            for j in range(rows):
                t=j/(rows-1); z=-5+(h+5)*t
                scale=1-.48*t+.025*math.sin(t*math.pi*5)
                for i in range(count):
                    a=i*math.tau/count; wave=1+.045*math.sin(a*5+cliff_index)+.022*math.sin(a*11+t*4)
                    verts.append((x+r*scale*wave*math.cos(a),y+r*scale*wave*math.sin(a),z+.15*math.sin(a*3)*t))
            for j in range(rows-1):
                for i in range(count):faces.append((j*count+i,j*count+(i+1)%count,(j+1)*count+(i+1)%count,(j+1)*count+i))
            faces.extend([tuple(reversed(range(count))),tuple(range((rows-1)*count,rows*count))])
            d=bpy.data.meshes.new('Closed submerged cliff'); d.from_pydata(verts,[],faces); d.materials.append(jade)
            # Keep a cool rock palette, independent of photographic foliage.
            rock=material('layered blue rock',(.23,.34,.33)); d.materials.clear(); d.materials.append(rock); o.data=d
            for p in d.polygons:p.use_smooth=len(p.vertices)==4
    if name=='home_island':
        bpy.context.view_layer.update()
        # Walkable-looking ledges hug the same six ring profiles as the cliffs.
        cliffs=CLIFFS[:5]
        cliff_objects=[o for o in bpy.context.scene.objects if 'Stratified monumental cliff' in o.name]
        for index,(x,y,r,h) in enumerate(cliffs):
            surface=BVHTree.FromObject(cliff_objects[index],bpy.context.evaluated_depsgraph_get())
            points=[]
            for i in range(81):
                t=i/80; a=-math.pi*.5+t*math.pi*2.1; z=1.15+t*h*.65
                rr=r*(.98-.22*t)+.6
                radial=Vector((math.cos(a),math.sin(a),0))
                hit,normal,_,_=surface.ray_cast(Vector((x,y,z))+radial*r*2,-radial,r*3)
                if hit is not None:
                    points.append(tuple(hit+radial*.28+Vector((0,0,.09))))
            path(points,1.05,paving)
        for side in [-1,1]:
            path([(side*32,-25+49*t/40,1.15) for t in range(41)],1.5,paving,'Harbor neighborhood footpath')
        for x,y in [(-29,9),(-42,-7),(31,19),(0,-22),(40,-7)]:
            path([(x*t/40+.9*math.sin(t/40*math.pi),1+(y-1)*t/40,1.16) for t in range(41)],1.3,paving,'Harbor neighborhood footpath')
        for i in range(12):
            x=(-1 if i%2 else 1)*(22+i%3*7); y=-16+(i//2)*8
            # Small domestic outbuildings: workshop sheds, shade awnings and racks.
            bpy.ops.mesh.primitive_cube_add(size=1,location=(x,y,1.8)); o=bpy.context.object; o.name='Port ancillary shed'; o.scale=(1.8,1.3,1.4); o.data.materials.append(bark); o.select_set(False)
            mesh('Shed pitched tiled roof',[(x-1.1,y-.8,2.55),(x+1.1,y-.8,2.55),(x,y-.8,3.1),(x-1.1,y+.8,2.55),(x+1.1,y+.8,2.55),(x,y+.8,3.1)],[(0,2,5,3),(2,1,4,5)],jade)
            curve('Fishing rack rail',[(x-1,y+1,1.15),(x-1,y+1,2.3),(x+1,y+1,2.3),(x+1,y+1,1.15)],.055,bark)
    export(source,source.parent.parent/f'{name}.glb')
print('REFERENCE_STYLE_ENVIRONMENT_READY')
