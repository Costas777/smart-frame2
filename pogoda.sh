#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  ПАГОДА — ЕКАТЕРИНБУРГ  v2.0
#  Панель погоды для фото-рамки (Puppy Linux)
#
#  НЕ НУЖЕН Python! НЕ НУЖЕН HTTP-сервер!
#  Требуется только: bash + curl (или wget) + браузер
#
#  Запуск: кликните правой кнопкой → "Выполнить"
#  Или в терминале:  bash pogoda.sh
# ═══════════════════════════════════════════════════════════════

DIR="/tmp/pogoda-ekb"
mkdir -p "$DIR"

LAT=56.8389
LON=60.6057
TZ="Asia/Yekaterinburg"

# ─── URL API ───
W_URL="https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m,pressure_msl,precipitation,cloud_cover&hourly=temperature_2m,weather_code,precipitation_probability,wind_speed_10m,precipitation&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_sum,wind_speed_10m_max,precipitation_probability_max&timezone=${TZ}&forecast_days=7"
A_URL="https://air-quality-api.open-meteo.com/v1/air-quality?latitude=${LAT}&longitude=${LON}&current=pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone,us_aqi&hourly=pm2_5,us_aqi&timezone=${TZ}&forecast_days=1"

# ─── Функция загрузки ───
dl() {
    if command -v curl >/dev/null 2>&1; then
        curl -s --connect-timeout 15 --max-time 30 "$1" 2>/dev/null
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O- --timeout=30 "$1" 2>/dev/null
    else
        return 1
    fi
}

# ─── Загрузка данных ───
echo "  Загружаю данные о погоде..."

WDATA=$(dl "$W_URL")
ADATA=$(dl "$A_URL")

if [ -z "$WDATA" ]; then
    echo ""
    echo "  ╔════════════════════════════════════════════╗"
    echo "  ║  ОШИБКА: не удалось загрузить данные       ║"
    echo "  ║                                            ║"
    echo "  ║  Возможные причины:                        ║"
    echo "  ║  1. Нет интернета                          ║"
    echo "  ║  2. Не установлен curl или wget            ║"
    echo "  ║                                            ║"
    echo "  ║  Проверьте в терминале:                    ║"
    echo "  ║    curl --version                          ║"
    echo "  ║    wget --version                          ║"
    echo "  ║                                            ║"
    echo "  ║  Если curl/wget нет — установите:          ║"
    echo "  ║  Откройте Puppy Package Manager (PPM)      ║"
    echo "  ║  Найдите и установите пакет 'curl'         ║"
    echo "  ╚════════════════════════════════════════════╝"
    echo ""
    read -p "Нажмите Enter для выхода..."
    exit 1
fi

if [ -z "$ADATA" ]; then
    ADATA='{"current":{"us_aqi":0,"us_aqi_label":"Нет данных","pm2_5":0,"pm10":0,"carbon_monoxide":0,"nitrogen_dioxide":0,"sulphur_dioxide":0,"ozone":0},"hourly":{"time":[],"pm2_5":[],"us_aqi":[]}}'
fi

echo "  [OK] Данные получены"

