import {AbsoluteFill, useCurrentFrame} from 'remotion';
import {colors} from '../config';
import {easeInOut, float, kf, mix, pop, prog} from '../lib/anim';
import {useLayout} from '../lib/layout';
import {SceneKey, endOf, starts} from '../timeline';
import {PHONE} from './ui';
import {AiCoachScreen} from '../scenes/S03AiCoach';
import {PlanningScreen} from '../scenes/S04Planning';
import {GuidedScreen} from '../scenes/S05Guided';
import {ProgressScreen} from '../scenes/S06Progress';
import {CoachingScreen} from '../scenes/S07Coaching';
import {AdminSplash, WorkspaceScreen} from '../scenes/C0Chapters';
import {CoachHomeScreen} from '../scenes/C1CoachHome';
import {CoachProgramScreen} from '../scenes/C2CoachProgram';
import {CoachFeedbackScreen} from '../scenes/C3CoachFeedback';
import {CoachAttendanceScreen} from '../scenes/C4CoachAttendance';
import {AdminDash} from '../scenes/A1AdminDash';
import {AdminRequests} from '../scenes/A2AdminRequests';
import {AdminRisk} from '../scenes/A3AdminRisk';
import {AdminManage} from '../scenes/A4AdminManage';
import {AdminShell} from './AdminShell';

const order = ['aiCoach', 'planning', 'guided', 'progress', 'coaching', 'chCoach', 'coachHome', 'coachProgram', 'coachFeedback', 'coachAttendance'] as const;
const screens = {aiCoach: AiCoachScreen, planning: PlanningScreen, guided: GuidedScreen, progress: ProgressScreen, coaching: CoachingScreen, chCoach: WorkspaceScreen, coachHome: CoachHomeScreen, coachProgram: CoachProgramScreen, coachFeedback: CoachFeedbackScreen, coachAttendance: CoachAttendanceScreen};
const adminOrder = ['adminDash', 'adminRequests', 'adminRisk', 'adminManage'] as const;
const adminScreens = {adminDash: AdminDash, adminRequests: AdminRequests, adminRisk: AdminRisk, adminManage: AdminManage};
const ADMIN = starts.chAdmin;
/** The phone alternates right / left from one scene to the next. */
export const phoneSide = (i: number) => (i % 2 ? 'left' : 'right');

/** Where the device sits in each scene (center). Shared by the device and the callouts. */
export const usePhonePos = () => {
  const {portrait, width} = useLayout();
  const f = useCurrentFrame();
  const xs: [SceneKey, number][] = [...order.map((k, i): [SceneKey, number] => [k, phoneSide(i) === 'right' ? 1390 : 530]), ['chAdmin', 960]];
  const keys: [number, number][] = [];
  xs.forEach(([k, x], i) => { if (i) keys.push([starts[k] - 16, xs[i - 1][1]]); keys.push([i ? starts[k] + 16 : starts[k], x]); });
  return {x: portrait ? width / 2 : kf(f, keys), y: portrait ? 1262 : kf(f, [[ADMIN - 16, 540], [ADMIN + 16, 706]]), scale: portrait ? 1.3 : 1.1};
};

type Rect = {x: number; y: number; w: number; h: number; r: number; bg: string; ring?: number};
/** Shared element: the end of one screen becomes the start of the next (phone coordinates). */
const morphs: {at: number; from: Rect; to: Rect}[] = [
  {at: starts.planning, from: {x: 18, y: 386, w: 348, h: 236, r: 18, bg: '#F1EDE7'}, to: {x: 16, y: 432, w: 358, h: 214, r: 24, bg: '#FDFCFA'}},
  {at: starts.guided, from: {x: 33, y: 486, w: 324, h: 60, r: 16, bg: '#F4EBDF'}, to: {x: 125, y: 221, w: 140, h: 140, r: 70, bg: '#FF9800', ring: 12}},
  {at: starts.progress, from: {x: 125, y: 221, w: 140, h: 140, r: 70, bg: '#FF9800', ring: 12}, to: {x: 38, y: 440, w: 310, h: 4, r: 2, bg: '#FF9800'}},
  {at: starts.coaching, from: {x: 340, y: 409, w: 16, h: 16, r: 8, bg: colors.ember}, to: {x: 33, y: 121, w: 58, h: 58, r: 29, bg: colors.amber}},
  {at: starts.coachHome, from: {x: 194, y: 386, w: 180, h: 62, r: 16, bg: colors.amber}, to: {x: 16, y: 104, w: 358, h: 92, r: 20, bg: '#26272D'}},
];
const hex = (c: string) => [1, 3, 5].map((i) => parseInt(c.slice(i, i + 2), 16));
const mixColor = (a: string, b: string, p: number) => { const x = hex(a), y = hex(b); return `rgb(${x.map((v, i) => Math.round(mix(v, y[i], p))).join(',')})`; };

const Morph: React.FC<{f: number}> = ({f}) => {
  const m = morphs.find((o) => f >= o.at - 13 && f <= o.at + 20);
  if (!m) return null;
  const p = prog(f, m.at - 10, m.at + 12, easeInOut);
  const o = prog(f, m.at - 13, m.at - 12) * (1 - prog(f, m.at + 12, m.at + 20));
  const v = (k: 'x' | 'y' | 'w' | 'h' | 'r') => mix(m.from[k], m.to[k], p);
  const bg = mixColor(m.from.bg, m.to.bg, p);
  const ring = m.to.ring ? mix(70, m.to.ring, prog(p, 0.45, 1, (t) => t)) : m.from.ring ? mix(m.from.ring, 2, p) : 0;
  return <div style={{position: 'absolute', left: v('x'), top: v('y'), width: v('w'), height: v('h'), borderRadius: v('r'), boxSizing: 'border-box', opacity: o, background: ring && ring < v('h') / 2 - 1 ? 'transparent' : bg, border: ring && ring < v('h') / 2 - 1 ? `${ring}px solid ${bg}` : undefined}} />;
};

