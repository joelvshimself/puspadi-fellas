(() => {
const $ = s => document.querySelector(s);
const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));
const lerp = (a, b, t) => a + (b - a) * t;
const seg = (p, a, b) => clamp((p - a) / (b - a));
const ease = t => t < .5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
const backOut = t => 1 + 2.70158 * Math.pow(t - 1, 3) + 1.70158 * Math.pow(t - 1, 2);
const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
const FONT = '-apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif';
function rng(seed){return()=>{seed|=0;seed=seed+0x6D2B79F5|0;let t=Math.imul(seed^seed>>>15,1|seed);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296}}

const ST = {
  ok:{c:'#27B657',t:'Accessible',bg:'#DDF6E4',fg:'#178a3c'},
  part:{c:'#FF9F0A',t:'Partly accessible',bg:'#FFF1D9',fg:'#a35f00'},
  no:{c:'#EF4136',t:'Not accessible',bg:'#FDE3E1',fg:'#b3261c'},
  unk:{c:'#97A3AF',t:'No info yet'}
};
const IC = {
  ok:'<svg viewBox="0 0 24 24"><path d="M6 12.5l4 4 8-9" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  part:'<svg viewBox="0 0 24 24"><path d="M12 5.5v8.5" stroke="currentColor" stroke-width="3" stroke-linecap="round"/><circle cx="12" cy="18.5" r="1.9" fill="currentColor"/></svg>',
  no:'<svg viewBox="0 0 24 24"><path d="M7 7l10 10M17 7L7 17" stroke="currentColor" stroke-width="3" stroke-linecap="round"/></svg>'
};

/* ---------------- sample data ---------------- */
const PLACES = [
 {id:'park23',name:'Park23 Mall',cat:'Mall',area:'Tuban',x:1600,y:1420,st:'ok',tags:['mall','shopping'],near:1,n:7,last:'2 days ago',
  f:[['Ramp at main entrance','ok'],['Elevators to every floor','ok'],['Accessible toilet','ok'],['Drop-off area','part']],
  note:'The ramp at the main entrance is gentle. Security will open the wide gate if you ask.'},
 {id:'beachwalk',name:'Beachwalk Shopping Center',cat:'Mall',area:'Kuta',x:700,y:640,st:'ok',tags:['mall','shopping'],near:1,n:12,last:'1 week ago',
  f:[['Step-free entrance','ok'],['Elevators','ok'],['Accessible toilet, level 1','ok'],['Crossing to the beach','no']],
  note:'Inside is easy. Crossing the road to the beach means a high curb with no dropped section.'},
 {id:'artmarket',name:'Kuta Art Market',cat:'Market',area:'Kuta',x:680,y:980,st:'part',tags:['market','shopping','souvenir'],n:5,last:'3 weeks ago',
  f:[['Main lane is flat','ok'],['Narrow between stalls','part'],['Ramp','no'],['Accessible toilet','no']],
  note:'Main lane is paved but tight between stalls. Two steps at the back exit.'},
 {id:'puradalem',name:'Pura Dalem Kahyangan Kuta',cat:'Hindu temple',area:'Kuta',x:1290,y:880,st:'no',tags:['worship','religious','temple','pura','hindu'],near:1,n:4,last:'1 month ago',
  f:[['Steps at the candi bentar gate','no'],['Ramp','no'],['Flat outer courtyard','ok']],
  note:'Steep stone steps at the split gate. The outer courtyard is flat if someone can help you up.'},
 {id:'masjid',name:'Masjid Nurul Huda',cat:'Mosque',area:'Kuta',x:1660,y:860,st:'part',tags:['worship','religious','mosque','masjid','islam'],n:6,last:'2 weeks ago',
  f:[['Ramp to the prayer hall','ok'],['Step at the wudu area','no'],['Accessible toilet','part']],
  note:'Ramp to the main hall. The wudu area has a step and no seat.'},
 {id:'gereja',name:'Gereja St. Fransiskus Xaverius',cat:'Catholic church',area:'Kuta',x:1180,y:1260,st:'ok',tags:['worship','religious','church','gereja','christian'],near:1,n:9,last:'5 days ago',
  f:[['Step-free side door','ok'],['Wheelchair space near the front','ok'],['Accessible toilet','part']],
  note:'Use the side door. Ushers make space at the front for wheelchairs.'},
 {id:'vihara',name:'Vihara Dharmayana',cat:'Buddhist temple',area:'Kuta',x:1380,y:1300,st:'part',tags:['worship','religious','vihara','buddhist','temple'],n:3,last:'2 months ago',
  f:[['Flat courtyard','ok'],['Five steps to the main hall','no'],['Portable ramp on request','part']],
  note:'Courtyard is flat. Staff can bring a portable ramp for the main hall.'},
 {id:'waterbom',name:'Waterbom Bali',cat:'Water park',area:'Tuban',x:880,y:1120,st:'part',tags:['water park','attraction','family'],n:8,last:'1 week ago',
  f:[['Smooth paths','ok'],['Accessible changing room','ok'],['Most slides need stairs','no']],
  note:'Paths and the lazy river area are fine. Most slides start at the top of stairs.'},
 {id:'kutabeach',name:'Kuta Beach',cat:'Beach',area:'Kuta',x:620,y:860,st:'part',tags:['beach','pantai'],n:11,last:'4 days ago',
  f:[['Paved promenade','ok'],['Getting onto the sand','no'],['Accessible toilet','part']],
  note:'The promenade is smooth. Getting onto the sand needs help.'},
 {id:'segara',name:'Pura Segara Kuta',cat:'Hindu shrine',area:'Kuta',x:600,y:1250,st:'no',tags:['worship','religious','temple','pura','hindu','beach'],n:2,last:'3 months ago',
  f:[['Sandy ground','no'],['Steps to the shrine','no']],
  note:'Beachside shrine on loose sand. No firm path.'},
 {id:'discovery',name:'Discovery Mall Bali',cat:'Mall',area:'Tuban',x:720,y:1420,st:'ok',tags:['mall','shopping'],n:10,last:'1 week ago',
  f:[['Step-free entrance','ok'],['Elevators','ok'],['Accessible toilet','ok'],['Beach exit','part']],
  note:'Easy inside. The exit to the beach has a short slope with loose sand at the end.'},
 {id:'galeria',name:'Mal Bali Galeria',cat:'Mall',area:'Simpang Siur',x:2050,y:1320,st:'ok',tags:['mall','shopping'],n:6,last:'3 weeks ago',
  f:[['Disabled parking','ok'],['Ramp at the main door','ok'],['Accessible toilet','ok']],
  note:'Parking bays are close to the ramp.'},
 {id:'airport',name:'Ngurah Rai Airport (DPS)',cat:'Airport',area:'Tuban',x:1110,y:1700,st:'ok',tags:['airport','travel'],n:14,last:'2 days ago',
  f:[['Assistance service','ok'],['Accessible toilets','ok'],['Aerobridges, some gates','part']],
  note:'Book assistance with your airline. Some gates use buses and stairs.'},
 {id:'santorini',name:'Santorini Restaurant',cat:'Restaurant',area:'Legian',x:1120,y:420,st:'no',tags:['restaurant','food','cafe'],n:3,last:'1 month ago',
  f:[['Two steps at the door','no'],['Toilet upstairs','no'],['Ground-floor tables','ok']],
  note:'Staff helped lift the chair up the steps, but the toilet is upstairs.'},
 {id:'warung',name:'Warung Kopi Pantai',cat:'Café',area:'Kuta',x:960,y:760,st:'ok',tags:['cafe','food','coffee','restaurant'],n:4,last:'6 days ago',
  f:[['Level entrance','ok'],['Space between tables','ok'],['Accessible toilet','part']],
  note:'Level floor from the street. The toilet door is a bit narrow.'}
];
const USER = {x:1180, y:1050};