# ═══════════════════════════════════════════════════════════
#  ФУНКЦИЯ: Генерация HTML с嵌入ными данными
# ═══════════════════════════════════════════════════════════
generate_html() {
    local wdata="$1"
    local adata="$2"

    cat > "$DIR/index.html" << 'HTMLHEAD'
<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
<meta http-equiv="refresh" content="900">
<title>Погода — Екатеринбург</title>
<style>
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
html,body{height:100%;overflow:hidden;background:#000;color:#fff;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;-webkit-font-smoothing:antialiased;user-select:none;-webkit-user-select:none}
.sb::-webkit-scrollbar{display:none}.sb{-ms-overflow-style:none;scrollbar-width:none}
.dash{position:relative;height:100vh;width:100%;overflow:hidden;display:flex;flex-direction:column}
.bg{position:absolute;top:0;right:0;bottom:0;left:0;z-index:0;transition:background 3s ease-in-out}
.bg .ov{position:absolute;top:0;right:0;bottom:0;left:0;background:linear-gradient(to bottom,rgba(0,0,0,.6),rgba(0,0,0,.3),rgba(0,0,0,.65))}
.bg .gr{position:absolute;top:0;right:0;bottom:0;left:0;opacity:.03;background-image:linear-gradient(rgba(0,220,255,.5) 1px,transparent 1px),linear-gradient(90deg,rgba(0,220,255,.5) 1px,transparent 1px);background-size:60px 60px}
.content{position:relative;z-index:1;display:flex;flex-direction:column;height:100%;padding:16px 20px 12px}
.top-row{display:flex;align-items:flex-start;justify-content:space-between;flex-shrink:0;margin-bottom:4px}
.clock-section{display:flex;flex-direction:column;align-items:center;gap:2px}
.clock-row{display:flex;align-items:center;gap:14px}
.city-label{font-size:11px;color:rgba(0,220,255,.6);text-transform:uppercase;letter-spacing:.12em;font-weight:500}
.date-label{font-size:10px;color:rgba(255,255,255,.3)}
.aclock{width:130px;height:130px;border-radius:50%;border:2px solid rgba(255,255,255,.15);position:relative;background:rgba(0,0,0,.25);flex-shrink:0}
.aclock .tick{position:absolute;top:4px;left:50%;width:1px;height:8px;margin-left:-.5px;background:rgba(255,255,255,.2);transform-origin:.5px 61px}
.aclock .tick.major{height:12px;width:2px;margin-left:-1px;background:rgba(255,255,255,.45);transform-origin:1px 61px}
.aclock .num{position:absolute;font-size:11px;font-weight:300;color:rgba(255,255,255,.4);width:20px;height:20px;line-height:20px;text-align:center}
.aclock .hand{position:absolute;bottom:50%;left:50%;transform-origin:bottom center;border-radius:2px}
.aclock .h-hand{width:3px;height:30px;margin-left:-1.5px;background:rgba(255,255,255,.85)}
.aclock .m-hand{width:2px;height:40px;margin-left:-1px;background:rgba(255,255,255,.7)}
.aclock .s-hand{width:1px;height:46px;margin-left:-.5px;background:rgba(0,220,255,.8)}
.aclock .center{position:absolute;top:50%;left:50%;width:6px;height:6px;margin:-3px;border-radius:50%;background:rgba(0,220,255,.9)}
.digi{font-size:36px;font-weight:200;letter-spacing:.05em;font-variant-numeric:tabular-nums;color:rgba(255,255,255,.9);line-height:1}
.digi .colon{animation:cpulse 1s ease-in-out infinite;display:inline-block}
@keyframes cpulse{0%,100%{opacity:.4}50%{opacity:1}}
.weather-summary{display:flex;flex-direction:column;align-items:flex-end;gap:0;text-align:right}
.ws-temp{font-size:48px;font-weight:100;line-height:1;font-variant-numeric:tabular-nums}
.ws-desc{font-size:14px;color:rgba(255,255,255,.6);margin-top:2px}
.ws-icon{font-size:28px;line-height:1;margin-bottom:2px}
.ws-feels{font-size:11px;color:rgba(255,255,255,.35);margin-top:4px}
.ws-details{display:flex;gap:14px;margin-top:6px;flex-wrap:wrap;justify-content:flex-end}
.ws-detail{font-size:10px;color:rgba(255,255,255,.4);display:flex;align-items:center;gap:3px}
.ws-detail b{color:rgba(255,255,255,.6);font-weight:500}
.tabs{display:flex;gap:2px;flex-shrink:0;margin-top:8px;border-bottom:1px solid rgba(255,255,255,.08);padding-bottom:0}
.tab-btn{padding:6px 10px;font-size:10px;color:rgba(255,255,255,.35);background:none;border:none;cursor:pointer;text-transform:uppercase;letter-spacing:.06em;transition:color .2s;border-bottom:2px solid transparent;margin-bottom:-1px;font-family:inherit}
.tab-btn:hover{color:rgba(255,255,255,.6)}
.tab-btn.active{color:rgba(0,220,255,.9);border-bottom-color:rgba(0,220,255,.6)}
.tab-panes{flex:1;overflow:hidden;position:relative;margin-top:8px}
.tab-pane{position:absolute;top:0;right:0;bottom:0;left:0;overflow-y:auto;opacity:0;visibility:hidden;transition:opacity .3s,visibility .3s}
.tab-pane.active{opacity:1;visibility:visible}
.hourly-scroll{display:flex;gap:8px;overflow-x:auto;padding-bottom:8px}
.hcard{flex-shrink:0;width:54px;padding:8px 4px;border-radius:8px;background:rgba(255,255,255,.04);text-align:center;display:flex;flex-direction:column;align-items:center;gap:3px;transition:background .2s}
.hcard:hover{background:rgba(255,255,255,.08)}
.hcard.now{background:rgba(0,220,255,.1);border:1px solid rgba(0,220,255,.2)}
.hcard-time{font-size:9px;color:rgba(255,255,255,.35)}
.hcard-icon{font-size:18px;line-height:1}
.hcard-temp{font-size:12px;font-weight:500;font-variant-numeric:tabular-nums}
.hcard-precip{font-size:8px;color:rgba(0,180,255,.6)}
.wrow{display:flex;align-items:center;padding:4px 6px;border-radius:6px;transition:background .2s}
.wrow:hover{background:rgba(255,255,255,.03)}
.wrow.today{background:rgba(0,220,255,.06)}
.wday{width:50px;font-size:11px;color:rgba(255,255,255,.5);flex-shrink:0}
.wrow.today .wday{color:rgba(0,220,255,.8);font-weight:600}
.wdate{width:22px;font-size:9px;color:rgba(255,255,255,.2);text-align:center;flex-shrink:0}
.wicon{width:24px;text-align:center;font-size:15px;flex-shrink:0}
.wprecip{width:34px;text-align:right;font-size:9px;color:rgba(0,180,255,.5);flex-shrink:0}
.wmin{width:24px;text-align:right;font-size:11px;color:rgba(255,255,255,.35);font-variant-numeric:tabular-nums;flex-shrink:0}
.wbar{flex:1;height:6px;background:rgba(255,255,255,.05);border-radius:99px;position:relative;min-width:30px;margin:0 6px}
.wbar-fill{position:absolute;height:100%;border-radius:99px;transition:left .5s,width .5s}
.wmax{width:24px;font-size:11px;color:rgba(255,255,255,.65);font-variant-numeric:tabular-nums;flex-shrink:0}
.aqi-big{display:flex;align-items:center;gap:16px;margin-bottom:12px}
.aqi-num{font-size:42px;font-weight:100;font-variant-numeric:tabular-nums;line-height:1}
.aqi-lbl{font-size:11px;color:rgba(255,255,255,.3);text-transform:uppercase;letter-spacing:.05em}
.aqi-lvl{font-size:14px;font-weight:500;margin-top:2px}
.aqi-dsc{font-size:10px;color:rgba(255,255,255,.25);margin-top:4px;line-height:1.5}
.poll-grid{display:flex;flex-wrap:wrap;gap:10px}
.poll-item{background:rgba(255,255,255,.04);border-radius:6px;padding:8px 10px;min-width:90px}
.poll-name{font-size:8px;color:rgba(255,255,255,.25);text-transform:uppercase;letter-spacing:.04em;margin-bottom:2px}
.poll-val{font-size:14px;color:rgba(255,255,255,.7);font-weight:500;font-variant-numeric:tabular-nums}
.poll-unit{font-size:8px;color:rgba(255,255,255,.2);margin-left:2px}
.sun-top{display:flex;justify-content:space-between;align-items:center;margin-bottom:8px}
.sun-item{text-align:center}
.sun-item-label{font-size:9px;color:rgba(255,255,255,.3);text-transform:uppercase;letter-spacing:.08em}
.sun-item-time{font-size:16px;font-weight:500;font-variant-numeric:tabular-nums;margin-top:2px}
.sun-mid{text-align:center}
.sun-mid-label{font-size:9px;color:rgba(255,255,255,.25);text-transform:uppercase;letter-spacing:.05em}
.sun-mid-val{font-size:12px;color:rgba(255,255,255,.5);font-variant-numeric:tabular-nums}
.sun-arc{margin:8px 0}
.sun-arc svg{width:100%;height:60px;display:block}
.sun-remain{text-align:center;margin-bottom:10px}
.sun-remain-lbl{font-size:9px;color:rgba(255,255,255,.2);text-transform:uppercase;letter-spacing:.05em}
.sun-remain-val{font-size:11px;color:rgba(251,191,36,.6);font-variant-numeric:tabular-nums}
.sun-wk-label{font-size:9px;color:rgba(255,255,255,.2);text-transform:uppercase;letter-spacing:.05em;margin-bottom:4px}
.sun-wk-row{display:flex;justify-content:space-between;font-size:10px;padding:2px 0}
.sun-wk-day{color:rgba(255,255,255,.3);width:50px}
.sun-wk-day.today{color:rgba(0,220,255,.6)}
.sun-wk-rise{color:rgba(251,191,36,.5);font-variant-numeric:tabular-nums}
.sun-wk-dash{color:rgba(255,255,255,.1)}
.sun-wk-set{color:rgba(251,146,60,.5);font-variant-numeric:tabular-nums}
.update-info{position:fixed;bottom:6px;right:10px;font-size:8px;color:rgba(255,255,255,.15);z-index:10}
</style>
</head>
<body>
<div class="dash">
  <div class="bg" id="bg"><div class="ov"></div><div class="gr"></div></div>
  <div class="content">
    <div class="top-row">
      <div class="clock-section">
        <div class="city-label">Екатеринбург</div>
        <div class="clock-row">
          <div class="aclock" id="aclock"></div>
          <div><div class="digi" id="digi">--:--:--</div><div class="date-label" id="datelabel">--</div></div>
        </div>
      </div>
      <div class="weather-summary" id="wsummary">
        <div class="ws-icon" id="ws-icon">--</div>
        <div class="ws-temp" id="ws-temp">--°</div>
        <div class="ws-desc" id="ws-desc">Загрузка...</div>
        <div class="ws-feels" id="ws-feels"></div>
        <div class="ws-details" id="ws-details"></div>
      </div>
    </div>
    <div class="tabs" id="tabs">
      <button class="tab-btn active" data-tab="current">Текущая</button>
      <button class="tab-btn" data-tab="hourly">Почасовая</button>
      <button class="tab-btn" data-tab="weekly">Неделя</button>
      <button class="tab-btn" data-tab="aqi">Качество</button>
      <button class="tab-btn" data-tab="sun">Солнце</button>
    </div>
    <div class="tab-panes" id="panes">
      <div class="tab-pane active" id="p-current"></div>
      <div class="tab-pane" id="p-hourly"></div>
      <div class="tab-pane" id="p-weekly"></div>
      <div class="tab-pane" id="p-aqi"></div>
      <div class="tab-pane" id="p-sun"></div>
    </div>
  </div>
</div>
<div class="update-info" id="updinfo"></div>
<script>
var WD =
HTMLHEAD

    # Вставка данных погоды (без экранирования — JSON валиден в JS)
    printf '%s' "$wdata" >> "$DIR/index.html"

    cat >> "$DIR/index.html" << 'HTMLMID'
;
var AD =
HTMLMID

    # Вставка данных качества воздуха
    printf '%s' "$adata" >> "$DIR/index.html"

    cat >> "$DIR/index.html" << 'HTMLJS'
;

// ══════════════════════════════════════
//  УТИЛИТЫ
// ══════════════════════════════════════
var DAYS_RU=['Воскресенье','Понедельник','Вторник','Среда','Четверг','Пятница','Суббота'];
var DAYS_SHORT=['Вс','Пн','Вт','Ср','Чт','Пт','Сб'];
var MONTHS_RU=['января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря'];
function pad(n){return n<10?'0'+n:''+n}
function wmoInfo(c){
  var m={0:{d:'Ясно',i:'\u2600\uFE0F'},1:{d:'Преим. ясно',i:'\uD83C\uDF24\uFE0F'},2:{d:'Переменная обл.',i:'\u26C5'},3:{d:'Пасмурно',i:'\u2601\uFE0F'},45:{d:'Туман',i:'\uD83C\uDF2B\uFE0F'},48:{d:'Изморозь',i:'\uD83C\uDF2B\uFE0F'},51:{d:'Лёгкая морось',i:'\uD83C\uDF26\uFE0F'},53:{d:'Морось',i:'\uD83C\uDF26\uFE0F'},55:{d:'Сильная морось',i:'\uD83C\uDF27\uFE0F'},56:{d:'Ледяная морось',i:'\uD83C\uDF28\uFE0F'},57:{d:'Сильн. лед. морось',i:'\uD83C\uDF28\uFE0F'},61:{d:'Небольшой дождь',i:'\uD83C\uDF27\uFE0F'},63:{d:'Дождь',i:'\uD83C\uDF27\uFE0F'},65:{d:'Сильный дождь',i:'\uD83C\uDF27\uFE0F'},66:{d:'Ледяной дождь',i:'\uD83C\uDF28\uFE0F'},67:{d:'Сильн. лед. дождь',i:'\uD83C\uDF28\uFE0F'},71:{d:'Небольшой снег',i:'\uD83C\uDF28\uFE0F'},73:{d:'Снег',i:'\u2744\uFE0F'},75:{d:'Сильный снег',i:'\u2744\uFE0F'},77:{d:'Снежные зёрна',i:'\u2744\uFE0F'},80:{d:'Ливень',i:'\uD83C\uDF26\uFE0F'},81:{d:'Сильный ливень',i:'\uD83C\uDF27\uFE0F'},82:{d:'Очень сильный ливень',i:'\uD83C\uDF27\uFE0F'},85:{d:'Снегопад',i:'\uD83C\uDF28\uFE0F'},86:{d:'Сильный снегопад',i:'\u2744\uFE0F'},95:{d:'Гроза',i:'\u26C8\uFE0F'},96:{d:'Гроза с градом',i:'\u26C8\uFE0F'},99:{d:'Сильная гроза',i:'\u26C8\uFE0F'}};
  return m[c]||{d:'Неизвестно',i:'\u2753'};
}
function windDir(d){var r=['С','ССВ','СВ','ВСВ','В','ВЮВ','ЮВ','ЮЮВ','Ю','ЮЮЗ','ЮЗ','ЗЮЗ','З','ЗСЗ','СЗ','ССЗ'];return r[Math.round(d/22.5)%16];}
function fmtTime(iso){if(!iso)return'--:--';var p=iso.split('T')[1].split('+')[0];var h=parseInt(p.split(':')[0],10);return pad(h)+':'+p.split(':')[1];}
function aqiColor(v){if(v<=50)return'#22c55e';if(v<=100)return'#eab308';if(v<=150)return'#f97316';if(v<=200)return'#ef4444';if(v<=300)return'#a855f7';return'#7f1d1d';}
function aqiLevel(v){if(v<=50)return'Хорошее';if(v<=100)return'Умеренное';if(v<=150)return'Нездоровое (чувств.)';if(v<=200)return'Нездоровое';if(v<=300)return'Очень нездоровое';return'Опасное';}
function aqiDesc(v){if(v<=50)return'Качество воздуха отличное. Можно гулять и заниматься спортом.';if(v<=100)return'Приемлемое качество. Чувствительные люди могут заметить дискомфорт.';if(v<=150)return'Нездоров для чувствительных групп. Ограничьте время на улице.';if(v<=200)return'Все могут испытывать последствия. Ограничьте нахождение на улице.';if(v<=300)return'Предупреждение о здоровье. Избегайте нахождения на улице.';return'Опасно для здоровья! Оставайтесь в помещении.';}

// ══════════════════════════════════════
//  ФОНЫ (CSS-градиенты, без загрузки файлов)
// ══════════════════════════════════════
var bgs=[
  'linear-gradient(135deg,#0c0e1a 0%,#1a1040 30%,#3d1f5c 50%,#8b3a62 80%,#d4556b 100%)',
  'linear-gradient(to bottom,#0a1628 0%,#1b3a4b 35%,#2d6a4f 65%,#40916c 100%)',
  'linear-gradient(135deg,#141e30 0%,#243b55 35%,#533483 65%,#e94560 100%)',
  'linear-gradient(to bottom,#0d1b2a 0%,#1b263b 30%,#415a77 60%,#778da9 100%)',
  'linear-gradient(135deg,#0f0c29 0%,#302b63 50%,#24243e 100%)',
  'linear-gradient(to bottom,#1a1a2e 0%,#16213e 40%,#0f3460 70%,#533483 100%)'
];
var bgIdx=0;
var bgEl=document.getElementById('bg');
bgEl.style.background=bgs[0];
setInterval(function(){bgIdx=(bgIdx+1)%bgs.length;bgEl.style.background=bgs[bgIdx];},45000);

// ══════════════════════════════════════
//  АНАЛОГОВЫЕ ЧАСЫ
// ══════════════════════════════════════
(function(){
  var el=document.getElementById('aclock');
  for(var i=0;i<60;i++){
    var t=document.createElement('div');
    t.className='tick'+(i%5===0?' major':'');
    t.style.transform='rotate('+i*6+'deg)';
    el.appendChild(t);
  }
  for(var h=1;h<=12;h++){
    var n=document.createElement('div');n.className='num';
    var a=h*30-90,r=46;
    n.style.left=(65+r*Math.cos(a*Math.PI/180)-10)+'px';
    n.style.top=(65+r*Math.sin(a*Math.PI/180)-10)+'px';
    n.textContent=h;el.appendChild(n);
  }
  ['h-hand','m-hand','s-hand'].forEach(function(c){var d=document.createElement('div');d.className='hand '+c;el.appendChild(d);});
  var cd=document.createElement('div');cd.className='center';el.appendChild(cd);
})();

// ══════════════════════════════════════
//  ОБНОВЛЕНИЕ ЧАСОВ (каждую секунду)
// ══════════════════════════════════════
function updateClock(){
  var now=new Date(),h=now.getHours(),m=now.getMinutes(),s=now.getSeconds();
  document.getElementById('digi').innerHTML=pad(h)+'<span class="colon">:</span>'+pad(m)+'<span class="colon">:</span>'+pad(s);
  document.getElementById('datelabel').textContent=DAYS_RU[now.getDay()]+', '+now.getDate()+' '+MONTHS_RU[now.getMonth()]+' '+now.getFullYear();
  var hDeg=(h%12+m/60)*30,mDeg=(m+s/60)*6,sDeg=s*6;
  var hh=document.querySelector('.h-hand'),mh=document.querySelector('.m-hand'),sh=document.querySelector('.s-hand');
  if(hh)hh.style.transform='rotate('+hDeg+'deg)';
  if(mh)mh.style.transform='rotate('+mDeg+'deg)';
  if(sh)sh.style.transform='rotate('+sDeg+'deg)';
}
updateClock();setInterval(updateClock,1000);

// ══════════════════════════════════════
//  ВКЛАДКИ
// ══════════════════════════════════════
var TMAP={current:'p-current',hourly:'p-hourly',weekly:'p-weekly',aqi:'p-aqi',sun:'p-sun'};
document.getElementById('tabs').addEventListener('click',function(e){
  var btn=e.target.closest('.tab-btn');if(!btn)return;
  var id=btn.getAttribute('data-tab');
  var btns=document.querySelectorAll('.tab-btn');for(var i=0;i<btns.length;i++)btns[i].classList.remove('active');
  btn.classList.add('active');
  var panes=document.querySelectorAll('.tab-pane');for(var i=0;i<panes.length;i++)panes[i].classList.remove('active');
  var t=document.getElementById(TMAP[id]);if(t)t.classList.add('active');
});

// ══════════════════════════════════════
//  ОТОБРАЖЕНИЕ ПОГОДЫ
// ══════════════════════════════════════
function renderWeather(){
  if(!WD||!WD.current){document.getElementById('ws-desc').textContent='Нет данных';return;}
  var c=WD.current,wi=wmoInfo(c.weather_code);
  document.getElementById('ws-icon').textContent=wi.i;
  document.getElementById('ws-temp').textContent=Math.round(c.temperature_2m)+'°C';
  document.getElementById('ws-desc').textContent=wi.d;
  document.getElementById('ws-feels').textContent='Ощущается '+Math.round(c.apparent_temperature)+'°C';
  document.getElementById('ws-details').innerHTML=
    '<div class="ws-detail">\uD83D\uDCA7 <b>'+c.relative_humidity_2m+'</b>%</div>'+
    '<div class="ws-detail">\uD83D\uDCA8 <b>'+c.wind_speed_10m+'</b> м/с '+windDir(c.wind_direction_10m)+'</div>'+
    '<div class="ws-detail">\uD83D\uDCCA <b>'+Math.round(c.pressure_msl)+'</b> гПа</div>'+
    '<div class="ws-detail">\u2601 <b>'+c.cloud_cover+'</b>%</div>';
  if(WD.current_time)document.getElementById('updinfo').textContent='Обновлено: '+fmtTime(WD.current_time);
  renderCurrentTab(c,wi);renderHourlyTab();renderWeeklyTab();renderAQITab();renderSunTab();
}

function card(icon,label,value){
  return '<div style="background:rgba(255,255,255,.04);border-radius:8px;padding:10px 12px;min-width:140px;flex:1 1 0"><div style="font-size:8px;color:rgba(255,255,255,.25);text-transform:uppercase;letter-spacing:.04em;margin-bottom:4px">'+icon+' '+label+'</div><div style="font-size:15px;color:rgba(255,255,255,.8);font-weight:500;white-space:nowrap">'+value+'</div></div>';
}

function renderCurrentTab(c,wi){
  document.getElementById('p-current').innerHTML='<div style="padding:8px 4px"><div style="display:flex;flex-wrap:wrap;gap:10px">'+
    card('\uD83C\uDF21','Температура',Math.round(c.temperature_2m)+'°C')+
    card('\uD83C\uDF21','Ощущается',Math.round(c.apparent_temperature)+'°C')+
    card('\uD83D\uDCA7','Влажность',c.relative_humidity_2m+'%')+
    card('\uD83D\uDCA8','Ветер',c.wind_speed_10m+' м/с '+windDir(c.wind_direction_10m))+
    card('\uD83D\uDCCA','Давление',Math.round(c.pressure_msl)+' гПа')+
    card('\u2601','Облачность',c.cloud_cover+'%')+
    card('\uD83C\uDF27','Осадки',c.precipitation+' мм')+
    card('\uD83C\uDF24','Состояние',wi.d)+'</div></div>';
}

function renderHourlyTab(){
  var el=document.getElementById('p-hourly');
  if(!WD||!WD.hourly)return;
  var hr=WD.hourly,nowH=new Date().getHours(),html='<div class="hourly-scroll sb">',si=0;
  for(var i=0;i<hr.time.length;i++){var th=parseInt(hr.time[i].split('T')[1].split(':')[0],10);if(th>=nowH){si=i;break;}}
  if(nowH>parseInt(hr.time[hr.time.length-1].split('T')[1].split(':')[0],10))si=hr.time.length-24;
  var cnt=Math.min(24,hr.time.length-si);
  for(var i=0;i<cnt;i++){
    var idx=si+i;if(idx>=hr.time.length)break;
    var h=parseInt(hr.time[idx].split('T')[1].split(':')[0],10),isN=i===0,wi=wmoInfo(hr.weather_code[idx]);
    var pp=hr.precipitation_probability[idx],ps=pp>0?pp+'%':'';
    html+='<div class="hcard'+(isN?' now':'')+'"><div class="hcard-time">'+(isN?'Сейчас':pad(h)+':00')+'</div><div class="hcard-icon">'+wi.i+'</div><div class="hcard-temp">'+Math.round(hr.temperature_2m[idx])+'°</div>'+(ps?'<div class="hcard-precip">\uD83D\uDCA7 '+ps+'</div>':'')+'</div>';
  }
  el.innerHTML=html+'</div>';
}

function renderWeeklyTab(){
  var el=document.getElementById('p-weekly');
  if(!WD||!WD.daily)return;
  var d=WD.daily,todayS=new Date().toISOString().split('T')[0],mn=999,mx=-999,html='';
  for(var i=0;i<d.time.length;i++){if(d.temperature_2m_min[i]<mn)mn=d.temperature_2m_min[i];if(d.temperature_2m_max[i]>mx)mx=d.temperature_2m_max[i];}
  var rng=mx-mn||1;
  for(var i=0;i<d.time.length;i++){
    var dt=new Date(d.time[i]+'T12:00:00'),isT=d.time[i]===todayS,wi=wmoInfo(d.weather_code[i]);
    var pp=d.precipitation_probability_max[i],ps=pp>0?pp+'%':'';
    var minT=d.temperature_2m_min[i],maxT=d.temperature_2m_max[i];
    var left=((minT-mn)/rng)*100,width=Math.max(5,((maxT-minT)/rng)*100);
    var bc=minT<0?'rgba(56,189,248,.5)':minT<15?'rgba(34,197,94,.5)':'rgba(251,191,36,.5)';
    html+='<div class="wrow'+(isT?' today':'')+'"><div class="wday">'+DAYS_SHORT[dt.getDay()]+'</div><div class="wdate">'+dt.getDate()+'</div><div class="wicon">'+wi.i+'</div><div class="wprecip">'+(ps?'\uD83D\uDCA7 '+ps:'')+'</div><div class="wmin">'+Math.round(minT)+'°</div><div class="wbar"><div class="wbar-fill" style="left:'+left+'%;width:'+width+'%;background:'+bc+'"></div></div><div class="wmax">'+Math.round(maxT)+'°</div></div>';
  }
  el.innerHTML=html;
}

function renderAQITab(){
  var el=document.getElementById('p-aqi');
  if(!AD||!AD.current)return;
  var c=AD.current,aqi=c.us_aqi||0,clr=aqiColor(aqi);
  function pi(n,v,u){return '<div class="poll-item"><div class="poll-name">'+n+'</div><div class="poll-val">'+(v!=null?(typeof v==='number'?Math.round(v*10)/10:v):'--')+'<span class="poll-unit">'+u+'</span></div></div>';}
  el.innerHTML='<div style="padding:4px"><div class="aqi-big"><div><div class="aqi-num" style="color:'+clr+'">'+aqi+'</div><div class="aqi-lbl">Индекс AQI (США)</div><div class="aqi-lvl" style="color:'+clr+'">'+aqiLevel(aqi)+'</div><div class="aqi-dsc">'+aqiDesc(aqi)+'</div></div></div><div class="poll-grid">'+pi('PM2.5',c.pm2_5,'\u00B5g/m\u00B3')+pi('PM10',c.pm10,'\u00B5g/m\u00B3')+pi('O\u2083',c.ozone,'\u00B5g/m\u00B3')+pi('NO\u2082',c.nitrogen_dioxide,'\u00B5g/m\u00B3')+pi('SO\u2082',c.sulphur_dioxide,'\u00B5g/m\u00B3')+pi('CO',c.carbon_monoxide?Math.round(c.carbon_monoxide):'--','\u00B5g/m\u00B3')+'</div></div>';
}

function renderSunTab(){
  var el=document.getElementById('p-sun');
  if(!WD||!WD.daily)return;
  var d=WD.daily,todayS=new Date().toISOString().split('T')[0],ti=0;
  for(var i=0;i<d.time.length;i++){if(d.time[i]===todayS){ti=i;break;}}
  var rT=d.sunrise[ti],sT=d.sunset[ti],riseT=fmtTime(rT),setT=fmtTime(sT),dayLen='--';
  if(rT&&sT){var df=new Date(sT)-new Date(rT),dh=Math.floor(df/3600000),dm=Math.floor((df%3600000)/60000);dayLen=dh+'ч '+dm+'мин';}
  var now=new Date(),rMs=new Date(rT).getTime(),sMs=new Date(sT).getTime(),nMs=now.getTime(),prog=0;
  if(nMs>=rMs&&nMs<=sMs&&sMs>rMs)prog=(nMs-rMs)/(sMs-rMs);else if(nMs>sMs)prog=1;
  var aW=280,aH=50,cx=aW/2,cy=aH-4,r=50,ang=Math.PI-prog*Math.PI;
  var sx=cx+r*Math.cos(ang),sy=cy-r*Math.sin(ang),isD=prog>0&&prog<1;
  var sClr=isD?'#fbbf24':'rgba(255,255,255,.3)';
  var svg='<svg viewBox="0 0 '+aW+' '+aH+'" preserveAspectRatio="xMidYMid meet"><path d="M '+(cx-r)+' '+cy+' A '+r+' '+r+' 0 0 1 '+(cx+r)+' '+cy+'" fill="none" stroke="rgba(255,255,255,.08)" stroke-width="2" stroke-dasharray="4,4"/>'+(isD?'<path d="M '+(cx-r)+' '+cy+' A '+r+' '+r+' 0 0 1 '+sx.toFixed(1)+' '+sy.toFixed(1)+'" fill="none" stroke="rgba(251,191,36,.4)" stroke-width="2"/>':'')+'<circle cx="'+sx.toFixed(1)+'" cy="'+sy.toFixed(1)+'" r="5" fill="'+sClr+'" '+(isD?'style="filter:drop-shadow(0 0 6px rgba(251,191,36,.6))"':'')+'/><line x1="'+cx+'" y1="'+cy+'" x2="'+cx+'" y2="'+(cy-4)+'" stroke="rgba(255,255,255,.1)" stroke-width="1"/><text x="'+(cx-r)+'" y="'+(cy+12)+'" text-anchor="middle" fill="rgba(255,255,255,.2)" font-size="8" font-family="sans-serif">'+riseT+'</text><text x="'+(cx+r)+'" y="'+(cy+12)+'" text-anchor="middle" fill="rgba(255,255,255,.2)" font-size="8" font-family="sans-serif">'+setT+'</text></svg>';
  var remStr='';
  if(isD){var rm=sMs-nMs,rh=Math.floor(rm/3600000),rmi=Math.floor((rm%3600000)/60000);remStr='До заката: '+rh+'ч '+rmi+'мин';}
  else if(nMs<rMs){var rm2=rMs-nMs,rh2=Math.floor(rm2/3600000),rm3=Math.floor((rm2%3600000)/60000);remStr='До восхода: '+rh2+'ч '+rm3+'мин';}
  else{remStr='Солнце зашло';}
  var wkH='';
  for(var i=0;i<d.time.length;i++){var dt=new Date(d.time[i]+'T12:00:00');wkH+='<div class="sun-wk-row"><span class="sun-wk-day'+(i===ti?' today':'')+'">'+DAYS_SHORT[dt.getDay()]+'</span><span class="sun-wk-rise">'+fmtTime(d.sunrise[i])+'</span><span class="sun-wk-dash">\u2014</span><span class="sun-wk-set">'+fmtTime(d.sunset[i])+'</span></div>';}
  el.innerHTML='<div style="padding:4px"><div class="sun-top"><div class="sun-item"><div class="sun-item-label">\uD83C\uDF05 Восход</div><div class="sun-item-time" style="color:rgba(251,191,36,.7)">'+riseT+'</div></div><div class="sun-mid"><div class="sun-mid-label">Световой день</div><div class="sun-mid-val">'+dayLen+'</div></div><div class="sun-item"><div class="sun-item-label">\uD83C\uDF07 Закат</div><div class="sun-item-time" style="color:rgba(251,146,60,.7)">'+setT+'</div></div></div><div class="sun-arc">'+svg+'</div><div class="sun-remain"><div class="sun-remain-val">'+remStr+'</div></div><div class="sun-wk-label">Восход / Закат на неделю</div>'+wkH+'</div>';
}

renderWeather();
</script>
</body>
</html>
HTMLJS
}

# ═══════════════════════════════════════════════════════════
#  ГЕНЕРАЦИЯ HTML И ОТКРЫТИЕ БРАУЗЕРА
# ═══════════════════════════════════════════════════════════
generate_html "$WDATA" "$ADATA"

echo "  Файл создан: $DIR/index.html"

FILEURL="file://$DIR/index.html"

# Поиск браузера (Puppy Linux и другие)
BROWSER_CMD=""
for cmd in defaultbrowser xdg-open firefox palemoon seamonkey chromium chromium-browser google-chrome midori; do
    if command -v "$cmd" >/dev/null 2>&1; then
        BROWSER_CMD="$cmd"
        break
    fi
done

if [ -n "$BROWSER_CMD" ]; then
    echo "  Открываю браузер: $BROWSER_CMD"
    $BROWSER_CMD "$FILEURL" 2>/dev/null &
else
    echo ""
    echo "  Не могу найти браузер."
    echo "  Откройте вручную: $FILEURL"
    echo ""
fi

echo ""
echo "  ╔════════════════════════════════════════════╗"
echo "  ║  Погода — Екатеринбург                      ║"
echo "  ║  Данные обновляются каждые 15 минут       ║"
echo "  ║  Для полного экрана нажмите F11            ║"
echo "  ║  Чтобы остановить — закройте окно или      ║"
echo "  ║  нажмите Ctrl+C в терминале                ║"
echo "  ╚════════════════════════════════════════════╝"
echo ""

# ═══════════════════════════════════════════════════════════
#  АВТООБНОВЛЕНИЕ (каждые 15 минут)
# ═══════════════════════════════════════════════════════════
while true; do
    sleep 890
    echo "  $(date '+%H:%M:%S') Обновляю данные..."

    NEW_W=$(dl "$W_URL")
    NEW_A=$(dl "$A_URL")

    if [ -n "$NEW_W" ]; then WDATA="$NEW_W"; fi
    if [ -n "$NEW_A" ]; then ADATA="$NEW_A"; fi

    generate_html "$WDATA" "$ADATA"
    echo "  [OK] Обновлено"
done