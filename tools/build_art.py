"""Deterministic Kenney-compatible art compositions and original procedural audio.

Run from any directory. Fonts and supplied Kenney assets are local inputs. New
vector artwork/audio is CC0; supplied artwork stays under its original CC0.
"""
from pathlib import Path
import json, math, wave, hashlib, re, csv
import xml.etree.ElementTree as ET
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
GEN=ROOT/'assets_generated'; STORE=ROOT/'store'
for p in [GEN/'audio',GEN/'ui',STORE/'achievements',STORE/'leaderboards']: p.mkdir(parents=True,exist_ok=True)
OCEAN='#168a9b'; DEEP='#103d4c'; GOLD='#f9c64b'; CREAM='#fff1c8'; CORAL='#ec6b58'; INK='#113441'
S=3

def font(size,body=False):
    p=GEN/'fonts'/('Nunito-SemiBold.ttf' if body else 'LilitaOne-Regular.ttf')
    return ImageFont.truetype(str(p),int(size))

def paste_asset(canvas,path,center,maxsize,rotate=0):
    im=Image.open(ROOT/path).convert('RGBA')
    scale=min(maxsize[0]/im.width,maxsize[1]/im.height)
    im=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS)
    if rotate: im=im.rotate(rotate,Image.Resampling.BICUBIC,expand=True)
    canvas.alpha_composite(im,(round(center[0]-im.width/2),round(center[1]-im.height/2)))

def raster_vector(svg,scale=3):
    """Rasterize our small code-native SVG subset using sampled Bézier paths."""
    tree=ET.fromstring(svg);w=int(tree.get('width'));h=int(tree.get('height'))
    im=Image.new('RGBA',(w*scale,h*scale));d=ImageDraw.Draw(im)
    def paint(el,inherit={}):
        a=dict(inherit);a.update(el.attrib);tag=el.tag.split('}')[-1]
        fill=a.get('fill','black');fill=None if fill=='none' else fill
        stroke=a.get('stroke');stroke=None if stroke=='none' else stroke
        width=round(float(a.get('stroke-width','1'))*scale)
        if tag in ('rect','circle','ellipse'):
            if tag=='rect':
                x=float(a.get('x',0));y=float(a.get('y',0));box=(x*scale,y*scale,(x+float(a['width']))*scale,(y+float(a['height']))*scale)
                d.rectangle(box,fill=fill,outline=stroke,width=width)
            else:
                x=float(a['cx']);y=float(a['cy']);rx=float(a.get('r',a.get('rx',0)));ry=float(a.get('r',a.get('ry',0)))
                d.ellipse(((x-rx)*scale,(y-ry)*scale,(x+rx)*scale,(y+ry)*scale),fill=fill,outline=stroke,width=width)
        if tag=='path':
            tokens=re.findall('[MLHVQTCZ]|[-+]?(?:[0-9]*[.])?[0-9]+',a['d']);i=0;cmd='';pos=(0.,0.);start=pos;control=None;parts=[];points=[]
            def finish(closed=False):
                nonlocal points
                if points:parts.append((points,closed));points=[]
            while i<len(tokens):
                if tokens[i].isalpha():cmd=tokens[i];i+=1
                if cmd=='Z':
                    points.append(start);finish(True);pos=start;control=None;cmd='';continue
                count={'M':2,'L':2,'H':1,'V':1,'Q':4,'T':2,'C':6}[cmd]
                nums=[float(v) for v in tokens[i:i+count]];i+=count
                if cmd=='M':finish();pos=tuple(nums);start=pos;points=[pos];cmd='L';control=None
                elif cmd in ('L','H','V'):
                    pos=tuple(nums) if cmd=='L' else (nums[0],pos[1]) if cmd=='H' else (pos[0],nums[0]);points.append(pos);control=None
                else:
                    p0=pos
                    if cmd=='Q':p1=tuple(nums[:2]);p2=tuple(nums[2:]);control=p1
                    elif cmd=='T':p1=(2*p0[0]-control[0],2*p0[1]-control[1]) if control else p0;p2=tuple(nums);control=p1
                    else:p1=tuple(nums[:2]);p2=tuple(nums[2:4]);p3=tuple(nums[4:]);control=p2
                    for j in range(1,33):
                        t=j/32;u=1-t
                        if cmd=='C':pt=tuple(u*u*u*p0[c]+3*u*u*t*p1[c]+3*u*t*t*p2[c]+t*t*t*p3[c] for c in (0,1))
                        else:pt=tuple(u*u*p0[c]+2*u*t*p1[c]+t*t*p2[c] for c in (0,1))
                        points.append(pt)
                    pos=p3 if cmd=='C' else p2
            finish()
            for pts,closed in parts:
                xy=[(x*scale,y*scale) for x,y in pts]
                if fill and len(xy)>2:d.polygon(xy,fill=fill)
                if stroke:
                    d.line(xy,fill=stroke,width=width,joint='curve')
                    if a.get('stroke-linecap')=='round':
                        for x,y in (xy[0],xy[-1]):d.ellipse((x-width/2,y-width/2,x+width/2,y+width/2),fill=stroke)
        for child in el:paint(child,{k:v for k,v in a.items() if k in ('fill','stroke','stroke-width','stroke-linecap')})
    paint(tree)
    return im.resize((w,h),Image.Resampling.LANCZOS)