/* ---------------- world geometry ---------------- */
const BIG = 9000;
const coastX = y => 560 + 70*Math.sin(y/230) + 35*Math.sin(y/83+2);
const southY = x => 1640 + 50*Math.sin(x/260+1);
const lagoonX = y => 2260 + 45*Math.sin(y/210);
const isLand = (x,y) => x > coastX(y)+40 && y < southY(x)-40 && Math.abs(x-lagoonX(y)) > 60;
function densify(poly, step, closed=true){
  const out=[]; const n=poly.length;
  for(let i=0;i<(closed?n:n-1);i++){const a=poly[i],b=poly[(i+1)%n];const m=Math.max(1,Math.ceil(Math.hypot(b[0]-a[0],b[1]-a[1])/step));for(let j=0;j<m;j++)out.push([a[0]+(b[0]-a[0])*j/m,a[1]+(b[1]-a[1])*j/m]);}
  if(!closed) out.push(poly[n-1]); return out;
}
function spline(pts, step=30){
  const out=[];
  for(let i=0;i<pts.length-1;i++){
    const p0=pts[Math.max(i-1,0)],p1=pts[i],p2=pts[i+1],p3=pts[Math.min(i+2,pts.length-1)];
    const m=Math.max(2,Math.ceil(Math.hypot(p2[0]-p1[0],p2[1]-p1[1])/step));
    for(let j=0;j<m;j++){const t=j/m,t2=t*t,t3=t2*t;
      out.push([.5*(2*p1[0]+(-p0[0]+p2[0])*t+(2*p0[0]-5*p1[0]+4*p2[0]-p3[0])*t2+(-p0[0]+3*p1[0]-3*p2[0]+p3[0])*t3),
                .5*(2*p1[1]+(-p0[1]+p2[1])*t+(2*p0[1]-5*p1[1]+4*p2[1]-p3[1])*t2+(-p0[1]+3*p1[1]-3*p2[1]+p3[1])*t3)]);}
  }
  out.push(pts[pts.length-1]); return out;
}
const landPoly = densify([[-BIG,-BIG],[BIG,-BIG],[BIG,BIG],[-BIG,BIG]],250);
const coast=[]; for(let y=-1200;y<=2700;y+=30) coast.push([coastX(y),y]);
const seaW = densify([[-BIG,-BIG],[coastX(-1200),-BIG],...coast,[coastX(2700),BIG],[-BIG,BIG]],250);
const south=[]; for(let x=-1200;x<=3600;x+=30) south.push([x,southY(x)]);
const seaS = densify([[-BIG,southY(-1200)],...south,[BIG,southY(3600)],[BIG,BIG],[-BIG,BIG]],250);
const lagoon=[[lagoonX(-1200),-BIG]]; for(let y=-1200;y<=1700;y+=30) lagoon.push([lagoonX(y),y]);
const lagoonD = densify(lagoon,250,false);
const airport = densify([[720,1560],[1520,1560],[1520,1790],[720,1790]],40);
const runway = densify([[780,1660],[1460,1660],[1460,1700],[780,1700]],40);
const parks = [[1560,620,70],[2080,480,90],[1720,1250,55],[930,1260,48],[2420,900,80],[1900,-200,110],[1150,-420,90]].map(([cx,cy,r],i)=>{
  const R=rng(40+i),pts=[];for(let k=0;k<26;k++){const a=k/26*Math.PI*2;const rr=r*(.8+R()*.35);pts.push([cx+Math.cos(a)*rr*1.2,cy+Math.sin(a)*rr]);}return pts;});
