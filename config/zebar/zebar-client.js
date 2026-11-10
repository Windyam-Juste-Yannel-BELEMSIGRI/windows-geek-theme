// Loads the Zebar client library.
// Preferred: the pinned copy that install step 10 downloads into ./vendor (hash-checked, no network needed at logon).
// Fallback: the same version from esm.sh, as the official starter pack does (only if the local copy is missing).
let zebar;
try {
  zebar = await import('./vendor/zebar.mjs');
} catch {
  zebar = await import('https://esm.sh/zebar@3.0.3');
}
export default zebar;

// --- small helpers shared by the bar and the HUD ---
export function el(tag, cls, text) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text !== undefined) e.textContent = text;
  return e;
}

// Write text only when it changed, so nothing repaints (or restarts an animation) for identical values.
export function setText(node, text) {
  if (node.textContent !== text) node.textContent = text;
}

export function formatRate(bytesPerSec) {
  const b = Number(bytesPerSec) || 0;
  if (b >= 1e6) return (b / 1e6).toFixed(1) + 'M';
  if (b >= 1e3) return Math.round(b / 1e3) + 'k';
  return Math.round(b) + 'B';
}

export function formatUptime(ms) {
  const m = Math.floor((Number(ms) || 0) / 60000);
  const d = Math.floor(m / 1440);
  const h = Math.floor((m % 1440) / 60);
  return (d ? d + 'd ' : '') + (h ? h + 'h ' : '') + (m % 60) + 'm';
}

export const usageLevel = u => (u > 90 ? 'crit' : u > 80 ? 'warn' : '');

// Typewriter that cycles through `words` (same timings as the portfolio hero).
export function typewriter(node, words) {
  if (words.length < 2 || matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  let w = 0;
  let i = words[0].length;
  let erasing = true;
  const tick = () => {
    const word = words[w];
    i += erasing ? -1 : 1;
    node.textContent = word.slice(0, i);
    let wait = erasing ? 35 : 70;
    if (!erasing && i === word.length) { erasing = true; wait = 2200; }
    else if (erasing && i === 0) { erasing = false; w = (w + 1) % words.length; wait = 300; }
    setTimeout(tick, wait);
  };
  setTimeout(tick, 2400);
}