def star(d,center,r,fill=GOLD,n=5,inner=.46):
    cx,cy=center; pts=[]
    for k in range(2*n):
        a=-math.pi/2+k*math.pi/n; rr=r if k%2==0 else r*inner
        pts.append((cx+math.cos(a)*rr,cy+math.sin(a)*rr))
    d.polygon(pts,fill=fill)

def waves(d,w,h,step=55,color='#21a0ac'):
    for y in range(0,h+step,step):
        pts=[(x,y+math.sin(x/80+y)*7) for x in range(0,w+20,20)]
        d.line(pts,fill=color,width=3)

def draw_symbol(d,key,box,color=CREAM):
    x,y,w=box
    # Abstract, legible symbols intentionally remain unlocalized.
    if key in ('star','spark','chart'):
        if key=='chart':
            for dx,dy in [(-65,-40),(65,-60),(20,75)]: star(d,(x+dx,y+dy),38,color)
            d.line([(x-65,y-40),(x+65,y-60),(x+20,y+75)],fill=color,width=8)
        else: star(d,(x,y),w*.46,color,n=5 if key=='star' else 8,inner=.45)
    elif key=='anchor':
        d.ellipse((x-23,y-w*.48,x+23,y-w*.48+46),outline=color,width=9)
        d.line((x,y-w*.22,x,y+w*.35),fill=color,width=13)
        d.line((x-62,y-14,x+62,y-14),fill=color,width=13)
        d.arc((x-82,y-22,x+82,y+w*.40),0,180,fill=color,width=13)
        d.polygon([(x-80,y+17),(x-88,y-11),(x-55,y+7)],fill=color)
        d.polygon([(x+80,y+17),(x+88,y-11),(x+55,y+7)],fill=color)
    elif key=='skull':
        d.ellipse((x-70,y-75,x+70,y+48),fill=color)
        d.rectangle((x-38,y+23,x+38,y+79),fill=color)
        for dx in (-29,29): d.ellipse((x+dx-17,y-23,x+dx+17,y+12),fill=DEEP)
        d.polygon([(x,y+10),(x-10,y+30),(x+10,y+30)],fill=DEEP)
        for dx in (-18,18): d.line((x+dx,y+52,x+dx,y+82),fill=DEEP,width=7)
    elif key=='cannons':
        for side in (-1,1):
            pts=[(x+side*18,y+65),(x+side*80,y-64),(x+side*46,y-83),(x-side*15,y+50)]
            d.polygon(pts,fill=color)
        d.ellipse((x-34,y+39,x+34,y+103),fill=GOLD)
    elif key=='chest':
        d.rounded_rectangle((x-89,y-53,x+89,y+70),radius=16,fill='#bd8042')
        d.rectangle((x-89,y-4,x+89,y+12),fill=color)
        for dx in (-55,55): d.rectangle((x+dx-9,y-53,x+dx+9,y+70),fill=color)
        d.rounded_rectangle((x-17,y-17,x+17,y+23),radius=6,fill=GOLD)
        d.ellipse((x-5,y-8,x+5,y+3),fill=DEEP)
    elif key=='shield':
        d.polygon([(x-76,y-63),(x+76,y-63),(x+64,y+37),(x,y+99),(x-64,y+37)],fill=color)
        star(d,(x,y+5),41,GOLD)
    elif key=='flame':
        d.polygon([(x,y-99),(x+27,y-18),(x+62,y-55),(x+78,y+29),(x+43,y+78),(x-28,y+87),(x-74,y+34),(x-57,y-32),(x-20,y+5)],fill=CORAL)
        d.polygon([(x+4,y-19),(x+35,y+39),(x+18,y+69),(x-27,y+66),(x-34,y+38)],fill=GOLD)
    elif key=='snow':
        for k in range(6):
            a=k*math.pi/3; ux,uy=math.cos(a),math.sin(a)
            d.line((x,y,x+80*ux,y+80*uy),fill=color,width=12)
            bx,by=x+52*ux,y+52*uy
            for offset in (-1,1):
                b=a+offset*math.pi/3
                d.line((bx,by,bx-25*math.cos(b),by-25*math.sin(b)),fill=color,width=9)
    elif key=='crown':
        d.polygon([(x-83,y-37),(x-43,y+2),(x,y-75),(x+43,y+2),(x+83,y-37),(x+68,y+70),(x-68,y+70)],fill=GOLD)
        d.rectangle((x-68,y+55,x+68,y+79),fill=CREAM)
        for dx in (-76,0,76): d.ellipse((x+dx-10,y-55-(35 if dx==0 else 0),x+dx+10,y-35-(35 if dx==0 else 0)),fill=CREAM)
    elif key=='clock':
        d.ellipse((x-80,y-80,x+80,y+80),fill=color)
        d.ellipse((x-64,y-64,x+64,y+64),fill=DEEP)
        d.line((x,y-42,x,y,x+39,y+15),fill=GOLD,width=12)
        d.ellipse((x-10,y-10,x+10,y+10),fill=GOLD)
    elif key=='bolt':
        d.polygon([(x+6,y-101),(x-68,y+16),(x-9,y+16),(x-16,y+102),(x+74,y-25),(x+18,y-25)],fill=GOLD)
    elif key=='heart':
        d.ellipse((x-81,y-64,x+9,y+26),fill=CORAL)
        d.ellipse((x-9,y-64,x+81,y+26),fill=CORAL)
        d.polygon([(x-78,y-5),(x+78,y-5),(x,y+89)],fill=CORAL)
    elif key=='calendar':
        d.rounded_rectangle((x-76,y-69,x+76,y+77),radius=15,fill=color)
        d.rectangle((x-76,y-47,x+76,y-15),fill=CORAL)
        for dx in (-39,39): d.rounded_rectangle((x+dx-7,y-85,x+dx+7,y-44),radius=7,fill=GOLD)
        star(d,(x,y+28),37,GOLD)
    elif key=='wave':
        for dy in (-38,12,60):
            pts=[(x+xx,y+dy+math.sin(xx/34)*15) for xx in range(-93,94,6)]
            d.line(pts,fill=color,width=13)
    elif key=='leaf':
        d.ellipse((x-65,y-95,x+65,y+87),fill='#7dda85')
        d.line((x,y-66,x,y+77),fill=DEEP,width=10)
        for dy in (-28,15,56): d.line((x,dy+y,x+39,y+dy-32),fill=DEEP,width=8)
    elif key=='chain':
        for dx in (-47,47): d.rounded_rectangle((x+dx-55,y-26,x+dx+55,y+33),radius=28,outline=color,width=14)
    elif key=='fleet':
        for dx,dy in [(-64,23),(0,-45),(64,23)]:
            d.polygon([(x+dx-36,y+dy+33),(x+dx+36,y+dy+33),(x+dx,y+dy+60)],fill=GOLD)
            d.polygon([(x+dx,y+dy-52),(x+dx,y+dy+18),(x+dx+40,y+dy+18)],fill=color)
    elif key=='trophy':
        d.polygon([(x-58,y-70),(x+58,y-70),(x+43,y+22),(x,y+45),(x-43,y+22)],fill=GOLD)
        d.arc((x-92,y-68,x-26,y+15),75,285,fill=CREAM,width=12)
        d.arc((x+26,y-68,x+92,y+15),255,105,fill=CREAM,width=12)
        d.line((x,y+37,x,y+79),fill=GOLD,width=16)
        d.rounded_rectangle((x-52,y+69,x+52,y+94),radius=7,fill=CREAM)