const minor=[];
(function(){
  const R=rng(11);
  const runs=pts=>{const out=[];let cur=[];for(const p of pts){if(isLand(p[0],p[1]))cur.push(p);else{if(cur.length>1)out.push(cur);cur=[];}}if(cur.length>1)out.push(cur);return out;};
  for(let x=620;x<3300;x+=56+R()*36){let xx=x,cur=[];for(let y=-1300;y<1800;y+=45){xx+=(R()-.5)*9;if(R()<.07){minor.push(...runs(cur));cur=[];}else cur.push([xx,y]);}minor.push(...runs(cur));}
  for(let y=-1300;y<1700;y+=48+R()*34){let yy=y,cur=[];for(let x=300;x<3300;x+=45){yy+=(R()-.5)*9;if(R()<.08){minor.push(...runs(cur));cur=[];}else cur.push([x,yy]);}minor.push(...runs(cur));}
})();
const coastRoad=[];for(let y=-1200;y<=1520;y+=160)coastRoad.push([coastX(y)+105,y]);
const major=[
  [[900,-1500],[960,200],[1000,700],[1060,1200],[1180,1560]],
  [[1420,-1500],[1450,300],[1470,900],[1520,1530]],
  [[1950,-1500],[1880,500],[1840,1100],[1760,1500],[1500,1600],[900,1592],[640,1566]],
  [[600,320],[1200,330],[2000,360],[3400,390]],
  [[1000,1120],[1500,1150],[2000,1170],[3400,1210]],
  coastRoad
].map(p=>spline(p,30));
const LABELS=[{t:'Kuta',x:1240,y:740,s:66,w:700},{t:'Legian',x:1050,y:110,s:50,w:600},{t:'Tuban',x:1360,y:1470,s:46,w:600},{t:'Seminyak',x:1000,y:-700,s:48,w:600},
  {t:'Indian Ocean',x:180,y:980,s:42,w:400,sea:1},{t:'Ngurah Rai Airport',x:1120,y:1750,s:24,w:600,c:'#6d7a88'}];
const PINS=[];
(function(){
  const R=rng(3);
  PLACES.forEach(p=>PINS.push({x:p.x,y:p.y,st:p.st,id:p.id}));
  const pool=['ok','ok','part','no','ok','part'];
  let tries=0; while(PINS.length<34&&tries<500){tries++;const x=650+R()*1700,y=-250+R()*1750;if(!isLand(x,y))continue;if(PINS.some(q=>Math.hypot(q.x-x,q.y-y)<120))continue;if(Math.hypot(USER.x-x,USER.y-y)<90)continue;PINS.push({x,y,st:pool[Math.floor(R()*pool.length)]});}
  // reveal order: rough left-to-right sweep with noise
  PINS.forEach(p=>p.o=clamp((p.x-500)/1900*.75+R()*.25));
})();

/* ---------------- projection ---------------- */
const cam={x:1250,y:940,s:.5,rot:0,tilt:.5,invR:1/900,F:1400,ox:0,oy:0};
function P(x,y){
  const dx=(x-cam.x)*cam.s, dy=(y-cam.y)*cam.s;
  const c=Math.cos(cam.rot), s=Math.sin(cam.rot);
  const rx=dx*c-dy*s, ry=dx*s+dy*c;
  const rho=Math.hypot(rx,ry), R=1/cam.invR;
  let X=rx,Y=ry,Z=0;
  if(rho>1e-6){const ang=rho*cam.invR, A=Math.min(ang,1.5708), sc=R*Math.sin(A)/rho; X=rx*sc;Y=ry*sc;Z=R*(Math.cos(A)-1);}
  const ct=Math.cos(cam.tilt), st=Math.sin(cam.tilt);
  const Y2=Y*ct-Z*st, Z2=Y*st+Z*ct;
  const k=cam.F/(cam.F-Z2);
  return [cam.ox+X*k, cam.oy+Y2*k, k];
}
function horizonY(){const R=1/cam.invR,ct=Math.cos(cam.tilt),st=Math.sin(cam.tilt);const Y2=-R*ct+R*st,Z2=-R*st-R*ct;return cam.oy+Y2*cam.F/(cam.F-Z2);}

/* ---------------- map canvas ---------------- */
const stage=$('#stage'), mc=$('#map'), mx=mc.getContext('2d');
let MW=0,MH=0,DPR=1;
function sizeMap(){DPR=Math.min(devicePixelRatio||1,2);MW=stage.clientWidth;MH=stage.clientHeight;mc.width=Math.round(MW*DPR);mc.height=Math.round(MH*DPR);mc.style.width=MW+'px';mc.style.height=MH+'px';}
function poly(pts,close){mx.beginPath();for(let i=0;i<pts.length;i++){const p=P(pts[i][0],pts[i][1]);i?mx.lineTo(p[0],p[1]):mx.moveTo(p[0],p[1]);}if(close)mx.closePath();}
function addLine(pts){for(let i=0;i<pts.length;i++){const p=P(pts[i][0],pts[i][1]);i?mx.lineTo(p[0],p[1]):mx.moveTo(p[0],p[1]);}}
function drawPin(x,y,r,st,flip=1,alpha=1){
  if(alpha<=.01||r<1)return; const ctx=mx;
  ctx.save();ctx.globalAlpha=alpha;ctx.translate(x,y);ctx.scale(Math.max(.03,flip),1);
  ctx.shadowColor='rgba(15,34,53,.3)';ctx.shadowBlur=r*.7;ctx.shadowOffsetY=r*.18;
  ctx.beginPath();ctx.arc(0,0,r,0,Math.PI*2);ctx.fillStyle='#fff';ctx.fill();
  ctx.shadowColor='transparent';
  ctx.beginPath();ctx.arc(0,0,r*.8,0,Math.PI*2);ctx.fillStyle=ST[st].c;ctx.fill();
  ctx.strokeStyle='#fff';ctx.fillStyle='#fff';ctx.lineWidth=r*.2;ctx.lineCap='round';ctx.lineJoin='round';
  const g=r*.36;ctx.beginPath();
  if(st==='ok'){ctx.moveTo(-g,0);ctx.lineTo(-g*.25,g*.75);ctx.lineTo(g,-g*.7);ctx.stroke();}
  else if(st==='no'){ctx.moveTo(-g*.8,-g*.8);ctx.lineTo(g*.8,g*.8);ctx.moveTo(g*.8,-g*.8);ctx.lineTo(-g*.8,g*.8);ctx.stroke();}
  else if(st==='part'){ctx.moveTo(0,-g*1.05);ctx.lineTo(0,g*.3);ctx.stroke();ctx.beginPath();ctx.arc(0,g*.95,r*.11,0,7);ctx.fill();}
  else{ctx.font=`700 ${r*1.1}px ${FONT}`;ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText('?',0,r*.08);}
  ctx.restore();
}
function pill(x,y,text,size,alpha,bg='#fff',fg='#0F2235'){
  if(alpha<=.01)return;const ctx=mx;ctx.save();ctx.globalAlpha=alpha;ctx.font=`600 ${size}px ${FONT}`;
  const w=ctx.measureText(text).width+size*1.3,h=size*1.9;
  ctx.shadowColor='rgba(15,34,53,.22)';ctx.shadowBlur=10;ctx.shadowOffsetY=3;ctx.fillStyle=bg;
  ctx.beginPath();ctx.roundRect(x-w/2,y-h/2,w,h,h/2);ctx.fill();ctx.shadowColor='transparent';
  ctx.fillStyle=fg;ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(text,x,y+size*.05);ctx.restore();
}
const t0=performance.now();
let sel=null; const pcam={x:USER.x,y:USER.y,z:1,tx:USER.x,ty:USER.y,tz:1};

