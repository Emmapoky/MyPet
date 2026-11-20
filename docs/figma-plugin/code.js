// MyPet hi-fi v2: draws coloured wireframes, palette, style choices, inspiration
// and an ML Lab board underneath whatever is already on the current page.
// Run from Figma desktop: Plugins > Development > MyPet hi-fi v2.

var STAGE = 'fonts';
(async () => {
const hex = h => { h = h.replace('#', ''); return { r: parseInt(h.slice(0, 2), 16) / 255, g: parseInt(h.slice(2, 4), 16) / 255, b: parseInt(h.slice(4, 6), 16) / 255 }; };
const P = {
  brand: '#6A4FD6', brandStrong: '#5B47C7', heroA: '#6A4FD6', heroB: '#B5488A', record: '#C9417F',
  brandC: '#EEEAFF', onBrandC: '#4A36B0',
  page1: '#F1ECFF', page2: '#FCEFF6',
  primary: '#6A4FD6', primaryC: '#EEEAFF', onPrimaryC: '#4A36B0', teal: '#4A62C9',
  sky: '#4A62C9', skyC: '#E6EAFB', onSkyC: '#2E3F8F',
  pink: '#C23F7E', pinkC: '#FDE6F0', onPinkC: '#8A2A5C',
  sun: '#FFC94D', sunC: '#FFF3CF', onSunC: '#6B4A00',
  lav: '#9C86F5', lavC: '#F1EDFF', onLavC: '#4A36B0',
  surface: '#FFFFFF', border: '#E6DEFA', ink: '#2B2340', inkSoft: '#6B6480',
  changeC: '#FFF1D6', onChangeC: '#7A4A00', changeEdge: '#F2B544',
  loggedC: '#EDE7FF', onLoggedC: '#4A36B0', loggedEdge: '#8E7CF0',
  track: '#ECE8F5', navHi: '#EEEAFF', camera: '#1B1530', white: '#FFFFFF',
  pets: ['#6A4FD6', '#C23F7E', '#4A62C9', '#8E44AD', '#2F6FA8', '#B8476A', '#A86500', '#A0527A'],
  lab: '#ECEEF0', labInk: '#2A2F36', labSoft: '#5D6670'
};
const solid = (h, o) => [{ type: 'SOLID', color: hex(h), opacity: o === undefined ? 1 : o }];
const grad = (a, b, angle) => [{ type: 'GRADIENT_LINEAR', gradientTransform: angle === 'v' ? [[0, 1, 0], [-1, 0, 1]] : [[1, 0, 0], [0, 1, 0]], gradientStops: [{ position: 0, color: Object.assign(hex(a), { a: 1 }) }, { position: 1, color: Object.assign(hex(b), { a: 1 }) }] }];

// Fonts, with fallbacks
const F = {};
async function font(key, fam, style, fbFam, fbStyle) {
  try { await figma.loadFontAsync({ family: fam, style }); F[key] = { family: fam, style }; }
  catch (e) { await figma.loadFontAsync({ family: fbFam, style: fbStyle }); F[key] = { family: fbFam, style: fbStyle }; }
}
await font('h', 'Nunito', 'Bold', 'Inter', 'Bold');
await font('hx', 'Nunito', 'ExtraBold', 'Inter', 'Extra Bold');
await font('r', 'Atkinson Hyperlegible Next', 'Regular', 'Inter', 'Regular');
await font('s', 'Atkinson Hyperlegible Next', 'SemiBold', 'Inter', 'Semi Bold');
let ICONS = true;
try { await figma.loadFontAsync({ family: 'Material Symbols Rounded', style: 'Regular' }); } catch (e) { ICONS = false; }
await figma.loadFontAsync({ family: 'Inter', style: 'Regular' });

let T = (parent, chars, size, weight, color, opts) => {
  opts = opts || {};
  const t = figma.createText();
  t.fontName = F[weight || 'r'];
  t.fontSize = size;
  t.lineHeight = { unit: 'PIXELS', value: Math.round(size * 1.35) };
  t.characters = chars;
  t.fills = solid(color || P.ink);
  if (opts.align) t.textAlignHorizontal = opts.align;
  if (parent) parent.appendChild(t);
  if (opts.w === 'fill') { t.textAutoResize = 'HEIGHT'; t.layoutSizingHorizontal = 'FILL'; }
  else if (opts.w) { t.resize(opts.w, t.height); t.textAutoResize = 'HEIGHT'; }
  if (opts.grow) t.layoutGrow = 1;
  return t;
};
let I = (parent, name, size, color) => {
  const t = figma.createText();
  if (ICONS) { t.fontName = { family: 'Material Symbols Rounded', style: 'Regular' }; t.characters = name; }
  else { t.fontName = { family: 'Inter', style: 'Regular' }; t.characters = '•'; }
  t.fontSize = size || 24; t.fills = solid(color || P.ink);
  t.name = 'icon/' + name;
  if (parent) parent.appendChild(t);
  return t;
};
let AL = (dir, o) => {
  o = o || {};
  let f;
  if (typeof figma.createAutoLayout === 'function') f = figma.createAutoLayout(dir === 'h' ? 'HORIZONTAL' : 'VERTICAL');
  else { f = figma.createFrame(); f.layoutMode = dir === 'h' ? 'HORIZONTAL' : 'VERTICAL'; f.primaryAxisSizingMode = 'AUTO'; f.counterAxisSizingMode = 'AUTO'; }
  f.fills = o.fill ? (Array.isArray(o.fill) ? o.fill : solid(o.fill)) : [];
  f.itemSpacing = o.gap === undefined ? 0 : o.gap;
  const p = o.pad === undefined ? 0 : o.pad;
  if (Array.isArray(p)) { f.paddingTop = p[0]; f.paddingRight = p[1]; f.paddingBottom = p[2]; f.paddingLeft = p[3]; }
  else { f.paddingTop = f.paddingBottom = f.paddingLeft = f.paddingRight = p; }
  if (o.r !== undefined) f.cornerRadius = o.r;
  if (o.stroke) { f.strokes = solid(o.stroke); f.strokeWeight = o.sw || 1; }
  if (o.align) f.counterAxisAlignItems = o.align;
  if (o.main) f.primaryAxisAlignItems = o.main;
  if (o.name) f.name = o.name;
  if (o.shadow) f.effects = [{ type: 'DROP_SHADOW', color: { r: 0.17, g: 0.11, b: 0.1, a: 0.08 }, offset: { x: 0, y: 4 }, radius: 14, spread: 0, visible: true, blendMode: 'NORMAL' }];
  if (o.parent) { o.parent.appendChild(f); if (o.fillW) f.layoutSizingHorizontal = 'FILL'; if (o.grow) f.layoutGrow = 1; }
  return f;
};
let box = (parent, w, h, color, r) => { const b = figma.createRectangle(); b.resize(w, h); b.fills = solid(color); if (r !== undefined) b.cornerRadius = r; if (parent) parent.appendChild(b); return b; };
let circle = (parent, size, color, iconName, iconColor, iconSize) => {
  const c = AL('h', { fill: color, r: 999, align: 'CENTER', main: 'CENTER', parent });
  c.resize(size, size); c.primaryAxisSizingMode = 'FIXED'; c.counterAxisSizingMode = 'FIXED';
  if (iconName) I(c, iconName, iconSize || Math.round(size * 0.5), iconColor || P.white);
  return c;
};
// card with optional coloured left edge
let card = (parent, o) => {
  o = o || {};
  const c = AL('v', { fill: o.fill || P.surface, r: 18, pad: o.pad === undefined ? 16 : o.pad, gap: o.gap === undefined ? 10 : o.gap, shadow: o.shadow !== false, parent, fillW: true, name: o.name || 'Card' });
  if (o.edge) { c.strokes = solid(o.edge); c.strokeLeftWeight = 4; c.strokeTopWeight = 0; c.strokeRightWeight = 0; c.strokeBottomWeight = 0; }
  return c;
};
let button = (parent, label, o) => {
  o = o || {};
  const kind = o.kind || 'filled';
  const fill = kind === 'filled' ? (o.color || P.primary) : kind === 'tonal' ? P.primaryC : P.surface;
  const fg = kind === 'filled' ? P.white : kind === 'tonal' ? P.onPrimaryC : P.primary;
  const b = AL('h', { fill, r: 999, pad: [13, 24, 13, 24], gap: 8, align: 'CENTER', main: 'CENTER', parent, name: 'Button ' + label });
  if (kind === 'outlined') { b.strokes = solid(P.border); b.strokeWeight = 1.5; }
  if (o.icon) I(b, o.icon, 22, fg);
  T(b, label, 16, 's', fg);
  if (o.fill) b.layoutSizingHorizontal = 'FILL';
  if (o.grow) b.layoutGrow = 1;
  return b;
};
let chip = (parent, label, on, o) => {
  o = o || {};
  const c = AL('h', { fill: on ? (o.onColor || P.primary) : P.surface, r: 12, pad: [12, 14, 12, 14], gap: 6, align: 'CENTER', main: 'CENTER', parent, name: 'Chip ' + label });
  if (!on) { c.strokes = solid(P.border); c.strokeWeight = 1.5; }
  if (on) I(c, 'check', 18, P.white);
  T(c, label, 16, 's', on ? P.white : P.ink);
  c.minHeight = 48;
  if (o.grow) c.layoutGrow = 1;
  return c;
};
let petChip = (parent, name, color, on) => {
  const c = AL('h', { fill: on ? color : P.surface, r: 999, pad: [10, 16, 10, 12], gap: 6, align: 'CENTER', parent, name: 'Pet ' + name });
  if (!on) { c.strokes = solid(color); c.strokeWeight = 1.5; }
  I(c, 'pets', 18, on ? P.white : color);
  T(c, name, 15, 's', on ? P.white : color);
  return c;
};

// Phone shell
const TABS = [['Today', 'grid_view'], ['Pets', 'pets'], ['Check', 'center_focus_weak'], ['Insights', 'show_chart'], ['Reminders', 'checklist']];
let phone = (name, o) => {
  o = o || {};
  const s = figma.createFrame();
  s.name = name; s.resize(390, 844); s.cornerRadius = 32; s.clipsContent = true;
  s.fills = o.dark ? solid(P.camera) : grad(P.page1, P.page2, 'v');
  s.layoutMode = 'VERTICAL'; s.primaryAxisSizingMode = 'FIXED'; s.counterAxisSizingMode = 'FIXED';
  const sb = AL('h', { pad: [14, 26, 6, 26], main: 'SPACE_BETWEEN', parent: s, fillW: true, name: 'Status bar' });
  T(sb, '9:41', 14, 's', o.dark ? P.white : P.ink);
  const si = AL('h', { gap: 4, parent: sb }); I(si, 'signal_cellular_alt', 16, o.dark ? P.white : P.ink); I(si, 'battery_full', 16, o.dark ? P.white : P.ink);
  if (o.title) {
    const tb = AL('h', { pad: [6, 16, 6, 16], gap: 10, align: 'CENTER', parent: s, fillW: true, name: 'Top bar' });
    if (o.back) I(tb, 'arrow_back', 26, P.ink);
    if (o.logo) { const l = circle(tb, 32, P.brand, 'pets', P.white, 18); l.cornerRadius = 10; }
    T(tb, o.title, 26, 'h', P.ink, { grow: true });
    I(tb, 'more_vert', 24, P.inkSoft);
  }
  const body = AL('v', { gap: 14, pad: [6, 16, 16, 16], parent: s, fillW: true, grow: true, name: 'Body' });
  if (o.tab) {
    const wrap = AL('h', { pad: [6, 12, 20, 12], parent: s, fillW: true, name: 'Tab bar' });
    const bar = AL('h', { fill: P.surface, r: 28, pad: [8, 6, 8, 6], main: 'SPACE_BETWEEN', shadow: true, parent: wrap, fillW: true });
    for (const [label, ic] of TABS) {
      const on = label === o.tab;
      const t = AL('v', { gap: 2, align: 'CENTER', parent: bar, name: 'Tab ' + label }); t.minWidth = 64; t.minHeight = 52;
      const pill = AL('h', { fill: on ? P.navHi : undefined, r: 999, pad: [4, 14, 4, 14], parent: t }); I(pill, ic, 24, on ? P.brandStrong : P.ink);
      T(t, label, 12, 's', on ? P.brandStrong : P.ink);
    }
  }
  return { s, body };
};


// step tracking, so an error says where it happened
const wrapFn = (name, fn) => function () { try { return fn.apply(null, arguments); } catch (e) { throw new Error(name + ' > ' + (e && e.message ? e.message : e)); } };
T = wrapFn('T', T); I = wrapFn('I', I); AL = wrapFn('AL', AL); box = wrapFn('box', box); circle = wrapFn('circle', circle);
card = wrapFn('card', card); button = wrapFn('button', button); chip = wrapFn('chip', chip); petChip = wrapFn('petChip', petChip); phone = wrapFn('phone', phone);
// ---------- placement ----------
STAGE = 'placement';
const page = figma.currentPage;
let minX = 0, maxY = 0;
if (page.children.length) {
  minX = Math.min.apply(null, page.children.map(n => n.x));
  maxY = Math.max.apply(null, page.children.map(n => n.y + n.height));
}
const old = page.findOne(n => n.name === 'MyPet hi-fi v2' && n.parent === page);
if (old) { maxY = old.y - 400; old.remove(); }
const root = AL('v', { gap: 120, pad: 120, fill: '#FBFAFE', name: 'MyPet hi-fi v2', r: 40 });
page.appendChild(root);
root.x = minX; root.y = maxY + 400;

// Title
STAGE = 'Title';
const head = AL('h', { gap: 28, align: 'CENTER', parent: root });
const logo = circle(head, 120, P.brand, 'pets', P.white, 68); logo.cornerRadius = 34; logo.fills = grad(P.heroA, P.heroB); logo.name = 'Logo';
const ht = AL('v', { gap: 6, parent: head });
T(ht, 'MyPet · Hi-fi', 64, 'hx', P.ink);
T(ht, 'Coloured wireframes built on the agreed low-fi set above (Figure 4.5)', 24, 'r', P.inkSoft);

// ---------- Brand boards ----------
STAGE = 'Brand boards';
const boards = AL('h', { gap: 40, parent: root, name: 'Brand' });
const board = (title, w) => { const b = AL('v', { fill: P.surface, r: 28, pad: 40, gap: 24, parent: boards, shadow: true, name: title }); b.resize(w, 100); b.primaryAxisSizingMode = 'AUTO'; T(b, title, 30, 'hx', P.ink); return b; };

// Palette
STAGE = 'Palette';
const pal = board('Palette', 760);
const swRow = (title, list) => {
  T(pal, title, 16, 's', P.inkSoft);
  const r = AL('h', { gap: 14, parent: pal });
  for (const [n, h, fg] of list) {
    const c = AL('v', { gap: 8, parent: r });
    const sw = AL('v', { fill: h, r: 18, pad: 12, main: 'MAX', parent: c }); sw.resize(160, 96); sw.primaryAxisSizingMode = 'FIXED'; sw.counterAxisSizingMode = 'FIXED';
    if (h === P.surface) { sw.strokes = solid(P.border); sw.strokeWeight = 1; }
    T(sw, 'Aa', 20, 'hx', fg || P.white);
    T(c, n, 14, 's', P.ink); T(c, h, 13, 'r', P.inkSoft);
  }
};
swRow('Brand', [['Violet (actions)', P.brand], ['Berry', P.pink], ['Periwinkle', P.sky], ['Sun', P.sun, P.ink]]);
swRow('Accents and status', [['Lavender', P.lav, P.ink], ['Change (watch, not alarm)', P.changeC, P.onChangeC], ['Logged', P.loggedC, P.onLoggedC], ['Card', P.surface, P.ink]]);
T(pal, 'Pet colours', 16, 's', P.inkSoft);
const pr = AL('h', { gap: 12, parent: pal }); for (const c of P.pets) circle(pr, 48, c, 'pets', P.white, 24);
T(pal, 'Hero and page', 16, 's', P.inkSoft);
const gr = AL('h', { gap: 14, parent: pal });
const g1 = box(gr, 330, 80, P.brand, 18); g1.fills = grad(P.heroA, P.heroB);
const g2 = box(gr, 330, 80, P.brand, 18); g2.fills = grad(P.page1, P.page2); g2.strokes = solid(P.border); g2.strokeWeight = 1;

// Type and shape
STAGE = 'Type and shape';
const ty = board('Type and shape', 560);
const tyRow = (sample, spec, size, w) => { const r = AL('v', { gap: 2, parent: ty }); T(r, sample, size, w); T(r, spec, 13, 'r', P.inkSoft); };
tyRow('98%', 'Numbers · Nunito ExtraBold 40', 40, 'hx');
tyRow('Good evening', 'Headings · Nunito Bold 26 (rounded, friendly)', 26, 'h');
tyRow('Biscuit is logged', 'Body · Atkinson Hyperlegible Next 16 (made for low vision)', 16, 'r');
tyRow('Log now', 'Buttons · Atkinson SemiBold 16', 16, 's');
const sh = AL('h', { gap: 16, align: 'MAX', parent: ty });
for (const [lbl, r, w, h] of [['Cards 18', 18, 110, 80], ['Hero 24', 24, 110, 80], ['Chips 12', 12, 80, 48], ['Buttons pill', 999, 120, 48]]) { const c = AL('v', { gap: 6, parent: sh }); const b = box(c, w, h, P.brandC, r); b.strokes = solid(P.brand); b.strokeWeight = 1.5; T(c, lbl, 13, 'r', P.inkSoft); }
T(ty, 'Every tap target 48 px or more · text 4.5:1 or better', 14, 's', P.primary);

// Style choices
STAGE = 'Style choices';
const st = board('Style choices', 560);
const bullet = (parent, ic, color, title, sub) => { const r = AL('h', { gap: 14, align: 'MIN', parent }); circle(r, 40, color, ic, P.white, 22); const c = AL('v', { gap: 2, parent: r }); T(c, title, 17, 's', P.ink); if (sub) T(c, sub, 14, 'r', P.inkSoft, { w: 420 }); };
bullet(st, 'wb_sunny', P.brand, 'Violet to pink hero', 'Greets you by time of day');
bullet(st, 'pets', P.pets[0], 'A colour per pet', 'Left edge and chip in the pet colour');
bullet(st, 'touch_app', P.primary, 'Big, few taps', 'Log in 3 taps, 48 px targets');
bullet(st, 'short_text', P.lav, 'Fewer words', 'One line per card, details on tap');
bullet(st, 'visibility', P.sun, 'Watch, not alarm', 'Amber for changes, never red');
bullet(st, 'videocam', P.record, 'Full-screen camera', 'Pick the pet at the bottom, 5 to 10 s clip');

// Inspiration
STAGE = 'Inspiration';
const ins = board('Inspiration', 760);
const INSPIRATION = [
  ['Old MyPet app', 'Greeting hero, stat tiles, colour edge per pet', P.lavC],
  ['Pitch slides', 'Violet, pink, sky blue and sun', P.pinkC],
  ['Petnoter', 'Calm, warm words · one profile per pet', P.skyC],
  ['Tractive', 'Compare with the pet\'s own normal · few tabs', P.sunC],
  ['PetDesk', 'Care as a simple checklist', P.loggedC],
  ['Traini', 'Camera as the main action, no "translator" claims', P.brandC],
  ['Snapchat', 'Full-screen camera, choices at the bottom', P.pinkC],
  ['My Pet, 11pets', 'What to avoid: long feature menus', P.changeC]
];
for (const [app, took, color] of INSPIRATION) {
  const r = AL('h', { gap: 14, align: 'CENTER', parent: ins });
  const tag = AL('h', { fill: color || P.brandC, r: 12, pad: [8, 14, 8, 14], parent: r }); tag.resize(200, 40); tag.primaryAxisSizingMode = 'FIXED';
  T(tag, app, 15, 's', P.ink);
  T(r, took, 15, 'r', P.inkSoft, { w: 460 });
}

// ---------- Screens ----------
STAGE = 'Screens';
const scrTitle = (parent, t) => T(parent, t, 36, 'hx', P.ink);
const flowRow = (title) => { const w = AL('v', { gap: 28, parent: root, name: title }); scrTitle(w, title); const r = AL('h', { gap: 48, align: 'MIN', parent: w }); return r; };
const labelled = (row, label, scr) => { const c = AL('v', { gap: 14, parent: row, name: label }); T(c, label, 20, 'h', P.inkSoft); c.appendChild(scr); return c; };
const S = {};

// shared bits
const hero = (body) => {
  const h = AL('v', { fill: grad(P.heroA, P.heroB), r: 24, pad: 18, gap: 14, parent: body, fillW: true, shadow: true, name: 'Hero' });
  const top = AL('h', { parent: h, fillW: true, align: 'CENTER' });
  const tt = AL('v', { gap: 2, parent: top, grow: true }); T(tt, 'Good evening', 24, 'hx', P.white); T(tt, 'Thursday 19 November', 14, 's', P.white);
  circle(top, 52, P.white, 'pets', P.brand, 28);
  const st = AL('h', { gap: 10, parent: h, fillW: true });
  for (const [v, l] of [['2/2', 'logged'], ['2/3', 'done'], ['1', 'to look at']]) { const t = AL('v', { fill: P.white, r: 14, pad: 10, align: 'CENTER', parent: st, grow: true }); t.fills = solid(P.white, 0.18); T(t, v, 22, 'hx', P.white); T(t, l, 13, 's', P.white); }
  return h;
};
const pets = (body, active) => { const r = AL('h', { gap: 8, align: 'CENTER', parent: body }); petChip(r, 'Mochi', P.pets[1], active === 'Mochi'); petChip(r, 'Biscuit', P.pets[0], active === 'Biscuit'); I(r, 'add', 26, P.inkSoft); return r; };
const flag = (body, short, ttl, line) => {
  const c = card(body, { fill: P.changeC, edge: P.changeEdge, shadow: false, name: 'Change noticed', gap: 6 });
  const h = AL('h', { gap: 8, align: 'CENTER', parent: c }); I(h, 'trending_down', 22, P.onChangeC); T(h, ttl || 'Change noticed', 18, 'h', P.onChangeC);
  T(c, line || 'Energy lower than usual', 16, 'r', P.ink, { w: 'fill' });
  T(c, short ? 'Not a diagnosis · tap for details' : '2 of the last 3 days · usual 3 of 5', 13, 's', P.onChangeC, { w: 'fill' });
  return c;
};
const row = (parent, ic, icColor, label, right, rightColor) => { const r = AL('h', { gap: 12, align: 'CENTER', pad: [10, 0, 10, 0], parent, fillW: true }); I(r, ic, 24, icColor); T(r, label, 16, 's', P.ink, { grow: true }); if (right) T(r, right, 13, 's', rightColor || P.inkSoft); r.minHeight = 48; return r; };

// 1 Reminder
STAGE = '1 Reminder';
{
  const s = figma.createFrame(); s.name = '1 Reminder'; s.resize(390, 844); s.cornerRadius = 32; s.clipsContent = true;
  s.fills = grad(P.heroA, '#2B2340', 'v'); s.layoutMode = 'VERTICAL'; s.counterAxisAlignItems = 'CENTER'; s.primaryAxisSizingMode = 'FIXED'; s.counterAxisSizingMode = 'FIXED';
  s.paddingTop = 110; s.paddingLeft = s.paddingRight = 16; s.itemSpacing = 6;
  const tm = T(s, '9:41', 80, 'hx', P.white); T(s, 'Thursday 19 November', 16, 's', P.white);
  const sp = AL('v', { parent: s }); sp.resize(10, 260);
  const n = AL('v', { fill: P.surface, r: 26, pad: 16, gap: 12, parent: s, fillW: true, shadow: true, name: 'Notification' });
  const nh = AL('h', { gap: 8, align: 'CENTER', parent: n }); const lm = circle(nh, 22, P.brand, 'pets', P.white, 14); lm.cornerRadius = 6; T(nh, 'MyPet · now', 13, 'r', P.inkSoft);
  T(n, 'Log Biscuit\'s day?', 18, 'h', P.ink);
  const na = AL('h', { gap: 8, parent: n }); S.notifLog = button(na, 'Log now'); button(na, 'Later', { kind: 'tonal' });
  const miss = AL('h', { fill: P.sunC, r: 999, pad: [8, 14, 8, 14], gap: 6, align: 'CENTER', parent: s }); I(miss, 'event_busy', 18, P.onSunC); T(miss, 'Tuesday not logged', 14, 's', P.onSunC);
  S.reminder = s;
}
// 2 Today
STAGE = '2 Today';
{
  const { s, body } = phone('2 Today', { title: 'MyPet', logo: true, tab: 'Today' });
  hero(body); pets(body, 'Biscuit');
  const c = card(body, { edge: P.pets[0], gap: 0, name: "Biscuit's day" });
  T(c, "Biscuit's day", 18, 'h', P.ink);
  row(c, 'radio_button_unchecked', P.inkSoft, 'Daily log', 'by 9 pm');
  row(c, 'check_circle', P.loggedEdge, 'Breakfast', '8:05 am', P.onLoggedC);
  row(c, 'error', P.changeEdge, 'Breakfast', 'Missed Tue', P.onChangeC);
  S.logNow = button(body, 'Log now', { icon: 'edit_note', fill: true, color: P.brandStrong });
  S.today = s;
}
// 3 Quick log
STAGE = '3 Quick log';
{
  const { s, body } = phone('3 Quick log', { title: 'Log for Biscuit', back: true });
  const tg = AL('h', { fill: P.primaryC, r: 14, pad: [12, 16, 12, 16], gap: 10, align: 'CENTER', parent: body, fillW: true });
  I(tg, 'history', 22, P.onPrimaryC); T(tg, 'Same as last entry', 16, 's', P.onPrimaryC, { grow: true });
  const sw = AL('h', { fill: P.primary, r: 999, pad: 4, main: 'MAX', parent: tg }); sw.resize(52, 32); sw.primaryAxisSizingMode = 'FIXED'; sw.counterAxisSizingMode = 'FIXED'; circle(sw, 24, P.white);
  const q = (n, label, opts, on, sub) => {
    const w = AL('v', { gap: 8, parent: body, fillW: true });
    const h = AL('h', { gap: 8, align: 'CENTER', parent: w }); circle(h, 24, P.ink); h.children[0].appendChild(T(null, String(n), 13, 's', P.white)); T(h, label, 17, 'h', P.ink); if (sub) T(h, sub, 13, 'r', P.inkSoft);
    const r = AL('h', { gap: 8, parent: w, fillW: true });
    opts.forEach(o => chip(r, o, o === on, { grow: true }));
  };
  const vc = card(body, { gap: 4, name: 'Voice card' }); const vr = AL('h', { gap: 12, align: 'CENTER', parent: vc, fillW: true });
  circle(vr, 48, P.brand, 'mic', P.white, 26).fills = grad(P.heroA, P.heroB);
  const vt = AL('v', { gap: 2, parent: vr, grow: true }); T(vt, "Tell us about Biscuit's day", 16, 'h', P.ink); T(vt, 'For example: "ate well, a bit tired"', 13, 'r', P.inkSoft, { w: 250 });
  q(1, 'Ate today', ['All', 'Some', 'None'], 'All');
  q(2, 'Energy', ['1', '2', '3', '4', '5'], '3', 'Usual for Biscuit: 4');
  q(3, 'Toilet normal', ['Yes', 'No', "Didn't see"], 'Yes');
  const nf = AL('h', { fill: P.surface, r: 14, pad: [4, 4, 4, 16], gap: 8, align: 'CENTER', parent: body, fillW: true }); nf.strokes = solid(P.border); nf.strokeWeight = 1.5;
  T(nf, 'Add a note', 16, 'r', P.inkSoft, { grow: true }); circle(nf, 48, P.lavC, 'mic', P.onLavC, 24);
  const sp = AL('v', { parent: body, grow: true });
  S.save = button(body, 'Save', { fill: true });
  S.quick = s;
}
// 4 Check (full-screen camera, pet picked at the bottom)
STAGE = '4 Check';
{
  const { s, body } = phone('4 Check', { dark: true });
  body.paddingTop = 8; body.paddingBottom = 28; body.itemSpacing = 12;
  s.fills = [{ type: 'GRADIENT_LINEAR', gradientTransform: [[0, 1, 0], [-1, 0, 1]], gradientStops: [{ position: 0, color: Object.assign(hex('#3B3360'), { a: 1 }) }, { position: 1, color: Object.assign(hex(P.camera), { a: 1 }) }] }];
  const top = AL('h', { align: 'CENTER', main: 'SPACE_BETWEEN', parent: body, fillW: true });
  const x = circle(top, 44, '#000000', 'close', P.white, 24); x.fills = solid('#000000', 0.3);
  const who = AL('h', { r: 999, pad: [8, 14, 8, 10], gap: 6, align: 'CENTER', parent: top }); who.fills = solid('#000000', 0.3); circle(who, 24, P.pets[0], 'pets', P.white, 14); T(who, 'Biscuit', 15, 's', P.white);
  const fl = circle(top, 44, '#000000', 'video_library', P.white, 24); fl.fills = solid('#000000', 0.3); fl.name = 'Choose a video';
  const vf = AL('v', { parent: body, grow: true, fillW: true, align: 'CENTER', main: 'CENTER', name: 'Viewfinder' }); I(vf, 'crop_free', 200, P.white); vf.children[0].opacity = 0.5;
  const pv = AL('h', { r: 999, pad: [6, 12, 6, 12], gap: 6, align: 'CENTER', parent: body }); pv.fills = solid('#000000', 0.3); I(pv, 'lock', 14, P.white); T(pv, 'Deleted after the check', 13, 's', P.white);
  const strip = AL('h', { gap: 14, align: 'CENTER', main: 'CENTER', parent: body, fillW: true, name: 'Pet picker' });
  const bub = c => { const o = circle(strip, 52, c, 'pets', P.white, 24); o.opacity = 0.9; return o; };
  bub(P.pets[1]); bub(P.pets[2]);
  const recWrap = AL('h', { r: 999, pad: 5, parent: strip }); recWrap.strokes = solid(P.white); recWrap.strokeWeight = 5;
  S.rec = circle(recWrap, 76, P.record, 'pets', P.white, 34); S.rec.name = 'Record'; S.rec.fills = grad(P.heroA, P.heroB);
  bub(P.pets[3]); bub(P.pets[4]);
  const lbl = AL('h', { gap: 18, align: 'CENTER', main: 'CENTER', parent: body, fillW: true });
  const up = AL('v', { gap: 2, align: 'CENTER', parent: lbl }); I(up, 'flip_camera_ios', 24, P.white); T(up, 'Flip', 12, 's', P.white);
  T(lbl, 'Hold for 5–10 s', 14, 's', P.white);
  const nm = AL('v', { gap: 2, align: 'CENTER', parent: lbl }); I(nm, 'swipe', 24, P.white); T(nm, 'Swipe pets', 12, 's', P.white);
  S.check = s;
}
// 5 Result
STAGE = '5 Result';
const resultBase = (name, kind) => {
  const { s, body } = phone(name, { title: 'Result', back: true });
  if (kind === 'main') {
    // clip with detected moments
    const v = AL('v', { fill: P.camera, r: 18, pad: 10, gap: 8, parent: body, fillW: true, name: 'Clip player' });
    const scr = AL('h', { fill: '#3B3360', r: 12, align: 'CENTER', main: 'CENTER', parent: v, fillW: true }); scr.resize(338, 150); scr.counterAxisSizingMode = 'FIXED';
    circle(scr, 52, '#000000', 'play_arrow', P.white, 30).fills = solid('#000000', 0.4);
    const tl = figma.createFrame(); tl.name = 'Timeline'; tl.fills = []; v.appendChild(tl); tl.resize(338, 22); tl.layoutSizingHorizontal = 'FILL';
    const base = box(tl, 338, 6, '#FFFFFF', 999); base.opacity = 0.25; base.y = 8;
    const marks = [[0.18, 0.12, P.pink], [0.45, 0.2, P.sky], [0.74, 0.1, P.pink]];
    for (const [x0, w, c] of marks) { const m = box(tl, Math.round(338 * w), 14, c, 999); m.x = Math.round(338 * x0); m.y = 4; }
    const tt = AL('h', { main: 'SPACE_BETWEEN', parent: v, fillW: true }); T(tt, '0:00', 12, 's', P.white); T(tt, '0:08', 12, 's', P.white);
    const mm = AL('h', { gap: 8, parent: body, fillW: true, name: 'Moments' });
    for (const [t, lbl, ic, c] of [['0:01', 'Whimper', 'graphic_eq', P.pink], ['0:03', 'Tail low', 'visibility', P.sky], ['0:06', 'Whimper', 'graphic_eq', P.pink]]) {
      const ch = AL('h', { fill: c, r: 999, pad: [8, 12, 8, 8], gap: 4, align: 'CENTER', parent: mm, name: 'Moment ' + t });
      I(ch, 'play_circle', 20, P.white); I(ch, ic, 16, P.white); T(ch, t + ' ' + lbl, 13, 's', P.white);
    }
    const c = card(body, { gap: 6, edge: P.pets[0] });
    T(c, 'Most likely', 14, 's', P.inkSoft);
    const r = AL('h', { align: 'CENTER', parent: c, fillW: true }); T(r, 'Happy or playful', 22, 'h', P.ink, { grow: true }); T(r, '72%', 40, 'hx', P.primary);
    const tr = AL('h', { fill: P.track, r: 999, parent: c, fillW: true }); tr.resize(326, 10); tr.counterAxisSizingMode = 'FIXED'; box(tr, 235, 10, P.primary, 999);
    const o = AL('h', { gap: 12, parent: c, fillW: true });
    for (const [e, p] of [['Calm', 14], ['Uneasy', 9], ['Upset', 5]]) T(o, e + ' ' + p + '%', 13, 's', P.inkSoft);
  } else if (kind === 'unsure') {
    const c = card(body, { gap: 6 });
    const h = AL('h', { gap: 8, align: 'CENTER', parent: c }); I(h, 'help', 26, P.lav); T(h, 'Not sure', 22, 'h', P.ink);
    T(c, 'Nothing stood out this time', 15, 'r', P.inkSoft);
    const o = card(body, { gap: 10 });
    for (const [e, p] of [['Calm', 38], ['Happy or playful', 31], ['Sad or uneasy', 19], ['Upset', 12]]) { const r2 = AL('v', { gap: 4, parent: o, fillW: true }); const t = AL('h', { parent: r2, fillW: true }); T(t, e, 15, 'r', P.ink, { grow: true }); T(t, p + '%', 15, 's', P.inkSoft); const tr = AL('h', { fill: P.track, r: 999, parent: r2, fillW: true }); tr.resize(326, 8); tr.counterAxisSizingMode = 'FIXED'; box(tr, Math.round(326 * p / 100), 8, P.lav, 999); }
  } else if (kind === 'notheard') {
    const c = card(body, { gap: 10 });
    circle(c, 56, P.sunC, 'hearing', P.onSunC, 30);
    T(c, 'Didn\'t clearly hear Biscuit', 22, 'h', P.ink, { w: 'fill' });
    T(c, 'Heard: people talking', 15, 'r', P.inkSoft);
    const tip = AL('h', { fill: P.primaryC, r: 14, pad: 12, gap: 8, align: 'CENTER', parent: body, fillW: true }); I(tip, 'tips_and_updates', 20, P.onPrimaryC); T(tip, 'Try closer, somewhere quieter', 15, 's', P.onPrimaryC);
  }
  const sh = card(body, { gap: 8 }); if (kind === 'main') sh.visible = false; T(sh, 'Heard', 16, 'h', P.ink); const ch = AL('h', { gap: 8, parent: sh });
  for (const x of (kind === 'notheard' ? ['Speech', 'TV'] : ['Barking', 'Panting'])) { const t = AL('h', { fill: P.page1, r: 10, pad: [6, 10, 6, 10], gap: 4, align: 'CENTER', parent: ch }); I(t, 'graphic_eq', 16, P.inkSoft); T(t, x, 14, 's', P.ink); }
  const note = AL('h', { fill: P.lavC, r: 14, pad: 12, gap: 8, align: 'CENTER', parent: body, fillW: true }); I(note, 'info', 18, P.onLavC); T(note, 'Not a medical diagnosis', 14, 's', P.onLavC);
  const sp = AL('v', { parent: body, grow: true });
  const bt = AL('h', { gap: 12, parent: body, fillW: true });
  const a = button(bt, kind === 'notheard' ? 'Try again' : 'Retake', { kind: 'outlined', icon: 'replay', grow: true });
  const b = kind === 'notheard' ? null : button(bt, 'Save', { icon: 'check', grow: true });
  return { s, retake: a, save: b };
};
const R1 = resultBase('5 Result', 'main'); S.result = R1.s;
// 6 Insights
STAGE = '6 Insights';
{
  const { s, body } = phone('6 Insights', { title: 'Insights', tab: 'Insights' });
  const seg = AL('h', { fill: P.track, r: 999, pad: 4, parent: body, fillW: true });
  for (const [t, on] of [['7 days', true], ['30 days', false]]) { const c = AL('h', { fill: on ? P.surface : undefined, r: 999, pad: [10, 0, 10, 0], main: 'CENTER', parent: seg, grow: true }); T(c, t, 15, 's', on ? P.ink : P.inkSoft); }
  flag(body, false);
  const c = card(body, { gap: 10, edge: P.pets[0] }); T(c, 'Energy', 18, 'h', P.ink);
  const ch = figma.createFrame(); ch.name = 'Chart'; ch.fills = []; c.appendChild(ch); ch.resize(326, 130); ch.layoutSizingHorizontal = 'FILL';
  const band = box(ch, 326, 26, P.primaryC, 6); band.y = 28;
  const vals = [3, 3, 4, 3, 1, 1, 3]; const days = ['F', 'S', 'S', 'M', 'T', 'W', 'T'];
  vals.forEach((v, i) => { const h = v * 22; const b = box(ch, 30, h, v <= 1 ? P.changeEdge : P.pets[0], 8); b.x = 10 + i * 45; b.y = 108 - h; const d = T(null, days[i], 13, 's', P.inkSoft); ch.appendChild(d); d.x = 20 + i * 45; d.y = 110; });
  const sp = AL('v', { parent: body, grow: true });
  button(body, 'Export for the vet', { kind: 'tonal', icon: 'picture_as_pdf', fill: true });
  S.insights = s;
}
const row1 = flowRow('Key screens (from Figure 4.5)');
labelled(row1, '1 Reminder', S.reminder); labelled(row1, '2 Today', S.today); labelled(row1, '3 Quick log', S.quick);
labelled(row1, '4 Check', S.check); labelled(row1, '5 Result', S.result); labelled(row1, '6 Insights', S.insights);

// Extra states
STAGE = 'Extra states';
{
  const { s, body } = phone('Today, logged', { title: 'MyPet', logo: true, tab: 'Today' });
  hero(body); pets(body, 'Biscuit');
  S.flagCard = flag(body, true);
  const ok = AL('h', { fill: P.loggedC, r: 14, pad: [12, 16, 12, 16], gap: 8, align: 'CENTER', parent: body, fillW: true }); I(ok, 'check_circle', 22, P.onLoggedC); T(ok, 'Biscuit is logged', 16, 's', P.onLoggedC);
  S.today2 = s;
}
{
  const { s, body } = phone('Pets', { title: 'Pets', tab: 'Pets' });
  for (const [n, sub, c, ic] of [['Mochi', 'Cat', P.pets[1], 'check_circle'], ['Biscuit', 'Dog', P.pets[0], 'check_circle'], ['Kopi', 'Cat', P.pets[2], 'radio_button_unchecked']]) {
    const k = card(body, { edge: c, gap: 0 }); const r = AL('h', { gap: 14, align: 'CENTER', parent: k, fillW: true });
    circle(r, 64, c, 'photo_camera', P.white, 28); const t = AL('v', { gap: 2, parent: r, grow: true }); T(t, n, 20, 'h', P.ink); T(t, sub, 14, 'r', P.inkSoft);
    I(r, ic, 26, ic === 'check_circle' ? P.loggedEdge : P.inkSoft);
  }
  const sp = AL('v', { parent: body, grow: true });
  button(body, 'Add a pet', { icon: 'add', fill: true, color: P.brandStrong });
  S.pets = s;
}
{
  const { s, body } = phone('Insights, first week', { title: 'Insights', tab: 'Insights' });
  const st2 = card(body, { gap: 6, name: 'Getting to know' }); const sh2 = AL('h', { gap: 8, align: 'CENTER', parent: st2 }); I(sh2, 'pets', 22, P.brand); T(sh2, 'Getting to know Biscuit', 18, 'h', P.ink);
  T(st2, 'Adult dog · daily kcal range', 15, 'r', P.ink, { w: 'fill' }); T(st2, 'Source: AAHA, PNA', 12, 'r', P.inkSoft);
  const c = card(body, { gap: 12, pad: 24 }); c.counterAxisAlignItems = 'CENTER';
  circle(c, 80, P.sunC, 'hourglass_top', P.onSunC, 40);
  T(c, 'Unlocks after 7 days', 20, 'h', P.ink, { align: 'CENTER' });
  T(c, '4 of 7 days logged', 15, 'r', P.inkSoft);
  const tr = AL('h', { fill: P.track, r: 999, parent: c, fillW: true }); tr.resize(300, 10); tr.counterAxisSizingMode = 'FIXED'; box(tr, 171, 10, P.sun, 999);
  S.early = s;
}
const R2 = resultBase('Result, not sure', 'unsure');
const R3 = resultBase('Result, didn\'t hear', 'notheard');
const row2 = flowRow('More states');
labelled(row2, 'Today, logged', S.today2); labelled(row2, 'Pets', S.pets); labelled(row2, 'Insights, first week', S.early);
labelled(row2, 'Result, not sure', R2.s); labelled(row2, 'Result, didn\'t hear', R3.s);

const AVATARS = {"cat-1-ginger": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 200 200\" xmlns:c2pa=\"http://c2pa.org/manifest\"><path d=\"M42 92 L50 30 L88 62Z\" fill=\"#F2A65A\"/><path d=\"M158 92 L150 30 L112 62Z\" fill=\"#F2A65A\"/><path d=\"M54 74 L58 46 L78 64Z\" fill=\"#F7C7D6\"/><path d=\"M146 74 L142 46 L122 64Z\" fill=\"#F7C7D6\"/><ellipse cx=\"100\" cy=\"112\" rx=\"66\" ry=\"58\" fill=\"#F2A65A\"/><path d=\"M86 58 Q90 72 86 84\" stroke=\"#D9822E\" stroke-width=\"6\" fill=\"none\" stroke-linecap=\"round\"/><path d=\"M100 58 Q104 72 100 84\" stroke=\"#D9822E\" stroke-width=\"6\" fill=\"none\" stroke-linecap=\"round\"/><path d=\"M114 58 Q118 72 114 84\" stroke=\"#D9822E\" stroke-width=\"6\" fill=\"none\" stroke-linecap=\"round\"/><ellipse cx=\"100\" cy=\"138\" rx=\"30\" ry=\"22\" fill=\"#FFF8F2\"/><circle cx=\"74\" cy=\"106\" r=\"7\" fill=\"#2B2340\"/><circle cx=\"126\" cy=\"106\" r=\"7\" fill=\"#2B2340\"/><circle cx=\"76.5\" cy=\"103.5\" r=\"2.2\" fill=\"#fff\"/><circle cx=\"128.5\" cy=\"103.5\" r=\"2.2\" fill=\"#fff\"/><ellipse cx=\"62\" cy=\"124\" rx=\"9\" ry=\"5\" fill=\"#F2A6C8\" opacity=\"0.7\"/><ellipse cx=\"138\" cy=\"124\" rx=\"9\" ry=\"5\" fill=\"#F2A6C8\" opacity=\"0.7\"/><path d=\"M92 128 Q100 123 108 128 Q100 137 92 128Z\" fill=\"#2B2340\"/><path d=\"M100 133 V140 M100 140 Q92 147 85 141 M100 140 Q108 147 115 141\" stroke=\"#2B2340\" stroke-width=\"3\" fill=\"none\" stroke-linecap=\"round\"/><path d=\"M60 132 L30 126\" stroke=\"#2B2340\" stroke-width=\"2\" stroke-linecap=\"round\" opacity=\"0.5\"/><path d=\"M60 140 L30 144\" stroke=\"#2B2340\" stroke-width=\"2\" stroke-linecap=\"round\" opacity=\"0.5\"/><path d=\"M140 132 L170 126\" stroke=\"#2B2340\" stroke-width=\"2\" stroke-linecap=\"round\" opacity=\"0.5\"/><path d=\"M140 140 L170 144\" stroke=\"#2B2340\" stroke-width=\"2\" stroke-linecap=\"round\" opacity=\"0.5\"/><metadata><c2pa:manifest>AAAWgmp1bWIAAAAeanVtZGMycGEAEQAQgAAAqgA4m3EDYzJwYQAAABZcanVtYgAAAEdqdW1kYzJtYQARABCAAACqADibcQN1cm46YzJwYTo1NzQzZjM4Ny0yN2U0LTQ4MGEtYjU0Ni1lNmYxNGJmZjYzYTEAAAADl2p1bWIAAAApanVtZGMyYXMAEQAQgAAAqgA4m3EDYzJwYS5hc3NlcnRpb25zAAAAALxqdW1iAAAARGp1bWRjYm9yABEAEIAAAKoAOJtxE2MycGEuaW5ncmVkaWVudC52MwAAAAAYYzJzaFznc5jvg8cPfWvHT2XnN3cAAABwY2JvcqNpZGM6Zm9ybWF0bWltYWdlL3N2Zyt4bWxqaW5zdGFuY2VJRHgseG1wOmlpZDowYWM3ZjM1MS1mMTM0LTRkNGItYjk4YS1jYjE1YzU3Y2FjZmRscmVsYXRpb25zaGlwaHBhcmVudE9mAAAB4mp1bWIAAABBanVtZGNib3IAEQAQgAAAqgA4m3ETYzJwYS5hY3Rpb25zLnYyAAAAABhjMnNoFvGSFBE0RdiNWk5bHyDDrgAAAZljYm9yomdhY3Rpb25zgqJmYWN0aW9ua2MycGEub3BlbmVkanBhcmFtZXRlcnOha2luZ3JlZGllbnRzgaJjdXJseC1zZWxmI2p1bWJmPWMycGEuYXNzZXJ0aW9ucy9jMnBhLmluZ3JlZGllbnQudjNkaGFzaFgg77rXDI2Scl2+jaxXOm+MMF1C3SXn38HgOQYM/pYReAOkZmFjdGlvbngdY29tLmFudGhyb3BpYy5jbGF1ZGUucHJvdmlkZWRqcGFyYW1ldGVyc6F4H2NvbS5hbnRocm9waWMub3JpZ2luLWNvbmZpZGVuY2VndW5rbm93bmtkZXNjcmlwdGlvbnhmQ2xhdWRlIHByb3ZpZGVkIHRoaXMgZmlsZSBhdCB0aGUgcmVxdWVzdCBvZiBhIHVzZXIgYW5kIG1heSBoYXZlIGNyZWF0ZWQgb3IgbW9kaWZpZWQgdGhlIGZpbGUgY29udGVudHMubXNvZnR3YXJlQWdlbnShZG5hbWVmQ2xhdWRlcmFsbEFjdGlvbnNJbmNsdWRlZPUAAADIanVtYgAAAEBqdW1kY2JvcgARABCAAACqADibcRNjMnBhLmhhc2guZGF0YQAAAAAYYzJzaJWSAoh/EKQ51OFK2x13yUkAAACAY2JvcqVjYWxnZnNoYTI1NmNwYWRMAAAAAAAAAAAAAAAAZGhhc2hYIAoZVMTtO0RJY7hOkNEshWFLOA86i5nLWZ5P6pB2nHd7ZG5hbWVuanVtYmYgbWFuaWZlc3RqZXhjbHVzaW9uc4GiZXN0YXJ0GQacZmxlbmd0aBkeBAAAAj5qdW1iAAAAJ2p1bWRjMmNsABEAEIAAAKoAOJtxA2MycGEuY2xhaW0udjIAAAACD2Nib3KlY2FsZ2ZzaGEyNTZpc2lnbmF0dXJleE1zZWxmI2p1bWJmPS9jMnBhL3VybjpjMnBhOjU3NDNmMzg3LTI3ZTQtNDgwYS1iNTQ2LWU2ZjE0YmZmNjNhMS9jMnBhLnNpZ25hdHVyZWppbnN0YW5jZUlEeCx4bXA6aWlkOmI3NDcyYzNmLWZkOGQtNGE2YS1hMDUyLWY0ODNkZjg4YzA2NXJjcmVhdGVkX2Fzc2VydGlvbnODomN1cmx4LXNlbGYjanVtYmY9YzJwYS5hc3NlcnRpb25zL2MycGEuaW5ncmVkaWVudC52M2RoYXNoWCDvutcMjZJyXb6NrFc6b4wwXULdJeffweA5Bgz+lhF4A6JjdXJseCpzZWxmI2p1bWJmPWMycGEuYXNzZXJ0aW9ucy9jMnBhLmFjdGlvbnMudjJkaGFzaFggnZZzdSDrAVwhGY6UB8+pJLO5TmP2Ts7+tAFXFw4f5quiY3VybHgpc2VsZiNqdW1iZj1jMnBhLmFzc2VydGlvbnMvYzJwYS5oYXNoLmRhdGFkaGFzaFggz5vsCVJ1MkL7q2DHoy7zgRxkSA3JpvLXkfMrGJTWqop0Y2xhaW1fZ2VuZXJhdG9yX2luZm+jZG5hbWVvQW50aHJvcGljIEZpbGVzZ3ZlcnNpb25lMS4wLjBrc3BlY1ZlcnNpb25lMi40LjAAABA4anVtYgAAAChqdW1kYzJjcwARABCAAACqADibcQNjMnBhLnNpZ25hdHVyZQAAABAIY2JvctKEWQISogEmGCFZAgowggIGMIIBjaADAgECAhRA5aAK7sI50L64g/oGQgU9Z1UTADAKBggqhkjOPQQDAzBJMRcwFQYDVQQKEw5BbnRocm9waWMsIFBCQzEuMCwGA1UEAxMlQW50aHJvcGljIENvbnRlbnQgQ3JlZGVudGlhbHMgUm9vdCBDQTAeFw0yNjA4MDcxODQzNTZaFw0yODA4MDYxOTQzNTZaMEQxFzAVBgNVBAoTDkFudGhyb3BpYywgUEJDMSkwJwYDVQQDEyBBbnRocm9waWMgQ2xhdWRlIENvbnRlbnQgU2lnbmluZzBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABJh6CmvLUBgFFNU0vUKlOVtE6djd17L5SuwX0LemFisBM3dkd/3cyjxFA3Qo5S46fX0/ihY0VZ7mfb9KF703t5OjWDBWMA4GA1UdDwEB/wQEAwIHgDAVBgNVHSUEDjAMBgorBgEEAYPoXgIBMAwGA1UdEwEB/wQCMAAwHwYDVR0jBBgwFoAUzlHiBIFOZFsj+OPEz5o+nMHXXMIwCgYIKoZIzj0EAwMDZwAwZAIwMXMdFJ4BetLLVY7ORuE9noqbbAZOZn/aArXyTwFAZfKrPzxF2vPoJNf1+UCdg1XGAjBwX1zd9WGqYkqmL5SFqw1QySjr1zJfpJM9+1rdDwSPLMOPOjKuiXjoU/pUUeG9RwmhY3BhZFkNngAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPZYQKT1OwG/D2VnJwnV00Y7D5znxrBT7b5t29i9EQZBtTjOWAnfxQ6sKoZ/sgY/+1Ush2y1FHw4+ahzu0i/AY48ePQ=</c2pa:manifest></metadata></svg>", "cat-2-grey": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 200 200\" xmlns:c2pa=\"http://c2pa.org/manifest\"><path d=\"M42 92 L50 30 L88 62Z\" fill=\"#A7A3B8\"/><path d=\"M158 92 L150 30 L112 62Z\" fill=\"#A7A3B8\"/><path d=\"M54 74 L58 46 L78 64Z\" fill=\"#F7C7D6\"/><path d=\"M146 74 L142 46 L122 64Z\" fill=\"#F7C7D6\"/><ellipse cx=\"100\" cy=\"112\" rx=\"66\" ry=\"58\" fill=\"#A7A3B8\"/><ellipse cx=\"100\" cy=\"138\" rx=\"30\" ry=\"22\" fill=\"#FFF8F2\"/><circle cx=\"74\" cy=\"106\" r=\"7\" fill=\"#2B2340\"/><circle cx=\"126\" cy=\"106\" r=\"7\" fill=\"#2B2340\"/><circle cx=\"76.5\" cy=\"103.5\" r=\"2.2\" fill=\"#fff\"/><circle cx=\"128.5\" cy=\"103.5\" r=\"2.2\" fill=\"#fff\"/><ellipse cx=\"62\" cy=\"124\" rx=\"9\" ry=\"5\" fill=\"#F2A6C8\" opacity=\"0.7\"/><ellipse cx=\"138\" cy=\"124\" rx=\"9\" ry=\"5\" fill=\"#F2A6C8\" opacity=\"0.7\"/><path d=\"M92 128 Q100 123 108 128 Q100 137 92 128Z\" fill=\"#2B2340\"/><path d=\"M100 133 V140 M100 140 Q92 147 85 141 M100 140 Q108 147 115 141\" stroke=\"#2B2340\" stroke-width=\"3\" fill=\"none\" stroke-linecap=\"round\"/><path d=\"M60 132 L30 126\" stroke=\"#2B2340\" stroke-width=\"2\" stroke-linecap=\"round\" opacity=\"0.5\"/><path d=\"M60 140 L30 144\" stroke=\"#2B2340\" stroke-width=\"2\" stroke-linecap=\"round\" opacity=\"0.5\"/><path d=\"M140 132 L170 126\" stroke=\"#2B2340\" stroke-width=\"2\" stroke-linecap=\"round\" opacity=\"0.5\"/><path d=\"M140 140 L170 144\" stroke=\"#2B2340\" stroke-width=\"2\" stroke-linecap=\"round\" opacity=\"0.5\"/><metadata><c2pa:manifest>AAAWgmp1bWIAAAAeanVtZGMycGEAEQAQgAAAqgA4m3EDYzJwYQAAABZcanVtYgAAAEdqdW1kYzJtYQARABCAAACqADibcQN1cm46YzJwYTo4ZDc4NTZjOS02OGIyLTQ4MDAtYWM2ZS04MTJmYmQxMTdlYmUAAAADl2p1bWIAAAApanVtZGMyYXMAEQAQgAAAqgA4m3EDYzJwYS5hc3NlcnRpb25zAAAAALxqdW1iAAAARGp1bWRjYm9yABEAEIAAAKoAOJtxE2MycGEuaW5ncmVkaWVudC52MwAAAAAYYzJzaOY8dAioKbuovPD0zwurCj8AAABwY2JvcqNpZGM6Zm9ybWF0bWltYWdlL3N2Zyt4bWxqaW5zdGFuY2VJRHgseG1wOmlpZDoyZjA4NjNhYy04MWQ5LTRlYTItYWIyYS1kYWYzMDc4Mzk1NGNscmVsYXRpb25zaGlwaHBhcmVudE9mAAAB4mp1bWIAAABBanVtZGNib3IAEQAQgAAAqgA4m3ETYzJwYS5hY3Rpb25zLnYyAAAAABhjMnNo+ugZ/BJIdSkLbiTalJfvHAAAAZljYm9yomdhY3Rpb25zgqJmYWN0aW9ua2MycGEub3BlbmVkanBhcmFtZXRlcnOha2luZ3JlZGllbnRzgaJjdXJseC1zZWxmI2p1bWJmPWMycGEuYXNzZXJ0aW9ucy9jMnBhLmluZ3JlZGllbnQudjNkaGFzaFgg0fVu2FkS6mc5vfOT33rUo62hX6DCZO1+lmxvWzcSy0GkZmFjdGlvbngdY29tLmFudGhyb3BpYy5jbGF1ZGUucHJvdmlkZWRqcGFyYW1ldGVyc6F4H2NvbS5hbnRocm9waWMub3JpZ2luLWNvbmZpZGVuY2VndW5rbm93bmtkZXNjcmlwdGlvbnhmQ2xhdWRlIHByb3ZpZGVkIHRoaXMgZmlsZSBhdCB0aGUgcmVxdWVzdCBvZiBhIHVzZXIgYW5kIG1heSBoYXZlIGNyZWF0ZWQgb3IgbW9kaWZpZWQgdGhlIGZpbGUgY29udGVudHMubXNvZnR3YXJlQWdlbnShZG5hbWVmQ2xhdWRlcmFsbEFjdGlvbnNJbmNsdWRlZPUAAADIanVtYgAAAEBqdW1kY2JvcgARABCAAACqADibcRNjMnBhLmhhc2guZGF0YQAAAAAYYzJzaHq4118hFr1D3FdP+yo77fQAAACAY2JvcqVjYWxnZnNoYTI1NmNwYWRMAAAAAAAAAAAAAAAAZGhhc2hYIJSuMtu0sHeFIQ/bJ7rrly21P6d9+fhZ+t+OUPoIHw6WZG5hbWVuanVtYmYgbWFuaWZlc3RqZXhjbHVzaW9uc4GiZXN0YXJ0GQVqZmxlbmd0aBkeBAAAAj5qdW1iAAAAJ2p1bWRjMmNsABEAEIAAAKoAOJtxA2MycGEuY2xhaW0udjIAAAACD2Nib3KlY2FsZ2ZzaGEyNTZpc2lnbmF0dXJleE1zZWxmI2p1bWJmPS9jMnBhL3VybjpjMnBhOjhkNzg1NmM5LTY4YjItNDgwMC1hYzZlLTgxMmZiZDExN2ViZS9jMnBhLnNpZ25hdHVyZWppbnN0YW5jZUlEeCx4bXA6aWlkOjA5NDg2YWJhLWI0MmMtNDVlMS1iNjYxLWY2NWYyZjJlNTg2NXJjcmVhdGVkX2Fzc2VydGlvbnODomN1cmx4LXNlbGYjanVtYmY9YzJwYS5hc3NlcnRpb25zL2MycGEuaW5ncmVkaWVudC52M2RoYXNoWCDR9W7YWRLqZzm985PfetSjraFfoMJk7X6WbG9bNxLLQaJjdXJseCpzZWxmI2p1bWJmPWMycGEuYXNzZXJ0aW9ucy9jMnBhLmFjdGlvbnMudjJkaGFzaFggBcHPrp9pUZ+lfjAF8Jq5NZEzId4HDBEBT5c5fUzMOs2iY3VybHgpc2VsZiNqdW1iZj1jMnBhLmFzc2VydGlvbnMvYzJwYS5oYXNoLmRhdGFkaGFzaFggDG1nMReuPy6I78s1/0Cp4nDSFIlwh/pnCpo54j76UhB0Y2xhaW1fZ2VuZXJhdG9yX2luZm+jZG5hbWVvQW50aHJvcGljIEZpbGVzZ3ZlcnNpb25lMS4wLjBrc3BlY1ZlcnNpb25lMi40LjAAABA4anVtYgAAAChqdW1kYzJjcwARABCAAACqADibcQNjMnBhLnNpZ25hdHVyZQAAABAIY2JvctKEWQISogEmGCFZAgowggIGMIIBjaADAgECAhRA5aAK7sI50L64g/oGQgU9Z1UTADAKBggqhkjOPQQDAzBJMRcwFQYDVQQKEw5BbnRocm9waWMsIFBCQzEuMCwGA1UEAxMlQW50aHJvcGljIENvbnRlbnQgQ3JlZGVudGlhbHMgUm9vdCBDQTAeFw0yNjA4MDcxODQzNTZaFw0yODA4MDYxOTQzNTZaMEQxFzAVBgNVBAoTDkFudGhyb3BpYywgUEJDMSkwJwYDVQQDEyBBbnRocm9waWMgQ2xhdWRlIENvbnRlbnQgU2lnbmluZzBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABJh6CmvLUBgFFNU0vUKlOVtE6djd17L5SuwX0LemFisBM3dkd/3cyjxFA3Qo5S46fX0/ihY0VZ7mfb9KF703t5OjWDBWMA4GA1UdDwEB/wQEAwIHgDAVBgNVHSUEDjAMBgorBgEEAYPoXgIBMAwGA1UdEwEB/wQCMAAwHwYDVR0jBBgwFoAUzlHiBIFOZFsj+OPEz5o+nMHXXMIwCgYIKoZIzj0EAwMDZwAwZAIwMXMdFJ4BetLLVY7ORuE9noqbbAZOZn/aArXyTwFAZfKrPzxF2vPoJNf1+UCdg1XGAjBwX1zd9WGqYkqmL5SFqw1QySjr1zJfpJM9+1rdDwSPLMOPOjKuiXjoU/pUUeG9RwmhY3BhZFkNngAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPZYQB9z2M/2hq7MzUglXHb4QIfChPQ5JJ4fJ56l5irq7vqYdMsplFfj2cmrIrgGtdr1/d0wNuIk+fXXiTaQUAFWnNE=</c2pa:manifest></metadata></svg>", "cat-3-tuxedo": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 200 200\" xmlns:c2pa=\"http://c2pa.org/manifest\"><path d=\"M42 92 L50 30 L88 62Z\" fill=\"#3E3650\"/><path d=\"M158 92 L150 30 L112 62Z\" fill=\"#3E3650\"/><path d=\"M54 74 L58 46 L78 64Z\" fill=\"#F7C7D6\"/><path d=\"M146 74 L142 46 L122 64Z\" fill=\"#F7C7D6\"/><ellipse cx=\"100\" cy=\"112\" rx=\"66\" ry=\"58\" fill=\"#3E3650\"/><ellipse cx=\"100\" cy=\"138\" rx=\"30\" ry=\"22\" fill=\"#FFF8F2\"/><circle cx=\"74\" cy=\"106\" r=\"7\" fill=\"#2B2340\"/><circle cx=\"126\" cy=\"106\" r=\"7\" fill=\"#2B2340\"/><circle cx=\"76.5\" cy=\"103.5\" r=\"2.2\" fill=\"#fff\"/><circle cx=\"128.5\" cy=\"103.5\" r=\"2.2\" fill=\"#fff\"/><ellipse cx=\"62\" cy=\"124\" rx=\"9\" ry=\"5\" fill=\"#F2A6C8\" opacity=\"0.7\"/><ellipse cx=\"138\" cy=\"124\" rx=\"9\" ry=\"5\" fill=\"#F2A6C8\" opacity=\"0.7\"/><path d=\"M92 128 Q100 123 108 128 Q100 137 92 128Z\" fill=\"#2B2340\"/><path d=\"M100 133 V140 M100 140 Q92 147 85 141 M100 140 Q108 147 115 141\" stroke=\"#2B2340\" stroke-width=\"3\" fill=\"none\" stroke-linecap=\"round\"/><path d=\"M60 132 L30 126\" stroke=\"#2B2340\" stroke-width=\"2\" stroke-linecap=\"round\" opacity=\"0.5\"/><path d=\"M60 140 L30 144\" stroke=\"#2B2340\" stroke-width=\"2\" stroke-linecap=\"round\" opacity=\"0.5\"/><path d=\"M140 132 L170 126\" stroke=\"#2B2340\" stroke-width=\"2\" stroke-linecap=\"round\" opacity=\"0.5\"/><path d=\"M140 140 L170 144\" stroke=\"#2B2340\" stroke-width=\"2\" stroke-linecap=\"round\" opacity=\"0.5\"/><metadata><c2pa:manifest>AAAWgmp1bWIAAAAeanVtZGMycGEAEQAQgAAAqgA4m3EDYzJwYQAAABZcanVtYgAAAEdqdW1kYzJtYQARABCAAACqADibcQN1cm46YzJwYTpiNjQyY2RjOC0yNWExLTRiYTEtYmVhMS1lNWE0ZmM3ZGY1ZDIAAAADl2p1bWIAAAApanVtZGMyYXMAEQAQgAAAqgA4m3EDYzJwYS5hc3NlcnRpb25zAAAAALxqdW1iAAAARGp1bWRjYm9yABEAEIAAAKoAOJtxE2MycGEuaW5ncmVkaWVudC52MwAAAAAYYzJzaNOy1D8U4H0xnPbyyyjFj9oAAABwY2JvcqNpZGM6Zm9ybWF0bWltYWdlL3N2Zyt4bWxqaW5zdGFuY2VJRHgseG1wOmlpZDpjZjk1NmJiNC02MDZiLTRiZjItYWNkOS1hM2I4YTUyNGU1NWFscmVsYXRpb25zaGlwaHBhcmVudE9mAAAB4mp1bWIAAABBanVtZGNib3IAEQAQgAAAqgA4m3ETYzJwYS5hY3Rpb25zLnYyAAAAABhjMnNooQ+cgmgh1VrDmD907sxthQAAAZljYm9yomdhY3Rpb25zgqJmYWN0aW9ua2MycGEub3BlbmVkanBhcmFtZXRlcnOha2luZ3JlZGllbnRzgaJjdXJseC1zZWxmI2p1bWJmPWMycGEuYXNzZXJ0aW9ucy9jMnBhLmluZ3JlZGllbnQudjNkaGFzaFggjcAAaIH4avgkzn1SWspabIicu8MsNzg+DRdN1L2IUWqkZmFjdGlvbngdY29tLmFudGhyb3BpYy5jbGF1ZGUucHJvdmlkZWRqcGFyYW1ldGVyc6F4H2NvbS5hbnRocm9waWMub3JpZ2luLWNvbmZpZGVuY2VndW5rbm93bmtkZXNjcmlwdGlvbnhmQ2xhdWRlIHByb3ZpZGVkIHRoaXMgZmlsZSBhdCB0aGUgcmVxdWVzdCBvZiBhIHVzZXIgYW5kIG1heSBoYXZlIGNyZWF0ZWQgb3IgbW9kaWZpZWQgdGhlIGZpbGUgY29udGVudHMubXNvZnR3YXJlQWdlbnShZG5hbWVmQ2xhdWRlcmFsbEFjdGlvbnNJbmNsdWRlZPUAAADIanVtYgAAAEBqdW1kY2JvcgARABCAAACqADibcRNjMnBhLmhhc2guZGF0YQAAAAAYYzJzaAnFEKliY5q3cqr12xHpGQwAAACAY2JvcqVjYWxnZnNoYTI1NmNwYWRMAAAAAAAAAAAAAAAAZGhhc2hYIFlHds5+U3fQRV6zy3+db70Ghfj+G0wmqJRbD3+3xT2WZG5hbWVuanVtYmYgbWFuaWZlc3RqZXhjbHVzaW9uc4GiZXN0YXJ0GQVqZmxlbmd0aBkeBAAAAj5qdW1iAAAAJ2p1bWRjMmNsABEAEIAAAKoAOJtxA2MycGEuY2xhaW0udjIAAAACD2Nib3KlY2FsZ2ZzaGEyNTZpc2lnbmF0dXJleE1zZWxmI2p1bWJmPS9jMnBhL3VybjpjMnBhOmI2NDJjZGM4LTI1YTEtNGJhMS1iZWExLWU1YTRmYzdkZjVkMi9jMnBhLnNpZ25hdHVyZWppbnN0YW5jZUlEeCx4bXA6aWlkOjIzZTU3MmEyLTcyMjktNDE2ZC1hM2NiLTJlNTFiNjI2ZjUwNXJjcmVhdGVkX2Fzc2VydGlvbnODomN1cmx4LXNlbGYjanVtYmY9YzJwYS5hc3NlcnRpb25zL2MycGEuaW5ncmVkaWVudC52M2RoYXNoWCCNwABogfhq+CTOfVJaylpsiJy7wyw3OD4NF03UvYhRaqJjdXJseCpzZWxmI2p1bWJmPWMycGEuYXNzZXJ0aW9ucy9jMnBhLmFjdGlvbnMudjJkaGFzaFggjvmk9vEzDPNk9PKYJTVYI1qrBZLY8J5jhT5IcF8ftGeiY3VybHgpc2VsZiNqdW1iZj1jMnBhLmFzc2VydGlvbnMvYzJwYS5oYXNoLmRhdGFkaGFzaFggJmX4kwQlxCNId1ueQALzEFQqa6aNhu9uaBITrWG6Jal0Y2xhaW1fZ2VuZXJhdG9yX2luZm+jZG5hbWVvQW50aHJvcGljIEZpbGVzZ3ZlcnNpb25lMS4wLjBrc3BlY1ZlcnNpb25lMi40LjAAABA4anVtYgAAAChqdW1kYzJjcwARABCAAACqADibcQNjMnBhLnNpZ25hdHVyZQAAABAIY2JvctKEWQISogEmGCFZAgowggIGMIIBjaADAgECAhRA5aAK7sI50L64g/oGQgU9Z1UTADAKBggqhkjOPQQDAzBJMRcwFQYDVQQKEw5BbnRocm9waWMsIFBCQzEuMCwGA1UEAxMlQW50aHJvcGljIENvbnRlbnQgQ3JlZGVudGlhbHMgUm9vdCBDQTAeFw0yNjA4MDcxODQzNTZaFw0yODA4MDYxOTQzNTZaMEQxFzAVBgNVBAoTDkFudGhyb3BpYywgUEJDMSkwJwYDVQQDEyBBbnRocm9waWMgQ2xhdWRlIENvbnRlbnQgU2lnbmluZzBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABJh6CmvLUBgFFNU0vUKlOVtE6djd17L5SuwX0LemFisBM3dkd/3cyjxFA3Qo5S46fX0/ihY0VZ7mfb9KF703t5OjWDBWMA4GA1UdDwEB/wQEAwIHgDAVBgNVHSUEDjAMBgorBgEEAYPoXgIBMAwGA1UdEwEB/wQCMAAwHwYDVR0jBBgwFoAUzlHiBIFOZFsj+OPEz5o+nMHXXMIwCgYIKoZIzj0EAwMDZwAwZAIwMXMdFJ4BetLLVY7ORuE9noqbbAZOZn/aArXyTwFAZfKrPzxF2vPoJNf1+UCdg1XGAjBwX1zd9WGqYkqmL5SFqw1QySjr1zJfpJM9+1rdDwSPLMOPOjKuiXjoU/pUUeG9RwmhY3BhZFkNngAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPZYQD+mN/qHt8hFhGojANM8TdMy+LWDdjzOM3mzLimFq8fO4YCgmpm2vfpirXR94TinlGkJXw4ZzqDh//w21f0jVhs=</c2pa:manifest></metadata></svg>", "dog-1-golden": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 200 200\" xmlns:c2pa=\"http://c2pa.org/manifest\"><ellipse cx=\"100\" cy=\"110\" rx=\"62\" ry=\"60\" fill=\"#E8B86A\"/><path d=\"M48 70 Q20 80 30 140 Q46 150 62 120Z\" fill=\"#C98E3E\"/><path d=\"M152 70 Q180 80 170 140 Q154 150 138 120Z\" fill=\"#C98E3E\"/><ellipse cx=\"100\" cy=\"138\" rx=\"34\" ry=\"26\" fill=\"#FFF8F2\"/><circle cx=\"74\" cy=\"104\" r=\"7\" fill=\"#2B2340\"/><circle cx=\"126\" cy=\"104\" r=\"7\" fill=\"#2B2340\"/><circle cx=\"76.5\" cy=\"101.5\" r=\"2.2\" fill=\"#fff\"/><circle cx=\"128.5\" cy=\"101.5\" r=\"2.2\" fill=\"#fff\"/><ellipse cx=\"62\" cy=\"122\" rx=\"9\" ry=\"5\" fill=\"#F2A6C8\" opacity=\"0.7\"/><ellipse cx=\"138\" cy=\"122\" rx=\"9\" ry=\"5\" fill=\"#F2A6C8\" opacity=\"0.7\"/><path d=\"M92 126 Q100 121 108 126 Q100 135 92 126Z\" fill=\"#2B2340\"/><path d=\"M93 142 Q100 158 107 142Z\" fill=\"#F27BAA\"/><path d=\"M100 131 V138 M100 138 Q92 145 85 139 M100 138 Q108 145 115 139\" stroke=\"#2B2340\" stroke-width=\"3\" fill=\"none\" stroke-linecap=\"round\"/><metadata><c2pa:manifest>AAAWgmp1bWIAAAAeanVtZGMycGEAEQAQgAAAqgA4m3EDYzJwYQAAABZcanVtYgAAAEdqdW1kYzJtYQARABCAAACqADibcQN1cm46YzJwYToxMTI4Y2I2OS03MGZmLTQ2ODItYjI3OS1lNTgwN2MzNTAyYTkAAAADl2p1bWIAAAApanVtZGMyYXMAEQAQgAAAqgA4m3EDYzJwYS5hc3NlcnRpb25zAAAAALxqdW1iAAAARGp1bWRjYm9yABEAEIAAAKoAOJtxE2MycGEuaW5ncmVkaWVudC52MwAAAAAYYzJzaKEAf/hagU63aJoL/9zFtyAAAABwY2JvcqNpZGM6Zm9ybWF0bWltYWdlL3N2Zyt4bWxqaW5zdGFuY2VJRHgseG1wOmlpZDo1NDQzYjhiNi00ZGU3LTQ0MGYtOGJhZC1kMWI1YmFiZmYyZDFscmVsYXRpb25zaGlwaHBhcmVudE9mAAAB4mp1bWIAAABBanVtZGNib3IAEQAQgAAAqgA4m3ETYzJwYS5hY3Rpb25zLnYyAAAAABhjMnNoNUQz75to/0YqMTFcA/iTtgAAAZljYm9yomdhY3Rpb25zgqJmYWN0aW9ua2MycGEub3BlbmVkanBhcmFtZXRlcnOha2luZ3JlZGllbnRzgaJjdXJseC1zZWxmI2p1bWJmPWMycGEuYXNzZXJ0aW9ucy9jMnBhLmluZ3JlZGllbnQudjNkaGFzaFgg+9+aGrxKTETKqz0/sBXZMcrcdW44AXvfUQEfo4g/OhCkZmFjdGlvbngdY29tLmFudGhyb3BpYy5jbGF1ZGUucHJvdmlkZWRqcGFyYW1ldGVyc6F4H2NvbS5hbnRocm9waWMub3JpZ2luLWNvbmZpZGVuY2VndW5rbm93bmtkZXNjcmlwdGlvbnhmQ2xhdWRlIHByb3ZpZGVkIHRoaXMgZmlsZSBhdCB0aGUgcmVxdWVzdCBvZiBhIHVzZXIgYW5kIG1heSBoYXZlIGNyZWF0ZWQgb3IgbW9kaWZpZWQgdGhlIGZpbGUgY29udGVudHMubXNvZnR3YXJlQWdlbnShZG5hbWVmQ2xhdWRlcmFsbEFjdGlvbnNJbmNsdWRlZPUAAADIanVtYgAAAEBqdW1kY2JvcgARABCAAACqADibcRNjMnBhLmhhc2guZGF0YQAAAAAYYzJzaL5mfcYA8IKv4G2zeni1vAcAAACAY2JvcqVjYWxnZnNoYTI1NmNwYWRMAAAAAAAAAAAAAAAAZGhhc2hYIIMtW3+eLWE72AEAWGoowRR0nk+bJq/JIm4d5cibCh9nZG5hbWVuanVtYmYgbWFuaWZlc3RqZXhjbHVzaW9uc4GiZXN0YXJ0GQPPZmxlbmd0aBkeBAAAAj5qdW1iAAAAJ2p1bWRjMmNsABEAEIAAAKoAOJtxA2MycGEuY2xhaW0udjIAAAACD2Nib3KlY2FsZ2ZzaGEyNTZpc2lnbmF0dXJleE1zZWxmI2p1bWJmPS9jMnBhL3VybjpjMnBhOjExMjhjYjY5LTcwZmYtNDY4Mi1iMjc5LWU1ODA3YzM1MDJhOS9jMnBhLnNpZ25hdHVyZWppbnN0YW5jZUlEeCx4bXA6aWlkOmNkOGY4NGRmLTQ2YTgtNDFiYS04ZGFmLTEyYjYzMmM0YmE3OHJjcmVhdGVkX2Fzc2VydGlvbnODomN1cmx4LXNlbGYjanVtYmY9YzJwYS5hc3NlcnRpb25zL2MycGEuaW5ncmVkaWVudC52M2RoYXNoWCD735oavEpMRMqrPT+wFdkxytx1bjgBe99RAR+jiD86EKJjdXJseCpzZWxmI2p1bWJmPWMycGEuYXNzZXJ0aW9ucy9jMnBhLmFjdGlvbnMudjJkaGFzaFggLOG4Tu86aS9D5OLDxidYUN9LAXjYph1cXV54F+TmlUiiY3VybHgpc2VsZiNqdW1iZj1jMnBhLmFzc2VydGlvbnMvYzJwYS5oYXNoLmRhdGFkaGFzaFggeKpi1xwFEhs/Vc8xQjVy6pFRHvS69OWUM72hprC7upl0Y2xhaW1fZ2VuZXJhdG9yX2luZm+jZG5hbWVvQW50aHJvcGljIEZpbGVzZ3ZlcnNpb25lMS4wLjBrc3BlY1ZlcnNpb25lMi40LjAAABA4anVtYgAAAChqdW1kYzJjcwARABCAAACqADibcQNjMnBhLnNpZ25hdHVyZQAAABAIY2JvctKEWQISogEmGCFZAgowggIGMIIBjaADAgECAhRA5aAK7sI50L64g/oGQgU9Z1UTADAKBggqhkjOPQQDAzBJMRcwFQYDVQQKEw5BbnRocm9waWMsIFBCQzEuMCwGA1UEAxMlQW50aHJvcGljIENvbnRlbnQgQ3JlZGVudGlhbHMgUm9vdCBDQTAeFw0yNjA4MDcxODQzNTZaFw0yODA4MDYxOTQzNTZaMEQxFzAVBgNVBAoTDkFudGhyb3BpYywgUEJDMSkwJwYDVQQDEyBBbnRocm9waWMgQ2xhdWRlIENvbnRlbnQgU2lnbmluZzBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABJh6CmvLUBgFFNU0vUKlOVtE6djd17L5SuwX0LemFisBM3dkd/3cyjxFA3Qo5S46fX0/ihY0VZ7mfb9KF703t5OjWDBWMA4GA1UdDwEB/wQEAwIHgDAVBgNVHSUEDjAMBgorBgEEAYPoXgIBMAwGA1UdEwEB/wQCMAAwHwYDVR0jBBgwFoAUzlHiBIFOZFsj+OPEz5o+nMHXXMIwCgYIKoZIzj0EAwMDZwAwZAIwMXMdFJ4BetLLVY7ORuE9noqbbAZOZn/aArXyTwFAZfKrPzxF2vPoJNf1+UCdg1XGAjBwX1zd9WGqYkqmL5SFqw1QySjr1zJfpJM9+1rdDwSPLMOPOjKuiXjoU/pUUeG9RwmhY3BhZFkNngAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPZYQCwYbCJ2PDjxHkbvxGNWWo/5MxBEsVwC11XosSZrmqOXQIrus2ezDHIrRcy+ev3oG4rQca4M53ThADGbn2VqgVI=</c2pa:manifest></metadata></svg>", "dog-2-spotted": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 200 200\" xmlns:c2pa=\"http://c2pa.org/manifest\"><ellipse cx=\"100\" cy=\"110\" rx=\"62\" ry=\"60\" fill=\"#FFFFFF\"/><path d=\"M48 70 Q20 80 30 140 Q46 150 62 120Z\" fill=\"#5B4A3A\"/><path d=\"M152 70 Q180 80 170 140 Q154 150 138 120Z\" fill=\"#5B4A3A\"/><ellipse cx=\"72\" cy=\"96\" rx=\"22\" ry=\"20\" fill=\"#5B4A3A\"/><ellipse cx=\"100\" cy=\"138\" rx=\"34\" ry=\"26\" fill=\"#F3EEE8\"/><circle cx=\"74\" cy=\"104\" r=\"7\" fill=\"#2B2340\"/><circle cx=\"126\" cy=\"104\" r=\"7\" fill=\"#2B2340\"/><circle cx=\"76.5\" cy=\"101.5\" r=\"2.2\" fill=\"#fff\"/><circle cx=\"128.5\" cy=\"101.5\" r=\"2.2\" fill=\"#fff\"/><ellipse cx=\"62\" cy=\"122\" rx=\"9\" ry=\"5\" fill=\"#F2A6C8\" opacity=\"0.7\"/><ellipse cx=\"138\" cy=\"122\" rx=\"9\" ry=\"5\" fill=\"#F2A6C8\" opacity=\"0.7\"/><path d=\"M92 126 Q100 121 108 126 Q100 135 92 126Z\" fill=\"#2B2340\"/><path d=\"M93 142 Q100 158 107 142Z\" fill=\"#F27BAA\"/><path d=\"M100 131 V138 M100 138 Q92 145 85 139 M100 138 Q108 145 115 139\" stroke=\"#2B2340\" stroke-width=\"3\" fill=\"none\" stroke-linecap=\"round\"/><metadata><c2pa:manifest>AAAWgmp1bWIAAAAeanVtZGMycGEAEQAQgAAAqgA4m3EDYzJwYQAAABZcanVtYgAAAEdqdW1kYzJtYQARABCAAACqADibcQN1cm46YzJwYToyMWI3Nzc5Zi01NmRmLTQxMzgtYTlmOC0zZWUxMzA3OTgzMTgAAAADl2p1bWIAAAApanVtZGMyYXMAEQAQgAAAqgA4m3EDYzJwYS5hc3NlcnRpb25zAAAAALxqdW1iAAAARGp1bWRjYm9yABEAEIAAAKoAOJtxE2MycGEuaW5ncmVkaWVudC52MwAAAAAYYzJzaDRu/KCDnR4ZmGu40Zz9SpMAAABwY2JvcqNpZGM6Zm9ybWF0bWltYWdlL3N2Zyt4bWxqaW5zdGFuY2VJRHgseG1wOmlpZDphZjE4MGVjNC05YzVlLTRjZWItYjdmNC0zMGI2MTA4MDM5OWRscmVsYXRpb25zaGlwaHBhcmVudE9mAAAB4mp1bWIAAABBanVtZGNib3IAEQAQgAAAqgA4m3ETYzJwYS5hY3Rpb25zLnYyAAAAABhjMnNoF5JQSd8qZYnAgVokd3uwoAAAAZljYm9yomdhY3Rpb25zgqJmYWN0aW9ua2MycGEub3BlbmVkanBhcmFtZXRlcnOha2luZ3JlZGllbnRzgaJjdXJseC1zZWxmI2p1bWJmPWMycGEuYXNzZXJ0aW9ucy9jMnBhLmluZ3JlZGllbnQudjNkaGFzaFggYm3/BsJHyLxbcpKMAytFip6WpKE/ZyMPyAowqvBrfB+kZmFjdGlvbngdY29tLmFudGhyb3BpYy5jbGF1ZGUucHJvdmlkZWRqcGFyYW1ldGVyc6F4H2NvbS5hbnRocm9waWMub3JpZ2luLWNvbmZpZGVuY2VndW5rbm93bmtkZXNjcmlwdGlvbnhmQ2xhdWRlIHByb3ZpZGVkIHRoaXMgZmlsZSBhdCB0aGUgcmVxdWVzdCBvZiBhIHVzZXIgYW5kIG1heSBoYXZlIGNyZWF0ZWQgb3IgbW9kaWZpZWQgdGhlIGZpbGUgY29udGVudHMubXNvZnR3YXJlQWdlbnShZG5hbWVmQ2xhdWRlcmFsbEFjdGlvbnNJbmNsdWRlZPUAAADIanVtYgAAAEBqdW1kY2JvcgARABCAAACqADibcRNjMnBhLmhhc2guZGF0YQAAAAAYYzJzaKmjA318G/XsdNZZf84RXbMAAACAY2JvcqVjYWxnZnNoYTI1NmNwYWRMAAAAAAAAAAAAAAAAZGhhc2hYIJwQl0dpqgKTRulTHDIhYnakGimcqRpcFU8l+R+StHAqZG5hbWVuanVtYmYgbWFuaWZlc3RqZXhjbHVzaW9uc4GiZXN0YXJ0GQQIZmxlbmd0aBkeBAAAAj5qdW1iAAAAJ2p1bWRjMmNsABEAEIAAAKoAOJtxA2MycGEuY2xhaW0udjIAAAACD2Nib3KlY2FsZ2ZzaGEyNTZpc2lnbmF0dXJleE1zZWxmI2p1bWJmPS9jMnBhL3VybjpjMnBhOjIxYjc3NzlmLTU2ZGYtNDEzOC1hOWY4LTNlZTEzMDc5ODMxOC9jMnBhLnNpZ25hdHVyZWppbnN0YW5jZUlEeCx4bXA6aWlkOjcxZWQ2YmU2LTM2NzMtNDY3Ni1iZGVlLTdkNGJmNjhiZjY0Y3JjcmVhdGVkX2Fzc2VydGlvbnODomN1cmx4LXNlbGYjanVtYmY9YzJwYS5hc3NlcnRpb25zL2MycGEuaW5ncmVkaWVudC52M2RoYXNoWCBibf8GwkfIvFtykowDK0WKnpakoT9nIw/ICjCq8Gt8H6JjdXJseCpzZWxmI2p1bWJmPWMycGEuYXNzZXJ0aW9ucy9jMnBhLmFjdGlvbnMudjJkaGFzaFggRiOFUGHjwGZQ3EvDU61npkDkTPgzzQTjkDSUQ7oTYmSiY3VybHgpc2VsZiNqdW1iZj1jMnBhLmFzc2VydGlvbnMvYzJwYS5oYXNoLmRhdGFkaGFzaFggMwaX5KitVNjN5D6sBfdeRpikaMJRH/U532cuClDLw5N0Y2xhaW1fZ2VuZXJhdG9yX2luZm+jZG5hbWVvQW50aHJvcGljIEZpbGVzZ3ZlcnNpb25lMS4wLjBrc3BlY1ZlcnNpb25lMi40LjAAABA4anVtYgAAAChqdW1kYzJjcwARABCAAACqADibcQNjMnBhLnNpZ25hdHVyZQAAABAIY2JvctKEWQISogEmGCFZAgowggIGMIIBjaADAgECAhRA5aAK7sI50L64g/oGQgU9Z1UTADAKBggqhkjOPQQDAzBJMRcwFQYDVQQKEw5BbnRocm9waWMsIFBCQzEuMCwGA1UEAxMlQW50aHJvcGljIENvbnRlbnQgQ3JlZGVudGlhbHMgUm9vdCBDQTAeFw0yNjA4MDcxODQzNTZaFw0yODA4MDYxOTQzNTZaMEQxFzAVBgNVBAoTDkFudGhyb3BpYywgUEJDMSkwJwYDVQQDEyBBbnRocm9waWMgQ2xhdWRlIENvbnRlbnQgU2lnbmluZzBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABJh6CmvLUBgFFNU0vUKlOVtE6djd17L5SuwX0LemFisBM3dkd/3cyjxFA3Qo5S46fX0/ihY0VZ7mfb9KF703t5OjWDBWMA4GA1UdDwEB/wQEAwIHgDAVBgNVHSUEDjAMBgorBgEEAYPoXgIBMAwGA1UdEwEB/wQCMAAwHwYDVR0jBBgwFoAUzlHiBIFOZFsj+OPEz5o+nMHXXMIwCgYIKoZIzj0EAwMDZwAwZAIwMXMdFJ4BetLLVY7ORuE9noqbbAZOZn/aArXyTwFAZfKrPzxF2vPoJNf1+UCdg1XGAjBwX1zd9WGqYkqmL5SFqw1QySjr1zJfpJM9+1rdDwSPLMOPOjKuiXjoU/pUUeG9RwmhY3BhZFkNngAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPZYQBHcjwebNFLB9kssl1g00kaaqqbTWJYTUfV5coqufYaELn0XFdXlUMZqUp9lZXY4ggPl4pAivQU9CbCV6nmZqwg=</c2pa:manifest></metadata></svg>", "dog-3-pointy": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 200 200\" xmlns:c2pa=\"http://c2pa.org/manifest\"><ellipse cx=\"100\" cy=\"110\" rx=\"62\" ry=\"60\" fill=\"#B07A52\"/><path d=\"M46 96 L52 34 L88 66Z\" fill=\"#8A5A38\"/><path d=\"M154 96 L148 34 L112 66Z\" fill=\"#8A5A38\"/><ellipse cx=\"100\" cy=\"138\" rx=\"34\" ry=\"26\" fill=\"#FFF8F2\"/><circle cx=\"74\" cy=\"104\" r=\"7\" fill=\"#2B2340\"/><circle cx=\"126\" cy=\"104\" r=\"7\" fill=\"#2B2340\"/><circle cx=\"76.5\" cy=\"101.5\" r=\"2.2\" fill=\"#fff\"/><circle cx=\"128.5\" cy=\"101.5\" r=\"2.2\" fill=\"#fff\"/><ellipse cx=\"62\" cy=\"122\" rx=\"9\" ry=\"5\" fill=\"#F2A6C8\" opacity=\"0.7\"/><ellipse cx=\"138\" cy=\"122\" rx=\"9\" ry=\"5\" fill=\"#F2A6C8\" opacity=\"0.7\"/><path d=\"M92 126 Q100 121 108 126 Q100 135 92 126Z\" fill=\"#2B2340\"/><path d=\"M100 131 V138 M100 138 Q92 145 85 139 M100 138 Q108 145 115 139\" stroke=\"#2B2340\" stroke-width=\"3\" fill=\"none\" stroke-linecap=\"round\"/><metadata><c2pa:manifest>AAAWgmp1bWIAAAAeanVtZGMycGEAEQAQgAAAqgA4m3EDYzJwYQAAABZcanVtYgAAAEdqdW1kYzJtYQARABCAAACqADibcQN1cm46YzJwYTpiZTZlMjZlZi0wOGMyLTQ5OTctYjk2Zi1kNWEwMzQ4NzI0ZjEAAAADl2p1bWIAAAApanVtZGMyYXMAEQAQgAAAqgA4m3EDYzJwYS5hc3NlcnRpb25zAAAAALxqdW1iAAAARGp1bWRjYm9yABEAEIAAAKoAOJtxE2MycGEuaW5ncmVkaWVudC52MwAAAAAYYzJzaK06YRz5ZrlJ738SC+6yu5QAAABwY2JvcqNpZGM6Zm9ybWF0bWltYWdlL3N2Zyt4bWxqaW5zdGFuY2VJRHgseG1wOmlpZDplNzNjOGUxMy0xMGNmLTRiNjktYmMzOS1lMDBkNmZiM2I1YWZscmVsYXRpb25zaGlwaHBhcmVudE9mAAAB4mp1bWIAAABBanVtZGNib3IAEQAQgAAAqgA4m3ETYzJwYS5hY3Rpb25zLnYyAAAAABhjMnNo2lhi0Vxlbmd2qLcGdkhVAAAAAZljYm9yomdhY3Rpb25zgqJmYWN0aW9ua2MycGEub3BlbmVkanBhcmFtZXRlcnOha2luZ3JlZGllbnRzgaJjdXJseC1zZWxmI2p1bWJmPWMycGEuYXNzZXJ0aW9ucy9jMnBhLmluZ3JlZGllbnQudjNkaGFzaFgg/WMkfd4b9ewZbWQ8B1IIiGRfjoH3BEAssNUpS743CXukZmFjdGlvbngdY29tLmFudGhyb3BpYy5jbGF1ZGUucHJvdmlkZWRqcGFyYW1ldGVyc6F4H2NvbS5hbnRocm9waWMub3JpZ2luLWNvbmZpZGVuY2VndW5rbm93bmtkZXNjcmlwdGlvbnhmQ2xhdWRlIHByb3ZpZGVkIHRoaXMgZmlsZSBhdCB0aGUgcmVxdWVzdCBvZiBhIHVzZXIgYW5kIG1heSBoYXZlIGNyZWF0ZWQgb3IgbW9kaWZpZWQgdGhlIGZpbGUgY29udGVudHMubXNvZnR3YXJlQWdlbnShZG5hbWVmQ2xhdWRlcmFsbEFjdGlvbnNJbmNsdWRlZPUAAADIanVtYgAAAEBqdW1kY2JvcgARABCAAACqADibcRNjMnBhLmhhc2guZGF0YQAAAAAYYzJzaMfCDEP4A0xBx/owM01pfbQAAACAY2JvcqVjYWxnZnNoYTI1NmNwYWRMAAAAAAAAAAAAAAAAZGhhc2hYIN/YoVLEZhTowZszFnrZc4qvvVROon5Tkf/Ap/aoFocAZG5hbWVuanVtYmYgbWFuaWZlc3RqZXhjbHVzaW9uc4GiZXN0YXJ0GQN7Zmxlbmd0aBkeBAAAAj5qdW1iAAAAJ2p1bWRjMmNsABEAEIAAAKoAOJtxA2MycGEuY2xhaW0udjIAAAACD2Nib3KlY2FsZ2ZzaGEyNTZpc2lnbmF0dXJleE1zZWxmI2p1bWJmPS9jMnBhL3VybjpjMnBhOmJlNmUyNmVmLTA4YzItNDk5Ny1iOTZmLWQ1YTAzNDg3MjRmMS9jMnBhLnNpZ25hdHVyZWppbnN0YW5jZUlEeCx4bXA6aWlkOjE0YjIyYTI1LTVjNWQtNGI3OS1iMGEzLTlmODNhZTM0NTdiZHJjcmVhdGVkX2Fzc2VydGlvbnODomN1cmx4LXNlbGYjanVtYmY9YzJwYS5hc3NlcnRpb25zL2MycGEuaW5ncmVkaWVudC52M2RoYXNoWCD9YyR93hv17BltZDwHUgiIZF+OgfcEQCyw1SlLvjcJe6JjdXJseCpzZWxmI2p1bWJmPWMycGEuYXNzZXJ0aW9ucy9jMnBhLmFjdGlvbnMudjJkaGFzaFggbJ36DgaI37GxUKR3ssWI8yrxyINhZytey+qH4wslm8WiY3VybHgpc2VsZiNqdW1iZj1jMnBhLmFzc2VydGlvbnMvYzJwYS5oYXNoLmRhdGFkaGFzaFggLlQ06Rrxzjg1XJfOmETYDj37L03tmnO/Q7MFKfLptvp0Y2xhaW1fZ2VuZXJhdG9yX2luZm+jZG5hbWVvQW50aHJvcGljIEZpbGVzZ3ZlcnNpb25lMS4wLjBrc3BlY1ZlcnNpb25lMi40LjAAABA4anVtYgAAAChqdW1kYzJjcwARABCAAACqADibcQNjMnBhLnNpZ25hdHVyZQAAABAIY2JvctKEWQISogEmGCFZAgowggIGMIIBjaADAgECAhRA5aAK7sI50L64g/oGQgU9Z1UTADAKBggqhkjOPQQDAzBJMRcwFQYDVQQKEw5BbnRocm9waWMsIFBCQzEuMCwGA1UEAxMlQW50aHJvcGljIENvbnRlbnQgQ3JlZGVudGlhbHMgUm9vdCBDQTAeFw0yNjA4MDcxODQzNTZaFw0yODA4MDYxOTQzNTZaMEQxFzAVBgNVBAoTDkFudGhyb3BpYywgUEJDMSkwJwYDVQQDEyBBbnRocm9waWMgQ2xhdWRlIENvbnRlbnQgU2lnbmluZzBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABJh6CmvLUBgFFNU0vUKlOVtE6djd17L5SuwX0LemFisBM3dkd/3cyjxFA3Qo5S46fX0/ihY0VZ7mfb9KF703t5OjWDBWMA4GA1UdDwEB/wQEAwIHgDAVBgNVHSUEDjAMBgorBgEEAYPoXgIBMAwGA1UdEwEB/wQCMAAwHwYDVR0jBBgwFoAUzlHiBIFOZFsj+OPEz5o+nMHXXMIwCgYIKoZIzj0EAwMDZwAwZAIwMXMdFJ4BetLLVY7ORuE9noqbbAZOZn/aArXyTwFAZfKrPzxF2vPoJNf1+UCdg1XGAjBwX1zd9WGqYkqmL5SFqw1QySjr1zJfpJM9+1rdDwSPLMOPOjKuiXjoU/pUUeG9RwmhY3BhZFkNngAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPZYQJZwPBQI3Vjy9owU0TpMbAwPzy7uzQPTabY2WnLQcoJa5xo5n+OfQjuV4tynLnxsrG41yGnDkqh7qIEAn22CrCk=</c2pa:manifest></metadata></svg>", "guide-dog": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 200 200\" xmlns:c2pa=\"http://c2pa.org/manifest\"><ellipse cx=\"100\" cy=\"110\" rx=\"62\" ry=\"60\" fill=\"#E8B86A\"/><path d=\"M48 70 Q20 80 30 140 Q46 150 62 120Z\" fill=\"#C98E3E\"/><path d=\"M152 70 Q180 80 170 140 Q154 150 138 120Z\" fill=\"#C98E3E\"/><ellipse cx=\"100\" cy=\"138\" rx=\"34\" ry=\"26\" fill=\"#FFF8F2\"/><circle cx=\"74\" cy=\"104\" r=\"7\" fill=\"#2B2340\"/><circle cx=\"126\" cy=\"104\" r=\"7\" fill=\"#2B2340\"/><circle cx=\"76.5\" cy=\"101.5\" r=\"2.2\" fill=\"#fff\"/><circle cx=\"128.5\" cy=\"101.5\" r=\"2.2\" fill=\"#fff\"/><ellipse cx=\"62\" cy=\"122\" rx=\"9\" ry=\"5\" fill=\"#F2A6C8\" opacity=\"0.7\"/><ellipse cx=\"138\" cy=\"122\" rx=\"9\" ry=\"5\" fill=\"#F2A6C8\" opacity=\"0.7\"/><path d=\"M92 126 Q100 121 108 126 Q100 135 92 126Z\" fill=\"#2B2340\"/><path d=\"M93 142 Q100 158 107 142Z\" fill=\"#F27BAA\"/><path d=\"M100 131 V138 M100 138 Q92 145 85 139 M100 138 Q108 145 115 139\" stroke=\"#2B2340\" stroke-width=\"3\" fill=\"none\" stroke-linecap=\"round\"/><path d=\"M58 160 Q100 186 142 160 L132 178 Q100 196 68 178Z\" fill=\"#6A4FD6\"/><circle cx=\"100\" cy=\"184\" r=\"6\" fill=\"#FFC94D\"/><metadata><c2pa:manifest>AAAWgmp1bWIAAAAeanVtZGMycGEAEQAQgAAAqgA4m3EDYzJwYQAAABZcanVtYgAAAEdqdW1kYzJtYQARABCAAACqADibcQN1cm46YzJwYTo1ZGFjM2FkYy05YTg0LTQ1MWItYmJmNC05ZjI5ZjhhZWViZDQAAAADl2p1bWIAAAApanVtZGMyYXMAEQAQgAAAqgA4m3EDYzJwYS5hc3NlcnRpb25zAAAAALxqdW1iAAAARGp1bWRjYm9yABEAEIAAAKoAOJtxE2MycGEuaW5ncmVkaWVudC52MwAAAAAYYzJzaEWOcSKyjpIMGqUtSQJNp/UAAABwY2JvcqNpZGM6Zm9ybWF0bWltYWdlL3N2Zyt4bWxqaW5zdGFuY2VJRHgseG1wOmlpZDo1ZTMxMDhmYS1hMDFkLTRjMDQtODU1NC0zMDIxNGEzZTkwMzlscmVsYXRpb25zaGlwaHBhcmVudE9mAAAB4mp1bWIAAABBanVtZGNib3IAEQAQgAAAqgA4m3ETYzJwYS5hY3Rpb25zLnYyAAAAABhjMnNo61aZNMQUECoNWc2NNLndSAAAAZljYm9yomdhY3Rpb25zgqJmYWN0aW9ua2MycGEub3BlbmVkanBhcmFtZXRlcnOha2luZ3JlZGllbnRzgaJjdXJseC1zZWxmI2p1bWJmPWMycGEuYXNzZXJ0aW9ucy9jMnBhLmluZ3JlZGllbnQudjNkaGFzaFggFGxpDqkgpz796YTby7yDkuChXBfWxXGLeBF1KQyF+zGkZmFjdGlvbngdY29tLmFudGhyb3BpYy5jbGF1ZGUucHJvdmlkZWRqcGFyYW1ldGVyc6F4H2NvbS5hbnRocm9waWMub3JpZ2luLWNvbmZpZGVuY2VndW5rbm93bmtkZXNjcmlwdGlvbnhmQ2xhdWRlIHByb3ZpZGVkIHRoaXMgZmlsZSBhdCB0aGUgcmVxdWVzdCBvZiBhIHVzZXIgYW5kIG1heSBoYXZlIGNyZWF0ZWQgb3IgbW9kaWZpZWQgdGhlIGZpbGUgY29udGVudHMubXNvZnR3YXJlQWdlbnShZG5hbWVmQ2xhdWRlcmFsbEFjdGlvbnNJbmNsdWRlZPUAAADIanVtYgAAAEBqdW1kY2JvcgARABCAAACqADibcRNjMnBhLmhhc2guZGF0YQAAAAAYYzJzaEHtPWgvORJw1mMdQ+wvrYYAAACAY2JvcqVjYWxnZnNoYTI1NmNwYWRMAAAAAAAAAAAAAAAAZGhhc2hYINh8Zx0EUUfw8NX9pF6UlfdSCCuB4YTelGsNKy+4HHG8ZG5hbWVuanVtYmYgbWFuaWZlc3RqZXhjbHVzaW9uc4GiZXN0YXJ0GQRMZmxlbmd0aBkeBAAAAj5qdW1iAAAAJ2p1bWRjMmNsABEAEIAAAKoAOJtxA2MycGEuY2xhaW0udjIAAAACD2Nib3KlY2FsZ2ZzaGEyNTZpc2lnbmF0dXJleE1zZWxmI2p1bWJmPS9jMnBhL3VybjpjMnBhOjVkYWMzYWRjLTlhODQtNDUxYi1iYmY0LTlmMjlmOGFlZWJkNC9jMnBhLnNpZ25hdHVyZWppbnN0YW5jZUlEeCx4bXA6aWlkOmY4OTBiM2M5LWMwMWQtNGFiOS05ODIwLTQ3ZWQ3YmQzNDg5ZXJjcmVhdGVkX2Fzc2VydGlvbnODomN1cmx4LXNlbGYjanVtYmY9YzJwYS5hc3NlcnRpb25zL2MycGEuaW5ncmVkaWVudC52M2RoYXNoWCAUbGkOqSCnPv3phNvLvIOS4KFcF9bFcYt4EXUpDIX7MaJjdXJseCpzZWxmI2p1bWJmPWMycGEuYXNzZXJ0aW9ucy9jMnBhLmFjdGlvbnMudjJkaGFzaFggtHao4MMJjhT+wJaCoe3jTUBCZMURtFfHFpuX/KEZd2WiY3VybHgpc2VsZiNqdW1iZj1jMnBhLmFzc2VydGlvbnMvYzJwYS5oYXNoLmRhdGFkaGFzaFgg15YevEpEZIino4gAQ0mMJW8+VT3vx/dkb8WZejJAGzt0Y2xhaW1fZ2VuZXJhdG9yX2luZm+jZG5hbWVvQW50aHJvcGljIEZpbGVzZ3ZlcnNpb25lMS4wLjBrc3BlY1ZlcnNpb25lMi40LjAAABA4anVtYgAAAChqdW1kYzJjcwARABCAAACqADibcQNjMnBhLnNpZ25hdHVyZQAAABAIY2JvctKEWQISogEmGCFZAgowggIGMIIBjaADAgECAhRA5aAK7sI50L64g/oGQgU9Z1UTADAKBggqhkjOPQQDAzBJMRcwFQYDVQQKEw5BbnRocm9waWMsIFBCQzEuMCwGA1UEAxMlQW50aHJvcGljIENvbnRlbnQgQ3JlZGVudGlhbHMgUm9vdCBDQTAeFw0yNjA4MDcxODQzNTZaFw0yODA4MDYxOTQzNTZaMEQxFzAVBgNVBAoTDkFudGhyb3BpYywgUEJDMSkwJwYDVQQDEyBBbnRocm9waWMgQ2xhdWRlIENvbnRlbnQgU2lnbmluZzBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABJh6CmvLUBgFFNU0vUKlOVtE6djd17L5SuwX0LemFisBM3dkd/3cyjxFA3Qo5S46fX0/ihY0VZ7mfb9KF703t5OjWDBWMA4GA1UdDwEB/wQEAwIHgDAVBgNVHSUEDjAMBgorBgEEAYPoXgIBMAwGA1UdEwEB/wQCMAAwHwYDVR0jBBgwFoAUzlHiBIFOZFsj+OPEz5o+nMHXXMIwCgYIKoZIzj0EAwMDZwAwZAIwMXMdFJ4BetLLVY7ORuE9noqbbAZOZn/aArXyTwFAZfKrPzxF2vPoJNf1+UCdg1XGAjBwX1zd9WGqYkqmL5SFqw1QySjr1zJfpJM9+1rdDwSPLMOPOjKuiXjoU/pUUeG9RwmhY3BhZFkNngAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPZYQAxVsKKYUuoryPHI+gs3WsnAoPM7PxYnePR5JqvzymIox6lPU3TVoYhJku/gwNGE45R9V/nvEYauKr7MYdpwXvA=</c2pa:manifest></metadata></svg>"};

STAGE = 'New in the app';
const avatar = (parent, key, size, bg) => {
  const c = circle(parent, size, bg);
  c.clipsContent = true;
  try {
    const px = Math.round(size * 0.94);
    const svg = AVATARS[key].replace('<svg ', '<svg width="' + px + '" height="' + px + '" ');
    const n = figma.createNodeFromSvg(svg); n.name = key; c.appendChild(n);
    n.layoutPositioning = 'ABSOLUTE'; n.x = Math.round((size - px) / 2); n.y = Math.round(size * 0.06);
  } catch (e) { I(c, 'pets', Math.round(size * 0.5), P.white); }
  return c;
};
const lockFrame = (name) => {
  const s = figma.createFrame(); s.name = name; s.resize(390, 844); s.cornerRadius = 32; s.clipsContent = true;
  s.fills = grad(P.heroA, '#2B2340', 'v'); s.layoutMode = 'VERTICAL'; s.counterAxisAlignItems = 'CENTER'; s.primaryAxisSizingMode = 'FIXED'; s.counterAxisSizingMode = 'FIXED';
  s.paddingTop = 100; s.paddingLeft = s.paddingRight = 16; s.itemSpacing = 6;
  return s;
};
const NX = {};

// Pet profile: picture, colour, avatar
{
  const { s, body } = phone('Pet profile', { title: 'Biscuit', back: true });
  const top = AL('v', { align: 'CENTER', gap: 10, parent: body, fillW: true });
  avatar(top, 'dog-1-golden', 112, P.pets[0]);
  button(top, 'Add a photo', { kind: 'tonal', icon: 'photo_camera' });
  T(body, 'Picture', 16, 'h', P.ink);
  const ar = AL('h', { gap: 10, parent: body, fillW: true, main: 'CENTER' });
  ['cat-1-ginger', 'cat-2-grey', 'cat-3-tuxedo', 'dog-1-golden', 'dog-2-spotted', 'dog-3-pointy'].forEach((k, i) => { const a = avatar(ar, k, 50, P.pets[i % 8]); if (k === 'dog-1-golden') { a.strokes = solid(P.ink); a.strokeWeight = 3; } });
  T(body, 'Colour', 16, 'h', P.ink);
  const cr = AL('h', { gap: 8, parent: body, fillW: true, main: 'CENTER' });
  P.pets.forEach((c, i) => { const d = circle(cr, 36, c, i === 0 ? 'check' : undefined, P.white, 20); });
  const nf = AL('h', { fill: P.surface, r: 14, pad: [14, 16, 14, 16], parent: body, fillW: true }); nf.strokes = solid(P.border); nf.strokeWeight = 1.5; T(nf, 'Biscuit', 16, 'r', P.ink);
  const sp = AL('h', { gap: 8, parent: body, fillW: true }); chip(sp, 'Cat', false, { grow: true }); chip(sp, 'Dog', true, { grow: true });
  AL('v', { parent: body, grow: true });
  button(body, 'Save', { fill: true });
  NX.profile = s;
}
// Walkthrough with the guide dog
{
  const { s, body } = phone('Walkthrough', { title: 'MyPet', logo: true, tab: 'Today' });
  hero(body); pets(body, 'Biscuit');
  AL('v', { parent: body, grow: true });
  const b = AL('v', { fill: '#FBF8FF', r: 22, pad: 16, gap: 12, parent: body, fillW: true, shadow: true, name: 'Guide bubble' }); b.strokes = solid(P.brand); b.strokeWeight = 1.5;
  const r = AL('h', { gap: 12, align: 'CENTER', parent: b, fillW: true });
  const ga = avatar(r, 'guide-dog', 64, P.lavC); ga.strokes = solid(P.brand); ga.strokeWeight = 3;
  const gt = AL('v', { gap: 2, parent: r, grow: true }); T(gt, 'This is Biscuit. Tap Log now.', 17, 's', P.ink); const hp = AL('h', { fill: P.brandC, r: 999, pad: [3, 10, 3, 10], parent: gt }); T(hp, 'Tap me to shrink', 12, 's', P.onBrandC);
  const bt = AL('h', { gap: 8, parent: b, fillW: true }); button(bt, 'Skip', { kind: 'outlined', grow: true }); button(bt, 'Next', { grow: true });
  NX.tour = s;
}
// Try a demo
{
  const { s, body } = phone('Try a demo', { title: 'Try a demo', back: true });
  for (const [n, sub, k, ci] of [['Biscuit', 'Energy dropping', 'dog-1-golden', 0], ['Mochi', 'Eating less', 'cat-2-grey', 1], ['Pepper', 'All steady', 'dog-3-pointy', 2], ['Bean', 'Just started', 'cat-1-ginger', 3], ['Carl', 'Log by voice while driving', 'drive', 5]]) {
    const k2 = card(body, { edge: P.pets[ci], gap: 0 }); const r = AL('h', { gap: 14, align: 'CENTER', parent: k2, fillW: true });
    if (k === 'drive') circle(r, 60, P.lavC, 'directions_car', P.onLavC, 30); else avatar(r, k, 60, P.lavC); const t = AL('v', { gap: 2, parent: r, grow: true }); T(t, n, 20, 'h', P.ink); T(t, sub, 14, 'r', P.inkSoft);
    I(r, 'play_circle', 30, P.brand);
  }
  NX.demo = s;
}
// Notification quick-fill
{
  const s = lockFrame('Notification quick-fill');
  T(s, '9:41', 80, 'hx', P.white); T(s, 'Thursday 20 November', 16, 's', P.white);
  AL('v', { parent: s }).resize(10, 190);
  const n = AL('v', { fill: P.surface, r: 26, pad: 16, gap: 12, parent: s, fillW: true, shadow: true, name: 'Notification' });
  const nh = AL('h', { gap: 8, align: 'CENTER', parent: n }); const lm = circle(nh, 22, P.brand, 'pets', P.white, 14); lm.cornerRadius = 6; T(nh, 'MyPet · now', 13, 'r', P.inkSoft);
  T(n, "Biscuit's day?", 18, 'h', P.ink);
  T(n, 'Hold to answer here, or tap to open.', 14, 'r', P.inkSoft, { w: 'fill' });
  const q1 = AL('h', { gap: 8, parent: n, fillW: true }); button(q1, 'All normal', { icon: 'check', grow: true }); button(q1, 'Tell us about today', { kind: 'tonal', grow: true });
  const q3 = AL('h', { gap: 8, parent: n, fillW: true }); button(q3, 'Open the log', { kind: 'outlined', grow: true }); button(q3, 'Later', { kind: 'outlined', grow: true });
  NX.notif = s;
}
// Voice quick-fill
{
  const { s, body } = phone('Voice log', { title: 'Talk to log', back: true });
  const m = AL('v', { align: 'CENTER', gap: 10, parent: body, fillW: true });
  const ring = circle(m, 120, P.brandC); const mic = circle(ring, 96, P.brand, 'mic', P.white, 48); mic.fills = grad(P.heroA, P.heroB);
  T(m, 'Listening', 15, 's', P.inkSoft, { align: 'CENTER' });
  const tc = card(body, { gap: 8 }); T(tc, '"Biscuit ate well but seemed a bit tired"', 18, 'h', P.ink, { w: 'fill' });
  const ch = AL('h', { gap: 8, parent: body, fillW: true });
  chip(ch, 'Ate', true, { grow: true }); chip(ch, 'Energy 3', true, { grow: true });
  const ch2 = AL('h', { gap: 8, parent: body, fillW: true }); chip(ch2, 'Toilet normal', true, { grow: true });
  AL('v', { parent: body, grow: true });
  button(body, 'Save', { fill: true });
  NX.voice = s;
}
// Siri shortcut
{
  const s = lockFrame('Siri shortcut');
  s.paddingTop = 220;
  const orb = circle(s, 140, P.pink); orb.fills = grad(P.sky, P.pink);
  T(s, 'Tell MyPet about today', 22, 'hx', P.white, { align: 'CENTER' });
  AL('v', { parent: s }).resize(10, 120);
  const k = AL('h', { fill: P.surface, r: 22, pad: 16, gap: 12, align: 'CENTER', parent: s, fillW: true, shadow: true });
  circle(k, 44, P.loggedC, 'check', P.onLoggedC, 26); T(k, 'Got it. MyPet will add it to today\'s log.', 16, 'h', P.ink, { grow: true });
  NX.siri = s;
}
// Guide and FAQ
{
  const { s, body } = phone('Guide and FAQ', { title: 'Guide and FAQ', back: true });
  const names = ['Getting started', 'Logging a day', 'Checking a clip', 'Insights and baselines', 'Privacy and your data'];
  names.forEach((n, i) => {
    const c = AL('v', { fill: P.surface, r: 20, pad: 16, gap: 8, parent: body, fillW: true, shadow: true, name: n });
    const h = AL('h', { align: 'CENTER', parent: c, fillW: true, gap: 10 });
    T(h, n, 17, 'h', P.ink, { grow: true });
    I(h, i === 0 ? 'expand_less' : 'expand_more', 24, P.brand);
    if (i === 0) T(c, 'Add your pet, log a normal day in one tap, and check a short clip when something seems off.', 14, 'r', P.inkSoft, { fillW: true });
  });
  NX.guide = s;
}
// Widgets: home and lock screen
{
  const s = figma.createFrame(); s.name = 'Widgets'; s.resize(390, 844); s.cornerRadius = 32; s.clipsContent = true;
  s.fills = grad('#8E7CF0', '#F27BAA', 'v'); s.layoutMode = 'VERTICAL'; s.primaryAxisSizingMode = 'FIXED'; s.counterAxisSizingMode = 'FIXED';
  s.paddingTop = 90; s.paddingLeft = s.paddingRight = 16; s.itemSpacing = 14;
  T(s, 'Lock screen', 15, 's', P.white);
  const lk = AL('h', { gap: 10, align: 'CENTER', parent: s });
  const lw = (ic) => { const c = circle(lk, 56, '#FFFFFF', ic, P.white, 28); c.fills = solid('#FFFFFF', 0.25); return c; };
  lw('edit_note'); lw('mic');
  const rect = AL('h', { r: 16, pad: [10, 14, 10, 14], gap: 8, align: 'CENTER', parent: lk }); rect.fills = solid('#FFFFFF', 0.25); I(rect, 'pets', 22, P.white); T(rect, 'Biscuit 2/3', 15, 's', P.white);
  T(s, 'Home screen', 15, 's', P.white);
  const row = AL('h', { gap: 14, parent: s });
  const w1 = AL('v', { fill: P.surface, r: 24, pad: 14, gap: 6, parent: row, shadow: true, name: 'Small widget' }); w1.resize(160, 160); w1.primaryAxisSizingMode = 'FIXED'; w1.counterAxisSizingMode = 'FIXED';
  const h1 = AL('h', { gap: 8, align: 'CENTER', parent: w1 }); avatar(h1, 'dog-1-golden', 36, P.pets[0]); T(h1, 'Biscuit', 16, 'h', P.ink);
  T(w1, '2/3', 34, 'hx', P.brand); T(w1, 'logged today', 13, 's', P.inkSoft);
  const w2 = AL('v', { fill: P.surface, r: 24, pad: 14, gap: 10, parent: row, shadow: true, name: 'Log widget' }); w2.resize(160, 160); w2.primaryAxisSizingMode = 'FIXED'; w2.counterAxisSizingMode = 'FIXED'; w2.counterAxisAlignItems = 'CENTER'; w2.primaryAxisAlignItems = 'CENTER';
  circle(w2, 64, P.brand, 'mic', P.white, 32).fills = grad(P.heroA, P.heroB); T(w2, 'Log by voice', 14, 's', P.ink, { align: 'CENTER' });
  const w3 = AL('h', { fill: P.surface, r: 24, pad: 16, gap: 14, align: 'CENTER', parent: s, fillW: true, shadow: true, name: 'Medium widget' });
  [['dog-1-golden', P.pets[0], 'check_circle'], ['cat-2-grey', P.pets[1], 'radio_button_unchecked'], ['cat-1-ginger', P.pets[2], 'check_circle']].forEach(([k, c, ic]) => { const v = AL('v', { gap: 4, align: 'CENTER', parent: w3, grow: true }); avatar(v, k, 56, c); I(v, ic, 22, ic === 'check_circle' ? P.loggedEdge : P.inkSoft); });
  NX.widgets = s;
}
// Test this phone (More > Test this phone, app 73b7197)
{
  const mk = (name) => phone(name, { title: 'Test this phone', back: true });
  { const { s, body } = mk('Test this phone');
    T(body, 'Times a real behaviour check on this phone, with two example clips. Nothing about you or your pets is sent. Use Wi-Fi the first time on the web link, as the models download once.', 15, 'r', P.inkSoft, { w: 'fill' });
    AL('v', { parent: body, grow: true }); button(body, 'Start the test', { fill: true, icon: 'speed' }); NX.test1 = s; }
  { const { s, body } = mk('Test running');
    const c = card(body, { gap: 12 }); const r = AL('h', { gap: 12, align: 'CENTER', parent: c, fillW: true }); circle(r, 36, P.brandC, 'progress_activity', P.brand, 22); T(r, 'Checking dog clip…', 17, 'h', P.ink, { grow: true });
    NX.test2 = s; }
  { const { s, body } = mk('Test result');
    const h = AL('v', { fill: grad(P.heroA, P.heroB), r: 24, pad: 20, gap: 4, parent: body, fillW: true, shadow: true, name: 'Hero' });
    T(h, 'iPhone', 15, 's', P.white); T(h, 'A check takes about 2.1 s', 22, 'hx', P.white, { w: 'fill' });
    const c = card(body, { gap: 10 });
    for (const [a, b] of [['Model load', '1.4 s'], ['Dog clip', '2.0 s'], ['Cat clip', '2.2 s'], ['Dog clip again', '2.1 s']]) { const r = AL('h', { parent: c, fillW: true }); T(r, a, 16, 'r', P.ink, { grow: true }); T(r, b, 16, 's', P.ink); }
    const r2 = AL('h', { parent: c, fillW: true }); T(r2, 'Whole test', 17, 'hx', P.ink, { grow: true }); T(r2, '7.7 s', 17, 'hx', P.ink);
    AL('v', { parent: body, grow: true });
    button(body, 'Send to Erwyna', { fill: true, icon: 'send' }); button(body, 'Copy results', { kind: 'outlined' }); button(body, 'Run again', { kind: 'text' });
    NX.test3 = s; }
}
// Saved clips setting
{
  const { s, body } = phone('Saved clips', { title: 'Saved clips', back: true });
  const seg = AL('h', { fill: P.track, r: 999, pad: 4, parent: body, fillW: true });
  for (const [t, on] of [['Video', true], ['Sound', false], ['Results', false]]) { const c = AL('h', { fill: on ? P.surface : undefined, r: 999, pad: [10, 0, 10, 0], main: 'CENTER', parent: seg, grow: true }); T(c, t, 15, 's', on ? P.ink : P.inkSoft); }
  const pv = AL('h', { gap: 8, align: 'CENTER', fill: P.lavC, r: 14, pad: 14, parent: body, fillW: true }); I(pv, 'lock', 20, P.onLavC); T(pv, 'Stays on this phone only', 15, 's', P.onLavC, { grow: true });
  const r = card(body, { gap: 0 }); row(r, 'play_circle', P.brand, 'Replay moments'); row(r, 'delete', P.inkSoft, 'Delete all clips');
  NX.clips = s;
}
// Vet PDF import
{
  const { s, body } = phone('Vet PDF import', { title: 'Health record', back: true });
  const c = card(body, { gap: 4 }); const h = AL('h', { gap: 12, align: 'CENTER', parent: c }); circle(h, 48, P.pinkC, 'picture_as_pdf', P.onPinkC, 26); T(h, 'vet_report.pdf', 17, 'h', P.ink);
  const f = card(body, { gap: 0 }); T(f, 'Found', 16, 'h', P.ink);
  row(f, 'check_circle', P.loggedEdge, 'Vaccines', 'Added', P.onLoggedC); row(f, 'check_circle', P.loggedEdge, 'Weight', '12.4 kg', P.onLoggedC); row(f, 'check_circle', P.loggedEdge, 'Medicine', 'Added', P.onLoggedC);
  const m = AL('h', { gap: 8, align: 'CENTER', fill: P.sunC, r: 14, pad: 14, parent: body, fillW: true }); I(m, 'edit', 20, P.onSunC); T(m, 'Add allergies', 15, 's', P.onSunC, { grow: true });
  AL('v', { parent: body, grow: true });
  button(body, 'Save to record', { fill: true });
  NX.pdf = s;
}

// Next build (from the pet-owner review): weight, extras, pet details
{
  const { s, body } = phone('Insights, weight', { title: 'Insights', tab: 'Insights' });
  const c = card(body, { gap: 8, edge: P.pets[2], name: 'Weight card' }); T(c, 'Weight', 18, 'h', P.ink);
  const ch = figma.createFrame(); ch.name = 'Weight chart'; ch.fills = []; c.appendChild(ch); ch.resize(326, 130); ch.layoutSizingHorizontal = 'FILL';
  [10, 60, 110].forEach(y => { const g = box(ch, 326, 1, P.border); g.y = y; });
  const pts = [[14, 112], [100, 90], [220, 60], [310, 30]];
  try { const v = figma.createVector(); v.vectorPaths = [{ windingRule: 'NONE', data: 'M ' + pts.map(p => p.join(' ')).join(' L ') }]; v.strokes = solid(P.pets[2]); v.strokeWeight = 4; v.strokeCap = 'ROUND'; v.strokeJoin = 'ROUND'; ch.appendChild(v); } catch (e) {}
  pts.forEach(p => { const d = circle(ch, 12, P.pets[2]); d.x = p[0] - 6; d.y = p[1] - 6; });
  const dr = AL('h', { main: 'SPACE_BETWEEN', parent: c, fillW: true }); T(dr, '14 Feb', 13, 'r', P.inkSoft); T(dr, '15 Mar', 13, 'r', P.inkSoft);
  T(c, '7.6 kg now, 3.2 kg heavier than on 14 Feb', 16, 'r', P.ink, { w: 'fill' });
  T(body, 'Only compared with Biscuit, 13 Feb to 12 Mar', 13, 'r', P.inkSoft);
  AL('v', { parent: body, grow: true });
  button(body, 'Export for the vet', { kind: 'tonal', icon: 'picture_as_pdf', fill: true });
  NX.weight = s;
}
{
  const { s, body } = phone('Quick log, extras', { title: 'Log for Biscuit', back: true });
  const c = card(body, { gap: 4, name: 'Extra checks' }); T(c, 'Extra checks', 18, 'h', P.ink);
  for (const lbl of ['Drinking more than usual', 'Accident indoors', 'Vomited']) {
    const r = AL('h', { gap: 8, align: 'CENTER', parent: c, fillW: true, pad: [6, 0, 6, 0] }); T(r, lbl, 16, 's', P.ink, { grow: true });
    const g = AL('h', { gap: 6, parent: r }); chip(g, 'No', true); chip(g, 'Yes', false);
  }
  AL('v', { parent: body, grow: true });
  button(body, 'Save', { fill: true });
  NX.extras = s;
}
{
  const { s, body } = phone('Pet details', { title: 'About Biscuit', back: true });
  const c = card(body, { gap: 0, name: 'Details' });
  row(c, 'content_cut', P.brand, 'Neutered', 'Yes', P.inkSoft);
  row(c, 'cake', P.brand, 'Age', 'about 4 years', P.inkSoft);
  row(c, 'restaurant', P.brand, 'Usual portion', '120 g', P.inkSoft);
  row(c, 'schedule', P.brand, 'Meals a day', '2', P.inkSoft);
  T(body, 'Adult size', 16, 'h', P.ink);
  const sz = AL('h', { gap: 8, parent: body, fillW: true }); chip(sz, 'Small', false, { grow: true }); chip(sz, 'Medium', true, { grow: true }); chip(sz, 'Large', false, { grow: true });
  const ex = AL('h', { gap: 8, align: 'CENTER', fill: P.lavC, r: 14, pad: 14, parent: body, fillW: true }); I(ex, 'add_circle', 20, P.onLavC); T(ex, 'Add extra checks', 15, 's', P.onLavC, { grow: true });
  AL('v', { parent: body, grow: true });
  button(body, 'Save', { fill: true });
  NX.details = s;
}

{
  const { s, body } = phone('Pet page', { title: 'Biscuit', back: true });
  const c = card(body, { gap: 6, edge: P.pets[2], name: 'Typical' }); T(c, 'What is typical for Biscuit', 18, 'h', P.ink);
  T(c, 'Biscuit is an adult dog, medium size.', 15, 'r', P.ink, { w: 'fill' });
  T(c, 'A rough daily energy need is about 640 kcal.', 15, 'r', P.ink, { w: 'fill' });
  T(c, 'From the AAHA 2021 and Pet Nutrition Alliance guides. A starting point, not a diagnosis.', 12, 'r', P.inkSoft, { w: 'fill' });
  const tb = AL('h', { gap: 8, align: 'CENTER', parent: body }); I(tb, 'restart_alt', 20, P.brand); T(tb, 'Something changed', 15, 's', P.brand);
  T(body, 'Timeline (59)', 18, 'h', P.ink);
  const tl = card(body, { gap: 10 });
  for (const [tm, ti, de] of [['7:00 pm', 'Daily log', 'Ate all · Energy 4 of 5 · Toileting normal'], ['8:05 am', 'Breakfast', 'Done'], ['Sun', 'Daily log', 'Ate all · Energy 4 of 5']]) {
    const r = AL('h', { gap: 12, align: 'MIN', parent: tl, fillW: true }); T(r, tm, 13, 'r', P.inkSoft, { w: 56 }); circle(r, 10, P.brand);
    const t = AL('v', { gap: 2, parent: r, grow: true }); T(t, ti, 16, 'h', P.ink); T(t, de, 13, 'r', P.inkSoft, { w: 'fill' });
  }
  NX.petpage = s;
}
const row3 = flowRow('New in the app (20 Nov)');
labelled(row3, 'Pet profile', NX.profile); labelled(row3, 'Walkthrough', NX.tour); labelled(row3, 'Try a demo', NX.demo);
labelled(row3, 'Notification quick-fill', NX.notif); labelled(row3, 'Voice log', NX.voice); labelled(row3, 'Siri shortcut', NX.siri);
labelled(row3, 'Widgets (not built)', NX.widgets); labelled(row3, 'Guide and FAQ', NX.guide); labelled(row3, 'Test this phone', NX.test1); labelled(row3, 'Test running', NX.test2); labelled(row3, 'Test result', NX.test3); labelled(row3, 'Saved clips', NX.clips); labelled(row3, 'Vet PDF import', NX.pdf);
const row4 = flowRow('Pet-owner review changes (in the app 20 Nov)');
labelled(row4, 'Insights, weight', NX.weight); labelled(row4, 'Quick log, extras', NX.extras); labelled(row4, 'Pet details', NX.details); labelled(row4, 'Pet page', NX.petpage);

// Tracker: what is drawn and what is built
STAGE = 'Tracker';
{
  const w = AL('v', { gap: 20, parent: root, name: 'Figma and app tracker' });
  T(w, 'Figma and app tracker · updated 20 Nov 2026', 36, 'hx', P.ink);
  const t = AL('v', { fill: P.surface, r: 24, pad: 32, gap: 10, parent: w, shadow: true });
  const hdr = AL('h', { parent: t }); for (const [x, wd] of [['Feature', 420], ['Requirement', 200], ['In Figma', 160], ['In the app', 160]]) T(hdr, x, 14, 's', P.inkSoft, { w: wd });
  const ST = [
    ['Quick log in 3 taps', 'FR05 NFR01', 'Drawn', 'In app'],
    ['Check: full-screen clip, pet picker', 'FR02 FR20', 'Drawn', 'In app'],
    ['Result: clip with detected moments', 'FR20', 'Drawn', 'In app'],
    ['Pet picture, avatars, colour', 'FR01', 'Drawn', 'In app'],
    ['Walkthrough and demo pets', '', 'Drawn', 'In app'],
    ['Vet PDF import', 'FR04', 'Drawn', 'In app'],
    ['Saved clips setting', 'FR02', 'Drawn', 'In app'],
    ['Light and dark mode', 'NFR04', 'Drawn', 'In app'],
    ['Notification quick-fill', 'FR11 FR12', 'Drawn', 'In app'],
    ['Voice quick-fill', '', 'Drawn', 'In app'],
    ['Quick log: All / Some / None, extra checks', 'FR05', 'Drawn', 'In app'],
    ['Getting to know card, weight card', 'FR13 FR15', 'Drawn', 'In app'],
    ['Pet details and pet page: typical, something changed', 'FR01', 'Drawn', 'In app'],
    ['Demo: log by voice while driving', '', 'Drawn', 'In app'],
    ['Siri: Tell MyPet, All normal today', '', 'Drawn', 'In app'],
    ['Guide and FAQ (More, below Try a demo)', '', 'Drawn', 'In app'],
    ['More > Test this phone (timing test, 3 states)', '', 'Drawn', 'In app'],
    ['Home and lock-screen widgets', '', 'Drawn', 'Not in the app']
  ];
  for (const [f, rq, fg, ap] of ST) {
    const r = AL('h', { align: 'CENTER', parent: t, pad: [4, 0, 4, 0] });
    T(r, f, 16, 's', P.ink, { w: 420 }); T(r, rq || '·', 14, 'r', P.inkSoft, { w: 200 });
    const a = AL('h', { fill: P.loggedC, r: 999, pad: [4, 12, 4, 12], parent: r }); a.resize(150, 28); a.primaryAxisSizingMode = 'FIXED'; T(a, fg, 13, 's', P.onLoggedC);
    const gap = AL('v', { parent: r }); gap.resize(10, 4);
    const inApp = ap === 'In app'; const nxt = ap === 'Next build'; const b = AL('h', { fill: inApp ? P.loggedC : (nxt ? P.lavC : P.sunC), r: 999, pad: [4, 12, 4, 12], parent: r }); T(b, ap, 13, 's', inApp ? P.onLoggedC : (nxt ? P.onLavC : P.onSunC));
  }
}

// ---------- ML Lab ----------
STAGE = 'ML Lab';
{
  const w = AL('v', { gap: 28, parent: root, name: 'ML Lab' });
  const h = AL('h', { gap: 16, align: 'CENTER', parent: w });
  T(h, 'ML Lab', 36, 'hx', P.labInk);
  const tag = AL('h', { fill: '#2A2F36', r: 999, pad: [8, 16, 8, 16], parent: h }); T(tag, 'Li Shen\'s testing tool · not part of the MyPet app', 15, 's', P.white);
  const lab = AL('h', { fill: P.lab, r: 24, pad: 32, gap: 24, parent: w, name: 'ML Lab board' });
  lab.strokes = solid('#C9CED4'); lab.strokeWeight = 2; lab.dashPattern = [10, 8];
  const col = (title, wd) => { const c = AL('v', { fill: P.white, r: 16, pad: 24, gap: 14, parent: lab }); c.resize(wd, 100); c.primaryAxisSizingMode = 'AUTO'; T(c, title, 20, 'h', P.labInk); return c; };
  const sc = col('Scores on held-out clips', 360);
  for (const [k, v, sub] of [['Cat or dog', '90%', '346 of 383 clips'], ['Dog energy', '50%', '100 of 200 · chance 33%'], ['Dog mood', '45%', '89 of 200 · chance 33%'], ['Cat context', '36%', '34 of 94 · chance 33%']]) {
    const r = AL('h', { align: 'CENTER', parent: sc, fillW: true }); const t = AL('v', { parent: r, grow: true }); T(t, k, 16, 's', P.labInk); T(t, sub, 13, 'r', P.labSoft); T(r, v, 28, 'hx', P.labInk);
  }
  const lib = col('Test library', 460);
  const hdr = AL('h', { parent: lib, fillW: true }); for (const [t, wd] of [['Clip', 170], ['True', 110], ['Model', 110]]) T(hdr, t, 13, 's', P.labSoft, { w: wd });
  for (const [c, tr, pr, ok] of [['dog_0412.wav', 'High', 'High', true], ['dog_0533.wav', 'Low', 'Medium', false], ['cat_B03_07.wav', 'Food', 'Food', true], ['cat_N11_02.wav', 'Isolation', 'Brushing', false], ['dog_0871.wav', 'Positive', 'Positive', true]]) {
    const r = AL('h', { align: 'CENTER', parent: lib, fillW: true, pad: [6, 0, 6, 0] });
    T(r, c, 14, 'r', P.labInk, { w: 170 }); T(r, tr, 14, 'r', P.labInk, { w: 110 }); T(r, pr, 14, 's', P.labInk, { w: 110 }); I(r, ok ? 'check_circle' : 'cancel', 20, ok ? P.loggedEdge : '#9AA3AD');
  }
  const tc = col('Try a clip', 320);
  const drop = AL('v', { fill: P.lab, r: 14, pad: 24, gap: 8, align: 'CENTER', parent: tc, fillW: true }); drop.strokes = solid('#9AA3AD'); drop.strokeWeight = 1.5; drop.dashPattern = [6, 6];
  I(drop, 'upload_file', 36, P.labSoft); T(drop, 'Drop a clip or record', 14, 's', P.labSoft);
  T(tc, 'Shows sound labels, scores per class and timing (ms) for each clip', 13, 'r', P.labSoft, { w: 270 });
  T(tc, 'Repo: ml/flutter/behaviour_bench', 13, 's', P.labInk);
}

// ---------- prototype links ----------
STAGE = 'prototype links';
const go = async (node, dest) => { if (!node || !dest) return; try { await node.setReactionsAsync([{ trigger: { type: 'ON_CLICK' }, actions: [{ type: 'NODE', destinationId: dest.id, navigation: 'NAVIGATE', transition: { type: 'DISSOLVE', easing: { type: 'EASE_OUT' }, duration: 0.2 }, preserveScrollPosition: false, resetVideoPosition: false }] }]); } catch (e) {} };
await go(S.notifLog, S.quick); await go(S.logNow, S.quick); await go(S.save, S.today2); await go(S.flagCard, S.insights);
await go(S.rec, S.result); await go(R1.retake, S.check); await go(R1.save, S.today2);
const tab = (scr, name) => scr.findOne(n => n.name === 'Tab ' + name);
for (const scr of [S.today, S.today2, S.check, S.insights, S.pets, S.early]) {
  await go(tab(scr, 'Today'), S.today2); await go(tab(scr, 'Pets'), S.pets); await go(tab(scr, 'Check'), S.check); await go(tab(scr, 'Insights'), S.insights);
}
const qb = S.quick.findOne(n => n.name === 'icon/arrow_back'); await go(qb, S.today);
try {
  const fs = page.flowStartingPoints.filter(f => !String(f.name).startsWith('MyPet v2'));
  page.flowStartingPoints = fs.concat([{ nodeId: S.reminder.id, name: 'MyPet v2 · Log in 3 taps' }, { nodeId: S.today2.id, name: 'MyPet v2 · Notice a change' }, { nodeId: S.check.id, name: 'MyPet v2 · Check a clip' }]);
} catch (e) {}

figma.viewport.scrollAndZoomIntoView([root]);
figma.closePlugin('MyPet hi-fi v2 added below the wireframes');
})().catch(e => { const st = String((e && e.stack) || '').split('\n').slice(0, 3).join(' | '); figma.closePlugin('MyPet error at [' + STAGE + ']: ' + (e && e.message ? e.message : e) + ' · ' + st.slice(0, 120)); });
