#!/bin/bash
/usr/bin/curl -sL 'https://www.ici.fr/rss/la-rochelle/a-la-une.xml' > /tmp/ici_lr.xml &
/usr/bin/curl -sL 'https://www.ici.fr/rss/la-rochelle/rubrique/infos.xml' > /tmp/ici_info.xml &
/usr/bin/curl -sL 'https://www.charentelibre.fr/charente/rss.xml' > /tmp/cl.xml &
/usr/bin/curl -sL 'https://www.francetvinfo.fr/france.rss' > /tmp/fi_fr.xml &
/usr/bin/curl -sL 'https://www.francetvinfo.fr/monde.rss' > /tmp/fi_mo.xml &
/usr/bin/curl -sL 'https://www.france24.com/fr/rss' > /tmp/f24.xml &
/usr/bin/curl -sL 'https://www.clubic.com/feed/news.rss' > /tmp/clubic.xml &
/usr/bin/curl -sL 'https://www.numerama.com/feed/' > /tmp/numerama.xml &
wait

parse() {
  [ ! -s "$1" ] && return
  /usr/bin/awk -v RS='</item>' -v SRC="$2" -v MAX="${3:-10}" '
  /<item>/ && n < MAX {
    s=$0; sub(/.*<item>/,"",s)
    t=s; sub(/.*<title>/,"",t); sub(/<\/title>.*/,"",t)
    sub(/^<!\[CDATA\[/,"",t); sub(/\]\]>$/,"",t)
    gsub(/^ +| +$/,"",t); gsub(/[\n\r]/,"",t)
    u=s; sub(/.*<link>/,"",u); sub(/<\/link>.*/,"",u)
    sub(/#xtor[^\t\n]*/,"",u); sub(/\?at_medium[^\t\n]*/,"",u)
    gsub(/^ +| +$/,"",u); gsub(/[\n\r]/,"",u)
    h=""
    dy=""
    if(match(s,/<pubDate>[^<]+<\/pubDate>/)){
      pd=substr(s,RSTART,RLENGTH)
      if(match(pd,/[0-9][0-9]:[0-9][0-9]/))h=substr(pd,RSTART,5)
      if(match(pd,/[0-9][0-9]? [A-Z][a-z][a-z]/)){dy=substr(pd,RSTART,RLENGTH);sub(/ .*/,"",dy)}
    }
    img=""
    if(match(s,/enclosure[^>]+url="[^"]+"/)){
      img=substr(s,RSTART,RLENGTH)
      sub(/.*url="/,"",img); sub(/".*/,"",img)
    } else if(match(s,/media:content[^>]+url="[^"]+"/)){
      img=substr(s,RSTART,RLENGTH)
      sub(/.*url="/,"",img); sub(/".*/,"",img)
    } else if(match(s,/media:thumbnail[^>]+url="[^"]+"/)){
      img=substr(s,RSTART,RLENGTH)
      sub(/.*url="/,"",img); sub(/".*/,"",img)
    } else if(match(s,/img[^>]+src="http[^"]+\.(jpg|jpeg|png|webp)/)){
      img=substr(s,RSTART,RLENGTH)
      sub(/.*src="/,"",img); sub(/".*/,"",img)
    }
    gsub(/[\n\r ]/,"",img)
    gsub(/&amp;/,"\\&",img)
    if(t!=""&&length(t)>5){printf "%s\t%s\t%s\t%s\t%s\t%s\n",h,SRC,u,t,img,dy;n++}
  }' "$1"
}

dedup() {
  printf '%s\n' "$1" | /usr/bin/awk -F'\t' '{
    key=tolower($4); gsub(/[^a-zàâäéèêëïîôùûüÿç0-9 ]/,"",key); gsub(/  +/," ",key)
    w=split(key,a," "); sig=""
    for(i=1;i<=w&&i<=6;i++) sig=sig a[i]
    if(!seen[sig]++){print}
  }'
}

LOCAL=$(parse /tmp/ici_lr.xml "ICI" 8; parse /tmp/ici_info.xml "ICI" 6; parse /tmp/cl.xml "CL" 6)
LOCAL=$(dedup "$LOCAL")
FRANCE=$(parse /tmp/fi_fr.xml "FI" 18)
MONDE=$(parse /tmp/fi_mo.xml "FI" 9; parse /tmp/f24.xml "F24" 9)
MONDE=$(dedup "$MONDE")
TECH=$(parse /tmp/clubic.xml "CLB" 9; parse /tmp/numerama.xml "NUM" 9)

