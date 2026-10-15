"""Inventory every supplied asset; produce reproducible labelled contact sheets."""
from pathlib import Path
from collections import Counter
import json, math, hashlib, struct
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'Assets'
OUT = ROOT / 'docs' / 'asset_review'
OUT.mkdir(parents=True, exist_ok=True)
FONT = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 13)

def sheet(name, files, cell=(158,180), columns=7):
    files = sorted(files)
    if not files: return
    per_page = columns * 8
    for page in range(math.ceil(len(files)/per_page)):
        selected = files[page*per_page:(page+1)*per_page]
        canvas = Image.new('RGB',(columns*cell[0], math.ceil(len(selected)/columns)*cell[1]),'#173746')
        d = ImageDraw.Draw(canvas)
        for i,p in enumerate(selected):
            x=(i%columns)*cell[0]; y=(i//columns)*cell[1]
            im=Image.open(p).convert('RGBA'); im.thumbnail((cell[0]-20,cell[1]-58))
            canvas.paste(im,(x+(cell[0]-im.width)//2,y+5+(cell[1]-58-im.height)//2),im)
            label=p.name
            if name=='pack_previews':label=p.parent.name+'/'+p.name
            lines=[]
            while label and len(lines)<2:
                chars=1
                while chars<len(label) and d.textbbox((0,0),label[:chars+1],font=FONT)[2]<cell[0]-12:chars+=1
                lines.append(label[:chars]);label=label[chars:]
            if label:lines[-1]=lines[-1][:-3]+'...'
            for line_no,line in enumerate(lines):d.text((x+6,y+cell[1]-46+line_no*14),line,font=FONT,fill='#ffefc0')
            d.text((x+6,y+cell[1]-17),f'{Image.open(p).size}',font=FONT,fill='#8dc8cc')
        canvas.save(OUT/f'{name}_{page+1:02}.png')

def main():
    records=[]; packs=[]
    for pack in sorted(p for p in ASSETS.iterdir() if p.is_dir()):
        fs=sorted(p for p in pack.rglob('*') if p.is_file() and p.suffix.lower()!='.import' and p.name!='.gdignore')
        exts=Counter(p.suffix.lower() or '[none]' for p in fs)
        sizes=Counter(); modes=Counter(); bad=[]
        for p in fs:
            rec={'path':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
            if p.suffix.lower() in ('.png','.jpg','.jpeg','.gif','.webp'):
                try:
                    with Image.open(p) as im:
                        rec.update(width=im.width,height=im.height,mode=im.mode)
                        sizes[f'{im.width}x{im.height}']+=1; modes[im.mode]+=1
                        im.verify()
                except Exception as e: bad.append(f'{p}: {e}')
            if p.suffix.lower()=='.ogg':
                data=p.read_bytes(); marker=data.find(b'\x01vorbis')
                if marker>=0:
                    channels=data[marker+11];sample_rate=struct.unpack_from('<I',data,marker+12)[0]
                    pages=[];offset=0
                    while True:
                        offset=data.find(b'OggS',offset)
                        if offset<0:break
                        gp=struct.unpack_from('<Q',data,offset+6)[0]
                        if gp<2**63:pages.append(gp)
                        offset+=4
                    rec.update(codec='Ogg Vorbis',sample_rate=sample_rate,channels=channels,duration_seconds=round(max(pages,default=0)/sample_rate,4))
            records.append(rec)
        licenses=[p for p in fs if p.name.lower()=='license.txt']
        texts=[p.read_text(encoding='utf-8-sig',errors='replace') for p in licenses]
        packs.append({'pack':pack.name,'file_count':len(fs),'bytes':sum(p.stat().st_size for p in fs),'extensions':dict(exts),'image_dimensions':dict(sizes),'image_modes':dict(modes),'licenses':[p.relative_to(ROOT).as_posix() for p in licenses],'license_text':texts,'cc0':all('CC0' in t for t in texts) and bool(texts),'image_errors':bad})
    (OUT/'inventory.json').write_text(json.dumps({'packs':packs,'files':records},indent=2),encoding='utf-8')
    previews=[p for p in ASSETS.rglob('*') if p.is_file() and p.name.lower() in ('preview.png','sample.png','preview_kenneynl.png')]
    sheet('pack_previews',previews,(350,285),3)
    base=ASSETS/'PirateStuff'/'PNG'/'Default size'
    sheet('pirate_ships',(base/'Ships').glob('*.png'))
    sheet('pirate_parts',(base/'Ship parts').glob('*.png'))
    sheet('pirate_tiles',(base/'Tiles').glob('*.png'),(114,144),9)
    sheet('pirate_effects',(base/'Effects').glob('*.png'))
    sheet('medals',(ASSETS/'Medals'/'PNG').glob('*.png'))
    sheet('ui',(ASSETS/'UI'/'PNG'/'Default').glob('*.png'))
    sheet('particles',(ASSETS/'Particles'/'PNG (Transparent)').glob('*.png'),(124,148),8)
    sheet('smoke',(ASSETS/'SmokeParticles'/'PNG').rglob('*.png'),(112,132),9)
    foliage=ASSETS/'Foliage'/'PNG'
    sheet('foliage',[p for p in foliage.rglob('*.png') if '2x' not in str(p).lower() and '@2' not in str(p) and 'Retina' not in str(p)],(124,148),8)
    # Every distinct control design in one scale; avoid mechanically duplicated 2x files.
    for style in sorted((ASSETS/'MobileControls'/'Sprites').iterdir()):
        if style.is_dir(): sheet('mobile_controls_'+style.name.lower().replace(' ','_'),(style/'Default').glob('*.png'),(112,132),9)
    cross=[p for p in (ASSETS/'CrossHairs'/'PNG').rglob('*.png') if p.parent.name=='Dark']
    sheet('crosshairs',cross,(90,110),10)
    print(json.dumps([{k:v for k,v in p.items() if k not in ('license_text','image_dimensions','image_modes')} for p in packs],indent=2))

if __name__=='__main__': main()
