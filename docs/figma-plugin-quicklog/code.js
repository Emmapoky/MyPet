// MyPet quick-log: the very short-form log (Lingsha's idea)
// drawn below whatever is on the current page.
// Run from Figma desktop: Plugins > Development > MyPet quick-log.

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
STAGE = 'placement';
const page = figma.currentPage;
let minX = 0, maxY = 0;
if (page.children.length) { minX = Math.min.apply(null, page.children.map(n => n.x)); maxY = Math.max.apply(null, page.children.map(n => n.y + n.height)); }
const old = page.findOne(n => n.name === 'MyPet quick-log' && n.parent === page);
if (old) { maxY = old.y - 400; old.remove(); }
const root = AL('v', { gap: 100, pad: 120, fill: '#FBFAFE', name: 'MyPet quick-log', r: 40 });
page.appendChild(root); root.x = minX; root.y = maxY + 400;
const head = AL('h', { gap: 28, align: 'CENTER', parent: root });
const logo = circle(head, 120, P.brand, 'bolt', P.white, 68); logo.cornerRadius = 34; logo.fills = grad(P.heroA, P.heroB);
const ht = AL('v', { gap: 6, parent: head });
T(ht, 'MyPet · Quick log', 64, 'hx', P.ink);
T(ht, 'Log a normal day in under 5 seconds, from five doors, without opening the app', 24, 'r', P.inkSoft);
const scrTitle = (parent, t) => T(parent, t, 36, 'hx', P.ink);
const flowRow = (title) => { const w = AL('v', { gap: 28, parent: root, name: title }); scrTitle(w, title); const r = AL('h', { gap: 48, align: 'MIN', parent: w }); return r; };
const labelled = (row, label, scr) => { const c = AL('v', { gap: 14, parent: row, name: label }); T(c, label, 20, 'h', P.inkSoft); c.appendChild(scr); return c; };
const NOTE = (parent, t) => { const n = AL('v', { fill: P.sunC, r: 16, pad: 14, parent, name: 'Note' }); n.resize(390, 10); n.primaryAxisSizingMode = 'AUTO'; T(n, t, 15, 'r', P.onSunC, { w: 'fill' }); return n; };
STAGE = "frames";
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
const NX = {};
const lockFrame = (name) => {
  const s = figma.createFrame(); s.name = name; s.resize(390, 844); s.cornerRadius = 32; s.clipsContent = true;
  s.fills = grad(P.heroA, '#2B2340', 'v'); s.layoutMode = 'VERTICAL'; s.counterAxisAlignItems = 'CENTER'; s.primaryAxisSizingMode = 'FIXED'; s.counterAxisSizingMode = 'FIXED';
  s.paddingTop = 100; s.paddingLeft = s.paddingRight = 16; s.itemSpacing = 6;
  return s;
};
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
// Widgets: home and lock screen (matches app e752227; no pet names, free account)
{
  const s = figma.createFrame(); s.name = 'Widgets'; s.resize(390, 844); s.cornerRadius = 32; s.clipsContent = true;
  s.fills = grad('#8E7CF0', '#F27BAA', 'v'); s.layoutMode = 'VERTICAL'; s.primaryAxisSizingMode = 'FIXED'; s.counterAxisSizingMode = 'FIXED';
  s.paddingTop = 90; s.paddingLeft = s.paddingRight = 16; s.itemSpacing = 14;
  T(s, 'Lock screen', 15, 's', P.white);
  const lk = AL('h', { gap: 10, align: 'CENTER', parent: s });
  const cw = circle(lk, 56, '#FFFFFF', 'pets', P.white, 28); cw.fills = solid('#FFFFFF', 0.25); cw.name = 'Lock circular';
  const rect = AL('v', { r: 16, pad: [8, 14, 8, 14], gap: 2, parent: lk, name: 'Lock rectangular' }); rect.fills = solid('#FFFFFF', 0.25);
  const rh = AL('h', { gap: 6, align: 'CENTER', parent: rect }); I(rh, 'pets', 16, P.white); T(rh, 'MyPet', 13, 'h', P.white);
  T(rect, 'How was today?', 14, 's', P.white); T(rect, 'Tap to log', 12, 'r', P.white);
  const inl = AL('h', { gap: 6, align: 'CENTER', parent: s, name: 'Lock inline' }); I(inl, 'pets', 16, P.white); T(inl, 'Log today', 14, 's', P.white);
  T(s, 'Home screen', 15, 's', P.white);
  const w1 = AL('v', { r: 24, pad: 16, gap: 6, parent: s, shadow: true, name: 'Small widget' }); w1.fills = grad(P.heroA, P.heroB); w1.resize(160, 160); w1.primaryAxisSizingMode = 'FIXED'; w1.counterAxisSizingMode = 'FIXED';
  I(w1, 'pets', 32, P.white); AL('v', { parent: w1, grow: true }); T(w1, 'How was today?', 18, 'hx', P.white); T(w1, 'Tap to log', 13, 's', P.white);
  const w3 = AL('h', { r: 24, pad: 16, gap: 14, align: 'CENTER', parent: s, fillW: true, shadow: true, name: 'Medium widget' }); w3.fills = grad(P.heroA, P.heroB);
  const l = AL('v', { gap: 4, parent: w3, grow: true }); I(l, 'pets', 28, P.white); T(l, 'How was today?', 18, 'hx', P.white); T(l, 'Ate, energy, toileting', 13, 's', P.white);
  const rr = AL('v', { gap: 8, parent: w3 }); button(rr, 'All normal', { kind: 'outlined' }); button(rr, "Something's different", { kind: 'outlined' });
  T(s, 'Every tap opens mypet://app/log (the short form)', 13, 'r', P.white, { w: 'fill' });
  NX.widgets = s;
}
// Short form: the 10-second sheet (matches app 52ba07c)
{
  const { s, body } = phone('Short form', { title: 'Quick log', back: true });
  const pr = AL('h', { gap: 8, align: 'CENTER', parent: body }); petChip(pr, 'Biscuit', P.pets[0], true); petChip(pr, 'Mochi · done', P.pets[1], false);
  T(body, "How was Biscuit's day?", 24, 'hx', P.ink, { w: 'fill' });
  for (const [t, o, sel] of [['Ate', ['All', 'Some', 'None'], 0], ['Energy', ['Low', 'Usual', 'High'], 1], ['Toileting normal', ['Yes', 'No', "Didn't see"], 0]]) {
    const c = card(body, { gap: 10 }); T(c, t, 17, 'h', P.ink);
    const ch = AL('h', { gap: 8, parent: c, fillW: true }); o.forEach((x, i) => chip(ch, x, i === sel, { grow: true }));
  }
  T(body, "\"Didn't see\" is never counted as a problem", 13, 'r', P.inkSoft, { w: 'fill' });
  AL('v', { parent: body, grow: true });
  button(body, 'Save', { fill: true });
  NX.short = s;
}
// Short form, not yet complete
{
  const { s, body } = phone('Short form, not complete', { title: 'Quick log', back: true });
  T(body, "How was Biscuit's day?", 24, 'hx', P.ink, { w: 'fill' });
  for (const [t, o, sel] of [['Ate', ['All', 'Some', 'None'], 0], ['Energy', ['Low', 'Usual', 'High'], -1], ['Toileting normal', ['Yes', 'No', "Didn't see"], -1]]) {
    const c = card(body, { gap: 10 }); T(c, t, 17, 'h', P.ink);
    const ch = AL('h', { gap: 8, parent: c, fillW: true }); o.forEach((x, i) => chip(ch, x, i === sel, { grow: true }));
  }
  AL('v', { parent: body, grow: true });
  button(body, 'Answer all three to save', { kind: 'tonal' });
  NX.short2 = s;
}
// Done: shown after any quick door
{
  const { s, body } = phone('Logged confirmation', { title: 'Quick log' });
  const h = AL('v', { fill: grad(P.heroA, P.heroB), r: 24, pad: 24, gap: 6, align: 'CENTER', parent: body, fillW: true, shadow: true, name: 'Hero' });
  circle(h, 72, P.white, 'check', P.brand, 44);
  T(h, 'Biscuit is logged', 24, 'hx', P.white, { align: 'CENTER' }); T(h, 'Today 2 of 3 done', 15, 's', P.white, { align: 'CENTER' });
  button(body, 'Undo (10)', { kind: 'outlined', icon: 'undo' });
  button(body, 'Next: Mochi', { fill: true });
  T(body, 'Shows "Done" when every pet is logged', 13, 'r', P.inkSoft, { w: 'fill' });
  NX.done = s;
}
// Settings: which doors are on
{
  const { s, body } = phone('Quick-log doors', { title: 'Quick log', back: true });
  T(body, 'Choose how you log fast', 16, 'r', P.inkSoft, { w: 'fill' });
  for (const [ic, t, sub, on] of [['notifications', 'Reminder buttons', 'All normal from the notification', true], ['mic', 'Voice', 'Say how the day went', true], ['graphic_eq', 'Siri', '"Tell MyPet about today"', true], ['widgets', 'Widgets', 'Home and lock screen', false], ['edit_note', 'Short form', 'Three taps, one save', true]]) {
    const c = card(body, { gap: 0 }); const r = AL('h', { gap: 12, align: 'CENTER', parent: c, fillW: true });
    circle(r, 44, P.brandC, ic, P.brand, 24); const tt = AL('v', { gap: 2, parent: r, grow: true }); T(tt, t, 17, 'h', P.ink); T(tt, sub, 13, 'r', P.inkSoft);
    const sw = AL('h', { fill: on ? P.brand : P.track, r: 999, pad: 3, parent: r, align: 'CENTER' }); sw.resize(52, 30); sw.primaryAxisSizingMode = 'FIXED'; sw.counterAxisSizingMode = 'FIXED'; sw.primaryAxisAlignItems = on ? 'MAX' : 'MIN'; circle(sw, 24, P.white);
  }
  NX.doors = s;
}

