// Original soundtrack + SFX for the IronFit demo, synthesized from scratch (no third-party samples).
// 120 BPM, 120 s: one beat = 15 video frames at 30 fps. Run: npm run audio
import fs from 'node:fs';
const SR = 44100, DUR = 120, BEAT = 0.5, N = SR * DUR;
const L = new Float32Array(N), R = new Float32Array(N);
let seed = 7;
const rnd = () => ((seed = (seed * 1664525 + 1013904223) >>> 0) / 2147483648) - 1;
const hz = (m) => 440 * 2 ** ((m - 69) / 12);
const add = (t, len, fn, pan = 0, g = 1) => {
  const s = Math.floor(t * SR), n = Math.floor(len * SR);
  const gl = g * Math.cos((pan + 1) * Math.PI / 4), gr = g * Math.sin((pan + 1) * Math.PI / 4);
  for (let i = 0; i < n; i++) { const k = s + i; if (k < 0 || k >= N) continue; const v = fn(i / SR, i / n); L[k] += v * gl; R[k] += v * gr; }
};
const kick = (t, g = 0.85) => add(t, 0.32, (x) => Math.sin(2 * Math.PI * (48 * x + 26 * (1 - Math.exp(-x * 28)) / 5.2)) * Math.exp(-x * 11), 0, g);
const clap = (t, g = 0.2) => { let lp = 0; add(t, 0.2, (x) => { const n = rnd(); lp += (n - lp) * 0.5; return (n - lp) * Math.exp(-x * 24) * (x < 0.025 ? 0.5 + 0.5 * Math.sin(x * 800) : 1); }, 0.05, g); };
const hat = (t, g = 0.06, d = 55) => { let lp = 0; add(t, 0.09, (x) => { const n = rnd(); lp += (n - lp) * 0.75; return (n - lp) * Math.exp(-x * d) * 2; }, 0.25, g); };
const bass = (t, m, len, g = 0.3) => add(t, len, (x, p) => { const f = hz(m); return Math.tanh(1.6 * (Math.sin(2 * Math.PI * f * x) + 0.35 * Math.sin(4 * Math.PI * f * x))) * Math.min(1, x * 200) * (1 - p) ** 0.6; }, 0, g);
const pluck = (t, m, pan, g = 0.09) => [0, 0.375, 0.75].forEach((d, i) => add(t + d, 0.5, (x) => { const f = hz(m); return (Math.sin(2 * Math.PI * f * x) + 0.4 * Math.sin(4 * Math.PI * f * x) * Math.exp(-x * 12) + 0.15 * Math.sin(6 * Math.PI * f * x) * Math.exp(-x * 20)) * Math.exp(-x * 8) * Math.min(1, x * 400); }, i % 2 ? -pan : pan, g * 0.42 ** i));
const pad = (t, notes, len, g = 0.05, bright = 5) => notes.forEach((m, j) => [-0.06, 0.06].forEach((det, d) => add(t, len, (x, p) => { const f = hz(m + det); let v = 0; for (let h = 1; h <= bright; h++) v += Math.sin(2 * Math.PI * f * h * x + j) / (h * h * 0.9); const duck = t >= 13 && t < 115 ? 0.45 + 0.55 * Math.min(1, ((x % BEAT) / BEAT) * 1.6) : 1; return v * duck * Math.min(1, x / 0.15) * Math.min(1, (1 - p) * 8); }, d ? 0.6 : -0.6, g)));
const riser = (t, len, g = 0.14) => { let lp = 0; add(t, len, (x, p) => { const n = rnd(); lp += (n - lp) * (0.02 + 0.5 * p * p); return lp * p * p * 1.6; }, 0, g); };
const boom = (t, g = 0.8) => { let lp = 0; add(t, 2.2, (x) => { const n = rnd(); lp += (n - lp) * 0.05; return Math.sin(2 * Math.PI * (38 * x + 3 * (1 - Math.exp(-x * 9)))) * Math.exp(-x * 2.4) + lp * 1.4 * Math.exp(-x * 5); }, 0, g); };

