"""Export editable environmental sources as one mesh per asset for Godot."""
import bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sources=[ROOT/'assets/world'/p/'source'/f'{n}.blend' for p,n in [('islands/home_island','home_island'),('islands/sky_harbor','sky_harbor'),('ports/home_base','city_quarter')]]
sources += list((ROOT/'assets/world/islands/route_islands/source').glob('green_*.blend'))
for source in sources:
    bpy.ops.wm.open_mainfile(filepath=str(source)); bpy.ops.object.select_all(action='DESELECT')
    for o in bpy.context.scene.objects:
        if o.type in ['MESH','CURVE']:o.select_set(True)
    bpy.context.view_layer.objects.active=next(o for o in bpy.context.scene.objects if o.type=='MESH')
    bpy.ops.object.convert(target='MESH'); bpy.ops.object.join(); bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bpy.ops.export_scene.gltf(filepath=str(source.parent.parent/f'{source.stem}.glb'),export_format='GLB',use_selection=True)
print('ENVIRONMENT_RUNTIME_MESHES_CONSOLIDATED')
