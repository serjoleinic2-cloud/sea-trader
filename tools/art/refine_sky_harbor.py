"""Soften floating basalt geometry without changing island or berth positions."""
import bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
source=ROOT/'assets/world/islands/sky_harbor/source/sky_harbor.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
for obj in list(bpy.context.scene.objects):
    if obj.type!='MESH':continue
    if obj.name.startswith('Suspended basalt island'):
        bpy.context.view_layer.objects.active=obj
        mod=obj.modifiers.new('Rounded eroded basalt','SUBSURF'); mod.levels=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
        texture=bpy.data.textures.new('Floating rock erosion',type='CLOUDS'); texture.noise_scale=1.2
        mod=obj.modifiers.new('Natural stone irregularity','DISPLACE'); mod.texture=texture; mod.strength=.45
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if obj.name.startswith(('Suspended basalt','Layered broadleaf','Rooted rainforest')):
        for polygon in obj.data.polygons:polygon.use_smooth=True
bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active=next(o for o in bpy.context.scene.objects if o.type=='MESH')
bpy.ops.object.join(); bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.export_scene.gltf(filepath=str(source.parent.parent/'sky_harbor.glb'),export_format='GLB',use_selection=True)
print('SMOOTH_SKY_HARBOR_READY')
