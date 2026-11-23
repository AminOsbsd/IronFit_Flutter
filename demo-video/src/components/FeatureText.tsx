import type {LucideIcon} from 'lucide-react';
import {useCurrentFrame} from 'remotion';
import {colors} from '../config';
import {pop, prog} from '../lib/anim';
import {useLayout} from '../lib/layout';
import {fonts, gradient} from '../theme';
import {tone} from './Background';
import {KineticLines, fitLines} from './KineticText';
import {SceneKey, endOf, starts} from '../timeline';

/** Eyebrow + headline + supporting line. Same placement, rhythm and typography in every feature scene. */
export const FeatureText: React.FC<{scene: SceneKey; icon: LucideIcon; eyebrow: string; title: string[]; sub: string; side: 'left' | 'right' | 'top'}> = ({scene, icon: Icon, eyebrow, title, sub, side}) => {
  const f = useCurrentFrame();
  const {portrait, width, margin} = useLayout();
  const s = starts[scene], out = endOf(scene) - 16;
  if (f < s - 2 || f > out + 16) return null;
  const top = side === 'top' || portrait;
  const w = portrait ? width - margin * 2 : side === 'top' ? 1500 : 790;
  const dark = tone[scene] === 'dark', amber = tone[scene] === 'amber';
  const size = fitLines(title, w, portrait ? 104 : side === 'top' ? 84 : 104);
  const e = pop(f, s + 2), eo = prog(f, out, out + 10);
  const a = prog(f, s + 20, s + 42), b = prog(f, out, out + 10);
  return (
    <div style={{position: 'absolute', left: portrait ? margin : side === 'right' ? 990 : margin, width: w, top: portrait ? 130 : side === 'top' ? 48 : 0, height: top ? undefined : 1080, display: 'flex', flexDirection: 'column', justifyContent: 'center', gap: portrait ? 26 : side === 'top' ? 12 : 30}}>
      <div style={{display: 'flex', alignItems: 'center', gap: 18, opacity: Math.min(1, e) * (1 - eo), transform: `translateX(${(1 - e) * -40}px)`}}>
        <div style={{width: 62, height: 62, borderRadius: 18, background: amber ? colors.ink : gradient, display: 'grid', placeItems: 'center', transform: `scale(${e})`}}><Icon size={34} color={amber ? colors.amber : colors.ink} strokeWidth={2.4} /></div>
        <div style={{fontFamily: fonts.ui, fontWeight: 700, fontSize: 32, letterSpacing: '0.04em', color: amber ? colors.ink : dark ? colors.amber : colors.amberText}}>{eyebrow}</div>
      </div>
      <KineticLines lines={title} f={f} inAt={s + 6} outAt={out} size={size} color={amber ? colors.ink : dark ? colors.white : colors.charcoal} />
      <div style={{fontFamily: fonts.ui, fontSize: portrait ? 42 : 38, lineHeight: 1.35, fontWeight: 400, color: amber ? '#2B1D00' : dark ? '#C9CBD2' : '#4A4D55', opacity: a * (1 - b), transform: `translateY(${(1 - a) * 24 - b * 16}px)`}}>{sub}</div>
    </div>
  );
};