function drawMap(now,h,u,S){
  const ctx=mx,W=MW,H=MH;
  ctx.setTransform(DPR,0,0,DPR,0,0);
  const hy=horizonY();
  const sky=ctx.createLinearGradient(0,0,0,Math.max(hy,1));
  sky.addColorStop(0,'#D3E6F8');sky.addColorStop(1,'#F4F9FE');
  ctx.fillStyle=sky;ctx.fillRect(0,0,W,H);
  poly(landPoly,true);ctx.fillStyle='#F2EFE8';ctx.fill();
  ctx.fillStyle='#A9D6F5';poly(seaW,true);ctx.fill();poly(seaS,true);ctx.fill();
  ctx.lineCap='round';ctx.lineJoin='round';
  ctx.strokeStyle='#A9D6F5';ctx.lineWidth=70*cam.s;poly(lagoonD,false);ctx.stroke();
  ctx.fillStyle='#EDEAE3';poly(airport,true);ctx.fill();ctx.fillStyle='#D9D5CD';poly(runway,true);ctx.fill();
  ctx.fillStyle='#CFE8C6';for(const p of parks){poly(p,true);ctx.fill();}
  ctx.beginPath();for(const l of minor)addLine(l);ctx.strokeStyle='#FFFFFF';ctx.lineWidth=Math.max(.8,9*cam.s);ctx.stroke();
  ctx.beginPath();for(const r of major)addLine(r);ctx.strokeStyle='#E8CD8C';ctx.lineWidth=Math.max(2,24*cam.s);ctx.stroke();ctx.strokeStyle='#FDE8AA';ctx.lineWidth=Math.max(1.3,17*cam.s);ctx.stroke();
  // labels
  ctx.textAlign='center';ctx.textBaseline='middle';
  for(const L of LABELS){
    const [x,y,k]=P(L.x,L.y);if(y<hy+10)continue;
    const fs=clamp(L.s*cam.s*k*.9,9,u>.5?26:44);
    ctx.font=`${L.sea?'italic ':''}${L.w} ${fs}px ${FONT}`;
    ctx.lineWidth=fs*.18;ctx.strokeStyle=L.sea?'rgba(169,214,245,.8)':'rgba(255,255,255,.9)';ctx.strokeText(L.t,x,y);
    ctx.fillStyle=L.c||(L.sea?'#3E86C4':'#6B6257');ctx.fillText(L.t,x,y);
  }
  // user location
  {const [x,y,k]=P(USER.x,USER.y);const r=lerp(9*k,8*S.k,u);
    const cone=ctx.createRadialGradient(x,y,0,x,y,r*5);cone.addColorStop(0,'rgba(26,134,240,.45)');cone.addColorStop(1,'rgba(26,134,240,0)');
    ctx.fillStyle=cone;ctx.beginPath();ctx.moveTo(x,y);ctx.arc(x,y,r*5,-Math.PI/2-.5+Math.PI,-Math.PI/2+.5+Math.PI);ctx.closePath();ctx.fill();
    const pulse=reduce?0:((now-t0)%2200)/2200;ctx.beginPath();ctx.arc(x,y,r*(1+pulse*2.4),0,7);ctx.fillStyle=`rgba(26,134,240,${.25*(1-pulse)})`;ctx.fill();
    ctx.beginPath();ctx.arc(x,y,r+r*.35,0,7);ctx.fillStyle='#fff';ctx.shadowColor='rgba(0,0,0,.25)';ctx.shadowBlur=6;ctx.fill();ctx.shadowColor='transparent';
    ctx.beginPath();ctx.arc(x,y,r,0,7);ctx.fillStyle='#1A86F0';ctx.fill();}
  // pins
  const heroR=(W<820?10:12.5);
  let selP=null;
  for(const p of PINS){
    const [x,y,k]=P(p.x,p.y);
    if(x<-60||x>W+60||y<hy-10||y>H+60)continue;
    let st=p.st,flip=1,a=1,sc=1;
    if(u<1){
      const appear=reduce?1:clamp((now-t0-350-p.o*1500)/450);
      sc=lerp(backOut(appear),1,u);a=lerp(clamp(appear*3),1,u);
      const th=.04+p.o*.74,loc=seg(h,th,th+.1);
      if(loc<.5)st='unk';flip=lerp(Math.abs(Math.cos(loc*Math.PI)),1,u);
      const bl=seg(h,th+.06,th+.3);
      if(bl>0&&bl<1&&u<.2&&st!=='unk')pill(x,y-heroR*k*2.3-bl*20,st==='unk'?'':'+1 review',11*Math.max(.8,k),Math.sin(bl*Math.PI)*(1-u*5));
    }
    const isSel=p.id&&p.id===sel&&u>.9;
    const r=lerp(heroR*k,11*S.k,u)*sc*(isSel?1.5:1);
    if(isSel){selP=[x,y,r,p];continue;}
    drawPin(x,y,r,st,flip,a);
  }
  if(selP){const [x,y,r,p]=selP;const pl=reduce?0:((now-t0)%1600)/1600;
    ctx.beginPath();ctx.arc(x,y,r*(1+pl*1.6),0,7);ctx.fillStyle=ST[p.st].c;ctx.globalAlpha=.3*(1-pl);ctx.fill();ctx.globalAlpha=1;
    drawPin(x,y,r,p.st);const pl2=PLACES.find(q=>q.id===p.id);pill(x,y-r-16*S.k,pl2.name,13*S.k,1);}
  // atmosphere / fog for the globe view
  const fogA=1-u;
  if(fogA>.01){
    const fg=ctx.createLinearGradient(0,hy-2,0,hy+H*.32);
    fg.addColorStop(0,`rgba(244,249,254,${fogA})`);fg.addColorStop(.35,`rgba(244,249,254,${.55*fogA})`);fg.addColorStop(1,'rgba(244,249,254,0)');
    ctx.fillStyle=fg;ctx.fillRect(0,hy-2,W,H*.32+4);
    const rg=ctx.createRadialGradient(W/2,H*.75,Math.min(W,H)*.35,W/2,H*.75,Math.max(W,H)*.8);
    rg.addColorStop(0,'rgba(238,245,252,0)');rg.addColorStop(1,`rgba(238,245,252,${.7*fogA})`);
    ctx.fillStyle=rg;ctx.fillRect(0,0,W,H);
  }
}

