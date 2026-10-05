import bpy,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/world/ships/source/starter_sloop.blend'))
bpy.ops.object.select_all(action='DESELECT')
objects=[o for c in bpy.data.collections if c.name.startswith('Sea Trader') for o in c.objects if o.type=='MESH']
for obj in objects: obj.select_set(True)
bpy.context.view_layer.objects.active=objects[0]
bpy.ops.object.join()
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/world/ships/starter_sloop.glb'),export_format='GLB',use_selection=True)
for obj in bpy.context.scene.objects:
    if 'studio floor' in obj.name: obj.hide_render=True
scene=bpy.context.scene; scene.render.film_transparent=True
scene.render.resolution_x=480; scene.render.resolution_y=360; scene.cycles.samples=16
scene.render.filepath=str(ROOT/'assets/ui/ships/ship_sloop.png')
bpy.ops.render.render(write_still=True)
path=ROOT/'data/ships/ship_catalog.json'; data=json.loads(path.read_text(encoding='utf-8-sig'))
data['ships'][0]['ui_icon']='res://assets/ui/ships/ship_sloop.png'
path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('SLOOP_OPTIMIZED_AND_PORTRAIT_READY')