def icon(key,index,kind='achievement'):
    canvas=Image.new('RGBA',(512,512),DEEP)
    d=ImageDraw.Draw(canvas)
    palette=['#168a9b','#226b9b','#565384','#436a42','#a95342','#327d90','#866139']
    d.ellipse((26,26,486,486),fill=palette[index%len(palette)],outline=GOLD,width=14)
    d.ellipse((47,47,465,465),outline='#fff1c855',width=3)
    for k in range(28):
        a=k*math.tau/28
        cx=256+225*math.cos(a);cy=256+225*math.sin(a)
        d.ellipse((cx-4,cy-4,cx+4,cy+4),fill=CREAM)
    if kind=='achievement':
        # Reuse the reviewed Kenney medal shape; symbol keeps each award unique.
        medal=(index%9)+1
        # Trace the provided medal's flat geometric ribbon for a crisp 512px icon.
        ribbon=['#8f52a7','#d94443','#d94443','#4e84d3','#4e84d3','#4e84d3','#4e84d3','#8f52a7','#94c859'][medal-1]
        stripe=CREAM if medal not in (4,6,8) else GOLD
        d.polygon([(155,88),(357,88),(357,230),(256,332),(155,230)],fill=ribbon)
        d.polygon([(226,88),(286,88),(286,302),(256,332),(226,302)],fill=stripe)
        d.rectangle((152,83,360,96),fill=GOLD)
        d.ellipse((130,205,382,457),fill=DEEP,outline=GOLD,width=9)
        draw_symbol(d,key,(256,330,208))
    else:
        draw_symbol(d,key,(256,246,220))
        for cx,r in [(119,19),(393,19),(256,25)]: star(d,(cx,417),r,CREAM)
    return canvas

