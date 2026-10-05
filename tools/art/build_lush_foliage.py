"""Replace solid canopy blobs with textured curved leaf sprays in editable sources."""
import bpy, math, random
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
random.seed(932)
sources=[ROOT/'assets/world/islands/home_island/source/home_island.blend',ROOT/'assets/world/islands/sky_harbor/source/sky_harbor.blend',ROOT/'assets/world/ports/home_base/source/city_quarter.blend']
for source in sources:
    bpy.ops.wm.open_mainfile(filepath=str(source))
    material=bpy.data.materials.new('Detailed tropical leaf spray'); material.use_nodes=True
    material.surface_render_method='DITHERED'; material.diffuse_color=(.4,.65,.3,1)
    material.use_backface_culling=False
    nodes=material.node_tree.nodes; shader=nodes.get('Principled BSDF')
    image=bpy.data.images.load(str(ROOT/'assets/world/materials/textures/tropical_leaf_spray.png')); image.pack()
    tex=nodes.new('ShaderNodeTexImage'); tex.image=image
    material.node_tree.links.new(tex.outputs['Color'],shader.inputs['Base Color'])
    material.node_tree.links.new(tex.outputs['Alpha'],shader.inputs['Alpha'])
    shader.inputs['Roughness'].default_value=.72
    total=0
    for obj in list(bpy.context.scene.objects):
        if not obj.name.startswith('Layered broadleaf canopy') or obj.type!='MESH':continue
        rx,ry,rz=[float(d)/2 for d in obj.dimensions]
        verts=[]; faces=[]; uvcoords=[]
        count=max(24,min(72,int(rx*ry*12)))
        for index in range(count):
            a=random.random()*math.tau; v=random.uniform(-.7,.95); ring=math.sqrt(1-v*v)
            p=Vector((math.cos(a)*rx*ring,math.sin(a)*ry*ring,v*rz))*random.uniform(.35,1.02)
            normal=Vector((math.cos(a)*.55,math.sin(a)*.55,random.uniform(.5,1))).normalized()
            rotation=normal.to_track_quat('Z','Y'); size=random.uniform(.85,1.45); offset=len(verts)
            for y in range(3):
                for x in range(3):
                    u,w=x/2,y/2
                    q=Vector(((u-.5)*size,(w-.5)*size*1.2,math.sin(u*math.pi)*math.sin(w*math.pi)*.15))
                    verts.append(tuple(p+rotation@q)); uvcoords.append((u,w))
            for y in range(2):
                for x in range(2):
                    b=offset+y*3+x; faces.append((b,b+1,b+4,b+3))
        mesh=bpy.data.meshes.new('Curved individual jungle leaf sprays'); mesh.from_pydata(verts,[],faces); mesh.update()
        uv=mesh.uv_layers.new()
        for poly in mesh.polygons:
            poly.use_smooth=True
            for loop in poly.loop_indices:uv.data[loop].uv=uvcoords[mesh.loops[loop].vertex_index]
        mesh.materials.append(material); obj.data=mesh; obj.name='Textured broadleaf crown'; total+=count
    bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
    bpy.ops.object.select_all(action='DESELECT')
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join(); bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    path=source.parent.parent/(source.stem+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_image_format='AUTO')
    print('TEXTURED_FOLIAGE_READY',source.stem,total,'curved leaf sprays')
