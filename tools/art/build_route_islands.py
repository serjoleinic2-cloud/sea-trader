"""Closed, green route islands inside the unchanged navigation radius."""
import bpy, math, random
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
folder=ROOT/'assets/world/islands/route_islands'; (folder/'source').mkdir(parents=True,exist_ok=True)
(folder/'source/.gdignore').touch()
for variant in range(3):
    random.seed(72+variant); bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    materials=[]
    for name,color in [('Illustrated rock',(.25,.36,.35)),('Illustrated moss',(.21,.39,.22)),('Illustrated beach',(.64,.63,.45)),('Illustrated jade crowns',(.12,.32,.24)),('Illustrated tree bark',(.27,.18,.10))]:
        m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
        p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Roughness'].default_value=.9; materials.append(m)
    def height(x,y):
        return .6+sum(h*math.exp(-((x-px)**2+(y-py)**2)/w**2) for px,py,h,w in [(-9+variant*3,-8,17,7),(8,-3-variant*2,22,6),(1,9,13,7)])
    v=[]; faces=[]; N=96; rings=25
    for j in range(rings):
        t=j/(rings-1)
        for i in range(N):
            a=i*math.tau/N
            r=t*(26+1.4*math.sin(a*3+variant)+.8*math.sin(a*7))
            x,y=r*math.cos(a),r*math.sin(a)
            z=height(x,y)*(1-max(0,(t-.85)/.15)) if t<.99 else -2.4
            v.append((x,y,z))
    for j in range(rings-1):
        for i in range(N):faces.append((j*N+i,(j+1)*N+i,(j+1)*N+(i+1)%N,j*N+(i+1)%N))
    faces.append(tuple(reversed(range((rings-1)*N,rings*N))))
    d=bpy.data.meshes.new('Sculpted coastal ridges'); d.from_pydata(v,[],faces); d.update()
    for m in materials[:3]:d.materials.append(m)
    o=bpy.data.objects.new('Green island with submerged coast',d); bpy.context.collection.objects.link(o)
    for p in d.polygons:
        z=p.center.z; p.material_index=2 if z<.65 else (0 if p.normal.z<.15 else 1); p.use_smooth=True
    for k in range(65):
        a=k*2.399; r=3+19*(k%17)/17; x,y=math.cos(a)*r,math.sin(a)*r; z=height(x,y)
        # Curve trunks are tapered, gently bent, and rooted below the surface.
        c=bpy.data.curves.new('Bezier tree','CURVE'); c.dimensions='3D'; c.resolution_u=5; c.bevel_depth=.12; c.bevel_resolution=1
        s=c.splines.new('BEZIER'); s.bezier_points.add(2)
        h=2.5+k%3*.6
        for b,p,rad in zip(s.bezier_points,[(x,y,z-.2),(x+.3,y-.2,z+h*.55),(x+.1,y+.2,z+h)],[1,.8,.45]):b.co=p; b.handle_left_type='AUTO'; b.handle_right_type='AUTO'; b.radius=rad
        trunk=bpy.data.objects.new('Curved trunk',c); bpy.context.collection.objects.link(trunk); c.materials.append(materials[4])
        for tier in range(3):
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=(x+.1,y+.2,z+h-.5+tier*.65))
            crown=bpy.context.object; crown.name='Tiered jade foliage'; crown.scale=(1.35-tier*.25,1.15-tier*.2,.85); crown.data.materials.append(materials[3])
            for p in crown.data.polygons:p.use_smooth=True
    # A narrow coastal walking route between the green ridges.
    pv=[]
    for i in range(121):
        a=i*math.tau/120; r=17+1.3*math.sin(a*3+variant)
        for edge in [-.28,.28]:
            x,y=(r+edge)*math.cos(a),(r+edge)*math.sin(a)
            pv.append((x,y,height(x,y)+.16))
    pd=bpy.data.meshes.new('Coastal trail'); pd.from_pydata(pv,[],[(i*2,i*2+1,i*2+3,i*2+2) for i in range(120)]); pd.materials.append(materials[2])
    po=bpy.data.objects.new('Winding coastal footpath',pd); bpy.context.collection.objects.link(po)
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/'source'/f'green_{variant}.blend'),compress=True)
    # Keep editable sources separate; the runtime uses consolidated meshes.
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.convert(target='MESH'); bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bpy.ops.export_scene.gltf(filepath=str(folder/f'green_{variant}.glb'),export_format='GLB')
print('THREE_GREEN_ROUTE_ISLANDS_READY')
