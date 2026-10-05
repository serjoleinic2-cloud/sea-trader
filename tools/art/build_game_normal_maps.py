"""Derive subtle matching relief from authored game albedo maps."""
import bpy, numpy as np
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; folder=ROOT/'assets/world/materials/textures'
for kind in ['basalt','limestone','timber']:
    image=bpy.data.images.load(str(folder/(kind+'_game_albedo.png')))
    w,h=image.size; pixels=np.array(image.pixels[:],dtype=np.float32).reshape(h,w,4)
    height=pixels[:,:,:3].mean(axis=-1)
    height=(height+np.roll(height,1,0)+np.roll(height,-1,0)+np.roll(height,1,1)+np.roll(height,-1,1))/5
    dx=(np.roll(height,-1,1)-np.roll(height,1,1))*3; dy=(np.roll(height,-1,0)-np.roll(height,1,0))*3
    normal=np.stack((-dx,-dy,np.ones_like(height)),axis=-1); normal/=np.linalg.norm(normal,axis=-1)[:,:,None]
    pixels[:,:,:3]=normal*.5+.5; pixels[:,:,3]=1
    image=bpy.data.images.new(kind+'_game_normal',width=w,height=h,alpha=True)
    image.colorspace_settings.name='Non-Color'; image.pixels.foreach_set(pixels.ravel())
    image.filepath_raw=str(folder/(kind+'_game_normal.png')); image.file_format='PNG'; image.save()
print('AUTHORED_GAME_NORMAL_MAPS_READY')