// Chapters follow src/config.ts: member 10 s, coach 43 s, admin 77 s, benefits 110 s, end 115 s.
const PROG = {
  member: {ch: [[57, 60, 64, 71], [53, 57, 60, 67], [48, 55, 60, 64], [55, 59, 62, 69]], root: [33, 29, 36, 31]}, // Am F C G
  coach: {ch: [[53, 57, 60, 67], [55, 59, 62, 69], [57, 60, 64, 71], [48, 55, 60, 64]], root: [29, 31, 33, 36]}, // F G Am C
  admin: {ch: [[57, 60, 64, 71], [48, 55, 60, 64], [55, 59, 62, 69], [53, 57, 60, 67]], root: [33, 36, 31, 29]}, // Am C G F
};
const CH = PROG.member.ch;
const section = (t) => (t < 43 ? PROG.member : t < 77 ? PROG.coach : PROG.admin);
// Intro (0-10 s): hits on the hook words, riser into the logo
[0.5, 1.5, 2.5].forEach((t) => { boom(t, 0.55); clap(t, 0.12); });
for (let t = 0; t < 4; t += BEAT) hat(t, 0.05);
pad(0, [45, 52], 4.2, 0.06, 3); riser(3, 2, 0.2); boom(5, 0.95); pad(5, CH[0], 1, 0.05); pad(6, CH[3], 2, 0.05, 6); pad(8, CH[0], 2, 0.05, 6); riser(8.8, 1.2, 0.14);
[69, 72, 76, 79, 76, 72, 76, 83].forEach((m, i) => pluck(6 + i * 0.5, m, 0.4, 0.09));
// Chapter breaks: no drums, riser back into the groove
const BREAKS = [[10, 13], [43, 47], [77, 81], [110, 113]];
const inBreak = (t) => BREAKS.some(([a, b]) => t >= a && t < b);
BREAKS.forEach(([a, b], n) => { boom(a, 0.8); riser(b - 1.5, 1.5, 0.18); if (n < 3) [76, 79, 83, 88].forEach((m, i) => pluck(a + 0.5 + i * 0.5, m, 0.4, 0.07)); for (let t = a; t < b; t += BEAT) hat(t + 0.25, 0.04); });
for (let t = 41; t < 43; t += 0.25) clap(t, 0.05 + (t - 41) * 0.05);
for (let t = 75; t < 77; t += 0.25) clap(t, 0.05 + (t - 75) * 0.05);
// Groove, one beat at a time so chapters can start on any second
for (let tb = 10; tb < 115; tb += BEAT) {
  const bar = Math.floor(tb / 2), beat = Math.round((tb % 2) / BEAT), c = bar % 4, P = section(tb), brk = inBreak(tb);
  const energy = tb < 25 ? 1 : tb < 43 ? 2 : tb < 63 ? 2 : tb < 77 ? 3 : tb < 96 ? 2 : 3;
  if (beat === 0) pad(tb, P.ch[c], Math.min(2, 115 - tb), brk ? 0.045 : 0.034, brk ? 4 : 6);
  if (!brk) {
    kick(tb, 0.8);
    if (beat % 2 && tb >= 19) clap(tb);
    hat(tb + 0.25, 0.085);
    if (energy > 1) { hat(tb + 0.125, 0.03); hat(tb + 0.375, 0.035); }
    bass(tb + 0.25, P.root[c] + 12, 0.2, 0.24);
    if (energy > 1) bass(tb + 0.375, P.root[c] + 12, 0.11, 0.16);
    if (energy > 2 && beat === 3) bass(tb + 0.125, P.root[c] + 24, 0.1, 0.12);
  }
  const a = P.ch[c], pat = [0, 2, 1, 3, 2, 1, 3, 2, 0, 3, 2, 1, 3, 2, 1, 3], k = beat * 2;
  [0, 1].forEach((h) => { const n = pat[(k + h + (bar % 2) * 8) % 16]; pluck(tb + h * 0.25, a[n] + 12 + (energy > 2 && h && beat === 1 ? 12 : 0), (k + h) % 2 ? 0.5 : -0.5, brk ? 0.04 : 0.058); });
  if (energy > 2 && !brk && beat === 0) pluck(tb, a[3] + 24, 0.2, 0.05);
}
[13, 25, 47, 63, 81, 96].forEach((t) => boom(t, 0.38));
riser(113, 2, 0.22);
boom(115, 0.95); pad(115, [45, 52, 57, 60, 64, 71], 5, 0.036, 6); [81, 76, 72, 69].forEach((m, i) => pluck(115.5 + i * 0.5, m, 0.3, 0.1));

const write = (file, l, r, peak) => {
  let m = 0; for (let i = 0; i < l.length; i++) m = Math.max(m, Math.abs(l[i]), Math.abs(r[i]));
  const k = peak / (m || 1), b = Buffer.alloc(44 + l.length * 4);
  b.write('RIFF', 0); b.writeUInt32LE(36 + l.length * 4, 4); b.write('WAVEfmt ', 8); b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20); b.writeUInt16LE(2, 22); b.writeUInt32LE(SR, 24); b.writeUInt32LE(SR * 4, 28); b.writeUInt16LE(4, 32); b.writeUInt16LE(16, 34); b.write('data', 36); b.writeUInt32LE(l.length * 4, 40);
  for (let i = 0; i < l.length; i++) { b.writeInt16LE(Math.round(l[i] * k * 32767), 44 + i * 4); b.writeInt16LE(Math.round(r[i] * k * 32767), 46 + i * 4); }
  fs.writeFileSync(new URL('../public/audio/' + file, import.meta.url), b);
};
for (let i = 0; i < N; i++) { const t = i / SR, f = Math.min(1, t / 0.05) * Math.min(1, (DUR - t) / 2.2); L[i] = Math.tanh(L[i] * 0.95) * f; R[i] = Math.tanh(R[i] * 0.95) * f; }
write('music.wav', L, R, 0.8);
const sfx = (file, len, fn, peak = 0.7) => { const n = Math.floor(len * SR), l = new Float32Array(n), r = new Float32Array(n); for (let i = 0; i < n; i++) { const [a, b] = fn(i / SR, i / n); l[i] = a; r[i] = b; } write(file, l, r, peak); };
{ let lp = 0, hp = 0; sfx('whoosh.wav', 0.7, (x, p) => { const n = rnd(), e = Math.sin(Math.PI * p ** 0.75) ** 2; lp += (n - lp) * (0.03 + 0.35 * e); hp += (lp - hp) * 0.02; const v = (lp - hp) * e; return [v * (1 - p * 0.8), v * (0.2 + p * 0.8)]; }, 0.6); }
sfx('click.wav', 0.08, (x) => { const v = (Math.sin(2 * Math.PI * 2100 * x) + 0.5 * rnd()) * Math.exp(-x * 120); return [v, v]; }, 0.5);
sfx('pop.wav', 0.22, (x) => { const v = Math.sin(2 * Math.PI * (520 * x + 900 * x * x)) * Math.exp(-x * 22) * Math.min(1, x * 600); return [v, v]; }, 0.5);
console.log('audio written to public/audio');