gen() {
  printf '%s\n' "$1" | /usr/bin/awk -F'\t' 'NF>=4{
    di=""
    if(NF>=5 && $5!="") di=" data-img=\"" $5 "\""
    dd=""
    if(NF>=6 && $6!="") dd=" data-day=\"" $6 "\""
    printf "<li class=\"ni\"%s%s><div class=\"nt\">%s <span class=\"sr\">%s</span></div><div class=\"nn\"><a data-url=\"%s\">%s</a></div></li>\n",di,dd,$1,$2,$3,$4
  }'
}

CL=$(gen "$LOCAL")
CF=$(gen "$FRANCE")
CM=$(gen "$MONDE")
CT=$(gen "$TECH")
NOW=$(/bin/date '+%H:%M')
NOWTS=$(/bin/date '+%s')
FILE="$HOME/Desktop/lessentiel.html"

printf '<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="referrer" content="no-referrer"><meta name="apple-mobile-web-app-capable" content="yes"><meta name="apple-mobile-web-app-status-bar-style" content="black-translucent"><title>L'\''essentiel</title>\n' > "$FILE"

ICON="/Users/idata/Library/Mobile Documents/com~apple~CloudDocs/William/Logos/It's A Sony Logo.jpeg"
if [ -f "$ICON" ]; then
  printf '<link rel="icon" type="image/jpeg" href="data:image/jpeg;base64,' >> "$FILE"
  /usr/bin/base64 -i "$ICON" | /usr/bin/tr -d '\n' >> "$FILE"
  printf '">\n' >> "$FILE"
fi