/* ---------------- phone layout ---------------- */
const mapwrap=$('#mapwrap'),frame=$('#frame'),island=$('#island'),screen=$('#screen');
function phoneRect(){
  const W=MW,H=MH;let h,w,x,y;
  if(W<820){h=Math.min(H*.54,560);w=h*390/844;x=(W-w)/2;y=H-h-Math.max(16,w*.04)-6;}
  else{h=Math.min(H*.8,780);w=h*390/844;x=W*.29-w/2;y=(H-h)/2+30;}
  return {x,y,w,h,k:w/390,r:54*w/390};
}
let S=null;
function layoutPhone(){
  S=phoneRect();
  const bz=Math.max(7,S.w*.032);
  Object.assign(frame.style,{left:S.x+'px',top:S.y+'px',width:S.w+'px',height:S.h+'px',borderRadius:S.r+'px',
    boxShadow:`0 0 0 ${bz}px #0d131b, 0 0 0 ${bz+1.5}px #3a4350, 0 50px 90px -30px rgba(15,34,53,.55)`});
  Object.assign(island.style,{top:S.h*.014+'px',width:S.w*.3+'px',height:S.h*.04+'px'});
  stage.style.setProperty('--ptop',(S.y-bz)+'px');
}

/* ---------------- search UI ---------------- */
const q=$('#q'),results=$('#results'),sheet=$('#sheet'),clr=$('#clr'),pcardHost=$('#pcardHost');
function match(term){
  const t=term.trim().toLowerCase();
  if(!t)return PLACES.filter(p=>p.near);
  const words=t.split(/\s+/).filter(w=>w.length>1&&!['find','a','the','near','me','nearby','sites','site','places','place','of','in'].includes(w));
  return PLACES.filter(p=>{
    const hay=(p.name+' '+p.cat+' '+p.area).toLowerCase();
    if(hay.includes(t))return true;
    return words.length&&words.some(w=>hay.includes(w)||p.tags.some(g=>g.startsWith(w)||w.startsWith(g)));
  });
}
function renderResults(){
  const term=q.value;const list=match(term);
  clr.hidden=!term;
  if(!list.length){
    results.innerHTML=`<div class="empty"><b>No reviews for “${esc(term)}” yet</b>Been there? You can add the first one.<br><button type="button" tabindex="-1">Add a review</button></div>`;
    return;
  }
  results.innerHTML=`<div class="rhead">${term.trim()?list.length+' result'+(list.length>1?'s':''):'Nearby'}</div>`+list.map(p=>
    `<button class="ri" data-id="${p.id}" type="button"><span class="dot" style="background:${ST[p.st].c}">${IC[p.st]}</span><span class="t"><b>${p.name}</b><span>${p.cat} · ${p.area}</span></span><span class="s" style="color:${ST[p.st].fg}">${ST[p.st].t}</span></button>`).join('');
}
const esc=s=>s.replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
function openSheet(on){sheet.classList.toggle('open',on);}
function closeCard(){sel=null;pcardHost.innerHTML='';sheet.classList.remove('min');pcam.tx=USER.x;pcam.ty=USER.y;pcam.tz=1;}
function openPlace(id){
  const p=PLACES.find(x=>x.id===id);if(!p)return;
  sel=id;pcam.tx=p.x;pcam.ty=p.y+90;pcam.tz=1.25;
  openSheet(false);q.blur();sheet.classList.add('min');
  const s=ST[p.st];
  pcardHost.innerHTML=`<div class="pcard" role="dialog" aria-label="${p.name}">
    <div class="pc-ban" style="background:${s.bg};color:${s.fg}">${IC[p.st]}${s.t}</div>
    <button class="pc-x" type="button" aria-label="Close">${IC.no}</button>
    <div class="pc-body"><h4>${p.name}</h4><div class="pc-sub">${p.cat} · ${p.area}</div>
    <ul class="feats">${p.f.map(([t,v])=>`<li><i style="background:${ST[v].c}">${IC[v]}</i>${t}</li>`).join('')}</ul>
    <div class="pc-note"><b>From reviews</b>${p.note}</div>
    <div class="pc-foot"><span>${p.n} reviews</span><span>Last visit ${p.last}</span></div></div></div>`;
  pcardHost.querySelector('.pc-x').onclick=closeCard;
}
function runSearch(term){closeCard();q.value=term;renderResults();openSheet(true);}
q.addEventListener('input',()=>{if(sel)closeCard();renderResults();openSheet(true);});
q.addEventListener('focus',()=>{if(sel)closeCard();renderResults();openSheet(true);});
clr.addEventListener('click',()=>{q.value='';renderResults();q.focus();});
results.addEventListener('click',e=>{const b=e.target.closest('.ri');if(b)openPlace(b.dataset.id);else if(e.target.closest('.empty button'))scrollToP(.6);});
$('#cats').addEventListener('click',e=>{const b=e.target.closest('button');if(b)runSearch(b.dataset.q);});
document.querySelectorAll('.try').forEach(b=>b.addEventListener('click',()=>runSearch(b.dataset.q)));
document.addEventListener('pointerdown',e=>{if(!sheet.contains(e.target)&&!e.target.closest('.try')&&!q.value)openSheet(false);});
renderResults();