STAGE = 'layout';
const r1 = flowRow('1 · Five doors, one tap or less');
labelled(r1, 'Notification (hold)', NX.notif); labelled(r1, 'Siri', NX.siri); labelled(r1, 'Voice', NX.voice); labelled(r1, 'Widgets (lock + home)', NX.widgets); labelled(r1, 'Short form', NX.short); labelled(r1, 'Short form, not complete', NX.short2);
const r2 = flowRow('2 · After the log, and settings');
labelled(r2, 'Confirmation', NX.done); labelled(r2, 'Quick-log doors', NX.doors);
const nb = AL('v', { fill: P.surface, r: 28, pad: 36, gap: 14, parent: r2, shadow: true, name: 'Rules'}); nb.resize(560, 100); nb.primaryAxisSizingMode = 'AUTO';
T(nb, 'Rules for every door', 28, 'hx', P.ink);
for (const t of ['One tap = "All normal" for the selected pet.', 'Every door ends on the same confirmation, with Undo for 10 seconds.', 'Widgets open mypet://app/log on the short form. Save needs all three rows answered.', 'Same log entry as the full Quick log: one record, no duplicates.', 'Pet comes from the notification, or the last pet used.', 'Widgets only open the app on the short form (deep link); they never log by themselves.']) { const l = AL('h', { gap: 10, parent: nb, fillW: true }); I(l, 'check_circle', 20, P.brand); T(l, t, 17, 'r', P.ink, { grow: true }); }
const ab = AL('v', { fill: P.sunC, r: 28, pad: 36, gap: 12, parent: r2, name: 'Assumptions' }); ab.resize(480, 100); ab.primaryAxisSizingMode = 'AUTO';
T(ab, 'Assumed, to confirm with Lingsha', 26, 'hx', P.onSunC);
for (const t of ['Short form = 3 rows: Ate All/Some/None, Energy Low/Usual/High, Toileting Yes/No/Didn\'t see (as built, 52ba07c).', 'Widget tap opens the short form for the pet shown (free Apple account: no logging inside the widget).', 'No clip or weight in the short form.']) T(ab, '• ' + t, 16, 'r', P.onSunC, { w: 'fill' });
figma.viewport.scrollAndZoomIntoView([root]);
figma.closePlugin('MyPet quick-log added below your frames');
})().catch(e => { const st = String((e && e.stack) || '').split('\n').slice(0, 3).join(' | '); figma.closePlugin('MyPet error at [' + STAGE + ']: ' + (e && e.message ? e.message : e) + ' · ' + st.slice(0, 120)); });