cat >> "$FILE" << 'ENDHTML'
<style>
@import url('https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;600&display=swap');
:root{--bg:rgba(250,248,243,.78);--c:#1a1a1a;--c2:#999;--c3:#444;--bdr:#1A7CE8;--sep:rgba(0,0,0,.08);--nb:rgba(0,0,0,.05);--pls:#333;--lo:#8B6914;--fr:#1a5276;--mo:#c0392b;--te:#148f77;--lob:rgba(139,105,20,.018);--frb:rgba(26,82,118,.018);--mob:rgba(192,57,43,.018);--teb:rgba(20,143,119,.018);--loh:rgba(139,105,20,.06);--frh:rgba(26,82,118,.06);--moh:rgba(192,57,43,.06);--teh:rgba(20,143,119,.06);--los:rgba(253,251,245,.97);--frs:rgba(248,250,253,.97);--mos:rgba(253,249,248,.97);--tes:rgba(248,253,252,.97);--lof:rgba(253,251,245,.95);--frf:rgba(248,250,253,.95);--mof:rgba(253,249,248,.95);--tef:rgba(248,253,252,.95);--sha:rgba(0,0,0,.22);--rd-bg:rgba(250,248,243,.97)}
.dark{--bg:#1a1a1e;--c:#d8d5d0;--c2:#666;--c3:#777;--bdr:#1A7CE8;--sep:rgba(255,255,255,.06);--nb:rgba(255,255,255,.04);--pls:#888;--lo:#c4a033;--fr:#3498db;--mo:#e74c3c;--te:#1abc9c;--lob:rgba(196,160,51,.03);--frb:rgba(52,152,219,.03);--mob:rgba(231,76,60,.03);--teb:rgba(26,188,156,.03);--loh:rgba(196,160,51,.08);--frh:rgba(52,152,219,.08);--moh:rgba(231,76,60,.08);--teh:rgba(26,188,156,.08);--los:rgba(30,28,22,.97);--frs:rgba(22,26,32,.97);--mos:rgba(32,24,24,.97);--tes:rgba(22,30,28,.97);--lof:rgba(30,28,22,.95);--frf:rgba(22,26,32,.95);--mof:rgba(32,24,24,.95);--tef:rgba(22,30,28,.95);--sha:rgba(0,0,0,.5);--rd-bg:#1a1a1e}
*{margin:0;padding:0;box-sizing:border-box}
html,body{height:100vh;height:100dvh;overflow:hidden}
body{font-family:"SF Mono","Menlo","Monaco","Consolas",monospace;background:var(--bg);color:var(--c);transition:background .4s,color .4s}
.p{display:flex;flex-direction:column;height:100vh;height:100dvh;padding:28px 40px 0}
header{flex-shrink:0;display:flex;justify-content:space-between;align-items:flex-end;border-bottom:3px solid var(--bdr);padding-bottom:12px;margin-bottom:20px;animation:breatheBdr 3s ease-in-out infinite}
@keyframes breatheBdr{0%,100%{border-bottom-color:var(--bdr)}50%{border-bottom-color:rgba(26,124,232,.35)}}
.hl{display:flex;align-items:baseline;gap:14px;animation:breathe 3s ease-in-out infinite}
h1{font-size:26px;font-weight:700;text-transform:uppercase;letter-spacing:-.5px;cursor:pointer}
@keyframes breathe{0%,100%{opacity:1}50%{opacity:.45}}
.dot{color:var(--c3)}
.hr{text-align:right}
.ck{font-size:13px;color:var(--c2)}
.sl{font-size:10px;color:var(--c2);margin-top:4px;display:flex;align-items:center;justify-content:flex-end;gap:6px}
.pu{width:6px;height:6px;background:var(--pls);border-radius:50%;display:inline-block;animation:pu 2s ease-in-out infinite}
@keyframes pu{0%,100%{opacity:1}50%{opacity:.25}}
.rb{background:none;border:none;cursor:pointer;padding:2px;margin-left:4px;opacity:.3;transition:opacity .2s,transform .3s ease;vertical-align:middle;color:var(--c2)}
.rb:hover{opacity:.7}
.rb:last-of-type:hover{transform:rotate(180deg)}
.rb svg{width:12px;height:12px;display:block}
.tabs{display:none}
.g{flex:1;display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:0 28px;overflow:hidden;min-height:0}
.cw{position:relative;overflow:hidden;min-height:0;opacity:0;animation:colIn .5s ease forwards}
.cw:nth-child(1){animation-delay:0s}
.cw:nth-child(2){animation-delay:.12s;border-left:1px solid var(--sep)}
.cw:nth-child(3){animation-delay:.24s;border-left:1px solid var(--sep)}
.cw:nth-child(4){animation-delay:.36s;border-left:1px solid var(--sep)}
@keyframes colIn{from{opacity:0;transform:translateY(10px)}to{opacity:1;transform:translateY(0)}}
.c{padding-right:14px;padding-bottom:20px;overflow-y:scroll;overflow-x:hidden;height:100%;-webkit-overflow-scrolling:touch;transition:background .4s,opacity .4s}
.c::-webkit-scrollbar{display:none}
.c{scrollbar-width:none}
.cw:last-child .c{padding-right:0;padding-left:14px}
.cw:nth-child(2) .c,.cw:nth-child(3) .c,.cw:nth-child(4) .c{padding-left:14px}
.lo{background:var(--lob)}.fr{background:var(--frb)}.mo{background:var(--mob)}.te{background:var(--teb)}
.c.all-read{opacity:.5}
.c.all-read .sh{opacity:.5}
.fade{position:absolute;bottom:0;left:0;right:0;height:35px;pointer-events:none;z-index:3;opacity:0;transition:opacity .3s}
.c.lo+.fade{background:linear-gradient(to bottom,transparent,var(--lof))}
.c.fr+.fade{background:linear-gradient(to bottom,transparent,var(--frf))}
.c.mo+.fade{background:linear-gradient(to bottom,transparent,var(--mof))}
.c.te+.fade{background:linear-gradient(to bottom,transparent,var(--tef))}
.sh{font-size:11px;font-weight:800;letter-spacing:3px;text-transform:uppercase;padding-bottom:8px;margin-bottom:4px;border-bottom:2px solid;position:sticky;top:0;z-index:2;padding-top:2px;transition:color .4s,border-color .4s,background .4s,opacity .4s;cursor:pointer}
.sh:hover{opacity:.7}
.sh-dot{display:inline-block;width:6px;height:6px;border-radius:50%;margin-right:6px;vertical-align:middle;animation:pu 2s ease-in-out infinite}
.lo .sh{color:var(--lo);border-bottom-color:var(--lo);background:var(--los)}
.fr .sh{color:var(--fr);border-bottom-color:var(--fr);background:var(--frs)}
.mo .sh{color:var(--mo);border-bottom-color:var(--mo);background:var(--mos)}
.te .sh{color:var(--te);border-bottom-color:var(--te);background:var(--tes)}
.lo .sh-dot{background:var(--lo)}
.fr .sh-dot{background:var(--fr)}
.mo .sh-dot{background:var(--mo)}
.te .sh-dot{background:var(--te)}
.cnt{font-weight:400;opacity:.35;margin-left:6px;font-size:8px;letter-spacing:1px}
ul{list-style:none}
.ni{padding:9px 7px;margin:0 -7px;border-radius:4px;border-bottom:1px solid var(--nb);display:grid;grid-template-columns:52px 1fr;gap:0 7px;transition:background .2s,border-bottom-color .2s,opacity .3s}
.lo .ni:hover{background:var(--loh);border-bottom-color:var(--lo)}
.fr .ni:hover{background:var(--frh);border-bottom-color:var(--fr)}
.mo .ni:hover{background:var(--moh);border-bottom-color:var(--mo)}
.te .ni:hover{background:var(--teh);border-bottom-color:var(--te)}
.ni:last-child{border-bottom:none}
.ni.rd{opacity:.35}
.ni.rd:hover{opacity:.7}
.nt{font-size:10px;color:var(--c2);padding-top:2px;text-align:right;white-space:nowrap}
.lo .sr{color:var(--lo)}.fr .sr{color:var(--fr)}.mo .sr{color:var(--mo)}.te .sr{color:var(--te)}
.sr{font-size:7px;font-weight:700;letter-spacing:.5px;transition:color .4s}
.nn{font-size:12.5px;font-weight:400;line-height:1.45;display:flex;align-items:start;gap:5px}
.nn a{color:var(--c);text-decoration:none;display:inline-block;transition:transform .15s,color .4s;transform-origin:left center;cursor:pointer}
.nn a:hover{transform:scale(1.03)}
.fd{width:5px;height:5px;border-radius:50%;display:inline-block;flex-shrink:0;margin-top:7px;animation:pu 2s ease-in-out infinite}
.lo .fd{background:var(--lo)}.fr .fd{background:var(--fr)}.mo .fd{background:var(--mo)}.te .fd{background:var(--te)}
.ds{padding:4px 0;margin:0 -7px;font-size:7px;font-weight:500;letter-spacing:2px;text-transform:uppercase;color:var(--c2);opacity:.5;text-align:center;border-top:1px solid var(--nb);list-style:none}
.img-pop{position:fixed;pointer-events:none;z-index:1000;width:230px;border-radius:12px;box-shadow:0 4px 18px var(--sha);opacity:0;transition:opacity .5s ease;overflow:hidden}
.img-pop img{width:100%;height:158px;object-fit:cover;display:block}
.img-pop.show{opacity:1}
.reader{position:fixed;top:0;right:-50vw;width:50vw;height:100vh;height:100dvh;background:var(--rd-bg);z-index:900;transition:right .35s ease;box-shadow:-4px 0 20px rgba(0,0,0,.15);display:flex;flex-direction:column;font-family:'IBM Plex Mono',monospace}
.reader.open{right:0}
.reader-bar{flex-shrink:0;display:flex;justify-content:space-between;align-items:center;padding:16px 24px;border-bottom:1px solid var(--sep)}
.reader-close{background:none;border:none;cursor:pointer;color:var(--c2);font-size:18px;line-height:1;padding:4px 8px;opacity:.5;transition:opacity .2s;font-family:'IBM Plex Mono',monospace}
.reader-close:hover{opacity:1}
.reader-src{font-size:9px;color:var(--c2);letter-spacing:1px;text-transform:uppercase}
.reader-body{flex:1;overflow-y:auto;padding:24px 28px;-webkit-overflow-scrolling:touch}
.reader-body::-webkit-scrollbar{display:none}
.reader-body h2{font-size:17px;font-weight:600;line-height:1.4;margin-bottom:16px;color:var(--c)}
.reader-body .reader-meta{font-size:10px;color:var(--c2);margin-bottom:20px}
.reader-body .reader-img{width:280px;border-radius:8px;margin-bottom:16px;float:right;margin-left:20px;display:none}
.reader-body .reader-txt{font-size:12.5px;line-height:1.8;color:var(--c);opacity:.85}
.reader-body .reader-txt p{margin-bottom:12px}
.reader-body .reader-loading{font-size:11px;color:var(--c2);animation:pu 1.5s ease-in-out infinite}
.reader-body .reader-link{display:inline-block;margin-top:24px;font-size:10px;color:var(--bdr);text-decoration:none;letter-spacing:.5px;text-transform:uppercase;font-weight:600;clear:both}
.reader-body .reader-link:hover{text-decoration:underline}
@media(max-width:1200px){.g{grid-template-columns:repeat(2,minmax(0,1fr))}.cw{border:none!important}.c{padding:0!important;margin-bottom:20px}.reader{width:70vw;right:-70vw}}
@media(max-width:700px){
.p{padding:16px 16px 0}
header{flex-direction:column;align-items:flex-start;gap:8px;padding-bottom:10px;margin-bottom:12px}
.hl{gap:10px}
h1{font-size:20px}
.hr{width:100%;display:flex;justify-content:space-between;align-items:center}
.ck{font-size:11px}
.sl{display:none}
.tabs{display:flex;gap:0;margin-bottom:12px;border-bottom:2px solid var(--sep);flex-shrink:0}
.tab{flex:1;text-align:center;padding:8px 4px;font-size:9px;font-weight:700;letter-spacing:2px;text-transform:uppercase;color:var(--c2);cursor:pointer;border-bottom:2px solid transparent;margin-bottom:-2px;transition:color .2s,border-color .2s}
.tab.active{border-bottom-color:var(--bdr);color:var(--c)}
.g{grid-template-columns:1fr;gap:0}
.cw{display:none;border:none!important;opacity:1;animation:none}
.cw.mob-active{display:block}
.cw .c{padding:0!important}
.sh{display:none}
.fade{display:none}
.img-pop{display:none!important}
.ni{grid-template-columns:42px 1fr;padding:10px 4px}
.nn{font-size:13px;line-height:1.5}
.reader{width:100vw;right:-100vw}
.reader-body{padding:16px 20px}
.reader-body h2{font-size:16px}
.reader-body .reader-img{width:100%;float:none;margin-left:0;margin-bottom:16px;max-height:200px;object-fit:cover}
}
</style></head><body>
<div class="p">
<header>
<div class="hl"><h1 id="logo">L'essentiel<span class="dot">.</span></h1></div>
<div class="hr"><div class="ck" id="ck"></div><div class="sl"><span class="pu"></span><span id="rn">
ENDHTML

printf 'Mis à jour · <span data-ts="%s"></span></span><button class="rb" id="tb" title="Mode jour/nuit (D)"></button><button class="rb" id="mal" title="Tout marquer comme lu (L)"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg></button><button class="rb" id="mau" title="Tout marquer comme non lu (U)"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg></button><button class="rb" id="rb" title="Rafraîchir (R)"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 2v6h-6"/><path d="M3 12a9 9 0 0 1 15-6.7L21 8"/><path d="M3 22v-6h6"/><path d="M21 12a9 9 0 0 1-15 6.7L3 16"/></svg></button></div></div>\n</header>\n<div class="tabs" id="tabs"><div class="tab active" data-col="0">Ici</div><div class="tab" data-col="1">France</div><div class="tab" data-col="2">Monde</div><div class="tab" data-col="3">Tech</div></div>\n<div class="g">\n' "$NOWTS" >> "$FILE"

printf '<div class="cw mob-active"><div class="c lo"><div class="sh"><span class="sh-dot"></span>Ici</div><ul>\n%s\n</ul></div><div class="fade"></div></div>\n' "$CL" >> "$FILE"
printf '<div class="cw"><div class="c fr"><div class="sh"><span class="sh-dot"></span>France</div><ul>\n%s\n</ul></div><div class="fade"></div></div>\n' "$CF" >> "$FILE"
printf '<div class="cw"><div class="c mo"><div class="sh"><span class="sh-dot"></span>Monde</div><ul>\n%s\n</ul></div><div class="fade"></div></div>\n' "$CM" >> "$FILE"
printf '<div class="cw"><div class="c te"><div class="sh"><span class="sh-dot"></span>Tech</div><ul>\n%s\n</ul></div><div class="fade"></div></div>\n' "$CT" >> "$FILE"

cat >> "$FILE" << 'ENDHTML'
</div></div>
<div class="reader" id="reader"><div class="reader-bar"><span class="reader-src" id="reader-src"></span><button class="reader-close" id="reader-close">✕</button></div><div class="reader-body" id="reader-body"></div></div>
<script>(function(){
var buildTs=parseInt(document.querySelector("[data-ts]").getAttribute("data-ts"))*1000;
var isMobile=window.innerWidth<=700;

function tk(){
  var n=new Date();
  var d=n.toLocaleDateString("fr-FR",{weekday:"long",day:"numeric",month:"long",year:"numeric"});
  var t=n.toLocaleTimeString("fr-FR",{hour:"2-digit",minute:"2-digit"});
  document.getElementById("ck").textContent=d.charAt(0).toUpperCase()+d.slice(1)+(isMobile?"":" · "+t);
  var ago=Math.floor((n.getTime()-buildTs)/60000);
  var el=document.querySelector("[data-ts]");
  if(ago<1)el.textContent="à l’instant";
  else if(ago<60)el.textContent="il y a "+ago+"min";
  else if(ago<1440)el.textContent="il y a "+Math.floor(ago/60)+"h";
  else el.textContent="il y a "+Math.floor(ago/1440)+"j";
}
tk();setInterval(tk,30000);

var html=document.documentElement;
var mq=window.matchMedia("(prefers-color-scheme:dark)");
var manual=false;
var tb=document.getElementById("tb");
var moonSVG='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>';
var sunSVG='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="5"/><path d="M12 1v2m0 18v2M4.22 4.22l1.42 1.42m12.72 12.72l1.42 1.42M1 12h2m18 0h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/></svg>';
if(mq.matches)html.classList.add("dark");
function ui(){tb.innerHTML=html.classList.contains("dark")?sunSVG:moonSVG}
mq.addEventListener("change",function(e){if(!manual){if(e.matches)html.classList.add("dark");else html.classList.remove("dark");ui()}});
tb.addEventListener("click",function(){manual=true;html.classList.toggle("dark");ui()});
ui();

document.getElementById("rb").addEventListener("click",function(){location.reload()});
document.getElementById("logo").addEventListener("click",function(){location.reload()});

var tabs=document.querySelectorAll(".tab");
var cws=document.querySelectorAll(".cw");
tabs.forEach(function(tab){
  tab.addEventListener("click",function(){
    var idx=parseInt(tab.getAttribute("data-col"));
    tabs.forEach(function(t){t.classList.remove("active")});
    tab.classList.add("active");
    cws.forEach(function(cw,i){
      if(i===idx){cw.classList.add("mob-active")}else{cw.classList.remove("mob-active")}
    });
  });
});

var readList=JSON.parse(localStorage.getItem("lessentiel_read")||"[]");
document.querySelectorAll("a[data-url]").forEach(function(a){
  if(readList.indexOf(a.getAttribute("data-url"))!==-1)a.closest(".ni").classList.add("rd");
});

function updateTitle(){
  document.title="L’essentiel";
}
function checkAllRead(){
  document.querySelectorAll(".c").forEach(function(col){
    var nis=col.querySelectorAll(".ni");
    var rds=col.querySelectorAll(".ni.rd");
    if(nis.length>0&&rds.length===nis.length){col.classList.add("all-read")}else{col.classList.remove("all-read")}
  });
}
updateTitle();checkAllRead();

function markRead(ni){
  var a=ni.querySelector("a[data-url]");
  if(!a)return;
  var url=a.getAttribute("data-url");
  if(!ni.classList.contains("rd")){
    ni.classList.add("rd");
    if(readList.indexOf(url)===-1){readList.push(url);if(readList.length>300)readList=readList.slice(-300);localStorage.setItem("lessentiel_read",JSON.stringify(readList))}
    updateTitle();checkAllRead();
  }
}

function toggleRead(ni){
  var a=ni.querySelector("a[data-url]");
  if(!a)return;
  var url=a.getAttribute("data-url");
  if(ni.classList.contains("rd")){
    ni.classList.remove("rd");
    var idx=readList.indexOf(url);
    if(idx!==-1){readList.splice(idx,1);localStorage.setItem("lessentiel_read",JSON.stringify(readList))}
  }else{
    ni.classList.add("rd");
    if(readList.indexOf(url)===-1){readList.push(url);if(readList.length>300)readList=readList.slice(-300);localStorage.setItem("lessentiel_read",JSON.stringify(readList))}
  }
  updateTitle();checkAllRead();
}

var reader=document.getElementById("reader");
var readerBody=document.getElementById("reader-body");
var readerSrc=document.getElementById("reader-src");
document.getElementById("reader-close").addEventListener("click",function(){reader.classList.remove("open")});
document.addEventListener("keydown",function(e){if(e.key==="Escape")reader.classList.remove("open")});

var touchStartX=0;
reader.addEventListener("touchstart",function(e){touchStartX=e.touches[0].clientX},{passive:true});
reader.addEventListener("touchend",function(e){
  var dx=e.changedTouches[0].clientX-touchStartX;
  if(dx>80)reader.classList.remove("open");
},{passive:true});

function openReader(ni){
  var a=ni.querySelector("a[data-url]");
  if(!a)return;
  var url=a.getAttribute("data-url");
  var title=a.textContent;
  var img=ni.getAttribute("data-img")||"";
  var time=ni.querySelector(".nt").textContent.trim();
  var src=ni.querySelector(".sr").textContent.trim();
  readerSrc.textContent=src+" · "+time;
  var h='<h2>'+title+'</h2>';
  h+='<div class="reader-meta">'+src+' · '+time+'</div>';
  if(img)h+='<img class="reader-img" src="'+img+'" style="display:block" onerror="this.style.display=\'none\'">';
  h+='<div class="reader-txt"><span class="reader-loading">Chargement…</span></div>';
  h+='<a class="reader-link" href="'+url+'" target="_blank">Ouvrir sur le site →</a>';
  readerBody.innerHTML=h;
  readerBody.scrollTop=0;
  reader.classList.add("open");
  markRead(ni);
  fetch('http://localhost:5151/fetch?url='+encodeURIComponent(url))
    .then(function(r){return r.json()})
    .then(function(data){
      var txt=readerBody.querySelector(".reader-txt");
      if(data.text){
        var paragraphs=data.text.split('\n\n');
        var ph='';
        for(var i=0;i<paragraphs.length;i++){
          if(paragraphs[i].trim())ph+='<p>'+paragraphs[i].trim()+'</p>';
        }
        txt.innerHTML=ph||'<p>'+data.text+'</p>';
      }else if(data.error){
        txt.innerHTML='<p style="opacity:.5">Impossible de charger</p>';
      }
    })
    .catch(function(){
      var txt=readerBody.querySelector(".reader-txt");
      txt.innerHTML='<p style="opacity:.5">Lecture hors ligne non disponible</p>';
    });
}

var longPressTimer=null;
var longPressNi=null;

document.addEventListener("click",function(e){
  var a=e.target.closest("a[data-url]");
  if(a){
    var url=a.getAttribute("data-url");
    window.open(url,"_blank");
    markRead(a.closest(".ni"));
    e.preventDefault();
  }
});

document.addEventListener("contextmenu",function(e){
  if(reader.classList.contains("open")){
    var inReader=e.target.closest(".reader");
    if(inReader){e.preventDefault();reader.classList.remove("open");return}
  }
  var ni=e.target.closest(".ni");
  if(ni){e.preventDefault();openReader(ni)}
});

if(isMobile){
  document.addEventListener("touchstart",function(e){
    var ni=e.target.closest(".ni");
    if(ni){
      longPressNi=ni;
      longPressTimer=setTimeout(function(){
        openReader(ni);
        longPressNi=null;
      },500);
    }
  },{passive:true});
  document.addEventListener("touchmove",function(){
    if(longPressTimer){clearTimeout(longPressTimer);longPressTimer=null;longPressNi=null}
  },{passive:true});
  document.addEventListener("touchend",function(){
    if(longPressTimer){clearTimeout(longPressTimer);longPressTimer=null}
  },{passive:true});

  var lastTap=0;
  document.addEventListener("touchend",function(e){
    var ni=e.target.closest(".ni");
    if(ni&&!longPressNi){
      var now=Date.now();
      if(now-lastTap<300){
        e.preventDefault();
        toggleRead(ni);
        lastTap=0;
      }else{
        lastTap=now;
      }
    }
    longPressNi=null;
  });
}

document.addEventListener("auxclick",function(e){
  if(e.button===1){
    var ni=e.target.closest(".ni");
    if(ni){e.preventDefault();toggleRead(ni)}
  }
});
document.addEventListener("mousedown",function(e){
  if(e.button===1){var ni=e.target.closest(".ni");if(ni)e.preventDefault()}
});

document.getElementById("mal").addEventListener("click",function(){
  document.querySelectorAll(".ni").forEach(function(el){
    el.classList.add("rd");
    var a=el.querySelector("a[data-url]");
    if(a){var url=a.getAttribute("data-url");if(readList.indexOf(url)===-1)readList.push(url)}
  });
  if(readList.length>300)readList=readList.slice(-300);
  localStorage.setItem("lessentiel_read",JSON.stringify(readList));
  updateTitle();checkAllRead();
});

document.getElementById("mau").addEventListener("click",function(){
  document.querySelectorAll(".ni.rd").forEach(function(el){el.classList.remove("rd")});
  readList=[];
  localStorage.setItem("lessentiel_read",JSON.stringify(readList));
  updateTitle();checkAllRead();
});

document.querySelectorAll(".sh").forEach(function(sh){
  sh.addEventListener("click",function(){
    var col=sh.closest(".c");
    if(col)col.scrollTo({top:0,behavior:"smooth"});
  });
});

document.addEventListener("keydown",function(e){
  if(e.target.tagName==="INPUT"||e.target.tagName==="TEXTAREA")return;
  var k=e.key.toLowerCase();
  if(k==="d"){e.preventDefault();document.getElementById("tb").click()}
  else if(k==="r"&&!reader.classList.contains("open")){e.preventDefault();location.reload()}
  else if(k==="l"){e.preventDefault();document.getElementById("mal").click()}
  else if(k==="u"){e.preventDefault();document.getElementById("mau").click()}
});

if(!isMobile){
  var pop=document.createElement("div");
  pop.className="img-pop";
  var popImg=document.createElement("img");
  popImg.alt="";
  popImg.style.cssText="opacity:0;transition:opacity .4s ease";
  pop.appendChild(popImg);
  document.body.appendChild(pop);
  var maskTop="linear-gradient(to bottom,black 0%,black 70%,transparent 100%)";
  var maskBot="linear-gradient(to top,black 0%,black 70%,transparent 100%)";
  var hoverTimer=null;var currentEl=null;var popAbove=true;
  popImg.onload=function(){if(currentEl){popImg.style.opacity="1";pop.classList.add("show")}};
  popImg.onerror=function(){popImg.style.opacity="0";pop.classList.remove("show")};
  function mv(e){
    var pw=230,ph=158,gap=14,vw=window.innerWidth,vh=window.innerHeight,cx=e.clientX,cy=e.clientY,x,y;
    if(cy-ph-gap>8){y=cy-ph-gap;popAbove=true}else if(cy+gap+ph<vh-8){y=cy+gap;popAbove=false}else{y=vh-ph-8;popAbove=false}
    x=cx-pw/2;if(x<8)x=8;if(x+pw>vw-8)x=vw-pw-8;if(y<8)y=8;
    pop.style.left=x+"px";pop.style.top=y+"px";
    var m=popAbove?maskTop:maskBot;
    pop.style.webkitMaskImage=m;pop.style.maskImage=m;
  }
  var nitems=document.querySelectorAll(".ni[data-img]");
  for(var i=0;i<nitems.length;i++){
    (function(el){
      el.addEventListener("mouseenter",function(e){
        currentEl=el;mv(e);
        if(hoverTimer)clearTimeout(hoverTimer);
        hoverTimer=setTimeout(function(){
          popImg.style.opacity="0";pop.classList.remove("show");
          popImg.src=el.getAttribute("data-img");
        },500);
      });
      el.addEventListener("mousemove",mv);
      el.addEventListener("mouseleave",function(){
        currentEl=null;if(hoverTimer){clearTimeout(hoverTimer);hoverTimer=null}
        popImg.style.opacity="0";pop.classList.remove("show");
        setTimeout(function(){if(!currentEl){popImg.removeAttribute("src")}},500);
      });
    })(nitems[i]);
  }
}

var cols=document.querySelectorAll(".c");
for(var c=0;c<cols.length;c++){
  (function(col){
    var fade=col.parentElement.querySelector(".fade");
    function checkFade(){var cs=col.scrollHeight>col.clientHeight;var ab=col.scrollTop>=col.scrollHeight-col.clientHeight-5;fade.style.opacity=(cs&&!ab)?"1":"0"}
    col.addEventListener("scroll",checkFade);checkFade();
  })(cols[c]);
}

var today=new Date().getDate();
var nowMin=new Date().getHours()*60+new Date().getMinutes();
document.querySelectorAll(".c").forEach(function(col){
  var ul=col.querySelector("ul");if(!ul)return;
  var lis=ul.querySelectorAll(".ni");
  var prevDay=null;
  var sh=col.querySelector(".sh");
  if(sh&&lis.length>0){var sp=document.createElement("span");sp.className="cnt";sp.textContent="· "+lis.length;sh.appendChild(sp)}
  lis.forEach(function(el){
    var dayStr=el.getAttribute("data-day");
    var day=dayStr?parseInt(dayStr):null;
    if(prevDay!==null&&day!==null&&day!==prevDay){
      var sep=document.createElement("li");sep.className="ds";sep.textContent="hier";
      el.parentElement.insertBefore(sep,el);
    }
    if(day!==null)prevDay=day;
    if(day===today){
      var nt=el.querySelector(".nt");
      if(nt){var m=nt.textContent.match(/(\d{2}):(\d{2})/);
      if(m){var artMin=parseInt(m[1])*60+parseInt(m[2]);
      var diff=nowMin-artMin;
      if(diff>=0&&diff<=120){var dot=document.createElement("span");dot.className="fd";el.querySelector(".nn").prepend(dot)}
      if(diff>=0&&diff<60){nt.childNodes[0].textContent=diff+"m "}
      else if(diff>=60&&diff<180){nt.childNodes[0].textContent=Math.floor(diff/60)+"h "}
      }}
    }
  });
});

setTimeout(function(){location.reload()},1800000);
})();</script>
</body></html>
ENDHTML

/usr/bin/open "$FILE"
T_LO=$(printf '%s\n' "$LOCAL" | /usr/bin/grep -c .)
T_FR=$(printf '%s\n' "$FRANCE" | /usr/bin/grep -c .)
T_MO=$(printf '%s\n' "$MONDE" | /usr/bin/grep -c .)
T_TE=$(printf '%s\n' "$TECH" | /usr/bin/grep -c .)
echo "$((T_LO+T_FR+T_MO+T_TE)) actus (Ici:$T_LO France:$T_FR Monde:$T_MO Tech:$T_TE)"
