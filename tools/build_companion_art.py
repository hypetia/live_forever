#!/usr/bin/env python3
"""Rebuild the three original SVG companions; no external assets or image packages."""
from pathlib import Path
import random
ROOT=Path(__file__).resolve().parents[1]/'assets/art'
DEFS='''<defs>
<linearGradient id="skin" x1="0" x2="1" y2=".7"><stop stop-color="#dcc2a5"/><stop offset=".5" stop-color="#bba18a"/><stop offset="1" stop-color="#776757"/></linearGradient>
<linearGradient id="blue"><stop stop-color="#172c42"/><stop offset=".42" stop-color="#536575"/><stop offset=".67" stop-color="#334b62"/><stop offset="1" stop-color="#162634"/></linearGradient>
<linearGradient id="red"><stop stop-color="#5e292b"/><stop offset=".4" stop-color="#9b5145"/><stop offset=".7" stop-color="#823a33"/><stop offset="1" stop-color="#482628"/></linearGradient>
<radialGradient id="gold" cx=".35" cy=".2" r=".86"><stop stop-color="#d2b572"/><stop offset=".4" stop-color="#b69a59"/><stop offset=".8" stop-color="#8a7041"/><stop offset="1" stop-color="#554c36"/></radialGradient>
<radialGradient id="black" cx=".35" cy=".15" r=".9"><stop stop-color="#62645f"/><stop offset=".4" stop-color="#373e3e"/><stop offset="1" stop-color="#111b20"/></radialGradient>
<linearGradient id="cream"><stop stop-color="#dbceae"/><stop offset=".48" stop-color="#b9aa8e"/><stop offset="1" stop-color="#797465"/></linearGradient>
<linearGradient id="boot"><stop stop-color="#625e51"/><stop offset=".5" stop-color="#303a3d"/><stop offset="1" stop-color="#19232a"/></linearGradient>
<clipPath id="bearfur"><ellipse cx="180" cy="256" rx="88" ry="108"/><ellipse cx="180" cy="121" rx="69" ry="73"/></clipPath>
</defs>'''
def path(d,fill,stroke='#323734',w=1.5):return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{w}" stroke-linejoin="round"/>'
def ellipse(x,y,rx,ry,fill,stroke='none',w=1):return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}" stroke="{stroke}" stroke-width="{w}"/>'
def save(name,body):
 (ROOT/(name+'.svg')).write_text('<svg xmlns="http://www.w3.org/2000/svg" width="360" height="440" viewBox="0 0 360 440">'+DEFS+body+'</svg>\n')
# Detective: clothed natural child proportions; details remain legible in the portrait crop.
s=path('M139 277 L171 280 L166 350 L159 404 L137 405 L139 345 Z','url(#skin)')+path('M181 280 L211 277 L217 345 L219 404 L196 406 L188 346 Z','url(#skin)')
s+=path('M132 268 Q177 254 216 268 L215 322 L180 324 L173 299 L166 326 L133 322 Z','url(#boot)')
s+=path('M133 392 L162 394 L163 415 L171 424 Q153 431 126 426 L120 419 Z','url(#blue)')+path('M195 394 L221 392 L230 410 L246 420 L244 428 L192 429 Z','url(#blue)')
s+=path('M121 420 L169 421 L171 428 L126 431 Z','#b6b7ac')+path('M193 423 L245 420 L245 429 L193 432 Z','#b6b7ac')
s+=path('M133 130 L111 145 L92 214 L91 267 L108 272 L119 216 L140 164 Z','url(#blue)')+path('M213 129 L235 143 L258 214 L266 266 L249 275 L234 219 L210 166 Z','url(#blue)')
s+=ellipse(100,274,11,19,'url(#skin)')+ellipse(259,277,11,18,'url(#skin)')
s+=path('M143 119 L207 119 Q225 145 223 194 L214 283 Q174 293 131 282 L127 197 Q124 152 143 119 Z','url(#blue)')
s+=path('M155 119 L193 119 L185 211 L166 211 Z','url(#cream)')
s+=path('M153 121 L141 134 L158 153 L151 164 L169 220 L167 145 Z','#64737c')+path('M196 122 L210 136 L193 155 L200 168 L183 219 L183 145 Z','#223747')
s+=path('M166 102 L189 101 L192 128 L176 142 L159 126 Z','url(#skin)')
s+=path('M158 122 L175 138 L164 154 L154 135 Z','#d3d1bb')+path('M191 123 L176 138 L187 152 L199 135 Z','#b8b9ae')
s+=path('M154 139 L174 145 L200 137 L200 159 L176 150 L156 161 Z','url(#red)')+ellipse(176,148,6,6,'#9e5d4d')
s+=ellipse(178,75,33,41,'url(#skin)','#5b5149')
s+=path('M146 78 Q137 54 150 37 L143 24 L163 29 L175 17 L188 28 L207 26 L219 42 L210 67 L203 53 L188 63 L190 44 L174 57 L167 47 L154 66 L155 82 Z','url(#black)')
s+=path('M201 65 L211 80 L203 84 M197 94 Q205 96 210 91','none','#6f5c4d',1.4)
s+=path('M160 66 L172 63 M190 63 L202 61','none','#303b3f',2)
for x,y in [(165,74),(195,71)]:
 s+=ellipse(x,y,11,10,'none','#5d6970',2)+ellipse(x+3,y,2.1,3,'#26323a')+path(f'M{x-5} {y-3} L{x+6} {y-4}','none','#6b6057',1)