/* ---------------- review UI ---------------- */
const TILES=[['ENTRANCE','<rect x="7" y="9" width="24" height="24" rx="2" fill="#E7EEF7" stroke="#2f3a48" stroke-width="2"/><rect x="11" y="13" width="7" height="20" fill="#9CC4EE" stroke="#2f3a48" stroke-width="1.6"/><rect x="20" y="13" width="7" height="20" fill="#9CC4EE" stroke="#2f3a48" stroke-width="1.6"/><rect x="11" y="4" width="16" height="6" rx="1.5" fill="#FFD166" stroke="#2f3a48" stroke-width="1.6"/>'],
 ['ELEVATORS','<rect x="9" y="6" width="20" height="28" rx="2" fill="#E7EEF7" stroke="#2f3a48" stroke-width="2"/><path d="M19 6v28" stroke="#2f3a48" stroke-width="2"/><rect x="16" y="2" width="6" height="4" rx="1" fill="#FFD166" stroke="#2f3a48" stroke-width="1.4"/>'],
 ['TOILET','<rect x="6" y="8" width="8" height="12" rx="3" fill="#E7EEF7" stroke="#2f3a48" stroke-width="1.8"/><path d="M17 16h16c0 7-3 11-8 11s-8-4-8-11z" fill="#fff" stroke="#2f3a48" stroke-width="2"/><rect x="18" y="8" width="14" height="7" rx="2" fill="#E7EEF7" stroke="#2f3a48" stroke-width="1.8"/><path d="M22 27l-1 6h8l-1-6" fill="#fff" stroke="#2f3a48" stroke-width="1.8"/>'],
 ['OUTDOOR<br>PATHWAYS','<path d="M8 30c4-10 18-6 22-16 2-5-2-8-6-8" fill="none" stroke="#c8b79c" stroke-width="7" stroke-linecap="round"/><path d="M8 30c4-10 18-6 22-16 2-5-2-8-6-8" fill="none" stroke="#2f3a48" stroke-width="1.5" stroke-dasharray="3 3"/><circle cx="9" cy="10" r="4" fill="#5FB97C"/>'],
 ['SEATING','<rect x="6" y="14" width="26" height="6" rx="1.5" fill="#E7EEF7" stroke="#2f3a48" stroke-width="2"/><path d="M9 20v12M29 20v12M12 14V7M26 14V7M12 9h14" stroke="#2f3a48" stroke-width="2" stroke-linecap="round"/>'],
 ['PARKING','<rect x="5" y="5" width="28" height="28" rx="6" fill="#4A90E2" stroke="#2f3a48" stroke-width="2"/><circle cx="16" cy="12" r="2.4" fill="#fff"/><path d="M16 15v7h6l3 6M13 18a6 6 0 1 0 8 8" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>']];
const tileHTML=TILES.map(([n,ic],i)=>`<div class="tile" data-i="${i}"><span class="ck">${IC.ok}</span><svg class="ic" viewBox="0 0 38 38">${ic}</svg><span style="text-align:center">${n} ›</span></div>`).join('');
$('#grid6').innerHTML=tileHTML;$('#grid6b').innerHTML=tileHTML;
$('#grid6b .tile').classList.add('sel');
const rvA=$('#rvA'),rvB=$('#rvB'),rvC=$('#rvC'),rvBtn=$('#rvBtn'),rvBar=$('#rvBar'),tap=$('#tap'),toast=$('#toast');
const opts=[...document.querySelectorAll('#opts div')],tileA=document.querySelector('#grid6 .tile'),stepsLi=[...document.querySelectorAll('#rvSteps li')];
function setReview(r){
  const st=r<.34?0:r<.68?1:2;
  rvA.classList.toggle('off',st!==0);rvB.classList.toggle('off',st!==1);rvC.classList.toggle('off',st!==2);
  const aSel=r>.15,bSel=r>.5,sub=r>.84;
  tileA.classList.toggle('sel',aSel);opts[0].classList.toggle('sel',bSel);
  rvBtn.textContent=st===2?(sub?'Submitted':'Submit'):'Continue';
  rvBtn.classList.toggle('go',(st===0&&aSel)||(st===1&&bSel)||st===2);
  rvBar.style.width=(st===0?12:st===1?55:100)+'%';
  toast.classList.toggle('on',sub);
  let tp=null;
  if(r>.07&&r<.17)tp=[107,305];else if(r>.42&&r<.52)tp=[195,479];else if(r>.76&&r<.86)tp=[195,773];
  tap.classList.toggle('on',!!tp);if(tp){tap.style.left=tp[0]+'px';tap.style.top=tp[1]+'px';}
  stepsLi.forEach((li,i)=>{li.classList.toggle('on',i===st&&!(i===2&&sub));li.classList.toggle('done',i<st||(i===2&&sub));});
}
/* ---------------- detail UI ---------------- */
const detScroll=$('#detScroll'),newResp=$('#newResp');
function setDetail(d){
  detScroll.style.transform=`translateY(${-ease(seg(d,.05,.55))*470}px)`;
  const added=d>.55;
  newResp.classList.toggle('on',added);
  $('#b1').style.flexGrow=added?3:2;$('#l1').textContent='Easy · '+(added?3:2);
  $('#respN').textContent=(added?7:6)+' responses';
  $('#stN').textContent=added?7:6;$('#stE').textContent=(added?43:33)+'%';
}

