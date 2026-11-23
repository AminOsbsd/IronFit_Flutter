import type {LucideIcon} from 'lucide-react';
import {useCurrentFrame} from 'remotion';
import {colors} from '../config';
import {float, pop, prog} from '../lib/anim';
import {useLayout} from '../lib/layout';
import {fonts, gradient} from '../theme';
import {tone} from './Background';
import {SceneKey, endOf, starts} from '../timeline';

/** Glass chip floating next to the phone. (x, y) is the chip center, relative to the phone center. */
export const Callout: React.FC<{scene: SceneKey; icon: LucideIcon; text: string; cx: number; cy: number; x: number; y: number; at: number; phase: number}> = ({scene, icon: Icon, text, cx, cy, x, y, at, phase}) => {
  const f = useCurrentFrame();
  const {portrait} = useLayout();
  const s = starts[scene], out = endOf(scene) - 18;
  if (f < s + at || f > out + 14) return null;
  const p = pop(f, s + at), o = prog(f, out, out + 12);
  const dark = tone[scene] === 'dark';
  return (
    <div style={{position: 'absolute', left: cx + x + float(f, 5, 150, phase), top: cy + y + float(f, 12, 130, phase), transform: `translate(${portrait ? -50 : x < 0 ? -100 : 0}%,-50%) scale(${p * (1 - o * 0.5)})`, opacity: Math.min(1, p) * (1 - o), display: 'flex', alignItems: 'center', gap: 14, padding: portrait ? '14px 24px 14px 14px' : '14px 26px 14px 14px', borderRadius: 22, background: dark ? 'rgba(48,50,58,.72)' : 'rgba(255,255,255,.82)', border: `1.5px solid ${dark ? 'rgba(255,255,255,.18)' : 'rgba(255,255,255,.95)'}`, backdropFilter: 'blur(18px)', boxShadow: '0 22px 50px rgba(0,0,0,.28)', whiteSpace: 'nowrap'}}>
      <div style={{width: 46, height: 46, borderRadius: 14, background: gradient, display: 'grid', placeItems: 'center'}}><Icon size={25} color={colors.ink} strokeWidth={2.4} /></div>
      <span style={{fontFamily: fonts.ui, fontWeight: 600, fontSize: 28, color: dark ? colors.white : colors.charcoal}}>{text}</span>
    </div>
  );
};