s+=path('M175 73 L184 72 M147 70 L153 72','none','#596970',2)
s+=path('M139 194 L154 195 M197 194 L212 192 M178 212 L176 280','none','#9b9e92',1)
for x,y in [(146,218),(147,239),(145,260)]:s+=ellipse(x,y,2,2,'#a8a69a')
s+=path('M111 179 L119 197 L108 228 M232 181 L235 201 L246 239 M137 273 L165 277 M192 277 L211 274','none','#71808a',1.2)
save('conan',s)
# Bear: fur grain and knit seams give this explicitly selected mascot a tangible material.
s=''
for x in [129,227]:s+=ellipse(x,67,28,29,'url(#gold)','#675b41')+ellipse(x,68,17,18,'#9a7c49')
s+=ellipse(146,381,31,43,'url(#gold)')+ellipse(215,381,32,43,'url(#gold)')
s+=ellipse(141,418,36,14,'url(#gold)','#6a5c40')+ellipse(221,419,37,14,'url(#gold)','#6a5c40')
s+=ellipse(180,269,89,104,'url(#gold)','#6a5c40')
s+=path('M114 197 Q91 208 82 260 L87 296 Q101 309 115 289 L135 235 Z','url(#gold)')+path('M247 199 Q269 212 281 259 L275 299 Q258 308 245 287 L226 234 Z','url(#gold)')
s+=ellipse(180,121,68,75,'url(#gold)','#6a5c40')
rng=random.Random(71413)
s+='<g clip-path="url(#bearfur)" opacity=".17" stroke="#ead29b" stroke-width="1.1">'
for _ in range(600):
 x=rng.randrange(90,272);y=rng.randrange(42,370);s+=f'<path d="M{x} {y} l{rng.choice([-2,2])} 4"/>'
s+='</g>'
s+=path('M112 185 Q135 173 154 187 Q179 202 206 184 L246 185 L263 235 L239 247 L237 285 Q179 300 121 281 L122 242 L98 232 Z','url(#red)','#663d32',2)
s+=path('M149 187 Q178 211 208 186 M123 275 Q177 290 236 280 M111 210 L129 218 M238 214 L251 208','none','#ac6a56',2)
s+=ellipse(185,150,38,28,'#c4a565')+ellipse(192,136,14,10,'#423c31')
s+=ellipse(161,116,5,6,'#302f29')+ellipse(209,113,5,6,'#302f29')
s+=ellipse(159,114,1.5,2,'#d3c697')+ellipse(207,111,1.5,2,'#d3c697')
s+=path('M151 100 Q160 95 168 100 M200 97 Q211 92 218 99 M173 164 Q195 175 214 158','none','#715e3d',2)
s+=path('M180 202 L180 280 M114 188 L123 238 M247 188 L238 241','none','#c18568',.7)
save('pooh',s)
# Mouse: vintage sewn cloth, glove creases, and scuffed leather shoes.
s=ellipse(130,70,39,41,'url(#black)','#252e31')+ellipse(231,70,39,41,'url(#black)','#252e31')
s+=path('M145 290 L161 290 L156 386 L130 388 L132 331 Z','url(#black)')+path('M196 289 L215 289 L228 383 L202 389 L189 330 Z','url(#black)')
s+=ellipse(135,408,44,20,'url(#gold)','#6b6046')+ellipse(228,408,46,21,'url(#gold)','#6b6046')
s+=path('M106 412 Q137 428 171 413 M189 414 Q227 430 272 414','none','#c0aa70',2)
s+=path('M131 180 L111 192 L86 256 L91 278 L109 280 L125 244 L147 207 Z','url(#black)')+path('M225 179 L246 196 L275 258 L272 280 L254 281 L235 242 L210 203 Z','url(#black)')
s+=ellipse(181,233,63,79,'url(#black)','#283234')
s+=path('M123 257 Q181 273 239 256 L242 310 L192 320 L180 298 L171 320 L120 309 Z','url(#red)','#693c32',2)
s+=ellipse(157,285,8,11,'url(#cream)','#94896e')+ellipse(207,284,8,11,'url(#cream)','#94896e')
s+=ellipse(180,131,62,73,'url(#black)','#263033')
s+=ellipse(163,130,26,42,'url(#cream)')+ellipse(199,131,26,43,'url(#cream)')+ellipse(186,163,47,29,'url(#cream)')
s+=ellipse(165,128,6,16,'#30383a')+ellipse(200,127,6,16,'#30383a')+ellipse(195,151,17,11,'#263033')
s+=path('M154 171 Q184 192 215 168 M173 195 Q186 199 199 191','none','#5d5a4c',2)
s+=ellipse(97,282,21,24,'url(#cream)','#8c8d7b')+ellipse(267,285,21,24,'url(#cream)','#8c8d7b')
for x,y in [(88,279),(96,277),(260,279),(268,277)]:s+=path(f'M{x} {y} l2 13','none','#777c70',1.2)
s+=path('M129 72 Q140 43 155 45 M231 42 Q251 48 259 68 M134 203 L143 251 M224 207 L218 251 M125 304 Q151 315 171 311 M193 313 Q213 317 237 306','none','#7c7f75',.8)
save('mickey',s)
print('Built three original material-shaded SVG companions.')
