// Network-graph animation, ported from the portfolio hero: drifting nodes, links between close neighbours,
// and "packets" that travel along a link from time to time. Motion is time-based, so the look is the same at any
// frame rate; the frame rate itself is capped (default 20 fps) and can be lowered or paused by the caller.
export function startNetwork(canvas, options = {}) {
  const o = {
    maxNodes: 70,          // upper bound on the node count
    area: 16000,           // one node per `area` CSS px²
    linkDist: 140,         // CSS px under which two nodes are linked
    speed: 7.5,            // max node speed per axis, CSS px / second
    nodeColor: '#5c6b7a',
    linkAlpha: 0.5,
    nodeAlpha: 0.7,
    packetColor: '#00e5ff',
    hoverColor: '#00ff9c',
    packetRate: 0.036,     // chance per linked pair per second to emit a packet
    maxPackets: 12,
    fps: 20,
    maxDpr: 1,             // a soft background does not need device pixels: 2.25x fewer pixels to fill at 150 % scaling
    ...options,
  };
  const ctx = canvas.getContext('2d');
  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const dpr = Math.min(window.devicePixelRatio || 1, o.maxDpr);
  const pointer = { x: -999, y: -999 };
  let w = 0, h = 0, nodes = [], packets = [];
  let fps = o.fps, paused = false, raf = 0, timer = 0, last = 0;

  function resize() {
    const r = canvas.getBoundingClientRect();
    w = r.width; h = r.height;
    canvas.width = Math.round(w * dpr); canvas.height = Math.round(h * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    const count = Math.round(Math.min(o.maxNodes, (w * h) / o.area));
    nodes = Array.from({ length: count }, () => ({
      x: Math.random() * w, y: Math.random() * h,
      vx: (Math.random() - 0.5) * 2 * o.speed, vy: (Math.random() - 0.5) * 2 * o.speed,
      r: Math.random() * 1.6 + 0.8,
    }));
    packets = [];
  }

  function draw(dt) {
    ctx.clearRect(0, 0, w, h);
    for (const n of nodes) {
      n.x += n.vx * dt; n.y += n.vy * dt;
      if (n.x < 0 || n.x > w) { n.vx *= -1; n.x = Math.max(0, Math.min(w, n.x)); }
      if (n.y < 0 || n.y > h) { n.vy *= -1; n.y = Math.max(0, Math.min(h, n.y)); }
    }
    ctx.lineWidth = 0.6;
    ctx.strokeStyle = o.nodeColor;
    for (let i = 0; i < nodes.length; i++) {
      for (let j = i + 1; j < nodes.length; j++) {
        const a = nodes[i], b = nodes[j];
        const d = Math.hypot(a.x - b.x, a.y - b.y);
        if (d >= o.linkDist) continue;
        ctx.globalAlpha = (1 - d / o.linkDist) * o.linkAlpha;
        ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
        if (packets.length < o.maxPackets && Math.random() < o.packetRate * dt) packets.push({ a, b, t: 0 });
      }
    }
    packets = packets.filter(p => (p.t += 0.72 * dt) < 1 && Math.hypot(p.a.x - p.b.x, p.a.y - p.b.y) < o.linkDist);
    ctx.globalAlpha = 0.9;
    ctx.fillStyle = o.packetColor;
    for (const p of packets) {
      ctx.beginPath();
      ctx.arc(p.a.x + (p.b.x - p.a.x) * p.t, p.a.y + (p.b.y - p.a.y) * p.t, 1.8, 0, Math.PI * 2);
      ctx.fill();
    }
    for (const n of nodes) {
      const near = Math.hypot(n.x - pointer.x, n.y - pointer.y) < 120;
      ctx.globalAlpha = near ? 1 : o.nodeAlpha;
      ctx.fillStyle = near ? o.hoverColor : o.nodeColor;
      ctx.beginPath(); ctx.arc(n.x, n.y, near ? n.r + 1 : n.r, 0, Math.PI * 2); ctx.fill();
    }
    ctx.globalAlpha = 1;
  }

  // One timer tick per wanted frame, then a single requestAnimationFrame to draw in sync with the compositor.
  // (A bare requestAnimationFrame loop would wake the renderer at the display rate, e.g. 165 Hz, just to skip frames.)
  function frame(now) {
    const elapsed = now - last;
    last = now;
    draw(Math.min(elapsed, 250) / 1000);   // clamp: no jump after a pause or a throttled tab
    timer = setTimeout(() => { raf = requestAnimationFrame(frame); }, 1000 / fps - 4);
  }
  function run() {
    cancelAnimationFrame(raf);
    clearTimeout(timer);
    if (paused || reduced || document.hidden || fps <= 0) return;
    last = performance.now();
    raf = requestAnimationFrame(frame);
  }

  let resizeTimer;
  window.addEventListener('resize', () => { clearTimeout(resizeTimer); resizeTimer = setTimeout(() => { resize(); draw(0); }, 150); });
  window.addEventListener('pointermove', e => { const r = canvas.getBoundingClientRect(); pointer.x = e.clientX - r.left; pointer.y = e.clientY - r.top; });
  document.addEventListener('pointerleave', () => { pointer.x = pointer.y = -999; });
  document.addEventListener('visibilitychange', run);

  resize();
  draw(0);
  run();

  return {
    setFps(value) { if (value !== fps) { fps = value; run(); } },
    setPaused(value) { if (value !== paused) { paused = value; run(); } },
  };
}