def make_icons():
    definitions=json.loads((ROOT/'data'/'achievements.json').read_text(encoding='utf-8'))['achievements']
    keys=['anchor','cannons','chest','shield','fleet','skull','bolt','heart','star','leaf','flame','snow','crown','skull','trophy','wave','bolt','fleet','anchor','crown','wave','clock','trophy','chart','chart','calendar','heart','chain']
    for i,a in enumerate(definitions): icon(keys[i],i).save(STORE/'achievements'/f"{a['id']}.png",optimize=True)
    boards=[('endless_score','trophy'),('endless_survival','clock'),('campaign_stars','chart'),('total_plunder','chest')]
    for i,(slug,key) in enumerate(boards): icon(key,i+2,'leaderboard').save(STORE/'leaderboards'/f'{slug}.png',optimize=True)

def make_app_icon():
    # Pure vector asset: bold ship, skull sail, broadside sparks, tropical surf.
    svg='''<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
<rect width="512" height="512" fill="#168a9b"/>
<path d="M0 386Q64 347 128 386T256 386T384 386T512 386V512H0Z" fill="#116a7b"/>
<path d="M-20 451Q50 414 120 451T260 451T400 451T540 451" fill="none" stroke="#35b4ba" stroke-width="13"/>
<path d="M140 124Q128 278 180 390L256 455L332 390Q384 278 372 124Z" fill="#784a29"/>
<path d="M162 128Q155 277 200 377L256 426L312 377Q357 277 350 128Z" fill="#b77c39"/>
<path d="M172 140H340M177 319H335M199 365H313" fill="none" stroke="#d99b52" stroke-width="11"/>
<path d="M115 271L60 299M397 271L452 299" stroke="#103d4c" stroke-width="30" stroke-linecap="round"/>
<path d="M94 302L113 317M418 302L399 317" stroke="#ffe798" stroke-width="9"/>
<path d="M256 75V332" stroke="#784a29" stroke-width="23" stroke-linecap="round"/>
<circle cx="256" cy="89" r="20" fill="#d99b52" stroke="#784a29" stroke-width="9"/>
<path d="M151 130H361L377 255Q256 312 135 255Z" fill="#c84f43"/>
<path d="M163 140H349L361 244Q256 291 151 244Z" fill="#ec6b58"/>
<path d="M151 133H361" stroke="#f8cf78" stroke-width="9"/>
<g fill="#fff1c8"><ellipse cx="256" cy="208" rx="44" ry="37"/><path d="M231 224H281V257H231Z"/>
<path d="M211 251L301 284M211 284L301 251" stroke="#fff1c8" stroke-width="10" stroke-linecap="round"/></g>
<g fill="#c84f43"><circle cx="240" cy="207" r="11"/><circle cx="272" cy="207" r="11"/><path d="M256 219L248 232H264Z"/></g>
<path d="M244 245V259M267 245V259" stroke="#c84f43" stroke-width="5"/>
<path d="M47 279L39 259L60 267L74 249L75 272L95 281L73 287L70 309L56 292L35 298Z" fill="#f9c64b"/>
<path d="M465 279L473 259L452 267L438 249L437 272L417 281L439 287L442 309L456 292L477 298Z" fill="#f9c64b"/>
</svg>'''
    (GEN/'ui'/'app_icon.svg').write_text(svg,encoding='utf-8')
    im=raster_vector(svg)
    im.save(STORE/'app_icon_512.png',optimize=True)
    im.save(GEN/'ui'/'app_icon.png',optimize=True)
    # Android adaptive layers: the ship/cannon silhouette stays in the 264px
    # safe circle of a 432px canvas; launcher supplies its own outer mask.
    fg_tree=ET.fromstring(svg)
    for child in list(fg_tree)[:3]:fg_tree.remove(child)
    ship=raster_vector(ET.tostring(fg_tree,encoding='unicode')).resize((302,302),Image.Resampling.LANCZOS)
    foreground=Image.new('RGBA',(432,432));foreground.alpha_composite(ship,(65,65))
    foreground.save(GEN/'ui'/'app_icon_foreground.png',optimize=True)
    Image.new('RGB',(432,432),OCEAN).save(GEN/'ui'/'app_icon_background.png',optimize=True)

