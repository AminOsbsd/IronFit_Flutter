import {Dumbbell, LayoutDashboard, Users} from 'lucide-react';
import {AbsoluteFill, useCurrentFrame} from 'remotion';
import {colors, copy, durations} from '../config';
import {pop, prog, range} from '../lib/anim';
import {useLayout} from '../lib/layout';
import {displayStyle, fonts, gradient} from '../theme';
import {Logo} from '../components/Logo';
import {fitLines} from '../components/KineticText';

const icons = [Dumbbell, Users, LayoutDashboard];

/** 51-56 s: end card. No store badges: the app is not published on any store. */
export const End: React.FC = () => {
  const f = useCurrentFrame();
  const {width, height, portrait} = useLayout();
  const w = portrait ? 840 : 800;
  const size = fitLines([copy.end.cta], portrait ? 800 : 860, portrait ? 72 : 62);
  const btn = pop(f, 45, 14);
  return (
    <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', gap: portrait ? 74 : 54, transform: `scale(${range(f, 0, durations.end, 1, 1.035, (t) => t)})`, opacity: 1 - prog(f, durations.end - 12, durations.end, (t) => t)}}>
      <div style={{position: 'absolute', left: width / 2 - 700, top: height / 2 - 800, width: 1400, height: 1400, borderRadius: '50%', background: `radial-gradient(circle, ${colors.amber}40, transparent 60%)`, transform: `scale(${pop(f, 0, 20, 60)})`}} />
      <Logo width={w} m={prog(f, -4, 24)} w={prog(f, 4, 30)} t={prog(f, 26, 42)} />
      <div style={{...displayStyle, fontSize: size, color: colors.ink, background: gradient, padding: portrait ? '34px 54px' : '28px 52px', borderRadius: 26, transform: `scale(${btn})`, boxShadow: `0 24px 70px ${colors.amber}55`, whiteSpace: 'nowrap'}}>{copy.end.cta}</div>
      <div style={{display: 'flex', gap: portrait ? 22 : 24}}>
        {copy.end.roles.map((r, i) => {
          const I = icons[i], p = pop(f, 60 + i * 6);
          return <div key={r} style={{display: 'flex', alignItems: 'center', gap: 14, padding: '16px 30px', borderRadius: 20, background: 'rgba(255,255,255,.08)', border: '1.5px solid rgba(255,255,255,.18)', color: colors.white, fontFamily: fonts.ui, fontWeight: 600, fontSize: portrait ? 36 : 32, transform: `scale(${p})`, opacity: Math.min(1, p)}}><I size={32} color={colors.amber} />{r}</div>;
        })}
      </div>
    </AbsoluteFill>
  );
};
