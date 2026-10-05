"""Assemble the current modular capital into a Blender overview, without baking gameplay."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene
data=json.loads((ROOT/'data/world/home_base_visuals.json').read_text(encoding='utf8'))
def import_model(path,name,at=(0,0,0),scale=1,angle=0):
    before=set(scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/path.removeprefix('res://')))
    objects=set(scene.objects)-before
    group=bpy.data.collections.new(name); scene.collection.children.link(group)
    for obj in objects:
        for col in list(obj.users_collection):col.objects.unlink(obj)
        group.objects.link(obj)
        if obj.parent is None:
            obj.location=at; obj.scale=(scale,)*3; obj.rotation_euler.z=math.radians(angle)
    return group
import_model(data['terrain'],'Island — editable terrain source is separate')
for kind,levels in data['buildings'].items():
    x,y,angle,z=data['placements'][kind]; s=data['building_scales'][kind]
    import_model(levels[-1]['scene'],f'{kind} — level 30',(x,y,z),s,angle)
    detail=ROOT/f'assets/world/buildings/details/{kind}.glb'
    if detail.exists():import_model(f'res://assets/world/buildings/details/{kind}.glb',f'{kind} — carved facade and tiles',(x,y,z),s,angle)
    height=(2.8 if kind=='mage_guild' else .72 if kind in ['dock','fishing_wharf'] else 4.1)*s
    import_model('res://assets/world/buildings/styles/humans/architecture.glb',f'{kind} — human architecture',(x,y,z+height),s*.89)
for index,(x,y) in enumerate(data['tower_positions']):
    import_model(data['tower'],f'Island tower {index}',(x,y,1.1),data['tower_scale'])
for index,(x,y,angle,z) in enumerate(data['city_quarters']):
    import_model(data['city_quarter'],f'Civilian quarter {index}',(x,y,z),1,angle)
visuals=json.loads((ROOT/'data/world/ship_visuals.json').read_text(encoding='utf8'))['ships']
sky=json.loads((ROOT/'data/world/sky_harbor_visuals.json').read_text(encoding='utf8'))
import_model(sky['scene'],'Floating archipelago — editable source is separate')
for index,(x,y,z,r) in enumerate(sky['islands']):
    import_model(data['city_quarter'],f'Sky quarter {index}',(x,y,z+.9),.65)
    import_model('res://assets/world/props/heraldry/flagpole.glb',f'Sky flag mast {index}',(x-3,y,z+.9),1.1)
    if index<3:
        ship=visuals[['premium_royal_schooner','premium_golden_clipper','premium_imperial_yacht'][index]]
        import_model(ship['scene'],f'Sky moored ship {index}',(x+5,y-r*.6,z+.2),5.8/ship['length'])
for index,id in enumerate(['ship_barque','ship_schooner','premium_salvage_schooner','premium_royal_schooner','premium_golden_clipper']):
    visual=visuals[id]
    import_model(visual['scene'],f'Visiting merchant {index}',(-15 if index%2==0 else 15,28+(index//2)*9,.1),7/visual['length'],180 if index%2==0 else 0)
flag=bpy.data.materials.new('Canonical human heraldic banner'); flag.use_nodes=True
nodes=flag.node_tree.nodes; links=flag.node_tree.links; image=bpy.data.images.load(str(ROOT/'assets/ui/emblems/humans.png')); image.pack()
tex=nodes.new('ShaderNodeTexImage'); tex.image=image
mix=nodes.new('ShaderNodeMixRGB'); mix.inputs[1].default_value=(.04,.10,.15,1)
links.new(tex.outputs['Alpha'],mix.inputs[0]); links.new(tex.outputs['Color'],mix.inputs[2]); links.new(mix.outputs[0],nodes.get('Principled BSDF').inputs['Base Color'])
for index,(x,y,z) in enumerate(data['flag_positions']):
    import_model('res://assets/world/props/heraldry/flagpole.glb',f'Flag mast {index}',(x,y,z),1.7)
    v=[(x,y,z+8),(x+3.2,y,z+8),(x+3.2,y,z+5.7),(x,y,z+5.7)]
    mesh=bpy.data.meshes.new('Banner cloth'); mesh.from_pydata(v,[],[(0,1,2,3)]); mesh.materials.append(flag)
    obj=bpy.data.objects.new(f'Human crest {index}',mesh); scene.collection.objects.link(obj)
    uv=mesh.uv_layers.new()
    for loop,coord in zip(mesh.polygons[0].loop_indices,[(0,1),(1,1),(1,0),(0,0)]):uv.data[loop].uv=coord
water=bpy.data.materials.new('Preview harbor ocean'); water.diffuse_color=(.025,.24,.31,1)
bpy.ops.mesh.primitive_plane_add(size=1500,location=(0,0,-.08)); bpy.context.object.name='Preview ocean'; bpy.context.object.data.materials.append(water)
bpy.ops.object.light_add(type='AREA',location=(70,20,130)); light=bpy.context.object; light.data.energy=120000; light.data.size=70
light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(30,160,95)); camera=bpy.context.object
camera.rotation_euler=(Vector((0,0,28))-camera.location).to_track_quat('-Z','Y').to_euler(); camera.data.type='ORTHO'; camera.data.ortho_scale=180; scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=32; scene.render.resolution_x=1440; scene.render.resolution_y=960
scene.world.color=(.22,.28,.32); scene.view_settings.view_transform='AgX'
texture_folder=ROOT/'assets/world/materials/textures'
for material in bpy.data.materials:
    if not material.use_nodes:continue
    name=material.name.lower(); kind=''
    if 'basalt' in name:kind='basalt'
    elif 'limestone' in name or 'sandstone' in name:kind='limestone'
    elif 'teak' in name:kind='timber'
    elif 'meadow' in name:kind='foliage'
    if not kind:continue
    image=bpy.data.images.load(str(texture_folder/(kind+'_game_albedo.png')),check_existing=True); image.pack()
    nodes=material.node_tree.nodes; links=material.node_tree.links
    tex=nodes.new('ShaderNodeTexImage'); tex.image=image; tex.projection='BOX'; tex.projection_blend=.35
    coord=nodes.new('ShaderNodeTexCoord'); links.new(coord.outputs['Generated'],tex.inputs['Vector'])
    links.new(tex.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])
path=ROOT/'assets/world/ports/home_base/source/home_base_maximum.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(path),compress=True)
print('HARBOR_CITY_BLENDER_OVERVIEW_READY',str(path))
