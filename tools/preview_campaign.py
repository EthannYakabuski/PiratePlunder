"""Draw the exact authored campaign layouts for review; these are diagrams, not screenshots."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs'/'campaign_maps'
COLORS={'chaser':'#f1b07c','skirmisher':'#ef8c77','sniper':'#a4c9ff','rammer':'#e8a0d7','runner':'#ffdc73','boss':'#ff6363'}

def main():
    data=json.loads((ROOT/'data/campaign.json').read_text(encoding='utf-8-sig'))
    OUT.mkdir(parents=True,exist_ok=True)
    font=ImageFont.truetype(str(ROOT/'assets_generated/fonts/Nunito-SemiBold.ttf'),15)
    small=ImageFont.truetype(str(ROOT/'assets_generated/fonts/Nunito-SemiBold.ttf'),11)
    title=ImageFont.truetype(str(ROOT/'assets_generated/fonts/LilitaOne-Regular.ttf'),28)
    for biome in data['biomes']:
        levels=[l for l in data['levels'] if l['biome']==biome['id']]
        image=Image.new('RGB',(1440,710),'#092f3e')
        draw=ImageDraw.Draw(image)
        draw.text((20,12),biome['name']+' — authored voyage charts',font=title,fill='#ffe2a1')
        draw.text((20,50),'Green triangle: start · numbers: encounter groups · red: boss · rings: hazards · dots: supplies',font=font,fill='#b8d5ce')
        for i,level in enumerate(levels):
            ox=16+(i%5)*285; oy=86+(i//5)*304
            area=(ox+5,oy+36,ox+267,oy+276)
            draw.rounded_rectangle((ox,oy,ox+276,oy+295),10,fill='#154958')
            draw.text((ox+8,oy+6),f"{level['id']:02} {level['name']}",font=font,fill='#fff0ca')
            x,y,w,h=level['layout']['bounds']
            scale=min((area[2]-area[0])/w,(area[3]-area[1])/h)
            mx=area[0]+((area[2]-area[0])-w*scale)/2
            my=area[1]+((area[3]-area[1])-h*scale)/2
            def pos(v):return (mx+(v[0]-x)*scale,my+(v[1]-y)*scale)
            draw.rectangle((mx,my,mx+w*scale,my+h*scale),fill=biome['colors']['water'],outline='#73bdb6',width=1)
            for island in level['layout']['islands']:
                px,py=pos(island['pos']);r=island['radius']*scale
                draw.ellipse((px-r,py-r,px+r,py+r),fill=biome['colors']['sand'],outline='#f5e4ac')
                r*=.7
                draw.ellipse((px-r,py-r,px+r,py+r),fill='#5d9c72')
            for hazard in level['layout']['hazards']:
                px,py=pos(hazard['pos']);r=hazard['radius']*scale
                draw.ellipse((px-r,py-r,px+r,py+r),outline='#ffa575',width=2)
            for pickup in level['layout']['pickups']:
                px,py=pos(pickup['pos'])
                draw.ellipse((px-2,py-2,px+2,py+2),fill='#ffe38b' if pickup['type']=='coin' else '#92ffc2')
            for n,encounter in enumerate(level['encounters'],1):
                for ship in encounter['ships']:
                    px,py=pos(ship['pos'])
                    draw.ellipse((px-6,py-6,px+6,py+6),fill=COLORS[ship['kind']],outline='#173644')
                    draw.text((px,py),str(n),font=small,fill='#173644',anchor='mm')
            px,py=pos(level['layout']['player_spawn'])
            draw.polygon([(px,py-6),(px-5,py+5),(px+5,py+5)],fill='#a3ffc8',outline='#163f45')
            draw.text((ox+9,oy+278),f"{level['objective']['target']} ships · {len(level['encounters'])} encounters",font=small,fill='#c9ded3')
        image.save(OUT/(biome['id']+'.png'),optimize=True)
        print(OUT/(biome['id']+'.png'))

if __name__=='__main__':main()
