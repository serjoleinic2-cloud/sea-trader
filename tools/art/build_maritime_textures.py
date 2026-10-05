"""Tileable authored bitmap surfaces and tangent normal maps, generated in Blender."""
import bpy, numpy as np
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/world/materials/textures'; OUT.mkdir(parents=True,exist_ok=True)
n=1024; y,x=np.mgrid[0:n,0:n].astype(float)/n; rng=np.random.default_rng(518)
noise=np.zeros((n,n))
for freq in [3,7,17,43,113]:
    for k in range(3):
        a=rng.uniform(0,6.28); noise+=np.sin((x*np.cos(a)+y*np.sin(a))*freq*6.28+rng.uniform(0,6.28))/freq**.45
noise=noise/(abs(noise).max()+.001)
for kind in ['basalt','limestone','timber','plaster','slate','foliage','canvas']:
    h=.5+noise*.15
    if kind in ['limestone','slate']:
        row=np.floor(y*12); u=np.mod(x*8+np.mod(row,2)*.5,1); v=np.mod(y*12,1)
        mortar=(u<.035)|(v<.055); h=np.where(mortar,.14,h+.05*np.sin(row*2.3+np.floor(x*8)*7))
    elif kind=='timber':
        grain=np.sin(x*1800+np.sin(y*35)*2+noise*4)*.065
        h+=grain; h=np.where(np.mod(x*8,1)<.023,.14,h)
    elif kind=='basalt': h+=np.sin(x*55+noise*6)*.06
    elif kind=='canvas':h+=np.sin(x*800)*np.sin(y*800)*.04
    elif kind=='foliage':h+=np.sin(x*240)*np.sin(y*260)*.08
    h=np.clip(h,.04,.95)
    color=np.empty((n,n,4),np.float32); color[:,:,:3]=(.64+h[:,:,None]*.58); color[:,:,3]=1
    if kind=='basalt':color[:,:,1]*=1.035
    if kind=='timber':color[:,:,2]*=.94
    image=bpy.data.images.new(kind+'_albedo',width=n,height=n,alpha=True)
    image.pixels.foreach_set(np.clip(color,0,1).ravel()); image.filepath_raw=str(OUT/(kind+'_albedo.png')); image.file_format='PNG'; image.save()
    dx=(np.roll(h,-1,1)-np.roll(h,1,1))*3; dy=(np.roll(h,-1,0)-np.roll(h,1,0))*3
    normal=np.stack((-dx,-dy,np.ones_like(h)),axis=-1); normal/=np.linalg.norm(normal,axis=-1)[:,:,None]
    color[:,:,:3]=normal*.5+.5
    image=bpy.data.images.new(kind+'_normal',width=n,height=n,alpha=True)
    image.colorspace_settings.name='Non-Color'; image.pixels.foreach_set(color.ravel()); image.filepath_raw=str(OUT/(kind+'_normal.png')); image.file_format='PNG'; image.save()
print('MARITIME_TEXTURES_READY: seven albedo/normal pairs at 1024px')