/* ---------------- story update ---------------- */
const hero=$('#hero'),legend=$('#legend'),hint=$('#hint'),cap1=$('#cap1'),cap2=$('#cap2');
const cSearch=$('#cSearch'),cReview=$('#cReview'),cShare=$('#cShare'),pvRev=$('#pvRev'),pvDet=$('#pvDet');
const story=$('#story');
let lastInteractive=null;
function scrollToP(p){const r=story.getBoundingClientRect();window.scrollTo({top:scrollY+r.top+p*(r.height-innerHeight),behavior:reduce?'auto':'smooth'});}
function updateStory(now,P){
  const W=MW,H=MH,M=Math.max(W,H),mob=W<820;
  const h=seg(P,0,.2),u=ease(seg(P,.2,.3));
  // camera
  pcam.x+=(pcam.tx-pcam.x)*.08;pcam.y+=(pcam.ty-pcam.y)*.08;pcam.z+=(pcam.tz-pcam.z)*.08;
  const s0=M/(mob?1500:1900)*(1+.25*h),s1=S.w/640*pcam.z;
  cam.s=Math.exp(lerp(Math.log(s0),Math.log(s1),u));
  const drift=reduce?0:1,tt=now-t0;
  cam.x=lerp(1250+50*Math.sin(tt*.00008)*drift,pcam.x,u);
  cam.y=lerp(960+lerp(0,60,h),pcam.y,u);
  cam.rot=lerp(-.06+.05*Math.sin(tt*.00006)*drift,0,u);
  cam.tilt=lerp(.55-.12*h,0,u);
  cam.invR=Math.exp(lerp(Math.log(1/(M*.75)),Math.log(1/(M*60)),u));
  cam.F=M*1.5;
  cam.ox=lerp(W/2,S.x+S.w/2,u);cam.oy=lerp(H*(mob?.68:.72),S.y+S.h*.42,u);
  drawMap(now,h,u,S);
  // clip map into phone
  const sx=lerp(0,S.x,u),sy=lerp(0,S.y,u),sw=lerp(W,S.w,u),sh=lerp(H,S.h,u),rad=lerp(0,S.r,u);
  mapwrap.style.clipPath=u>0?`inset(${sy}px ${W-sx-sw}px ${H-sy-sh}px ${sx}px round ${rad}px)`:'none';
  frame.style.opacity=seg(u,.55,1);
  screen.style.transform=`translate(${S.x}px,${S.y}px) scale(${S.k})`;
  screen.style.opacity=seg(u,.8,1);
  const interactive=u>.97&&P<.545;
  if(interactive!==lastInteractive){lastInteractive=interactive;screen.style.pointerEvents=interactive?'auto':'none';
    screen.querySelectorAll('#pvMap button,#pvMap input').forEach(el=>el.tabIndex=interactive?0:-1);
    if(!interactive){q.blur();}}
  // hero
  const ho=seg(P,.18,.25);
  hero.style.opacity=1-ho;hero.style.transform=`translateY(${-70*ho}px)`;hero.style.visibility=ho>=1?'hidden':'visible';
  legend.style.opacity=1-seg(P,.16,.22);legend.style.visibility=P>=.22?'hidden':'visible';
  hint.style.opacity=1-seg(P,.02,.06);
  const c2=h>.42;cap1.style.opacity=c2?0:1;cap1.style.transform=c2?'translateY(-8px)':'none';cap2.style.opacity=c2?1:0;cap2.style.transform=c2?'none':'translateY(8px)';
  // copy
  cSearch.classList.toggle('on',P>=.28&&P<.54);
  cReview.classList.toggle('on',P>=.54&&P<.77);
  cShare.classList.toggle('on',P>=.77);
  pvRev.classList.toggle('on',P>=.54);
  pvDet.classList.toggle('on',P>=.77);
  setReview(seg(P,.56,.76));
  setDetail(seg(P,.79,.98));
}