def make_wheel():
    lines=[]
    for k in range(8):
        a=k*math.pi/4; x1=128+math.cos(a)*27;y1=128+math.sin(a)*27;x2=128+math.cos(a)*109;y2=128+math.sin(a)*109
        lines.append(f'<path d="M{x1:.2f} {y1:.2f}L{x2:.2f} {y2:.2f}" stroke="#5b3d2c" stroke-width="19" stroke-linecap="round"/><path d="M{x1:.2f} {y1:.2f}L{x2:.2f} {y2:.2f}" stroke="#d39a55" stroke-width="11" stroke-linecap="round"/>')
    svg='<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">'+''.join(lines)+'<circle cx="128" cy="128" r="77" fill="none" stroke="#5b3d2c" stroke-width="23"/><circle cx="128" cy="128" r="77" fill="none" stroke="#b57c40" stroke-width="14"/><circle cx="128" cy="128" r="27" fill="#5b3d2c"/><circle cx="128" cy="128" r="20" fill="#f9c64b"/><circle cx="128" cy="128" r="9" fill="#fff1c8"/></svg>'
    (GEN/'ui'/'ship_wheel.svg').write_text(svg,encoding='utf-8')
    raster_vector(svg).save(GEN/'ui'/'ship_wheel.png',optimize=True)

