"""Slice the generated 4x3 production atlases, retaining their real alpha channel."""
from pathlib import Path
from PIL import Image
import numpy as np
ROOT=Path(__file__).resolve().parents[2]/'assets/ui/ports'
names=['dock','warehouse','workshop','market','shipyard','timber_yard','fishing_wharf','mage_guild','annex','tower','scaffold','wall']
for folder in ROOT.iterdir():
    path=folder/'buildings_atlas.png'
    if not path.exists():continue
    image=Image.open(path).convert('RGBA');a=np.array(image.getchannel('A'))
    w,h=image.size
    # Locate quiet transparent gutters near expected grid boundaries. Tall towers
    # can start above an exact one-third cut, so use column-local row gutters.
    xs=[0]
    for col in range(1,4):
        lo,hi=int(w*(col/4-.025)),int(w*(col/4+.025))
        xs.append(lo+int(np.argmin((a[:,lo:hi]>20).sum(axis=0))))
    xs.append(w)
    for col in range(4):
        ys=[0]
        for row in [1,2]:
            lo,hi=int(h*(row/3-.045)),int(h*(row/3+.045))
            ys.append(lo+int(np.argmin((a[lo:hi,xs[col]:xs[col+1]]>20).sum(axis=1))))
        ys.append(h)
        for row in range(3):
            tile=image.crop((xs[col],ys[row],xs[col+1],ys[row+1]))
            bbox=tile.getchannel('A').point(lambda x:255 if x>20 else 0).getbbox()
            if not bbox:raise RuntimeError('Empty sprite: '+str(path))
            tile=tile.crop(bbox)
            result=Image.new('RGBA',(tile.width+8,tile.height+8))
            result.paste(tile,(4,4))
            result.save(folder/(names[row*4+col]+'.png'))
    print(folder.name, '12 sprites, true alpha')