/* ---------------- impact globe ---------------- */
const gc=$('#globe'),gx=gc.getContext('2d'),istage=$('#istage'),impact=$('#impact'),iA=$('#iA'),iB=$('#iB'),walkersEl=$('#walkers');
const walkers=[...document.querySelectorAll('.walker')];
let GW=0,GH=0;
function sizeGlobe(){GW=istage.clientWidth;GH=istage.clientHeight;gc.width=Math.round(GW*DPR);gc.height=Math.round(GH*DPR);gc.style.width=GW+'px';gc.style.height=GH+'px';}
const GP=[];{const N=2400;for(let i=0;i<N;i++){const y=1-2*(i+.5)/N,r=Math.sqrt(1-y*y),th=i*2.399963;GP.push([Math.cos(th)*r,y,Math.sin(th)*r]);}}
const GPins=[];{const R=rng(5);for(let i=0;i<70;i++){const p=GP[Math.floor(R()*GP.length)];const v=R();GPins.push({p,c:v<.55?ST.ok.c:v<.8?ST.part.c:ST.no.c});}}
function globeParams(q){
  const W=GW,H=GH,mob=W<700;
  const RA=mob?W*1.3:Math.max(W*.62,680), topA=H*(mob?.76:.74);
  const RB=Math.min(W,H)*(mob?.17:.13);
  const t=ease(seg(q,.32,.68));
  const R=Math.exp(lerp(Math.log(RA),Math.log(RB),t));
  const cy=lerp(topA+RA,H/2,t);
  return {R,cx:W/2,cy,t,RB};
}
function drawGlobe(now,q){
  const ctx=gx,W=GW,H=GH;ctx.setTransform(DPR,0,0,DPR,0,0);ctx.clearRect(0,0,W,H);
  const {R,cx,cy,t,RB}=globeParams(q);
  const glow=ctx.createRadialGradient(cx,cy,R*.9,cx,cy,R*1.18);glow.addColorStop(0,'rgba(140,200,255,.35)');glow.addColorStop(1,'rgba(140,200,255,0)');
  ctx.fillStyle=glow;ctx.beginPath();ctx.arc(cx,cy,R*1.18,0,7);ctx.fill();
  const body=ctx.createRadialGradient(cx-R*.3,cy-R*.45,R*.1,cx,cy,R);body.addColorStop(0,'#4FA2F7');body.addColorStop(1,'#0B4CA6');
  ctx.fillStyle=body;ctx.beginPath();ctx.arc(cx,cy,R,0,7);ctx.fill();
  ctx.strokeStyle='rgba(255,255,255,.35)';ctx.lineWidth=1.5;ctx.stroke();
  const ry=(reduce?0:(now-t0)*.00008)+q*1.2, rx=lerp(.95,.35,t);
  const cyr=Math.cos(ry),syr=Math.sin(ry),cxr=Math.cos(rx),sxr=Math.sin(rx);
  const dot=Math.max(1.1,Math.min(3.2,R*.006));
  ctx.fillStyle='#fff';
  for(const p of GP){
    const x1=p[0]*cyr+p[2]*syr,z1=-p[0]*syr+p[2]*cyr;
    const y2=p[1]*cxr-z1*sxr,z2=p[1]*sxr+z1*cxr;
    if(z2<=0)continue;
    const X=cx+x1*R,Y=cy-y2*R;if(Y<-5||Y>H+5||X<-5||X>W+5)continue;
    ctx.globalAlpha=.12+.5*z2;const d=dot*(.5+.5*z2);ctx.fillRect(X-d/2,Y-d/2,d,d);
  }
  ctx.globalAlpha=1;
  const pr=Math.max(3.2,Math.min(7,R*.022));
  for(const g of GPins){const p=g.p;
    const x1=p[0]*cyr+p[2]*syr,z1=-p[0]*syr+p[2]*cyr,y2=p[1]*cxr-z1*sxr,z2=p[1]*sxr+z1*cxr;
    if(z2<=.12)continue;const X=cx+x1*R,Y=cy-y2*R;if(Y<-10||Y>H+10)continue;
    ctx.globalAlpha=Math.min(1,z2*1.6);ctx.beginPath();ctx.arc(X,Y,pr*(.6+.4*z2)+1.6,0,7);ctx.fillStyle='#fff';ctx.fill();
    ctx.beginPath();ctx.arc(X,Y,pr*(.6+.4*z2),0,7);ctx.fillStyle=g.c;ctx.fill();}
  ctx.globalAlpha=1;
  // walkers on top of the globe
  const n=W<620?3:W<1000?4:6,sc=W<620?.82:1,sp=Math.min(190,(W-40)/(n+.2));
  const wa=1-seg(q,.28,.46);
  walkersEl.style.opacity=wa;walkersEl.style.visibility=wa<=0?'hidden':'visible';
  walkers.forEach((el,i)=>{
    if(i>=n){el.style.display='none';return;}el.style.display='';
    const x=cx+(i-(n-1)/2)*sp*Math.min(1,R/700+.2),dx=clamp(x-cx,-R,R),y=cy-Math.sqrt(Math.max(0,R*R-dx*dx));
    const ang=Math.asin(clamp(dx/R,-1,1));
    el.style.transform=`translate(${x-70}px,${y-150+3}px) rotate(${ang}rad) scale(${sc*lerp(1,.4,t)})`;
  });
  iA.style.opacity=1-seg(q,.26,.4);iA.style.transform=`translateY(${-50*seg(q,.26,.4)}px)`;
  const b=seg(q,.55,.75);iB.style.opacity=b;iB.style.transform=`scale(${lerp(.94,1,b)})`;
  iB.style.setProperty('--gr',RB+'px');
}

/* ---------------- CTA rider ---------------- */
$('#rider').innerHTML=walkers[0].querySelector('svg').outerHTML;

/* ---------------- loop ---------------- */
function resize(){sizeMap();sizeGlobe();layoutPhone();}
addEventListener('resize',resize);resize();
function frameLoop(now){
  requestAnimationFrame(frameLoop);
  const vh=innerHeight;
  const sr=story.getBoundingClientRect();
  if(sr.bottom>0&&sr.top<vh)updateStory(now,clamp(-sr.top/(sr.height-vh)));
  const ir=impact.getBoundingClientRect();
  if(ir.bottom>0&&ir.top<vh)drawGlobe(now,clamp(-ir.top/(ir.height-vh)));
}
requestAnimationFrame(frameLoop);
})();