def make_feature():
    im=Image.new('RGBA',(1024*S,500*S),OCEAN);d=ImageDraw.Draw(im)
    waves(d,1024*S,500*S,48*S,'#209bab')
    d.ellipse((-180*S,-190*S,340*S,520*S),fill='#0f7d8e')
    d.ellipse((771*S,-35*S,1165*S,213*S),fill='#f6e5bc')
    d.ellipse((825*S,-87*S,1168*S,158*S),fill='#29bd71')
    for p,c,size,rotation in [
        ('ship (3).png',(745,284),(163,283),-22),
        ('ship (2).png',(928,299),(120,211),28),
        ('ship (4).png',(611,108),(69,119),-22)]:
        paste_asset(im,'Assets/PirateStuff/PNG/Retina/Ships/'+p,(c[0]*S,c[1]*S),(size[0]*S,size[1]*S),rotation)
    paste_asset(im,'Assets/PirateStuff/PNG/Retina/Tiles/tile_71.png',(939*S,81*S),(103*S,103*S),-18)
    paste_asset(im,'Assets/PirateStuff/PNG/Retina/Effects/explosion2.png',(852*S,238*S),(100*S,100*S))
    paste_asset(im,'Assets/PirateStuff/PNG/Retina/Ship parts/cannonBall.png',(828*S,305*S),(24*S,24*S))
    paste_asset(im,'Assets/PirateStuff/PNG/Retina/Ship parts/cannonBall.png',(808*S,352*S),(20*S,20*S))
    d=ImageDraw.Draw(im)
    title=font(83*S);subtitle=font(25*S,True)
    d.text((66*S,119*S),'PIRATE',font=title,fill=CREAM,stroke_width=5*S,stroke_fill=DEEP)
    d.text((64*S,211*S),'PLUNDER',font=title,fill=GOLD,stroke_width=5*S,stroke_fill=DEEP)
    d.text((71*S,332*S),'Tiny ship. Huge trouble.',font=subtitle,fill=CREAM)
    for x,y,r in [(492,148,14),(600,337,10),(71,81,12)]:star(d,(x*S,y*S),r*S,GOLD)
    im.convert('RGB').resize((1024,500),Image.Resampling.LANCZOS).save(STORE/'feature_graphic_1024x500.png',optimize=True)

