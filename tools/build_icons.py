from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
master=Image.open(ROOT/'assets/branding/Sunder-master.png').convert('RGBA')
brand=ROOT/'addon/Sunder/Media/Brand';brand.mkdir(exist_ok=True)
for size,name in [(256,'SunderIcon'),(64,'SunderMinimap'),(512,'SunderSettings')]:
    master.resize((size,size),Image.Resampling.LANCZOS).save(brand/(name+'.tga'),compression=None)
master.resize((512,512),Image.Resampling.LANCZOS).save(ROOT/'assets/branding/Sunder-project-icon.png')
master.resize((256,256),Image.Resampling.LANCZOS).save(ROOT/'addon/Sunder/Media/Icon.tga',compression=None)
print('Rebuilt Sunder texture derivatives from the preserved master.')
