"""Check source geometry invariants before publishing an environmental revision."""
import bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
for folder,name in [('islands/home_island','home_island'),('islands/sky_harbor','sky_harbor'),('ports/home_base','city_quarter')]:
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/world'/folder/'source'/f'{name}.blend'))
    objects=list(bpy.context.scene.objects)
    assert not any('Buttress root' in o.name for o in objects),name
    assert any('Bezier curved tree trunk' in o.name for o in objects),name
    assert not any('Textured broadleaf crown' in o.name for o in objects),name
    if name=='home_island':
        cliffs=[o for o in objects if 'Stratified monumental cliff' in o.name]
        assert len(cliffs)==7
        for cliff in cliffs:
            assert min(v.co.z for v in cliff.data.vertices)<=-4.9,cliff.name
            edges={}
            for face in cliff.data.polygons:
                for edge in face.edge_keys:edges[edge]=edges.get(edge,0)+1
            assert all(count==2 for count in edges.values()),cliff.name
        paths=[o for o in objects if 'Mountain switchback footpath' in o.name]
        assert len(paths)==5 and all(len(o.data.polygons)>40 for o in paths)
        assert len([o for o in objects if 'Port ancillary shed' in o.name])==12
    print('SOURCE_GEOMETRY_OK',name)
for source in (ROOT/'assets/world/islands/route_islands/source').glob('green_*.blend'):
    bpy.ops.wm.open_mainfile(filepath=str(source))
    terrain=bpy.data.objects['Green island with submerged coast']
    assert min(v.co.z for v in terrain.data.vertices)<-2
    assert max(v.co.xy.length for v in terrain.data.vertices)<30
    assert any(p.material_index==1 for p in terrain.data.polygons)
    print('ROUTE_GEOMETRY_OK',source.stem)
print('REFERENCE_ENVIRONMENT_VALIDATED')