def write_wav(path,data,sr):
    pcm=(np.clip(data,-1,1)*32767).astype('<i2')
    with wave.open(str(path),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(sr);w.writeframes(pcm.tobytes())

def make_audio():
    sr=22050;rng=np.random.default_rng(837392)
    t=np.arange(int(sr*.58))/sr
    noise=rng.normal(0,.7,len(t)); smooth=np.convolve(noise,np.ones(11)/11,'same')
    phase=2*math.pi*(95*t-45*t*t)
    cannon=.62*np.sin(phase)*np.exp(-t*10)+.54*smooth*np.exp(-t*15)+.16*noise*np.exp(-t*55)
    cannon*=np.minimum(t/.003,1);cannon[-500:]*=np.linspace(1,0,500)
    cannon=.85*cannon/max(.9,np.max(np.abs(cannon)))
    write_wav(GEN/'audio'/'cannon.wav',cannon,sr)
    # Original 16-bar 6/8 shanty: plucked melody, accordion chords, bass, brush taps.
    eighth=60/92/3; beats=96;length=round(beats*eighth*sr);loop=np.zeros(length)
    def add(start,freq,duration,gain,voice='pluck'):
        n=int(duration*sr);tt=np.arange(n)/sr
        if voice=='pluck':
            sig=(np.sin(2*math.pi*freq*tt)+.33*np.sin(4*math.pi*freq*tt)+.13*np.sin(6*math.pi*freq*tt))*np.exp(-tt*9)
        elif voice=='reed':
            sig=(np.sin(2*math.pi*freq*tt)+.18*np.sin(6*math.pi*freq*tt)+.08*np.sin(10*math.pi*freq*tt))*np.minimum(tt/.04,1)*np.exp(-tt*2.7)
        elif voice=='bass': sig=np.sin(2*math.pi*freq*tt)*np.exp(-tt*5)
        else: sig=rng.normal(0,.4,n)*np.exp(-tt*44)
        sig*=gain; sig[-min(n,100):]*=np.linspace(1,0,min(n,100))
        ids=(int(round(start*sr))+np.arange(n))%length
        np.add.at(loop,ids,sig)
    phrases=[
        [62,65,69,69,67,65], [64,67,71,72,71,67],
        [65,69,72,74,72,69], [64,67,69,67,64,60],
        [62,65,69,74,72,69], [67,71,74,76,74,71],
        [65,69,72,69,67,65], [64,62,60,62,0,0],
        [74,72,69,65,69,72], [71,67,64,67,71,74],
        [72,69,65,69,72,77], [76,74,72,71,67,64],
        [74,69,65,62,65,69], [71,74,76,74,71,67],
        [72,69,65,64,62,60], [62,65,69,62,0,0]]
    roots=[50,48,53,48,50,55,53,50]*2
    hz=lambda midi:440*2**((midi-69)/12)
    for bar,notes in enumerate(phrases):
        for k,midi in enumerate(notes):
            if midi:add((bar*6+k)*eighth,hz(midi),eighth*1.7,.16)
            add((bar*6+k)*eighth,0,.11,.065,'brush')
        for k in (0,3):
            add((bar*6+k)*eighth,hz(roots[bar]-12),eighth*2.8,.21,'bass')
            for interval in (0,3 if roots[bar]==50 else 4,7):add((bar*6+k+1)*eighth,hz(roots[bar]+interval),eighth*1.9,.04,'reed')
    # Limiting avoids cannon/melody clipping when runtime mixes channels.
    loop=.60*np.tanh(loop*1.25)
    write_wav(GEN/'audio'/'pirate_loop.wav',loop,sr)
    manifest={'license':'CC0-1.0','author':'PiratePlunder contributors; original deterministic synthesis','sample_rate':sr,'channels':1,'format':'16-bit PCM WAV','seed':837392,'tracks':{'pirate_loop.wav':{'seconds':round(length/sr,4),'loop':True,'bpm_dotted_quarter':92,'meter':'6/8','loop_sample_begin':0,'loop_sample_end':length},'cannon.wav':{'seconds':len(cannon)/sr,'loop':False}},'peak_music':float(np.max(np.abs(loop))),'peak_cannon':float(np.max(np.abs(cannon)))}
    (GEN/'audio'/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')

def make_manifest():
    records=[]
    for p in sorted(STORE.rglob('*.png')):
        if 'screenshots' in p.parts: continue
        im=Image.open(p)
        records.append({'path':p.relative_to(ROOT).as_posix(),'width':im.width,'height':im.height,'mode':im.mode,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
    (STORE/'asset_manifest.json').write_text(json.dumps({'generated_by':'tools/build_art.py','license':'CC0 composition from supplied Kenney CC0 artwork','assets':records},indent=2),encoding='utf-8')

def make_static_font():
    dest=GEN/'fonts'/'Nunito-SemiBold.ttf'
    try:
        from fontTools.ttLib import TTFont
        from fontTools.varLib.instancer import instantiateVariableFont
    except ImportError:
        if dest.exists():return
        raise RuntimeError('First authoring run needs fontTools to instance Nunito at weight600. Runtime needs no Python/fontTools.')
    base=TTFont(GEN/'fonts'/'Nunito-Variable.ttf',recalcTimestamp=False)
    static=instantiateVariableFont(base,{'wght':600},inplace=False)
    names={1:'Nunito',2:'SemiBold',4:'Nunito SemiBold',6:'Nunito-SemiBold',16:'Nunito',17:'SemiBold'}
    for entry in static['name'].names:
        if entry.nameID in names:
            entry.string=names[entry.nameID].encode(entry.getEncoding())
    static.save(dest)

def make_setup_worksheets():
    achievements=json.loads((ROOT/'data'/'achievements.json').read_text(encoding='utf-8'))['achievements']
    config_path=ROOT/'config'/'play_games.json'
    config=json.loads(config_path.read_text(encoding='utf-8')) if config_path.exists() else {}
    # Console values belong to stable local IDs, never catalog positions.
    # These owner-supplied defaults total 975; existing worksheet edits win.
    default_points={
        'sea_legs':5,'first_broadside':5,'first_plunder':5,'deck_clear':10,
        'fleet_breaker':20,'sea_scourge':40,'powder_monkey':25,'flawless_voyage':30,
        'shoal_sheriff':20,'swamp_escape':25,'hot_streak':30,'ice_breaker':35,
        'pirate_king':75,'boss_buster':10,'tyrant_tamer':50,'treasure_tide':35,
        'power_pirate':20,'four_of_a_kind':15,'seasoned_captain':25,'fleet_of_legends':100,
        'endless_appetite':15,'marathon_marauder':40,'high_tide':50,'star_chart':50,
        'constellation_captain':150,'daily_deckhand':15,'welcome_aboard':25,'chain_reaction':50,
    }
    existing_points={}
    worksheet_path=STORE/'achievement_setup.csv'
    if worksheet_path.exists():
        with worksheet_path.open(newline='',encoding='utf-8-sig') as f:
            for row in csv.DictReader(f):
                if row.get('local_id') and row.get('points','').strip():
                    existing_points[row['local_id']]=int(row['points'])
    def backend_id(kind,definition):
        return str(config.get(kind+'_ids',{}).get(definition['id']) or definition.get('google_play_id',''))
    rows=[]
    for a in achievements:
        points=existing_points.get(a['id'],default_points.get(a['id'],5))
        rows.append({'local_id':a['id'],'google_play_id':backend_id('achievement',a),'name':a['name'],'description':a['description'],'type':'incremental' if a['incremental'] else 'standard','steps':a['target'] if a['incremental'] else '', 'points':points,'initial_state':'hidden' if a.get('hidden') else 'revealed','icon_file':f"store/achievements/{a['id']}.png"})
    points_total=sum(row['points'] for row in rows)
    with (STORE/'achievement_setup.csv').open('w',newline='',encoding='utf-8') as f:
        writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
    boards=json.loads((ROOT/'data'/'leaderboards.json').read_text(encoding='utf-8'))['leaderboards']
    rows=[{'local_id':b['id'],'google_play_id':backend_id('leaderboard',b),'name':b['name'],'description':b['description'],'score_order':'larger_is_better','format':b['format'],'value_multiplier':b['value_multiplier'],'icon_file':f"store/leaderboards/{b['id']}.png"} for b in boards]
    with (STORE/'leaderboard_setup.csv').open('w',newline='',encoding='utf-8') as f:
        writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
    fields={key:(STORE/f'{name}.txt').read_text(encoding='utf-8').strip() for key,name in [('title','app_name'),('short_description','short_description'),('full_description','full_description')]}
    limits={'title':30,'short_description':80,'full_description':4000}
    for key,value in fields.items():assert len(value)<=limits[key],f'{key} exceeds limit'
    metadata={'locale':'en-US','status':'submission_draft','category_suggestion':'GAME_ARCADE',**fields,'character_counts':{key:len(value) for key,value in fields.items()},'limits':limits,'suggested_achievement_points_total':points_total,'support_email':'','privacy_policy_url':'','alt_text':{'app_icon':'A coral skull-sail pirate ship fires side cannons over a teal ocean.','feature_graphic':'PiratePlunder: colorful pirate ships trade broadsides beside a tropical island.'},'cloud_services_claimed_in_copy':False,'worksheet_note':'Setup CSVs are human-readable worksheets, not a claim of Console bulk-import compatibility.'}
    metadata_path=STORE/'listing_metadata.json'
    if metadata_path.exists():
        previous_metadata=json.loads(metadata_path.read_text(encoding='utf-8'))
        if 'achievement_points_source' in previous_metadata:
            metadata['achievement_points_source']=previous_metadata['achievement_points_source']
    (STORE/'listing_metadata.json').write_text(json.dumps(metadata,indent=2),encoding='utf-8')

if __name__=='__main__':
    make_static_font();make_audio();make_app_icon();make_wheel();make_feature();make_icons();make_setup_worksheets();make_manifest()
    print('Generated original audio, vector wheel/app icon, store icon, feature graphic, 28 achievement icons, 4 leaderboard icons.')
