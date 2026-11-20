/* ÓÐRERIR — the Live Hall: the fleet's planning glass.

   Data: a same-origin snapshot at /livehall.json, written by the hall's own
   generator and served from this deck's origin:
     { generated_at, realm, tally{runes,projects,loom,wake,smiths},
       errands_armed[], smiths[{smith,state,pane}], ledger{underway,landed,charted} }

   The glass paints the saga's own tale first (the inline payload), then reads
   the snapshot and re-paints from it when it is present and valid; when it is
   absent or unreadable the tale stands, and says so. "Read again" re-reads on
   command; returning to the tab re-reads it (only when it has changed, so a
   word queued in this page is never wiped out from under the reader).

   The board's machinery is ported function-for-function from the saga-bearings
   fleet board and rebuilt in the carved cloth: the dealt slate stack with
   options + recommended marks + freeform + the 512-byte queue guard, stack
   navigation, the carved ledger, the dispatch picker, fail-closed render.

   READ-ONLY, ALWAYS. The glass shows; it does not write. There is no hold path
   from this page — a word queued here stays in this page. The two fields the
   snapshot carries that are machinery, not glass — `realm` and each smith's
   `pane` — are deliberately never rendered. */
(function(){
'use strict';
var root = document.getElementById('livehall');
if(!root) return;
var $ = function(s){ return root.querySelector(s); };
var $$ = function(s){ return Array.prototype.slice.call(root.querySelectorAll(s)); };

function el(tag, cls, text){ var n = document.createElement(tag); if(cls) n.className = cls; if(text != null) n.textContent = text; return n; }
function badge(tone, text){ return el('span', 'lh-badge lh-badge--' + tone, text); }
function isWarning(t){ return t && t.kind === 'warning'; }
function chartedQueued(rows){ return (rows || []).filter(function(t){ return !isWarning(t); }); }
function utf8ByteLength(text){ return new TextEncoder().encode(text).length; }
function stateTone(state){
  switch(String(state || '').toLowerCase()){
    case 'working': case 'active': case 'running': case 'lit': return 'online';
    case 'idle': case 'ready': case 'waiting': case 'drawn': return 'info';
    case 'blocked': case 'stuck': case 'error': case 'failed': return 'danger';
    default: return 'neutral';
  }
}
var CHECK = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>';

/* Fail closed on the tale itself: a board with unreadable inline data says so
   plainly instead of rendering an empty hall. */
function renderBoardError(msg){
  var board = $('.lh-board');
  if(!board) return;
  board.innerHTML = '';
  var slate = el('div', 'lh-slate lh-decision');
  var pad = el('div', 'lh-pad');
  pad.appendChild(el('h3', 'lh-title', 'The hall\u2019s board could not be carved'));
  pad.appendChild(el('p', 'lh-detail', msg + ' — the saga stands, and the board is shown un-dealt.'));
  slate.appendChild(pad);
  board.appendChild(slate);
}

var saga;
try {
  saga = JSON.parse(document.getElementById('lh-saga').textContent);
} catch (e) {
  renderBoardError('the hall\u2019s own tale is not valid JSON');
  return;
}
if(!saga || typeof saga !== 'object' || !Array.isArray(saga.captains_call)){
  renderBoardError('the hall\u2019s own tale does not have the required structure');
  return;
}

/* ============================================================
   THE TWO SHAPES BECOME ONE MODEL
   ============================================================ */
function isFeed(d){
  return !!(d && typeof d === 'object' && d.tally && typeof d.tally === 'object' &&
    Array.isArray(d.errands_armed) && d.ledger && typeof d.ledger === 'object');
}

/* the saga's own tale (the inline fallback) */
function modelFromSaga(d){
  var smiths = (d.smiths || []).map(function(n){ return { smith: n, state: null }; });
  var chartedMore = d.charted_more || 0;
  return {
    source: 'saga',
    generated: d.generated || 'the tale',
    countLine: (d.houses || []).length + ' houses · ' + (d.landed || []).length + ' carvings · one well — the saga\u2019s own count, told honestly',
    smiths: smiths,
    deck: (d.captains_call || []).map(function(item){
      return {
        key: item.key, type: item.type, title: item.title, repo: item.repo,
        detail: item.detail, about: item.about, decide: item.decide,
        options: item.options || [], recommend_value: item.recommend_value,
        allow_freeform: !!item.allow_freeform, freeform_hint: item.freeform_hint
      };
    }),
    underway: (d.underway || []).map(function(t){
      return {
        title: t.doing,
        sub: t.kind + ' · ' + (t.repo || t.id),
        badge: { tone: t.state === 'working' ? 'online' : 'info', label: t.state }
      };
    }),
    landed: (d.landed || []).map(function(t){
      return { title: t.what, sub: (t.repo || t.id) + ' · ' + t.owner };
    }),
    charted: (d.charted || []).map(function(t){
      return { id: t.id, title: t.title, sub: t.repo || t.id, reason: t.reason,
        kind: t.kind, dispatchable: !!t.dispatchable };
    }),
    chartedMore: chartedMore,
    chartedWarningMore: d.charted_warning_more || 0,
    tallyExtra: null
  };
}

/* the hall's own snapshot (the glass, read live) */
function modelFromFeed(f){
  var tally = f.tally || {};
  var smiths = (f.smiths || []).filter(function(s){ return s && s.smith; }).map(function(s){
    return { smith: s.smith, state: s.state || null };
  });
  var stateOf = {};
  smiths.forEach(function(s){ stateOf[s.smith] = s.state; });
  var errands = (f.errands_armed || []).filter(function(n){ return typeof n === 'string' && n; });
  var ledger = f.ledger || {};
  return {
    source: 'hall',
    generated: f.generated_at || '',
    countLine: 'read live from the hall\u2019s own snapshot — nothing here is written back',
    smiths: smiths,
    deck: errands.map(function(name){
      return {
        key: 'errand.' + name,
        type: 'errand',
        title: name,
        smith: name,
        state: stateOf[name] || null,
        about: 'armed in the hall — the errand Brokk holds for this smith',
        decide: 'the word that releases it, or holds it',
        options: [],                 /* the snapshot carries no options; none are invented */
        recommend_value: null,
        allow_freeform: true,
        freeform_hint: 'or inscribe the word in your own words…'
      };
    }),
    underway: (ledger.underway || []).map(function(n){
      return {
        title: n,
        sub: 'held in the hall',
        badge: stateOf[n] ? { tone: stateTone(stateOf[n]), label: stateOf[n] } : null
      };
    }),
    landed: (ledger.landed || []).map(function(n){
      return { title: n, sub: 'landed as work' };
    }),
    charted: (ledger.charted || []).map(function(n){
      return { id: n, title: n, sub: 'on the chart', reason: 'on the chart', dispatchable: true };
    }),
    chartedMore: 0,
    chartedWarningMore: 0,
    tallyExtra: [
      { n: tally.runes || 0, l: 'runes carved' },
      { n: tally.projects || 0, l: 'projects' },
      { n: tally.loom || 0, l: 'on the loom' },
      { n: tally.wake || 0, l: 'wake queue' },
      { n: tally.smiths || smiths.length, l: 'smiths' }
    ]
  };
}

/* ============================================================
   THE RENDER — one model, one board
   ============================================================ */
var deck;            /* #lh-call */
var cards = [];      /* the dealt slates */
var active = 0;      /* the slate under the hand */
var model = null;

function answeredCount(){ return deck.querySelectorAll('.is-queued').length; }

function renderTally(m){
  var strip = $('#lh-tally');
  strip.textContent = '';
  var callTotal = m.deck.length;
  var left = callTotal - answeredCount();
  var stats = [{ n: left, l: callTotal === 1 ? 'errand armed' : (m.source === 'hall' ? 'errands armed' : 'calls on the board'), call: true }];
  if(m.source === 'hall'){
    stats[0].l = left === 1 ? 'errand armed' : 'errands armed';
    stats = stats.concat(m.tallyExtra || []);
  } else {
    stats.push({ n: m.underway.length, l: 'kept underway' });
    stats.push({ n: m.landed.length, l: m.source === 'hall' ? 'landed' : 'landed as carvings' });
    stats.push({ n: chartedQueued(m.charted).length + m.chartedMore, l: 'charted next' });
  }
  stats.forEach(function(s){
    var t = el('div', 'lh-stat' + (s.call ? ' lh-stat--call' : ''));
    t.appendChild(el('span', 'lh-stat__num', String(s.n)));
    t.appendChild(el('span', 'lh-stat__label', s.l));
    strip.appendChild(t);
  });
  var sub = $('#lh-call-sub');
  sub.textContent = left
    ? left + (left === 1 ? ' slate' : ' slates') + (m.source === 'hall' ? ' armed · dealt by hand' : ' dealt · the hall\u2019s own gates')
    : 'every slate is queued — the board rests';
}

function renderSmiths(m){
  var strip = $('#lh-smiths');
  strip.textContent = '';
  if(!m.smiths.length) return;
  if(m.source === 'saga'){
    strip.appendChild(document.createTextNode(m.smiths.length + ' named smiths — '));
    m.smiths.forEach(function(s, i){
      if(i) strip.appendChild(document.createTextNode(' \u00b7 '));
      strip.appendChild(el('b', null, s.smith));
    });
    return;
  }
  m.smiths.forEach(function(s){
    var chip = el('span', 'lh-smith');
    chip.appendChild(el('span', 'lh-smith__name', s.smith));
    if(s.state) chip.appendChild(badge(stateTone(s.state), s.state));
    strip.appendChild(chip);
  });
}

function ctxRow(k, v, node){
  var row = el('div', 'lh-ctx__row');
  row.appendChild(el('span', 'lh-ctx__k', k));
  var val = el('span', 'lh-ctx__v', v || null);
  if(node) val.appendChild(node);
  row.appendChild(val);
  return row;
}

function smithChip(name, state){
  var chip = el('span', 'lh-smith-inline');
  chip.appendChild(el('span', 'lh-smith__name', name));
  if(state) chip.appendChild(badge(stateTone(state), state));
  return chip;
}

function renderDeck(m){
  deck.textContent = '';
  cards = [];

  m.deck.forEach(function(item){
    var card = el('div', 'lh-decision');
    var pad = el('div', 'lh-pad');

    var top = el('div', 'lh-top');
    if(item.type === 'merge'){
      top.appendChild(badge('online', 'checks green'));
      top.appendChild(badge(item.risk === 'low' ? 'neutral' : 'warn', 'risk ' + item.risk));
    } else if(item.type === 'errand'){
      top.appendChild(badge('solid', 'an armed errand'));
      if(item.smith) top.appendChild(smithChip(item.smith, item.state));
    } else {
      top.appendChild(badge('solid', 'the hall decides'));
      if(item.repo) top.appendChild(el('span', 'lh-repo', item.repo));
    }
    pad.appendChild(top);

    pad.appendChild(el('h3', 'lh-title', item.title));
    if(item.detail) pad.appendChild(el('p', 'lh-detail', item.detail));

    if(item.type !== 'merge' && (item.about || item.decide)){
      var ctx = el('div', 'lh-ctx');
      if(item.about) ctx.appendChild(ctxRow('about', item.about));
      if(item.decide) ctx.appendChild(ctxRow('decide', item.decide));
      if(item.type === 'errand' && item.smith) ctx.appendChild(ctxRow('smith', null, smithChip(item.smith, item.state)));
      pad.appendChild(ctx);
    }

    var form = document.createElement('form');
    form.setAttribute('data-lh-question', item.key);
    if(item.options && item.options.length){
      var opts = el('div', 'lh-opts');
      item.options.forEach(function(o){
        var lab = el('label', 'lh-opt');
        var input = document.createElement('input');
        input.type = 'radio'; input.name = 'answer'; input.value = o.value;
        lab.appendChild(input);
        var body = el('span', 'lh-opt__body');
        body.appendChild(el('span', 'lh-opt__label', o.label));
        if(o.hint) body.appendChild(el('span', 'lh-opt__hint', o.hint));
        lab.appendChild(body);
        if(item.recommend_value && o.value === item.recommend_value) lab.appendChild(el('span', 'lh-opt__rec', 'rec'));
        opts.appendChild(lab);
      });
      form.appendChild(opts);
    }

    if(item.allow_freeform){
      var ff = document.createElement('input');
      ff.type = 'text'; ff.name = 'note'; ff.className = 'lh-freeform';
      ff.placeholder = item.freeform_hint || 'or answer in your own words…';
      form.appendChild(ff);
    }

    var foot = el('div', 'lh-foot');
    var btn = el('button', 'lh-btn ' + (item.type === 'merge' ? 'lh-btn--gold' : 'lh-btn--primary'), 'Queue the word');
    btn.type = 'submit';
    foot.appendChild(btn);
    var q = el('span', 'lh-queued');
    q.innerHTML = CHECK + 'queued';
    foot.appendChild(q);
    var limit = el('span', 'lh-limit');
    limit.setAttribute('role', 'alert');
    foot.appendChild(limit);
    form.appendChild(foot);

    form.addEventListener('submit', function(ev){
      ev.preventDefault();
      limit.classList.remove('is-visible');
      var fd = new FormData(form);
      var value = fd.get('answer');
      var note = (fd.get('note') || '').trim();
      var answer = value ? (note ? value + ' — ' + note : value) : note;
      if(!answer) return;
      if(utf8ByteLength(answer) > 512){
        limit.textContent = 'the word is too long to queue (512 bytes at most).';
        limit.classList.add('is-visible');
        return;
      }
      /* READ-ONLY. The hall's own write path stays inside the hall; on the
         glass the word is acknowledged here and goes no further. */
      card.classList.add('is-queued');
      renderTally(model);
      setTimeout(function(){ showCard(active < cards.length - 1 ? active + 1 : active); }, 450);
    });

    pad.appendChild(form);
    card.appendChild(pad);
    deck.appendChild(card);
  });

  cards = Array.prototype.slice.call(deck.children);
  active = 0;
  var stackNav = $('#lh-stack-count').parentNode;
  if(cards.length){
    stackNav.hidden = false;
    showCard(0);
  } else {
    deck.classList.add('lh-call--empty');
    deck.appendChild(el('div', 'lh-empty', 'Nothing waits on the board right now.'));
    stackNav.hidden = true;
  }
}

function showCard(i){
  active = Math.max(0, Math.min(cards.length - 1, i));
  cards.forEach(function(c, j){ c.hidden = j !== active; });
  var answered = answeredCount();
  $('#lh-stack-count').textContent = 'slate ' + (active + 1) + ' of ' + cards.length +
    (answered ? ' · ' + answered + ' queued' : '');
  $('#lh-stack-prev').disabled = active === 0;
  $('#lh-stack-next').disabled = active === cards.length - 1;
  deck.classList.toggle('lh-call--penult', active === cards.length - 2);
  deck.classList.toggle('lh-call--last', active === cards.length - 1);
}

function rows(host, items, opts){
  host.textContent = '';
  if(!items.length){
    host.appendChild(el('div', 'lh-empty', opts.empty));
    return;
  }
  items.forEach(function(t){
    var row = el('div', 'lh-row');
    if(opts.check){
      var chk = el('span', 'lh-row__check');
      chk.innerHTML = CHECK;
      row.appendChild(chk);
    }
    if(t.badge) row.appendChild(badge(t.badge.tone, t.badge.label));
    var main = el('div', 'lh-row__main');
    main.appendChild(el('div', 'lh-row__title', t.title));
    main.appendChild(el('div', 'lh-row__sub', t.sub));
    row.appendChild(main);
    host.appendChild(row);
  });
}

function renderCharted(m){
  var ch = $('#lh-charted');
  ch.textContent = '';
  var bar = $('#lh-dispatch');
  bar.classList.remove('is-queued');
  var anyPickable = false;

  if(!chartedQueued(m.charted).length && !m.chartedMore){
    ch.appendChild(el('div', 'lh-empty', 'Nothing is charted.'));
  }
  m.charted.forEach(function(t){
    var row = el('div', 'lh-row');
    if(t.dispatchable && !isWarning(t)){
      anyPickable = true;
      var pick = document.createElement('input');
      pick.type = 'checkbox'; pick.className = 'lh-pick'; pick.value = t.id;
      pick.setAttribute('aria-label', 'Pick ' + t.id + ' for dispatch');
      pick.addEventListener('change', function(){
        if(pick.checked && utf8ByteLength(pickedIds().join(',')) > 512){
          pick.checked = false;
          refreshBar('the selection is too long (512 bytes at most). ');
          return;
        }
        refreshBar();
      });
      row.appendChild(pick);
    } else {
      row.appendChild(el('span', 'lh-pick-spacer'));
    }
    var main = el('div', 'lh-row__main');
    main.appendChild(el('div', 'lh-row__title', t.title));
    main.appendChild(el('div', 'lh-row__sub', t.reason ? t.reason + ' · ' + t.sub : t.sub));
    row.appendChild(main);
    // the shelf opens when pressed: the about of the charted work, and what a
    // dispatch of it will make.
    main.style.cursor = 'pointer';
    var det = el('div', 'lh-row__detail');
    det.style.display = 'none';
    det.appendChild(el('p', null, 'the about: ' + (t.sub || t.reason || 'the plans own the detail — read the project shelf')));
    det.appendChild(el('p', null, 'a dispatch of this will: carve an isolated worktree, raise the agent on it, and land the deliverable at the project shelf — the aim rides the brief, and the ticket is cut in the book.'));
    var open = false;
    main.addEventListener('click', function(){ open = !open; det.style.display = open ? 'block' : 'none'; });
    row.appendChild(det);
    if(isWarning(t)) row.appendChild(badge('danger', 'needs repair'));
    else if(t.reason) row.appendChild(badge('warn', 'waiting'));
    ch.appendChild(row);
  });
  var shown = chartedQueued(m.charted).length;
  var total = shown + m.chartedMore;
  $('#lh-charted-sub').textContent = m.chartedMore ? 'showing ' + shown + ' of ' + total : '';
  if(m.chartedMore) ch.appendChild(el('span', 'lh-morechip', '+' + m.chartedMore + ' more charted — the saga holds them'));
  if(m.chartedWarningMore) ch.appendChild(el('span', 'lh-morechip', '+' + m.chartedWarningMore + ' more crack' +
    (m.chartedWarningMore === 1 ? '' : 's') + ' — the healer walks at night'));

  if(anyPickable){
    bar.hidden = false;
    refreshBar();
  } else {
    bar.hidden = true;
  }
}

function pickedIds(){
  return $$('.lh-pick:checked').map(function(c){ return c.value; });
}
function refreshBar(limitMessage){
  var n = pickedIds().length;
  $('#lh-dispatch-count').textContent = limitMessage || (n ? n + ' picked for the dispatch' : 'pick charted work to dispatch');
  $('#lh-dispatch-btn').disabled = !n;
}

function renderProvenance(m){
  var asof = $('#lh-asof');
  asof.textContent = m.source === 'hall'
    ? 'live · ' + (m.generated || 'just now')
    : 'as the saga tells it · ' + (m.generated || 'the tale');
  asof.classList.toggle('is-live', m.source === 'hall');
}

function render(m){
  model = m;
  renderDeck(m);
  renderTally(m);
  renderSmiths(m);
  $('#lh-count').textContent = m.countLine || '';
  var live = m.source === 'hall';
  $('#lh-underway-sub').textContent = live ? 'held by the hall' : 'kept by the hall';
  $('#lh-landed-k').textContent = live ? 'landed' : 'landed as carvings';
  $('#lh-landed-sub').textContent = live ? 'the hall\u2019s own ledger' : 'the saga\u2019s thirteen';
  rows($('#lh-underway'), m.underway, { empty: 'Nothing is underway.' });
  var ld = $('#lh-landed');
  ld.classList.add('lh-rows--scroll');
  rows(ld, m.landed, { empty: live ? 'Nothing has landed yet.' : 'No carving has landed yet.', check: true });
  renderCharted(m);
  renderProvenance(m);
}

/* ============================================================
   THE STACK NAVIGATION + THE GLASS'S OWN CONTROLS
   ============================================================ */
deck = $('#lh-call');
$('#lh-stack-prev').addEventListener('click', function(){ showCard(active - 1); });
$('#lh-stack-next').addEventListener('click', function(){ showCard(active + 1); });
$('#lh-dispatch-btn').addEventListener('click', function(){
  var ids = pickedIds();
  if(!ids.length) return;
  if(utf8ByteLength(ids.join(',')) > 512){
    refreshBar('the selection is too long (512 bytes at most). ');
    return;
  }
  /* READ-ONLY: acknowledged here; the hall's own write path stays inside. */
  $('#lh-dispatch').classList.add('is-queued');
});

/* ============================================================
   PAINT, THEN READ THE HALL
   ============================================================ */
render(modelFromSaga(saga));
/* The hall says so when it is telling the tale rather than reading a board:
   invented rows must never pass for telemetry. Removed when a live feed arrives. */
try {
  if (!document.getElementById('saga-note')) {
    var note = document.createElement('div');
    note.id = 'saga-note';
    note.setAttribute('role', 'status');
    note.style.cssText = 'margin:12px 0;padding:10px 14px;border:1px solid rgba(201,151,63,0.45);border-radius:8px;font-size:0.9rem;line-height:1.45;opacity:0.9';
    note.textContent = 'Not connected \u2014 this board is the saga\u2019s sample, not your fleet. It reads live once the hall reaches its source.';
    var host = document.querySelector('.lh-board') || document.body;
    host.insertBefore(note, host.firstChild);
  }
} catch (e) { /* a courtesy; never break the page for it */ }

var lastFeed = null;
function readSnapshot(force){
  try {
    fetch('/livehall.json', { cache: 'no-store' })
      .then(function(r){ return r.ok ? r.json() : null; })
      .then(function(feed){
        if(!isFeed(feed)) return;                        /* the tale stands */
        var raw = JSON.stringify(feed);
        if(!force && raw === lastFeed) return;            /* nothing new to paint */
        lastFeed = raw;
        render(modelFromFeed(feed));
        var sn = document.getElementById('saga-note');
        if (sn) sn.remove();   /* live board: the sample marker has no business here */
      })
      .catch(function(){ /* the tale stands */ });
  } catch (e) { /* no fetch available — the tale stands */ }
}

var refreshBtn = $('#lh-refresh');
if(refreshBtn){
  refreshBtn.addEventListener('click', function(){
    refreshBtn.disabled = true;
    readSnapshot(true);
    setTimeout(function(){ refreshBtn.disabled = false; }, 400);
  });
}
/* coming back to the glass re-reads it — but only when it has changed, so a
   word queued in this page is never wiped out from under the reader */
document.addEventListener('visibilitychange', function(){
  if(!document.hidden) readSnapshot(false);
});
readSnapshot(false);
})();