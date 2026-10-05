"""Curved detailed palm fronds and waterline-correct finger piers."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
source=ROOT/'assets/world/islands/home_island/source/home_island.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
material=bpy.data.materials.new('Detailed tropical palm spray'); material.use_nodes=True
material.surface_render_method='DITHERED'; material.use_backface_culling=False
shader=material.node_tree.nodes.get('Principled BSDF'); shader.inputs['Roughness'].default_value=.72
tex=material.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=bpy.data.images.load(str(ROOT/'assets/world/materials/textures/tropical_palm_frond.png')); tex.image.pack()
material.node_tree.links.new(tex.outputs['Color'],shader.inputs['Base Color']); material.node_tree.links.new(tex.outputs['Alpha'],shader.inputs['Alpha'])
for obj in list(bpy.context.scene.objects):
    if obj.name.startswith('Finger pier teak planks'):obj.location.z=.24
    if not obj.name.startswith('Curved palm frond'):continue
    p=[v.co.copy() for v in obj.data.vertices]; start=p[0]; tip=p[2]; direction=tip-start
    flat=Vector((direction.x,direction.y,0)); length=flat.length; flat.normalize(); side=Vector((-flat.y,flat.x,0))
    verts=[]; faces=[]; uvs=[]
    for j in range(13):
        t=j/12; center=start+flat*length*t
        center.z=start.z+.65*math.sin(t*math.pi)-1.6*t*t
        width=.80*math.sin(t*math.pi)**.35+.05
        for k in range(3):
            across=k/2-.5; q=center+side*(across*width*2)
            q.z-=abs(across)*.16
            verts.append(tuple(q)); uvs.append((k/2,t))
    for j in range(12):
        for k in range(2):
            b=j*3+k; faces.append((b,b+1,b+4,b+3))
    data=bpy.data.meshes.new('Curved botanical palm leaflets'); data.from_pydata(verts,[],faces); data.update(); data.materials.append(material)
    uv=data.uv_layers.new()
    for polygon in data.polygons:
        polygon.use_smooth=True
        for loop in polygon.loop_indices:uv.data[loop].uv=uvs[data.loops[loop].vertex_index]
    obj.data=data; obj.name='Textured curved palm frond'
bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
bpy.ops.object.select_all(action='SELECT'); bpy.context.view_layer.objects.active=next(o for o in bpy.context.scene.objects if o.type=='MESH')
bpy.ops.object.join(); bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.export_scene.gltf(filepath=str(source.parent.parent/'home_island.glb'),export_format='GLB',use_selection=True)
p=ROOT/'data/world/home_base_visuals.json'; data=json.loads(p.read_text(encoding='utf-8-sig'))
data['placements']['dock'][3]=-.06; data['placements']['fishing_wharf'][3]=-.06
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('DETAILED_PALMS_AND_LOW_QUAYS_READY')
