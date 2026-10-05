"""Remove waterfall meshes from the separate sky harbor asset and re-export it."""
import bpy
import bmesh
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/world/islands/sky_harbor/source/sky_harbor.blend"
OUTPUT = ROOT / "assets/world/islands/sky_harbor/sky_harbor.glb"
WATER_NAMES = ("vr waterfall", "vr flowing water", "waterfall", "cascade")

bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
removed_faces = 0
for obj in bpy.context.scene.objects:
    if obj.type != "MESH":
        continue
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    doomed = []
    for face in bm.faces:
        slot = face.material_index
        material = obj.data.materials[slot] if slot < len(obj.data.materials) else None
        name = material.name.lower() if material else ""
        if any(token in name for token in WATER_NAMES):
            doomed.append(face)
    removed_faces += len(doomed)
    if doomed:
        bmesh.ops.delete(bm, geom=doomed, context="FACES")
        bm.to_mesh(obj.data)
        obj.data.update()
    bm.free()
    for slot in range(len(obj.data.materials) - 1, -1, -1):
        material = obj.data.materials[slot]
        name = material.name.lower() if material else ""
        has_faces = any(poly.material_index == slot for poly in obj.data.polygons)
        if not has_faces and any(token in name for token in WATER_NAMES):
            obj.data.materials.pop(index=slot)

meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
if not meshes:
    raise RuntimeError("The sky harbor source contains no remaining mesh objects")
bpy.ops.object.select_all(action="DESELECT")
for obj in meshes:
    obj.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE), compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_format="GLB", use_selection=True)
print(f"SKY_HARBOR_WATERFALLS_REMOVED: faces={removed_faces}")
