from pathlib import Path
from PIL import Image, ImageDraw
root=Path(__file__).resolve().parents[1]/'addon/Sunder/Media/Icons'
for name in ('favorite','pin','lock'):
    image=Image.open(root/(name+'.tga')).convert('RGBA')
    if name=='lock':
        scale=image.width/32
        ImageDraw.Draw(image).rounded_rectangle(tuple(round(v*scale) for v in (7,14,25,27)),radius=max(1,round(2*scale)),fill=(255,255,255,255))
    else:
        alpha=image.getchannel('A')
        mask=alpha.point(lambda value:255 if value>64 else 0)
        ImageDraw.floodfill(mask,(0,0),128)
        fill=mask.point(lambda value:255 if value==0 else 0)
        image.paste((255,255,255,255),(0,0,image.width,image.height),fill)
    image.save(root/(name+'-filled.tga'))
print('Rebuilt selected action textures from existing silhouettes.')

# Distinct semantic header symbols, drawn at 4x for consistent small-size edges.
for name in ('maximize','restore-size','window-menu','roster','dock','collapse-up','collapse-down','info'):
    image=Image.new('RGBA',(128,128));draw=ImageDraw.Draw(image)
    def line(points): draw.line([(x*4,y*4) for x,y in points],fill='white',width=6,joint='curve')
    def box(bounds): draw.rectangle(tuple(v*4 for v in bounds),outline='white',width=6)
    if name=='info':
        draw.ellipse((20,20,108,108),outline='white',width=6)
        draw.ellipse((59,36,69,46),fill='white');line([(16,14),(16,24)])
    elif name=='maximize': box((6,6,26,26))
    elif name=='restore-size':
        line([(11,6),(26,6),(26,21)]);box((6,11,21,26))
    elif name=='window-menu':
        for y in (9,16,23): line([(7,y),(25,y)])
    elif name=='roster':
        draw.ellipse((24,24,56,56),outline='white',width=6)
        draw.arc((12,64,68,116),180,360,fill='white',width=6)
        for y in (10,17,24): line([(20,y),(28,y)])
    elif name=='dock':
        box((5,6,27,26));line([(5,12),(27,12)]);line([(22,20),(11,20),(15,16)]);line([(11,20),(15,24)])
    else:
        points=[(8,19),(16,11),(24,19)] if name=='collapse-up' else [(8,13),(16,21),(24,13)]
        line(points)
    image.resize((32,32),Image.Resampling.LANCZOS).save(root/(name+'.tga'))
print('Rebuilt semantic window action icons.')
