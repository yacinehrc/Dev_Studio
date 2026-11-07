/* Dev Studio — interface */
(() => {
'use strict';

/* =============== Utilitaires =============== */
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const qi = n => '`' + String(n).replace(/`/g, '``') + '`';
const sqlStr = s => "'" + String(s).replace(/\\/g, '\\\\').replace(/'/g, "''") + "'";
const sleep = ms => new Promise(r => setTimeout(r, ms));
const store = {
  get(k, d) { try { const v = localStorage.getItem('ds.' + k); return v === null ? d : JSON.parse(v); } catch { return d; } },
  set(k, v) { try { localStorage.setItem('ds.' + k, JSON.stringify(v)); } catch {} },
};

const ICONS = {
  grid: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/>',
  code: '<polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/>',
  database: '<ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M3 5v14a9 3 0 0 0 18 0V5"/><path d="M3 12a9 3 0 0 0 18 0"/>',
  terminal: '<polyline points="4 17 10 11 4 5"/><line x1="12" x2="20" y1="19" y2="19"/>',
  sliders: '<line x1="4" x2="4" y1="21" y2="14"/><line x1="4" x2="4" y1="10" y2="3"/><line x1="12" x2="12" y1="21" y2="12"/><line x1="12" x2="12" y1="8" y2="3"/><line x1="20" x2="20" y1="21" y2="16"/><line x1="20" x2="20" y1="12" y2="3"/><line x1="2" x2="6" y1="14" y2="14"/><line x1="10" x2="14" y1="8" y2="8"/><line x1="18" x2="22" y1="16" y2="16"/>',
  logout: '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" x2="9" y1="12" y2="12"/>',
  plus: '<path d="M5 12h14"/><path d="M12 5v14"/>',
  folder: '<path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/>',
  file: '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/>',
  filePlus: '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="M9 15h6"/><path d="M12 18v-6"/>',
  folderPlus: '<path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/><line x1="12" x2="12" y1="10" y2="16"/><line x1="9" x2="15" y1="13" y2="13"/>',
  folderUp: '<path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/><path d="M12 10v6"/><path d="m9 13 3-3 3 3"/>',
  upload: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" x2="12" y1="3" y2="15"/>',
  download: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" x2="12" y1="15" y2="3"/>',
  refresh: '<path d="M21 12a9 9 0 1 1-3-6.7L21 8"/><path d="M21 3v5h-5"/>',
  trash: '<path d="M3 6h18"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/><path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>',
  pencil: '<path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/>',
  eye: '<path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/>',
  external: '<path d="M15 3h6v6"/><path d="M10 14 21 3"/><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>',
  save: '<path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/>',
  play: '<polygon points="6 3 20 12 6 21 6 3"/>',
  stop: '<rect x="5" y="5" width="14" height="14" rx="2"/>',
  x: '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
  arrowUp: '<path d="m5 12 7-7 7 7"/><path d="M12 19V5"/>',
  columns: '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M12 3v18"/>',
  table: '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18"/><path d="M3 15h18"/><path d="M12 3v18"/>',
  lock: '<rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
  user: '<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>',
  server: '<rect x="2" y="2" width="20" height="8" rx="2"/><rect x="2" y="14" width="20" height="8" rx="2"/><line x1="6" x2="6.01" y1="6" y2="6"/><line x1="6" x2="6.01" y1="18" y2="18"/>',
  archive: '<rect x="2" y="3" width="20" height="5" rx="1"/><path d="M4 8v11a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8"/><path d="M10 12h4"/>',
  copy: '<rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>',
  key: '<circle cx="7.5" cy="15.5" r="5.5"/><path d="m21 2-9.6 9.6"/><path d="m15.5 7.5 3 3L22 7l-3-3"/>',
  chevron: '<path d="m9 18 6-6-6-6"/>',
  hammer: '<path d="m15 12-8.5 8.5a2.12 2.12 0 1 1-3-3L12 9"/><path d="M17.64 15 22 10.64"/><path d="m20.91 11.7-1.25-1.25a2.4 2.4 0 0 1-.71-1.7V7.86L16.5 5.42A6 6 0 0 0 12.27 3.7H9l.92.82A6.18 6.18 0 0 1 12 9.1V11l2 2h2.17a2.4 2.4 0 0 1 1.7.71l1.25 1.25"/>',
};
const icon = (n, cls = '') => `<svg class="i ${cls}" viewBox="0 0 24 24" aria-hidden="true">${ICONS[n] || ''}</svg>`;
const hydrateIcons = (root = document) => $$('i[data-icon]', root).forEach(el => { el.outerHTML = icon(el.dataset.icon); });

function fmtSize(b) {
  if (b == null) return '';
  if (b < 1024) return b + ' o';
  const u = ['Ko', 'Mo', 'Go', 'To']; let i = -1;
  do { b /= 1024; i++; } while (b >= 1024 && i < u.length - 1);
  return (b < 10 ? b.toFixed(1) : Math.round(b)) + ' ' + u[i];
}
function fmtAgo(ts) {
  const s = Math.floor(Date.now() / 1000 - ts);
  if (s < 60) return "à l'instant";
  if (s < 3600) return `il y a ${Math.floor(s / 60)} min`;
  if (s < 86400) return `il y a ${Math.floor(s / 3600)} h`;
  if (s < 86400 * 30) return `il y a ${Math.floor(s / 86400)} j`;
  return new Date(ts * 1000).toLocaleDateString('fr-FR');
}
const urlFor = p => '/' + String(p).split('/').filter(Boolean).map(encodeURIComponent).join('/') + (p && !/\.[^/]+$/.test(p) ? '/' : '');
const extOf = p => { const m = /\.([^./]+)$/.exec(p); return m ? m[1].toLowerCase() : ''; };
const baseName = p => String(p).split('/').pop();
const dirName = p => String(p).split('/').slice(0, -1).join('/');
const IMG_EXT = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'ico', 'avif', 'bmp'];

async function copyText(t) {
  try { await navigator.clipboard.writeText(t); }
  catch {
    const ta = document.createElement('textarea'); ta.value = t; ta.style.position = 'fixed'; ta.style.opacity = '0';
    document.body.append(ta); ta.select(); document.execCommand('copy'); ta.remove();
  }
  toast('Copié');
}

/* =============== API =============== */
async function api(action, { params = {}, body, form } = {}) {
  const qs = new URLSearchParams({ action, ...params });
  const opt = { method: body || form ? 'POST' : 'GET', headers: { 'X-CSRF-Token': DS.csrf }, credentials: 'same-origin' };
  if (form) opt.body = form;
  else if (body) { opt.headers['Content-Type'] = 'application/json'; opt.body = JSON.stringify(body); }
  let res;
  try { res = await fetch('api.php?' + qs, opt); } catch { throw new Error('Serveur injoignable'); }
  if (res.status === 413) throw new Error('Fichier trop gros pour le serveur');
  let data;
  try { data = await res.json(); } catch { throw new Error(`Réponse invalide du serveur (HTTP ${res.status})`); }
  if (res.status === 401) { setTimeout(() => location.reload(), 800); throw new Error(data.error || 'Session expirée'); }
  if (!res.ok || data.error) throw new Error(data.error || `HTTP ${res.status}`);
  return data;
}
const apiUrl = (action, params = {}) => 'api.php?' + new URLSearchParams({ action, ...params });

/* =============== Toasts & modales =============== */
function toast(msg, err = false) {
  const t = document.createElement('div');
  t.className = 'toast' + (err ? ' err' : '');
  t.textContent = msg;
  $('#toasts').append(t);
  setTimeout(() => { t.style.opacity = '0'; t.style.transition = 'opacity .3s'; }, err ? 5000 : 2400);
  setTimeout(() => t.remove(), err ? 5400 : 2800);
}
const fail = e => toast(e.message || String(e), true);

function modal({ title, body = '', actions = [], wide = false, onOpen }) {
  return new Promise(resolve => {
    const back = document.createElement('div');
    back.className = 'modal-back';
    back.innerHTML = `<div class="modal ${wide ? 'wide' : ''}" role="dialog"><div class="modal-head"><h3>${esc(title)}</h3><button class="icon-btn" data-x>${icon('x')}</button></div><div class="modal-body"></div><div class="modal-foot"></div></div>`;
    const bodyEl = $('.modal-body', back);
    if (typeof body === 'string') bodyEl.innerHTML = body; else bodyEl.append(body);
    hydrateIcons(bodyEl);
    const foot = $('.modal-foot', back);
    let done = false;
    const close = v => { if (done) return; done = true; back.remove(); document.removeEventListener('keydown', onKey, true); resolve(v); };
    actions.forEach(a => {
      const b = document.createElement('button');
      b.className = 'btn ' + (a.cls || '');
      b.innerHTML = a.label;
      b.onclick = async () => {
        if (!a.handler) return close(a.value);
        b.disabled = true;
        try {
          const r = await a.handler(bodyEl);
          if (r === false) { b.disabled = false; return; }
          close(r === undefined ? a.value : r);
        } catch (e) { fail(e); b.disabled = false; }
      };
      foot.append(b);
    });
    if (!actions.length) foot.remove();
    const onKey = e => {
      if (e.key === 'Escape') { e.stopPropagation(); close(null); }
      else if (e.key === 'Enter' && e.target.tagName === 'INPUT' && back.contains(e.target)) {
        const p = foot.querySelector('.btn-primary, .btn-danger');
        if (p) { e.preventDefault(); p.click(); }
      }
    };
    document.addEventListener('keydown', onKey, true);
    $('[data-x]', back).onclick = () => close(null);
    back.addEventListener('mousedown', e => { if (e.target === back) close(null); });
    $('#modal-root').append(back);
    setTimeout(() => {
      const f = bodyEl.querySelector('input:not([type=checkbox]),select,textarea');
      if (f) f.focus();
      onOpen?.(bodyEl);
    }, 30);
  });
}
const askText = (title, label, value = '', okLabel = 'Valider', selectBase = false) => modal({
  title,
  body: `<label>${esc(label)}<input data-v value="${esc(value)}" spellcheck="false"></label>`,
  actions: [{ label: 'Annuler', value: null }, { label: okLabel, cls: 'btn-primary', handler: b => b.querySelector('[data-v]').value.trim() || false }],
  onOpen: b => {
    const i = b.querySelector('[data-v]');
    const dot = value.lastIndexOf('.');
    if (selectBase && dot > 0) i.setSelectionRange(0, dot); else i.select();
  },
});
const confirmBox = (title, html, okLabel = 'Supprimer', danger = true) => modal({
  title, body: `<p>${html}</p>`,
  actions: [{ label: 'Annuler', value: false }, { label: okLabel, cls: danger ? 'btn-danger' : 'btn-primary', value: true }],
});

/* =============== État & navigation =============== */
const state = {
  view: 'projects',
  projects: [],
  info: null,
  dir: store.get('dir', ''),
  items: [],
  tabs: [],
  active: null,
  previewOpen: false,
  db: { name: null, table: null, tab: 'tables', page: 1, per: 50, order: '', dir: 'ASC', dbs: [], tables: [], showSys: false, browse: null },
  term: { cwd: store.get('cwd', ''), job: null, offset: 0, timer: null, history: store.get('history', []), hIdx: -1 },
  jobs: [],
};

function show(view) {
  if (!$('#view-' + view)) view = 'projects';
  state.view = view;
  $$('.rail-btn[data-view]').forEach(b => b.classList.toggle('active', b.dataset.view === view));
  $$('.view').forEach(v => v.classList.toggle('active', v.id === 'view-' + view));
  if (location.hash !== '#' + view) history.replaceState(null, '', '#' + view);
  if (view === 'projects') loadProjects();
  if (view === 'editor') { loadDir(state.dir); setTimeout(() => editor.refresh(), 0); }
  if (view === 'db') { if (!state.info) loadInfo(); if (!state.db.dbs.length) loadDbs(); }
  if (view === 'terminal') { fillCwd(); loadJobs(); setTimeout(() => $('#term-cmd').focus(), 0); }
  if (view === 'settings') loadSettings();
}

/* =============== Projets =============== */
const TYPE = {
  react: { label: 'React', mark: 'JSX' },
  php: { label: 'PHP', mark: 'PHP' },
  html: { label: 'HTML', mark: '</>' },
  node: { label: 'Node', mark: 'JS' },
  folder: { label: 'Dossier', mark: '···' },
};

async function loadInfo() {
  try { state.info = await api('info'); } catch (e) { state.info = null; }
  renderStats();
  return state.info;
}

function renderStats() {
  const i = state.info;
  const el = $('#stats');
  if (!i) { el.innerHTML = ''; return; }
  const diskUsed = i.disk_total ? 1 - i.disk_free / i.disk_total : 0;
  const memUsed = i.mem?.MemTotal ? 1 - i.mem.MemAvailable / i.mem.MemTotal : 0;
  const s = (label, value, extra = '') => `<div class="stat"><div class="stat-label">${label}</div><div class="stat-value">${value}</div>${extra}</div>`;
  el.innerHTML =
    s('PHP', `<span class="led"></span>${esc(i.php)}`) +
    s('Node.js', `<span class="led ${i.node ? '' : 'off'}"></span>${esc(i.node || 'absent')}`) +
    s('MariaDB', `<span class="led ${i.mysql ? '' : 'off'}"></span>${esc(i.mysql ? i.mysql.split('-')[0] : 'arrêté')}`) +
    s('Disque', `${fmtSize(i.disk_total - i.disk_free)} / ${fmtSize(i.disk_total)}`, `<div class="meter"><div style="width:${(diskUsed * 100).toFixed(0)}%"></div></div>`) +
    s('Mémoire', `${fmtSize(i.mem.MemTotal - i.mem.MemAvailable)} / ${fmtSize(i.mem.MemTotal)}`, `<div class="meter"><div style="width:${(memUsed * 100).toFixed(0)}%"></div></div>`);
}

async function loadProjects() {
  $('#host-hint').textContent = `http://${location.host}/nom-du-projet/`;
  if (!state.info) loadInfo();
  try {
    const d = await api('projects');
    state.projects = d.projects;
  } catch (e) { fail(e); }
  renderProjects();
}

function renderProjects() {
  const g = $('#project-grid');
  if (!state.projects.length) {
    g.innerHTML = `<div class="empty-state">Aucun projet pour l'instant.<br><br><button class="btn btn-primary" data-act="new">${icon('plus')}Créer mon premier projet</button></div>`;
    return;
  }
  g.innerHTML = state.projects.map(p => {
    const t = TYPE[p.type] || TYPE.folder;
    let badges = `<span class="badge">${t.label}</span>`;
    if (p.type === 'react') {
      badges += p.node_modules ? '' : ' <span class="badge warn">npm install requis</span>';
      badges += p.dist ? ' <span class="badge ok">build ok</span>' : ' <span class="badge warn">pas de build</span>';
    }
    return `<div class="project t-${p.type}" data-name="${esc(p.name)}">
      <div class="project-top">
        <div class="project-icon">${esc(t.mark)}</div>
        <div><div class="project-name">${esc(p.name)}</div><div class="project-meta">modifié ${fmtAgo(p.mtime)}</div></div>
      </div>
      <div>${badges}</div>
      <div class="project-actions">
        <button class="btn btn-sm" data-act="open">${icon('code')}Ouvrir</button>
        <button class="btn btn-sm" data-act="preview">${icon('eye')}Aperçu</button>
        ${p.type === 'react' || p.type === 'node' ? `<button class="btn btn-sm" data-act="build">${icon('hammer')}Build</button>` : ''}
        <button class="btn btn-sm btn-ghost" data-act="term" title="Terminal">${icon('terminal')}</button>
        <span class="grow"></span>
        <button class="icon-btn danger" data-act="delete" title="Supprimer">${icon('trash')}</button>
      </div>
    </div>`;
  }).join('');
}

$('#project-grid').addEventListener('click', async e => {
  const b = e.target.closest('[data-act]');
  if (!b) return;
  if (b.dataset.act === 'new') return newProject();
  const name = b.closest('[data-name]')?.dataset.name;
  const p = state.projects.find(x => x.name === name);
  if (!p) return;
  switch (b.dataset.act) {
    case 'open':
      state.dir = p.name;
      show('editor');
      if (p.main) openFile(p.main);
      break;
    case 'preview':
      previewProject(p);
      break;
    case 'build':
      runInTerminal(p.name, p.node_modules ? 'npm run build' : 'npm install && npm run build');
      break;
    case 'term':
      state.term.cwd = p.name; store.set('cwd', p.name);
      show('terminal');
      break;
    case 'delete': {
      const ok = await confirmBox('Supprimer le projet', `Supprimer définitivement <b>${esc(p.name)}</b> et tous ses fichiers ?<br><span class="muted small">Les bases de données ne sont pas supprimées.</span>`);
      if (!ok) return;
      try {
        await api('delete', { body: { paths: [p.name] } });
        state.tabs.filter(t => t.path.startsWith(p.name + '/')).forEach(t => closeTab(t, true));
        if (state.dir === p.name || state.dir.startsWith(p.name + '/')) state.dir = '';
        toast('Projet supprimé'); loadProjects();
      } catch (e) { fail(e); }
    }
  }
});

async function previewProject(p) {
  if (p.type === 'react' || p.type === 'node') {
    if (p.dist) return window.open(urlFor(p.name + '/dist'), '_blank');
    const go = await confirmBox('Pas encore de build', `Le projet <b>${esc(p.name)}</b> n'a pas de dossier <code>dist/</code>. Lancer <code>npm run build</code> maintenant ?<br><span class="muted small">Astuce : <code>npm run dev</code> dans le Terminal lance un serveur avec rechargement automatique sur le port 5173.</span>`, 'Lancer le build', false);
    if (go) runInTerminal(p.name, p.node_modules ? 'npm run build' : 'npm install && npm run build');
    return;
  }
  window.open(urlFor(p.name), '_blank');
}

function newProject() {
  const tpls = [
    ['html', 'HTML / CSS / JS', 'Site statique : index.html, style.css, script.js'],
    ['php', 'PHP + MySQL', 'Crée aussi une base de données reliée + exemple CRUD'],
    ['react', 'React (Vite)', 'npm install + build automatiques (≈ 1 min)'],
    ['empty', 'Dossier vide', 'Pour importer ton propre code'],
  ];
  let sel = 'html';
  const body = document.createElement('div');
  body.style.cssText = 'display:flex;flex-direction:column;gap:14px';
  body.innerHTML = `<label>Nom du projet<input data-name placeholder="mon-site" spellcheck="false" pattern="[A-Za-z0-9][A-Za-z0-9_\\-]*"></label>
    <div class="tpl-grid">${tpls.map(([k, t, d]) => `<button type="button" class="tpl ${k === sel ? 'sel' : ''}" data-tpl="${k}"><b>${t}</b><span>${d}</span></button>`).join('')}</div>`;
  body.addEventListener('click', e => {
    const t = e.target.closest('[data-tpl]'); if (!t) return;
    sel = t.dataset.tpl; $$('.tpl', body).forEach(x => x.classList.toggle('sel', x === t));
  });
  modal({
    title: 'Nouveau projet', body,
    actions: [{ label: 'Annuler' }, {
      label: 'Créer le projet', cls: 'btn-primary', handler: async b => {
        const name = $('[data-name]', b).value.trim();
        if (!name) { toast('Donne un nom au projet', true); return false; }
        const r = await api('project_create', { body: { name, template: sel } });
        toast(`Projet « ${name} » créé` + (r.db ? ` (base « ${r.db} »)` : ''));
        state.projects = [];
        if (r.job) {
          state.term.cwd = name; store.set('cwd', name);
          show('terminal');
          attachJob(r.job);
        } else {
          state.dir = name;
          show('editor');
          if (r.open) openFile(r.open);
        }
        if (r.db) state.db.dbs = [];
        return true;
      },
    }],
  });
}
$('#btn-new-project').onclick = newProject;

/* =============== Explorateur =============== */
const FILE_COLORS = {
  js: ['JS', '#f5c451'], mjs: ['JS', '#f5c451'], jsx: ['JSX', '#7cc4ff'], ts: ['TS', '#7cc4ff'], tsx: ['TSX', '#7cc4ff'],
  php: ['PHP', '#b59cff'], html: ['<>', '#ffb86b'], htm: ['<>', '#ffb86b'], css: ['#', '#7cc4ff'], scss: ['#', '#ff8fb1'],
  json: ['{}', '#f5c451'], sql: ['SQL', '#6ee7d8'], md: ['MD', '#b9bfcc'], txt: ['TXT', '#7d8596'], svg: ['SVG', '#ffb86b'],
  png: ['IMG', '#4ade80'], jpg: ['IMG', '#4ade80'], jpeg: ['IMG', '#4ade80'], gif: ['IMG', '#4ade80'], webp: ['IMG', '#4ade80'], ico: ['IMG', '#4ade80'],
  zip: ['ZIP', '#ff6b6b'], env: ['ENV', '#c4f25e'], sh: ['SH', '#c4f25e'], xml: ['XML', '#ffb86b'], yml: ['YML', '#ff8fb1'], yaml: ['YML', '#ff8fb1'],
};
function fileIcon(item) {
  if (item.dir) return `<span class="ficon dir">${icon('folder')}</span>`;
  const c = FILE_COLORS[extOf(item.name)];
  return c ? `<span class="ficon" style="color:${c[1]}">${esc(c[0])}</span>` : `<span class="ficon" style="color:var(--muted)">${icon('file')}</span>`;
}

async function loadDir(path = state.dir) {
  try {
    const d = await api('list', { params: { path } });
    state.dir = d.path; state.items = d.items;
    store.set('dir', state.dir);
  } catch (e) { fail(e); state.dir = ''; state.items = []; }
  renderExplorer();
}

function renderExplorer() {
  const parts = state.dir ? state.dir.split('/') : [];
  let acc = '';
  $('#crumbs').innerHTML = `<button data-crumb="">www</button>` + parts.map(p => {
    acc = acc ? acc + '/' + p : p;
    return `<span class="sep">/</span><button data-crumb="${esc(acc)}">${esc(p)}</button>`;
  }).join('');
  const activePath = state.active?.path;
  $('#file-list').innerHTML = state.items.length ? state.items.map((it, i) => `
    <div class="frow ${it.path === activePath ? 'active' : ''}" data-i="${i}">
      ${fileIcon(it)}
      <span class="fname" title="${esc(it.name)}">${esc(it.name)}</span>
      <span class="fsize">${it.dir ? '' : fmtSize(it.size)}</span>
      <span class="facts">
        ${!it.dir ? `<button class="icon-btn" data-a="view" title="Voir dans le navigateur">${icon('eye')}</button>` : ''}
        ${extOf(it.name) === 'zip' ? `<button class="icon-btn" data-a="extract" title="Extraire">${icon('archive')}</button>` : ''}
        <button class="icon-btn" data-a="rename" title="Renommer">${icon('pencil')}</button>
        <button class="icon-btn" data-a="download" title="Télécharger${it.dir ? ' (zip)' : ''}">${icon('download')}</button>
        <button class="icon-btn danger" data-a="delete" title="Supprimer">${icon('trash')}</button>
      </span>
      <button class="open-btn" data-a="open">Ouvrir</button>
    </div>`).join('') : `<div class="placeholder" style="padding:30px 10px">${icon('folder')}<span>Dossier vide</span></div>`;
}

$('#crumbs').addEventListener('click', e => { const b = e.target.closest('[data-crumb]'); if (b) loadDir(b.dataset.crumb); });
$('#ex-up').onclick = () => loadDir(dirName(state.dir));
$('#ex-refresh').onclick = () => loadDir();
$('#ex-upload').onclick = () => $('#file-input').click();
$('#ex-upload-dir').onclick = () => $('#dir-input').click();
$('#file-input').onchange = e => { uploadFiles([...e.target.files].map(f => ({ file: f, rel: f.name })), state.dir); e.target.value = ''; };
$('#dir-input').onchange = e => {
  const list = [...e.target.files].filter(f => !/(^|\/)(node_modules|\.git)\//.test(f.webkitRelativePath)).map(f => ({ file: f, rel: f.webkitRelativePath || f.name }));
  uploadFiles(list, state.dir); e.target.value = '';
};
$('#ex-newfile').onclick = async () => {
  const n = await askText('Nouveau fichier', `Nom du fichier dans /${state.dir}`, '', 'Créer');
  if (!n) return;
  const path = (state.dir ? state.dir + '/' : '') + n;
  try {
    if (n.includes('/')) await api('mkdir', { body: { path: dirName(path) } }).catch(() => {});
    await api('create_file', { body: { path } });
    await loadDir(); openFile(path);
  } catch (e) { fail(e); }
};
$('#ex-newfolder').onclick = async () => {
  const n = await askText('Nouveau dossier', `Nom du dossier dans /${state.dir}`, '', 'Créer');
  if (!n) return;
  try { await api('mkdir', { body: { path: (state.dir ? state.dir + '/' : '') + n } }); loadDir(); } catch (e) { fail(e); }
};

$('#file-list').addEventListener('click', async e => {
  const row = e.target.closest('.frow'); if (!row) return;
  const it = state.items[+row.dataset.i]; if (!it) return;
  const a = e.target.closest('[data-a]')?.dataset.a || 'open';
  switch (a) {
    case 'open': return it.dir ? loadDir(it.path) : openFile(it.path);
    case 'view': return window.open(urlFor(it.path), '_blank');
    case 'download': return void (location.href = apiUrl('download', { path: it.path }));
    case 'extract':
      try { const r = await api('extract', { body: { path: it.path } }); toast('Extrait dans ' + baseName(r.path)); loadDir(); } catch (err) { fail(err); }
      return;
    case 'rename': {
      const n = await askText('Renommer', 'Nouveau nom', it.name, 'Renommer', !it.dir);
      if (!n || n === it.name) return;
      const to = (dirName(it.path) ? dirName(it.path) + '/' : '') + n;
      try {
        await api('rename', { body: { from: it.path, to } });
        state.tabs.forEach(t => {
          if (t.path === it.path) t.path = to;
          else if (t.path.startsWith(it.path + '/')) t.path = to + t.path.slice(it.path.length);
          t.name = baseName(t.path);
        });
        renderTabs(); loadDir();
      } catch (err) { fail(err); }
      return;
    }
    case 'delete': {
      const ok = await confirmBox('Supprimer', `Supprimer <b>${esc(it.name)}</b>${it.dir ? ' et tout son contenu' : ''} ?`);
      if (!ok) return;
      try {
        await api('delete', { body: { paths: [it.path] } });
        state.tabs.filter(t => t.path === it.path || t.path.startsWith(it.path + '/')).forEach(t => closeTab(t, true));
        loadDir();
      } catch (err) { fail(err); }
    }
  }
});

/* ----- Glisser-déposer depuis le PC ----- */
const explorer = $('#explorer');
let dragDepth = 0, dropRow = null;
const hasFiles = e => [...(e.dataTransfer?.types || [])].includes('Files');
const dropTargetFor = e => {
  const row = e.target.closest?.('.frow');
  const it = row && state.items[+row.dataset.i];
  return it && it.dir ? { path: it.path, row } : { path: state.dir, row: null };
};
const clearDropRow = () => { dropRow?.classList.remove('drop-in'); dropRow = null; };
explorer.addEventListener('dragenter', e => { if (!hasFiles(e)) return; e.preventDefault(); dragDepth++; explorer.classList.add('dragging'); });
explorer.addEventListener('dragleave', e => { if (!hasFiles(e)) return; if (--dragDepth <= 0) { dragDepth = 0; explorer.classList.remove('dragging'); clearDropRow(); } });
explorer.addEventListener('dragover', e => {
  if (!hasFiles(e)) return;
  e.preventDefault(); e.dataTransfer.dropEffect = 'copy';
  const t = dropTargetFor(e);
  if (t.row !== dropRow) { clearDropRow(); dropRow = t.row; dropRow?.classList.add('drop-in'); }
  $('#drop-target').textContent = '/var/www/' + t.path;
});
explorer.addEventListener('drop', async e => {
  if (!hasFiles(e)) return;
  e.preventDefault();
  const target = dropTargetFor(e).path;
  dragDepth = 0; explorer.classList.remove('dragging'); clearDropRow();
  const list = await collectDropped(e.dataTransfer);
  uploadFiles(list, target);
});
// Empêche le navigateur d'ouvrir un fichier lâché à côté
window.addEventListener('dragover', e => { if (hasFiles(e)) e.preventDefault(); });
window.addEventListener('drop', e => { if (hasFiles(e) && !explorer.contains(e.target)) { e.preventDefault(); toast("Dépose les fichiers dans l'explorateur (onglet Éditeur)", true); } });

async function collectDropped(dt) {
  const out = [];
  const entries = [...(dt.items || [])].filter(i => i.kind === 'file').map(i => i.webkitGetAsEntry?.()).filter(Boolean);
  if (!entries.length) { for (const f of dt.files) out.push({ file: f, rel: f.name }); return out; }
  const readAll = reader => new Promise((res, rej) => {
    const all = [];
    const next = () => reader.readEntries(b => { if (!b.length) return res(all); all.push(...b); next(); }, rej);
    next();
  });
  async function walk(entry, prefix) {
    if (entry.isFile) {
      const f = await new Promise((res, rej) => entry.file(res, rej));
      out.push({ file: f, rel: prefix + f.name });
    } else if (entry.isDirectory) {
      const kids = await readAll(entry.createReader());
      if (!kids.length) out.push({ dir: true, rel: prefix + entry.name });
      for (const k of kids) {
        if (k.isDirectory && (k.name === 'node_modules' || k.name === '.git')) continue;
        await walk(k, prefix + entry.name + '/');
      }
    }
  }
  for (const en of entries) await walk(en, '');
  return out;
}

async function uploadFiles(list, dir) {
  if (!list.length) return;
  const bar = $('#upload-bar'), fill = $('#upload-fill'), text = $('#upload-text');
  const files = list.filter(x => x.file), dirs = list.filter(x => x.dir);
  let done = 0, errors = 0, idx = 0;
  const total = files.length;
  bar.classList.remove('hidden');
  const upd = () => { fill.style.width = (total ? done / total * 100 : 100) + '%'; text.textContent = `Envoi ${done} / ${total}`; };
  upd();
  for (const d of dirs) await api('mkdir', { body: { path: (dir ? dir + '/' : '') + d.rel } }).catch(() => {});
  const worker = async () => {
    while (idx < files.length) {
      const it = files[idx++];
      const fd = new FormData();
      fd.append('file', it.file);
      fd.append('dir', dir);
      fd.append('relpath', it.rel);
      try { await api('upload', { form: fd }); }
      catch (e) { errors++; toast(`${it.rel} : ${e.message}`, true); }
      done++; upd();
    }
  };
  await Promise.all([worker(), worker(), worker()]);
  setTimeout(() => bar.classList.add('hidden'), 900);
  toast(errors ? `${total - errors} fichier(s) envoyé(s), ${errors} erreur(s)` : `${total} fichier(s) envoyé(s) dans /${dir}`, !!errors);
  if (state.view === 'editor') loadDir();
  state.projects = [];
}

/* =============== Éditeur =============== */
const MODES = {
  html: 'htmlmixed', htm: 'htmlmixed', vue: 'htmlmixed',
  js: 'javascript', mjs: 'javascript', cjs: 'javascript',
  jsx: 'jsx', tsx: { name: 'jsx', base: { name: 'javascript', typescript: true } },
  ts: { name: 'javascript', typescript: true }, json: { name: 'javascript', json: true },
  css: 'css', scss: 'text/x-scss', less: 'text/x-less',
  php: 'application/x-httpd-php', sql: 'text/x-mariadb', md: 'markdown',
  xml: 'xml', svg: 'xml', sh: 'shell', bash: 'shell', env: 'shell', yml: 'yaml', yaml: 'yaml',
};
const modeFor = p => MODES[extOf(p)] || (baseName(p).startsWith('.env') ? 'shell' : null);

const editor = (() => {
  const host = $('#editor-host');
  const hasCM = typeof window.CodeMirror === 'function';
  let cm = null, ta = null, current = null;
  const binView = document.createElement('div');
  binView.className = 'binary-view hidden';
  host.append(binView);

  if (hasCM) {
    cm = CodeMirror(host, {
      lineNumbers: true, tabSize: 2, indentUnit: 2, indentWithTabs: false,
      autoCloseBrackets: true, autoCloseTags: true, matchBrackets: true,
      matchTags: { bothTags: true }, styleActiveLine: true, lineWrapping: false,
      extraKeys: {
        'Ctrl-S': () => saveActive(), 'Cmd-S': () => saveActive(),
        'Ctrl-/': 'toggleComment', 'Cmd-/': 'toggleComment',
        Tab: c => c.somethingSelected() ? c.indentSelection('add') : c.replaceSelection(' '.repeat(c.getOption('indentUnit')), 'end'),
        'Shift-Tab': 'indentLess',
      },
    });
    cm.getWrapperElement().style.display = 'none';
    cm.on('changes', () => { if (current) markDirty(current); });
    cm.on('cursorActivity', () => { const c = cm.getCursor(); $('#st-pos').textContent = `Ln ${c.line + 1}, Col ${c.ch + 1}`; });
  } else {
    ta = document.createElement('textarea');
    ta.className = 'fallback hidden'; ta.spellcheck = false;
    host.append(ta);
    ta.addEventListener('input', () => { if (current) { current.doc.text = ta.value; markDirty(current); } });
    ta.addEventListener('keydown', e => {
      if (e.key === 'Tab') { e.preventDefault(); const s = ta.selectionStart; ta.setRangeText('  ', s, ta.selectionEnd, 'end'); ta.dispatchEvent(new Event('input')); }
    });
    setTimeout(() => toast("CodeMirror (CDN) indisponible : éditeur simple activé.", true), 500);
  }

  return {
    makeDoc(content, path) {
      if (hasCM) { const d = CodeMirror.Doc(content, modeFor(path)); return { d, gen: d.changeGeneration(true) }; }
      return { text: content, saved: content };
    },
    isDirty(doc) { return hasCM ? !doc.d.isClean(doc.gen) : doc.text !== doc.saved; },
    value(doc) { return hasCM ? doc.d.getValue() : doc.text; },
    snapshot(doc) { return hasCM ? doc.d.changeGeneration(true) : doc.text; },
    markSaved(doc, snap) { if (hasCM) doc.gen = snap; else doc.saved = snap; },
    show(tab) {
      current = tab;
      $('#empty-editor').classList.toggle('hidden', !!tab);
      const editable = tab && !tab.binary;
      if (hasCM) cm.getWrapperElement().style.display = editable ? '' : 'none'; else ta.classList.toggle('hidden', !editable);
      binView.classList.toggle('hidden', !tab || !tab.binary);
      if (!tab) return;
      if (tab.binary) {
        const url = urlFor(tab.path);
        binView.innerHTML = tab.image
          ? `<img src="${esc(url)}?t=${Date.now()}" alt=""><div class="muted small">${esc(tab.path)}</div>`
          : `<div class="placeholder">${icon('file')}<span>Fichier binaire — pas éditable ici.</span></div>`;
        binView.insertAdjacentHTML('beforeend', `<a class="btn btn-sm" href="${esc(apiUrl('download', { path: tab.path }))}">${icon('download')}Télécharger</a>`);
        return;
      }
      if (hasCM) { cm.swapDoc(tab.doc.d); cm.refresh(); cm.focus(); }
      else { ta.value = tab.doc.text; ta.focus(); }
    },
    refresh() { cm?.refresh(); },
    hasCM,
  };
})();

function markDirty(tab) {
  const dirty = editor.isDirty(tab.doc);
  if (dirty !== tab.dirty) { tab.dirty = dirty; renderTabs(); }
}

async function openFile(path) {
  let tab = state.tabs.find(t => t.path === path);
  if (!tab) {
    const ext = extOf(path);
    if (IMG_EXT.includes(ext)) {
      tab = { path, name: baseName(path), binary: true, image: true };
    } else {
      try {
        const d = await api('read', { params: { path } });
        tab = d.binary
          ? { path, name: baseName(path), binary: true }
          : { path, name: baseName(path), doc: editor.makeDoc(d.content, path), dirty: false };
      } catch (e) { return fail(e); }
    }
    state.tabs.push(tab);
  }
  if (state.view !== 'editor') show('editor');
  activate(tab);
}

function activate(tab) {
  state.active = tab || null;
  editor.show(state.active);
  renderTabs();
  $$('#file-list .frow').forEach(r => r.classList.toggle('active', state.items[+r.dataset.i]?.path === tab?.path));
  $('#st-file').textContent = tab ? '/var/www/' + tab.path : '—';
  $('#st-mode').textContent = tab ? (extOf(tab.path) || 'texte').toUpperCase() : '';
  if (!tab) $('#st-pos').textContent = '';
  if (state.previewOpen) setPreview(previewUrlFor(tab?.path));
}

function renderTabs() {
  $('#tabs').innerHTML = state.tabs.map((t, i) => `
    <div class="tab ${t === state.active ? 'active' : ''} ${t.dirty ? 'dirty' : ''}" data-t="${i}" title="${esc(t.path)}">
      <span class="tname">${esc(t.name)}</span><span class="tclose" data-close>${icon('x')}</span>
    </div>`).join('');
}
$('#tabs').addEventListener('click', e => {
  const el = e.target.closest('.tab'); if (!el) return;
  const t = state.tabs[+el.dataset.t];
  if (e.target.closest('[data-close]')) closeTab(t); else activate(t);
});
$('#tabs').addEventListener('auxclick', e => { if (e.button === 1) { const el = e.target.closest('.tab'); if (el) closeTab(state.tabs[+el.dataset.t]); } });

async function closeTab(tab, force = false) {
  if (!tab) return;
  if (!force && tab.dirty && !(await confirmBox('Modifications non enregistrées', `Fermer <b>${esc(tab.name)}</b> sans enregistrer ?`, 'Fermer sans enregistrer'))) return;
  const i = state.tabs.indexOf(tab);
  state.tabs.splice(i, 1);
  if (state.active === tab) activate(state.tabs[i] || state.tabs[i - 1] || null); else renderTabs();
}

async function saveActive() {
  const tab = state.active;
  if (!tab || tab.binary) return;
  const snap = editor.snapshot(tab.doc);
  const content = editor.value(tab.doc);
  try {
    await api('save', { body: { path: tab.path, content } });
    editor.markSaved(tab.doc, editor.hasCM ? snap : content);
    markDirty(tab);
    toast('Enregistré · ' + tab.name);
    if (state.previewOpen) $('#pv-frame').src = $('#pv-frame').src;
  } catch (e) { fail(e); }
}
$('#ed-save').onclick = saveActive;

document.addEventListener('keydown', e => {
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's') {
    e.preventDefault();
    if (state.view === 'editor') saveActive();
  }
});
window.addEventListener('beforeunload', e => { if (state.tabs.some(t => t.dirty)) { e.preventDefault(); e.returnValue = ''; } });

/* ----- Aperçu ----- */
function previewUrlFor(path) {
  if (!path) return urlFor(state.dir);
  const top = path.split('/')[0];
  const proj = state.projects.find(p => p.name === top);
  if (proj && (proj.type === 'react' || proj.type === 'node')) return urlFor(top + (proj.dist ? '/dist' : ''));
  if (['html', 'htm', 'php'].includes(extOf(path))) return urlFor(path);
  if (IMG_EXT.includes(extOf(path)) || extOf(path) === 'svg') return urlFor(path);
  return urlFor(dirName(path));
}
function setPreview(url) { $('#pv-url').value = url; $('#pv-frame').src = url; }
$('#ed-preview').onclick = async () => {
  state.previewOpen = !state.previewOpen;
  $('#preview-pane').classList.toggle('hidden', !state.previewOpen);
  if (state.previewOpen) {
    if (!state.projects.length) await api('projects').then(d => { state.projects = d.projects; }).catch(() => {});
    setPreview(previewUrlFor(state.active?.path));
  } else $('#pv-frame').src = 'about:blank';
  editor.refresh();
};
$('#ed-open').onclick = async () => {
  if (!state.projects.length) await api('projects').then(d => { state.projects = d.projects; }).catch(() => {});
  window.open(previewUrlFor(state.active?.path), '_blank');
};
$('#pv-reload').onclick = () => { $('#pv-frame').src = $('#pv-url').value; };
$('#pv-ext').onclick = () => window.open($('#pv-url').value, '_blank');
$('#pv-close').onclick = () => $('#ed-preview').click();
$('#pv-url').addEventListener('keydown', e => { if (e.key === 'Enter') $('#pv-frame').src = e.target.value; });

/* =============== Base de données =============== */
const DB = state.db;
let sqlEd = null;

function initSqlEditor() {
  const host = $('#sql-editor');
  const run = () => runSql();
  if (window.CodeMirror) {
    sqlEd = CodeMirror(host, {
      mode: 'text/x-mariadb', lineNumbers: true, matchBrackets: true, autoCloseBrackets: true, indentUnit: 2,
      extraKeys: { 'Ctrl-Enter': run, 'Cmd-Enter': run, 'Ctrl-/': 'toggleComment' },
      value: store.get('sql', 'SELECT 1;'),
    });
    sqlEd.on('changes', () => store.set('sql', sqlEd.getValue()));
    new ResizeObserver(() => sqlEd.refresh()).observe(host);
  } else {
    const ta = document.createElement('textarea');
    ta.value = store.get('sql', 'SELECT 1;'); ta.spellcheck = false;
    ta.addEventListener('keydown', e => { if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) { e.preventDefault(); run(); } });
    ta.addEventListener('input', () => store.set('sql', ta.value));
    host.append(ta);
    sqlEd = { getValue: () => ta.value, setValue: v => { ta.value = v; }, refresh() {}, focus: () => ta.focus(), getSelection: () => ta.value.substring(ta.selectionStart, ta.selectionEnd) };
  }
}

async function loadDbs(keepSelection = true) {
  try {
    const d = await api('db_list');
    DB.dbs = d.dbs;
    if (!keepSelection || (DB.name && !DB.dbs.some(x => x.name === DB.name))) { DB.name = null; DB.table = null; }
    if (DB.name) await loadTables();
  } catch (e) {
    DB.dbs = [];
    $('#db-tree').innerHTML = `<div class="placeholder" style="padding:30px 12px">${icon('database')}<span>${esc(e.message)}</span><button class="btn btn-sm" id="db-retry">Réessayer</button></div>`;
    $('#db-retry').onclick = () => loadDbs();
    return;
  }
  renderDbTree();
  setDbTab(DB.tab);
}

async function loadTables() {
  if (!DB.name) { DB.tables = []; return; }
  try { DB.tables = (await api('db_tables', { params: { db: DB.name } })).tables; }
  catch (e) { DB.tables = []; fail(e); }
}

function renderDbTree() {
  const vis = DB.dbs.filter(d => DB.showSys || !d.system);
  $('#db-tree').innerHTML = vis.map(d => `
    <div class="db-item ${d.system ? 'sys' : ''} ${d.name === DB.name && !DB.table ? 'active' : ''}" data-db="${esc(d.name)}">
      ${icon('database')}<span>${esc(d.name)}</span><span class="n">${d.tables}</span>
    </div>
    ${d.name === DB.name ? `<div class="db-tables">${DB.tables.map(t => `
      <div class="db-item ${t.name === DB.table ? 'active' : ''}" data-table="${esc(t.name)}">${icon('table')}<span>${esc(t.name)}</span><span class="n">${t.rows}</span></div>`).join('') || '<div class="muted small" style="padding:4px 8px">aucune table</div>'}</div>` : ''}
  `).join('') + `<button class="db-sys-toggle" id="db-sys">${DB.showSys ? 'Masquer' : 'Afficher'} les bases système</button>`;
  $('#db-sys').onclick = () => { DB.showSys = !DB.showSys; renderDbTree(); };
}

$('#db-tree').addEventListener('click', async e => {
  const t = e.target.closest('[data-table]');
  const d = e.target.closest('[data-db]');
  if (t) { DB.table = t.dataset.table; DB.page = 1; DB.order = ''; setDbTab('data'); renderDbTree(); return; }
  if (d) {
    const same = DB.name === d.dataset.db;
    DB.name = d.dataset.db; DB.table = null;
    if (!same) await loadTables();
    setDbTab('tables'); renderDbTree();
  }
});
$('#db-new').onclick = async () => {
  const n = await askText('Nouvelle base de données', 'Nom (lettres, chiffres, _ et -)', '', 'Créer');
  if (!n) return;
  try {
    await api('db_create', { body: { name: n } });
    toast(`Base « ${n} » créée — accessible aussi par dev_user`);
    DB.name = n; DB.table = null; await loadDbs(); setDbTab('tables');
  } catch (e) { fail(e); }
};

function setDbTab(tab) {
  if ((tab === 'data' || tab === 'structure') && !DB.table) tab = 'tables';
  DB.tab = tab;
  $$('#db-tabs button').forEach(b => {
    b.classList.toggle('active', b.dataset.dbtab === tab);
    b.disabled = (b.dataset.dbtab === 'data' || b.dataset.dbtab === 'structure') && !DB.table;
  });
  $$('.db-pane').forEach(p => p.classList.toggle('active', p.id === 'db-pane-' + tab));
  $('#db-title').innerHTML = DB.name ? `${esc(DB.name)}${DB.table ? `<span class="sep">›</span>${esc(DB.table)}` : ''}` : 'Choisis une base';
  renderDbPane();
}
$('#db-tabs').addEventListener('click', e => { const b = e.target.closest('[data-dbtab]'); if (b && !b.disabled) setDbTab(b.dataset.dbtab); });

function renderDbPane() {
  if (DB.tab === 'tables') renderTablesPane();
  else if (DB.tab === 'data') renderDataPane();
  else if (DB.tab === 'structure') renderStructurePane();
  else if (DB.tab === 'sql') {
    if (!sqlEd) initSqlEditor();
    $('#sql-db-label').textContent = DB.name ? `sur la base « ${DB.name} »` : 'aucune base sélectionnée (utilise USE nom;)';
    setTimeout(() => { sqlEd.refresh(); sqlEd.focus(); }, 0);
  }
}

function gridHtml(cols, rows, { numeric = [], actions = null, sortable = false, pk = [] } = {}) {
  const head = (actions ? '<th class="acts"></th>' : '') + cols.map(c => {
    const s = sortable && DB.order === c ? (DB.dir === 'ASC' ? ' ↑' : ' ↓') : '';
    return `<th class="${sortable ? 'sortable' : ''}" data-col="${esc(c)}">${esc(c)}${pk.includes(c) ? '<span class="pk" title="Clé primaire">🔑</span>' : ''}${s}</th>`;
  }).join('');
  const body = rows.map((r, ri) => '<tr>' + (actions ? `<td class="acts">${actions(ri)}</td>` : '') + r.map((v, i) => {
    if (v === null) return '<td class="null">NULL</td>';
    const s = typeof v === 'object' ? JSON.stringify(v) : String(v);
    return `<td class="${numeric[i] ? 'num' : ''}" title="${esc(s.length > 60 ? s.slice(0, 500) : '')}">${esc(s.length > 200 ? s.slice(0, 200) + '…' : s)}</td>`;
  }).join('') + '</tr>').join('');
  return `<div class="grid-wrap"><table class="grid"><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table></div>`;
}

function renderTablesPane() {
  const p = $('#db-pane-tables');
  if (!DB.name) {
    p.innerHTML = `<div class="placeholder">${icon('database')}<span>Sélectionne une base à gauche, ou crée-en une.</span><button class="btn btn-primary" id="tp-new">${icon('plus')}Nouvelle base</button></div>`;
    $('#tp-new').onclick = () => $('#db-new').click();
    return;
  }
  const app = state.info?.app_db;
  const isSys = DB.dbs.find(d => d.name === DB.name)?.system;
  p.innerHTML = `
    <div class="toolbar">
      <button class="btn btn-primary btn-sm" id="tp-create">${icon('plus')}Créer une table</button>
      <button class="btn btn-sm" id="tp-sql">${icon('terminal')}Requête SQL</button>
      <a class="btn btn-sm" href="${esc(apiUrl('db_export', { db: DB.name }))}">${icon('download')}Exporter .sql</a>
      <button class="btn btn-sm" id="tp-import">${icon('upload')}Importer .sql</button>
      <span class="grow"></span>
      ${isSys ? '' : `<button class="btn btn-danger btn-sm" id="tp-drop">${icon('trash')}Supprimer la base</button>`}
    </div>
    ${DB.tables.length ? gridHtml(['Table', 'Lignes', 'Taille', 'Moteur', 'Interclassement'],
      DB.tables.map(t => [t.name + (t.view ? ' (vue)' : ''), t.rows, fmtSize(t.bytes), t.engine || '—', t.collation || '—']),
      { numeric: [false, true, true], actions: i => `<button class="icon-btn" data-browse="${i}" title="Parcourir">${icon('eye')}</button><button class="icon-btn" data-struct="${i}" title="Structure">${icon('table')}</button>` })
      : `<div class="placeholder" style="margin:30px auto">${icon('table')}<span>Base vide. Crée ta première table.</span></div>`}
    ${app ? `<div class="section-title">Connexion depuis ton code PHP</div>
    <div class="code-block">$pdo = new PDO('mysql:host=localhost;dbname=${esc(DB.name)};charset=utf8mb4', '${esc(app.user)}', '${esc(app.pass)}');</div>` : ''}`;
  $('#tp-create').onclick = () => createTableModal();
  $('#tp-sql').onclick = () => setDbTab('sql');
  $('#tp-import').onclick = () => {
    const inp = document.createElement('input'); inp.type = 'file'; inp.accept = '.sql,text/plain';
    inp.onchange = async () => {
      const fd = new FormData(); fd.append('file', inp.files[0]); fd.append('db', DB.name);
      try { await api('db_import', { form: fd, params: { db: DB.name } }); toast('Import terminé'); await loadTables(); renderDbTree(); renderTablesPane(); } catch (e) { fail(e); }
    };
    inp.click();
  };
  $('#tp-drop')?.addEventListener('click', async () => {
    const n = await askText('Supprimer la base', `Tape « ${DB.name} » pour confirmer la suppression définitive`, '', 'Supprimer');
    if (n !== DB.name) { if (n) toast('Nom incorrect, rien supprimé', true); return; }
    try { await api('db_drop', { body: { name: DB.name } }); toast('Base supprimée'); DB.name = null; DB.table = null; await loadDbs(); setDbTab('tables'); } catch (e) { fail(e); }
  });
  p.onclick = e => {
    const b = e.target.closest('[data-browse],[data-struct]'); if (!b) return;
    const t = DB.tables[+(b.dataset.browse ?? b.dataset.struct)];
    DB.table = t.name; DB.page = 1; DB.order = '';
    setDbTab(b.dataset.browse !== undefined ? 'data' : 'structure'); renderDbTree();
  };
}

const NUMERIC_TYPE = /^(tinyint|smallint|mediumint|int|bigint|decimal|float|double|real|bit)/i;

async function renderDataPane() {
  const p = $('#db-pane-data');
  p.innerHTML = '<div class="muted">Chargement…</div>';
  let d;
  try {
    d = await api('db_browse', { params: { db: DB.name, table: DB.table, page: DB.page, per: DB.per, order: DB.order, dir: DB.dir } });
  } catch (e) { p.innerHTML = `<div class="placeholder">${esc(e.message)}</div>`; return; }
  DB.browse = d;
  const cols = d.columns.map(c => c.Field);
  const numeric = d.columns.map(c => NUMERIC_TYPE.test(c.Type));
  const from = d.total ? (d.page - 1) * d.per + 1 : 0, to = Math.min(d.total, d.page * d.per);
  const pages = Math.max(1, Math.ceil(d.total / d.per));
  p.innerHTML = `
    <div class="toolbar">
      <button class="btn btn-primary btn-sm" id="dp-insert">${icon('plus')}Insérer une ligne</button>
      <button class="btn btn-sm" id="dp-refresh">${icon('refresh')}Actualiser</button>
      <span class="grow"></span>
      <div class="pager">
        <span>${from}–${to} sur ${d.total}</span>
        <button class="icon-btn" id="dp-prev" ${d.page <= 1 ? 'disabled' : ''} title="Page précédente" style="transform:rotate(180deg)">${icon('chevron')}</button>
        <span>page ${d.page}/${pages}</span>
        <button class="icon-btn" id="dp-next" ${d.page >= pages ? 'disabled' : ''} title="Page suivante">${icon('chevron')}</button>
        <select id="dp-per" style="width:auto;padding:4px 6px">${[25, 50, 100, 250].map(n => `<option ${n === d.per ? 'selected' : ''}>${n}</option>`).join('')}</select>
      </div>
    </div>
    ${!d.pk.length ? '<div class="muted small">Pas de clé primaire : modification et suppression ligne par ligne indisponibles (utilise l\'onglet SQL).</div>' : ''}
    ${gridHtml(cols, d.rows, {
      numeric, sortable: true, pk: d.pk,
      actions: d.pk.length ? i => `<button class="icon-btn" data-edit="${i}" title="Modifier">${icon('pencil')}</button><button class="icon-btn danger" data-del="${i}" title="Supprimer">${icon('trash')}</button>` : null,
    })}
    ${d.rows.length ? '' : '<div class="placeholder" style="margin:20px auto"><span>Table vide.</span></div>'}`;
  $('#dp-insert').onclick = () => rowModal(null);
  $('#dp-refresh').onclick = renderDataPane;
  $('#dp-prev').onclick = () => { DB.page--; renderDataPane(); };
  $('#dp-next').onclick = () => { DB.page++; renderDataPane(); };
  $('#dp-per').onchange = e => { DB.per = +e.target.value; DB.page = 1; renderDataPane(); };
  p.onclick = async e => {
    const th = e.target.closest('th[data-col]');
    if (th) { const c = th.dataset.col; DB.dir = DB.order === c && DB.dir === 'ASC' ? 'DESC' : 'ASC'; DB.order = c; renderDataPane(); return; }
    const ed = e.target.closest('[data-edit]'), del = e.target.closest('[data-del]');
    if (ed) rowModal(+ed.dataset.edit);
    if (del) {
      const where = pkWhere(+del.dataset.del);
      if (!(await confirmBox('Supprimer la ligne', `Supprimer la ligne où ${esc(Object.entries(where).map(([k, v]) => `${k} = ${v}`).join(', '))} ?`))) return;
      try { await api('db_row_delete', { body: { db: DB.name, table: DB.table, where } }); toast('Ligne supprimée'); renderDataPane(); refreshTableCounts(); } catch (err) { fail(err); }
    }
  };
}

function pkWhere(ri) {
  const d = DB.browse; const w = {};
  d.pk.forEach(k => { w[k] = d.rows[ri][d.columns.findIndex(c => c.Field === k)]; });
  return w;
}

async function refreshTableCounts() { await loadTables(); renderDbTree(); }

function rowModal(ri) {
  const d = DB.browse;
  const editing = ri !== null;
  const row = editing ? d.rows[ri] : null;
  const body = document.createElement('div');
  body.style.cssText = 'display:flex;flex-direction:column;gap:12px';
  body.innerHTML = d.columns.map((c, i) => {
    const v = row ? row[i] : null;
    const isNull = editing && v === null;
    const big = /text|blob|json/i.test(c.Type);
    const auto = /auto_increment/i.test(c.Extra);
    const ph = auto ? 'auto' : (c.Default !== null ? `défaut : ${c.Default}` : /date|time/i.test(c.Type) ? 'AAAA-MM-JJ HH:MM:SS' : '');
    const val = v === null ? '' : String(v);
    const field = big
      ? `<textarea data-f="${i}" rows="3" placeholder="${esc(ph)}">${esc(val)}</textarea>`
      : `<input data-f="${i}" value="${esc(val)}" placeholder="${esc(ph)}" spellcheck="false">`;
    return `<label>${esc(c.Field)} <span class="muted" style="font-weight:400;font-family:var(--mono)">${esc(c.Type)}${c.Key === 'PRI' ? ' · PK' : ''}</span>
      ${field}
      ${c.Null === 'YES' ? `<span style="display:flex;gap:6px;align-items:center;font-weight:400"><input type="checkbox" data-null="${i}" ${isNull ? 'checked' : ''}> NULL</span>` : ''}
    </label>`;
  }).join('');
  modal({
    title: editing ? 'Modifier la ligne' : `Insérer dans ${DB.table}`, body, wide: d.columns.length > 6,
    actions: [{ label: 'Annuler' }, {
      label: editing ? 'Enregistrer' : 'Insérer', cls: 'btn-primary', handler: async b => {
        const values = {};
        d.columns.forEach((c, i) => {
          const f = $(`[data-f="${i}"]`, b), n = $(`[data-null="${i}"]`, b);
          const nv = n?.checked ? null : f.value;
          if (editing) {
            const orig = row[i] === null ? null : String(row[i]);
            if (nv !== orig) values[c.Field] = nv;
          } else if (n?.checked || f.value !== '') values[c.Field] = nv;
        });
        if (!Object.keys(values).length) { if (editing) return true; toast('Remplis au moins un champ', true); return false; }
        await api('db_row_save', { body: { db: DB.name, table: DB.table, values, where: editing ? pkWhere(ri) : {} } });
        toast(editing ? 'Ligne modifiée' : 'Ligne insérée');
        renderDataPane(); if (!editing) refreshTableCounts();
        return true;
      },
    }],
  });
}

async function renderStructurePane() {
  const p = $('#db-pane-structure');
  p.innerHTML = '<div class="muted">Chargement…</div>';
  let d;
  try { d = await api('db_structure', { params: { db: DB.name, table: DB.table } }); }
  catch (e) { p.innerHTML = `<div class="placeholder">${esc(e.message)}</div>`; return; }
  p.innerHTML = `
    <div class="toolbar">
      <button class="btn btn-sm" id="sp-rename">${icon('pencil')}Renommer</button>
      <button class="btn btn-sm" id="sp-alter">${icon('plus')}Ajouter une colonne</button>
      <span class="grow"></span>
      <button class="btn btn-sm btn-danger" id="sp-truncate">Vider</button>
      <button class="btn btn-sm btn-danger" id="sp-drop">${icon('trash')}Supprimer la table</button>
    </div>
    <div class="section-title">Colonnes</div>
    ${gridHtml(['Champ', 'Type', 'Null', 'Clé', 'Défaut', 'Extra', 'Commentaire'], d.columns.map(c => [c.Field, c.Type, c.Null, c.Key, c.Default, c.Extra, c.Comment]))}
    <div class="section-title">Index</div>
    ${d.indexes.length ? gridHtml(['Nom', 'Colonne', 'Unique', 'Type'], d.indexes.map(i => [i.Key_name, i.Column_name, i.Non_unique == 0 ? 'oui' : 'non', i.Index_type])) : '<div class="muted small">Aucun index</div>'}
    <div class="section-title">SQL de création</div>
    <div class="code-block">${esc(d.create)}</div>`;
  const op = async (opName, extra = {}) => { await api('db_table_op', { body: { db: DB.name, table: DB.table, op: opName, ...extra } }); };
  $('#sp-rename').onclick = async () => {
    const n = await askText('Renommer la table', 'Nouveau nom', DB.table, 'Renommer'); if (!n || n === DB.table) return;
    try { await op('rename', { to: n }); DB.table = n; await refreshTableCounts(); setDbTab('structure'); } catch (e) { fail(e); }
  };
  $('#sp-alter').onclick = () => {
    if (!sqlEd) initSqlEditor();
    sqlEd.setValue(`ALTER TABLE ${qi(DB.table)}\n  ADD COLUMN \`nouvelle_colonne\` VARCHAR(255) NULL;`);
    setDbTab('sql');
  };
  $('#sp-truncate').onclick = async () => {
    if (!(await confirmBox('Vider la table', `Supprimer <b>toutes les lignes</b> de ${esc(DB.table)} ?`, 'Vider'))) return;
    try { await op('truncate'); toast('Table vidée'); refreshTableCounts(); } catch (e) { fail(e); }
  };
  $('#sp-drop').onclick = async () => {
    if (!(await confirmBox('Supprimer la table', `Supprimer définitivement la table <b>${esc(DB.table)}</b> ?`))) return;
    try { await op('drop'); toast('Table supprimée'); DB.table = null; await refreshTableCounts(); setDbTab('tables'); } catch (e) { fail(e); }
  };
}

/* ----- Constructeur de table ----- */
const COL_TYPES = ['INT', 'BIGINT', 'TINYINT', 'VARCHAR', 'CHAR', 'TEXT', 'LONGTEXT', 'DECIMAL', 'FLOAT', 'DOUBLE', 'BOOLEAN', 'DATE', 'DATETIME', 'TIMESTAMP', 'TIME', 'JSON', 'BLOB'];
function buildCreateSql(name, cols) {
  const lines = cols.filter(c => c.name).map(c => {
    let t = c.type;
    if (c.len && /^(VARCHAR|CHAR|DECIMAL|INT|BIGINT|TINYINT)$/.test(t)) t += `(${c.len})`;
    else if (t === 'VARCHAR') t = 'VARCHAR(255)';
    else if (t === 'CHAR') t = 'CHAR(1)';
    else if (t === 'DECIMAL') t = 'DECIMAL(10,2)';
    let s = `  ${qi(c.name)} ${t}${c.nullable ? ' NULL' : ' NOT NULL'}`;
    if (c.ai) s += ' AUTO_INCREMENT';
    if (c.def !== '') s += ' DEFAULT ' + (/^(CURRENT_TIMESTAMP(\(\))?|NULL|TRUE|FALSE|-?\d+(\.\d+)?)$/i.test(c.def) ? c.def : sqlStr(c.def));
    return s;
  });
  const pk = cols.filter(c => c.name && c.pk).map(c => qi(c.name));
  if (pk.length) lines.push(`  PRIMARY KEY (${pk.join(', ')})`);
  return `CREATE TABLE ${qi(name || 'ma_table')} (\n${lines.join(',\n')}\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;`;
}
function createTableModal() {
  const cols = [
    { name: 'id', type: 'INT', len: '', def: '', nullable: false, ai: true, pk: true },
    { name: 'nom', type: 'VARCHAR', len: '255', def: '', nullable: false, ai: false, pk: false },
    { name: 'cree_le', type: 'DATETIME', len: '', def: 'CURRENT_TIMESTAMP', nullable: false, ai: false, pk: false },
  ];
  const body = document.createElement('div');
  body.style.cssText = 'display:flex;flex-direction:column;gap:14px';
  const render = () => {
    body.innerHTML = `<label>Nom de la table<input data-tname value="${esc(body.dataset.tname || '')}" placeholder="utilisateurs" spellcheck="false"></label>
      <div class="cols-builder">
        <div class="col-row head"><span>Colonne</span><span>Type</span><span>Taille</span><span>Défaut</span><span>NULL</span><span>A_I</span><span>PK</span><span></span></div>
        ${cols.map((c, i) => `<div class="col-row" data-c="${i}">
          <input data-k="name" value="${esc(c.name)}" spellcheck="false">
          <select data-k="type">${COL_TYPES.map(t => `<option ${t === c.type ? 'selected' : ''}>${t}</option>`).join('')}</select>
          <input data-k="len" value="${esc(c.len)}" placeholder="—">
          <input data-k="def" value="${esc(c.def)}" placeholder="—" spellcheck="false">
          <label class="chk"><input type="checkbox" data-k="nullable" ${c.nullable ? 'checked' : ''}></label>
          <label class="chk"><input type="checkbox" data-k="ai" ${c.ai ? 'checked' : ''}></label>
          <label class="chk"><input type="checkbox" data-k="pk" ${c.pk ? 'checked' : ''}></label>
          <button class="icon-btn danger" data-rm title="Retirer">${icon('x')}</button>
        </div>`).join('')}
      </div>
      <div><button class="btn btn-sm" data-add>${icon('plus')}Ajouter une colonne</button></div>
      <div class="section-title">SQL généré</div>
      <div class="code-block" data-preview></div>`;
    preview();
  };
  const preview = () => { $('[data-preview]', body).textContent = buildCreateSql(body.dataset.tname, cols); };
  body.addEventListener('input', e => {
    if (e.target.matches('[data-tname]')) { body.dataset.tname = e.target.value; return preview(); }
    const r = e.target.closest('[data-c]'); if (!r) return;
    const c = cols[+r.dataset.c], k = e.target.dataset.k;
    c[k] = e.target.type === 'checkbox' ? e.target.checked : e.target.value;
    if (k === 'ai' && c.ai) { c.pk = true; c.type = /INT/.test(c.type) ? c.type : 'INT'; render(); return; }
    preview();
  });
  body.addEventListener('change', e => { if (e.target.tagName === 'SELECT') body.dispatchEvent(new Event('input')); });
  body.addEventListener('click', e => {
    if (e.target.closest('[data-add]')) { cols.push({ name: '', type: 'VARCHAR', len: '255', def: '', nullable: true, ai: false, pk: false }); render(); $$('[data-k=name]', body).pop().focus(); }
    const rm = e.target.closest('[data-rm]'); if (rm) { cols.splice(+rm.closest('[data-c]').dataset.c, 1); render(); }
  });
  render();
  modal({
    title: `Nouvelle table dans ${DB.name}`, body, wide: true,
    actions: [{ label: 'Annuler' }, {
      label: 'Créer la table', cls: 'btn-primary', handler: async () => {
        const name = (body.dataset.tname || '').trim();
        if (!name) { toast('Donne un nom à la table', true); return false; }
        const r = await api('db_query', { body: { db: DB.name, sql: buildCreateSql(name, cols) } });
        const err = r.results.find(x => x.error); if (err) throw new Error(err.error);
        toast(`Table « ${name} » créée`);
        DB.table = name; await refreshTableCounts(); setDbTab('structure');
        return true;
      },
    }],
  });
}

/* ----- Éditeur SQL ----- */
const SNIPPETS = {
  select: t => `SELECT *\nFROM ${qi(t || 'ma_table')}\nWHERE 1\nLIMIT 100;`,
  insert: t => `INSERT INTO ${qi(t || 'ma_table')} (colonne1, colonne2)\nVALUES ('valeur1', 'valeur2');`,
  update: t => `UPDATE ${qi(t || 'ma_table')}\nSET colonne1 = 'valeur'\nWHERE id = 1;`,
  create: () => `CREATE TABLE produits (\n  id INT AUTO_INCREMENT PRIMARY KEY,\n  nom VARCHAR(255) NOT NULL,\n  prix DECIMAL(10,2) DEFAULT 0,\n  cree_le DATETIME DEFAULT CURRENT_TIMESTAMP\n);`,
};
$('#db-pane-sql').addEventListener('click', e => {
  const s = e.target.closest('[data-snippet]'); if (!s) return;
  sqlEd.setValue(SNIPPETS[s.dataset.snippet](DB.table)); sqlEd.focus();
});
$('#sql-run').onclick = () => runSql();

async function runSql() {
  const sel = sqlEd.getSelection?.() || '';
  const sql = (sel.trim() ? sel : sqlEd.getValue()).trim();
  if (!sql) return;
  const out = $('#sql-results');
  out.innerHTML = '<div class="muted">Exécution…</div>';
  try {
    const r = await api('db_query', { body: { db: DB.name || '', sql } });
    out.innerHTML = r.results.map(x => {
      if (x.error) return `<div class="result err"><div class="result-head"><span class="q">${esc(x.sql)}</span><span>Erreur</span></div><div class="result-msg">${esc(x.error)}</div></div>`;
      const info = x.columns ? `${x.count} ligne(s)${x.truncated ? ' (1000 affichées)' : ''}` : `${x.affected} ligne(s) affectée(s)`;
      return `<div class="result"><div class="result-head"><span class="q">${esc(x.sql)}</span><span>${info} · ${x.ms} ms</span></div>
        ${x.columns ? (x.rows.length ? gridHtml(x.columns, x.rows, { numeric: x.columns.map((_, i) => x.rows.length && typeof x.rows[0][i] === 'number') }) : '<div class="result-msg muted">Aucun résultat</div>') : '<div class="result-msg" style="color:var(--ok)">✓ OK</div>'}</div>`;
    }).join('') || '<div class="muted">Aucune requête</div>';
    const changed = r.results.some(x => !x.columns && !x.error);
    if (r.db && r.db !== DB.name) { DB.name = r.db; DB.table = null; await loadTables(); renderDbTree(); setDbTab('sql'); }
    if (changed) { const keep = DB.table; await loadDbs(); DB.table = keep && DB.tables.some(t => t.name === keep) ? keep : null; renderDbTree(); }
  } catch (e) { out.innerHTML = `<div class="result err"><div class="result-msg">${esc(e.message)}</div></div>`; }
}

/* =============== Terminal =============== */
const T = state.term;

function fillCwd() {
  const sel = $('#term-cwd');
  const fill = list => {
    sel.innerHTML = `<option value="">/var/www (racine)</option>` + list.map(p => `<option value="${esc(p.name)}">${esc(p.name)}${p.type === 'react' ? '  · React' : p.type === 'php' ? '  · PHP' : ''}</option>`).join('');
    if (T.cwd && !list.some(p => p.name === T.cwd)) sel.insertAdjacentHTML('beforeend', `<option value="${esc(T.cwd)}">${esc(T.cwd)}</option>`);
    sel.value = T.cwd; updPrompt();
  };
  if (state.projects.length) fill(state.projects);
  else api('projects').then(d => { state.projects = d.projects; fill(d.projects); }).catch(() => fill([]));
}
const updPrompt = () => { $('#term-prompt').textContent = `~/www${T.cwd ? '/' + T.cwd : ''} $`; };
$('#term-cwd').onchange = e => { T.cwd = e.target.value; store.set('cwd', T.cwd); updPrompt(); $('#term-cmd').focus(); };

function runInTerminal(cwd, cmd) {
  T.cwd = cwd; store.set('cwd', cwd);
  show('terminal');
  startCommand(cmd);
}

async function startCommand(cmd) {
  cmd = cmd.trim(); if (!cmd) return;
  T.history = [cmd, ...T.history.filter(h => h !== cmd)].slice(0, 50); store.set('history', T.history); T.hIdx = -1;
  try {
    const r = await api('run', { body: { cwd: T.cwd, cmd } });
    attachJob(r.job);
    loadJobs();
  } catch (e) { fail(e); }
}

$('#term-form').addEventListener('submit', e => { e.preventDefault(); const i = $('#term-cmd'); const c = i.value; i.value = ''; startCommand(c); });
$('#term-cmd').addEventListener('keydown', e => {
  if (e.key === 'ArrowUp' && T.hIdx < T.history.length - 1) { T.hIdx++; e.target.value = T.history[T.hIdx]; e.preventDefault(); }
  if (e.key === 'ArrowDown') { T.hIdx = Math.max(-1, T.hIdx - 1); e.target.value = T.hIdx < 0 ? '' : T.history[T.hIdx]; e.preventDefault(); }
});
$('#term-quick').addEventListener('click', e => { const b = e.target.closest('[data-cmd]'); if (b) startCommand(b.dataset.cmd); });

const ANSI = /\x1b\[[0-9;?]*[ -\/]*[@-~]|\x1b\][^\x07]*\x07/g;
function termAppend(text) {
  const out = $('#term-out');
  const atBottom = out.scrollHeight - out.scrollTop - out.clientHeight < 60;
  const clean = text.replace(ANSI, '').replace(/\r(?!\n)/g, '\n').replace(/\n?__DS_EXIT__:\d+\s*$/, '');
  const html = esc(clean).replace(/https?:\/\/[^\s<>"']+/g, u => `<span class="hl-url" data-url="${u}">${u}</span>`);
  out.insertAdjacentHTML('beforeend', html);
  if (atBottom) out.scrollTop = out.scrollHeight;
}
$('#term-out').addEventListener('click', e => {
  const u = e.target.closest('.hl-url'); if (!u) return;
  let url = u.dataset.url.replace(/&amp;/g, '&');
  try { const x = new URL(url); if (['localhost', '127.0.0.1', '0.0.0.0', '[::1]'].includes(x.hostname)) { x.hostname = location.hostname; url = x.href; } } catch {}
  window.open(url, '_blank');
});

function attachJob(job) {
  clearTimeout(T.timer);
  T.job = job.id; T.offset = 0;
  const out = $('#term-out');
  out.innerHTML = `<div class="cmdline"><span class="cwd">~/www${job.cwd ? '/' + esc(job.cwd) : ''}</span> $ ${esc(job.cmd)}</div>`;
  renderJobs();
  pollJob();
}

async function pollJob() {
  const id = T.job; if (!id) return;
  try {
    const r = await api('job_poll', { params: { id, offset: T.offset } });
    if (T.job !== id) return;
    if (r.chunk) termAppend(r.chunk);
    T.offset = r.offset;
    if (r.job.running) { T.timer = setTimeout(pollJob, 700); updateJobInList(r.job); return; }
    const ok = r.job.exit === 0;
    $('#term-out').insertAdjacentHTML('beforeend', `<div class="${ok ? 'done-ok' : 'done-err'}">${ok ? '✔ Terminé' : r.job.exit === 143 ? '■ Arrêté' : `✖ Terminé avec le code ${r.job.exit}`}</div>`);
    $('#term-out').scrollTop = $('#term-out').scrollHeight;
    updateJobInList(r.job);
    state.projects = [];
    if (state.view === 'terminal') fillCwd();
  } catch (e) { fail(e); }
}

async function loadJobs() {
  try { state.jobs = (await api('jobs')).jobs; } catch { return; }
  renderJobs();
  if (!T.job && state.view === 'terminal') { const j = state.jobs.find(x => x.running) || state.jobs[0]; if (j) attachJob(j); }
}
function updateJobInList(j) {
  const i = state.jobs.findIndex(x => x.id === j.id);
  if (i >= 0) state.jobs[i] = j; else state.jobs.unshift(j);
  renderJobs();
}
function renderJobs() {
  const running = state.jobs.some(j => j.running);
  const tb = $('.rail-btn[data-view=terminal]');
  tb.querySelector('.dot')?.remove();
  if (running) tb.insertAdjacentHTML('beforeend', '<span class="dot"></span>');
  $('#jobs-list').innerHTML = state.jobs.length ? state.jobs.map(j => `
    <div class="job ${j.running ? 'run' : j.exit === 0 ? 'ok' : 'err'} ${j.id === T.job ? 'active' : ''}" data-job="${esc(j.id)}">
      <span class="jdot"></span>
      <div class="jbody"><div class="jcmd" title="${esc(j.cmd)}">${esc(j.label || j.cmd)}</div><div class="jmeta">${esc(j.cwd || 'www')} · ${fmtAgo(j.started)}${j.running ? ' · en cours' : ''}</div></div>
      ${j.running ? `<button class="icon-btn danger" data-kill="${esc(j.id)}" title="Arrêter">${icon('stop')}</button>` : ''}
    </div>`).join('') : '<div class="muted small" style="padding:10px">Aucun processus</div>';
}
$('#jobs-list').addEventListener('click', async e => {
  const k = e.target.closest('[data-kill]');
  if (k) {
    try { await api('job_kill', { body: { id: k.dataset.kill } }); toast('Processus arrêté'); loadJobs(); } catch (err) { fail(err); }
    return;
  }
  const j = e.target.closest('[data-job]');
  if (j) { const job = state.jobs.find(x => x.id === j.dataset.job); if (job) attachJob(job); }
});
$('#jobs-clear').onclick = async () => { try { await api('jobs_clear', { body: {} }); loadJobs(); } catch (e) { fail(e); } };
setInterval(() => { if (!document.hidden && (state.view === 'terminal' || state.jobs.some(j => j.running))) loadJobs(); }, 5000);

/* =============== Paramètres =============== */
async function loadSettings() {
  const i = await loadInfo();
  if (!i) return;
  const a = i.app_db;
  $('#dbinfo').innerHTML = `
    <dl class="kv">
      <dt>Hôte</dt><dd>localhost</dd><span></span>
      <dt>Utilisateur</dt><dd>${esc(a.user)}</dd><button class="icon-btn" data-copy="${esc(a.user)}" title="Copier">${icon('copy')}</button>
      <dt>Mot de passe</dt><dd data-secret="${esc(a.pass)}">••••••••</dd><span style="display:flex"><button class="icon-btn" data-reveal title="Afficher">${icon('eye')}</button><button class="icon-btn" data-copy="${esc(a.pass)}" title="Copier">${icon('copy')}</button></span>
      <dt>Base par défaut</dt><dd>${esc(a.db)}</dd><span></span>
    </dl>
    <p class="muted small">Cet utilisateur a tous les droits sur chaque base créée depuis Dev Studio. Exemple :</p>
    <div class="code-block">$pdo = new PDO(
  'mysql:host=localhost;dbname=${esc(a.db)};charset=utf8mb4',
  '${esc(a.user)}', '${esc(a.pass)}'
);</div>`;
  const s = (k, v) => `<dt>${k}</dt><dd>${esc(v)}</dd><span></span>`;
  $('#serverinfo').innerHTML = `<dl class="kv">
    ${s('Machine', i.hostname)}${s('Connecté', i.user)}${s('PHP', i.php)}${s('Node.js', i.node || '—')}${s('npm', i.npm || '—')}
    ${s('MariaDB', i.mysql || 'arrêté')}${s('Disque libre', fmtSize(i.disk_free))}${s('Dev Studio', 'v' + i.version)}
  </dl>`;
  $('#form-username [name=username]').placeholder = i.user;
}
$('#view-settings').addEventListener('click', e => {
  const c = e.target.closest('[data-copy]'); if (c) copyText(c.dataset.copy);
  const r = e.target.closest('[data-reveal]');
  if (r) { const dd = $('[data-secret]', $('#dbinfo')); dd.textContent = dd.textContent.startsWith('•') ? dd.dataset.secret : '••••••••'; }
});
function pwScore(p) {
  let s = 0;
  if (p.length >= 8) s++; if (p.length >= 12) s++; if (p.length >= 16) s++;
  if (/[a-z]/.test(p) && /[A-Z]/.test(p)) s++; if (/\d/.test(p)) s++; if (/[^A-Za-z0-9]/.test(p)) s++;
  return Math.min(5, s);
}
$('#form-password [name=new]').addEventListener('input', e => {
  const s = pwScore(e.target.value);
  const f = $('#pw-meter-fill');
  f.style.width = (s / 5 * 100) + '%';
  f.style.background = ['var(--danger)', 'var(--danger)', 'var(--warn)', 'var(--warn)', 'var(--ok)', 'var(--accent)'][s];
});
$('#form-password').addEventListener('submit', async e => {
  e.preventDefault();
  const f = new FormData(e.target);
  if (f.get('new') !== f.get('confirm')) return toast('La confirmation ne correspond pas', true);
  try {
    await api('settings_password', { body: Object.fromEntries(f) });
    toast('Mot de passe changé ✔'); e.target.reset(); $('#pw-meter-fill').style.width = '0';
  } catch (err) { fail(err); }
});
$('#form-username').addEventListener('submit', async e => {
  e.preventDefault();
  try {
    const r = await api('settings_username', { body: Object.fromEntries(new FormData(e.target)) });
    DS.user = r.user; toast(`Identifiant changé : ${r.user}`); e.target.reset(); loadSettings();
  } catch (err) { fail(err); }
});

/* =============== Démarrage =============== */
hydrateIcons();
$$('.rail-btn[data-view]').forEach(b => b.addEventListener('click', () => show(b.dataset.view)));
window.addEventListener('hashchange', () => show(location.hash.slice(1)));
renderTabs();
show(location.hash.slice(1) || 'projects');
loadJobs();
})();