/** One device that lives through six scenes: a floating phone that finally unfolds into a desktop window. */
export const Device: React.FC = () => {
  const f = useCurrentFrame();
  const {portrait} = useLayout();
  const pos = usePhonePos();
  const s0 = starts.aiCoach - 12, end = endOf('adminManage');
  if (f < s0 || f > end + 16) return null;
  const inn = pop(f, s0, 17, 80), out = prog(f, end - 12, end + 12, easeInOut);
  const d = prog(f, ADMIN - 14, ADMIN + 18, easeInOut);
  const W = portrait ? 936 : 1380, H = portrait ? 1180 : 680;
  const w = mix(PHONE.w, W, d), h = mix(PHONE.h, H, d), r = mix(50, 24, d), bezel = mix(11, 5, d);
  const scale = mix(pos.scale, 1, d);
  const swingKeys: [number, number][] = [];
  order.forEach((k, n) => { const v = phoneSide(n) === 'right' ? -9 : 9; swingKeys.push([starts[k] + (n ? 16 : 0), v * 1.1], [endOf(k) - 16, v * 0.65]); });
  const swing = kf(f, swingKeys) * (portrait ? 0.55 : 1);
  const active = prog(f, starts.adminRequests - 12, starts.adminRequests + 10, easeInOut) * 2;
  const bump = order.slice(1).reduce((n: number, k) => n + Math.sin(prog(f, starts[k] - 14, starts[k] + 16, (t) => t) * Math.PI), 0);
  return (
    <AbsoluteFill style={{perspective: 2200}}>
      <div style={{position: 'absolute', left: pos.x, top: pos.y + float(f, 9, 140) * (1 - d * 0.6) + (1 - inn) * 900, transform: `translate(-50%,-50%) scale(${scale * (1 - bump * 0.07) * (1 + 0.03 * prog(f, ADMIN, end, (t) => t)) * (1 - out * 0.9)}) rotateY(${swing * (1 - d)}deg) rotateX(${float(f, 2.2, 170, 1) * (1 - d)}deg) rotateZ(${(1 - inn) * 14}deg)`, opacity: 1 - prog(f, end - 2, end + 12)}}>
        <div style={{position: 'relative', width: w + bezel * 2, height: h + bezel * 2, borderRadius: r + bezel, background: 'linear-gradient(145deg,#4A4C55,#1B1C20 35%,#101114)', boxShadow: '0 60px 120px rgba(0,0,0,.45), 0 18px 40px rgba(0,0,0,.3), inset 0 0 0 1.5px rgba(255,255,255,.16)'}}>
          <div style={{position: 'absolute', left: bezel, top: bezel, width: w, height: h, borderRadius: r, overflow: 'hidden', background: '#0B0B0D'}}>
            {d < 0.98 ? (
              <div style={{position: 'absolute', left: (w - PHONE.w) / 2, top: 0, width: PHONE.w, height: PHONE.h, opacity: 1 - prog(d, 0.15, 0.6, (t) => t)}}>
                {order.map((k, i) => {
                  const S = screens[k], s = starts[k], e = endOf(k), lastOne = i === order.length - 1;
                  if (f < s - 14 || (!lastOne && f > e + 16)) return null;
                  const a = i ? prog(f, s - 14, s + 14, easeInOut) : 1;
                  const b = lastOne ? 0 : prog(f, e - 14, e + 14, easeInOut);
                  return <div key={k} style={{position: 'absolute', inset: 0, transform: `translateX(${(1 - a) * 100 - b * 34}%)`, filter: b > 0 ? `brightness(${1 - b * 0.45})` : undefined}}><S f={f - s} /></div>;
                })}
                <Morph f={f} />
              </div>
            ) : null}
            {d > 0.12 ? (
              <div style={{position: 'absolute', left: (w - W) / 2, top: 0, width: W, height: H, opacity: prog(d, 0.4, 0.85, (t) => t)}}>
                {f >= starts.adminDash - 14 ? (
                  <AdminShell w={W} h={H} active={active}>
                    {adminOrder.map((k, n) => {
                      const S = adminScreens[k], st = starts[k], e = endOf(k), lastOne = n === adminOrder.length - 1;
                      if (f < st - 14 || (!lastOne && f > e + 14)) return null;
                      const a = n ? prog(f, st - 12, st + 12, easeInOut) : 1, b = lastOne ? 0 : prog(f, e - 12, e + 12, easeInOut);
                      return <div key={k} style={{position: 'absolute', inset: 0, background: '#0B0B0D', transform: `translateY(${(1 - a) * 100 - b * 30}%)`, filter: b > 0 ? `brightness(${1 - b * 0.5})` : undefined}}><S f={f - st} /></div>;
                    })}
                  </AdminShell>
                ) : null}
                {f < starts.adminDash + 14 ? <div style={{position: 'absolute', inset: 0, opacity: 1 - prog(f, starts.adminDash - 12, starts.adminDash + 8)}}><AdminSplash f={f - ADMIN} w={W} h={H} /></div> : null}
              </div>
            ) : null}
            <div style={{position: 'absolute', inset: 0, background: 'linear-gradient(115deg, rgba(255,255,255,.13) 0%, rgba(255,255,255,0) 32%)', opacity: 1 - d}} />
          </div>
          <div style={{position: 'absolute', left: '50%', top: bezel + 13, width: 18, height: 18, marginLeft: -9, borderRadius: 9, background: '#050506', boxShadow: 'inset 0 0 0 3px #17181c', opacity: 1 - d}} />
        </div>
      </div>
    </AbsoluteFill>
  );
};
