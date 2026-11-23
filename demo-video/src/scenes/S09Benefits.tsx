import {AbsoluteFill, useCurrentFrame} from 'remotion';
import {colors, copy, durations} from '../config';
import {float, pop, prog} from '../lib/anim';
import {useLayout} from '../lib/layout';
import {displayStyle, fonts, gradient} from '../theme';
import {KineticLines, fitLines} from '../components/KineticText';

/** 45-51 s: three benefits that are true of the app (no invented statistics). */
export const Benefits: React.FC = () => {
  const f = useCurrentFrame();
  const {width, portrait} = useLayout();
  const out = durations.benefits - 12;
  const title = portrait ? copy.benefits.title : [copy.benefits.title.join(' ')];
  const size = fitLines(title, width - (portrait ? 144 : 300), portrait ? 104 : 92);
  return (
    <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', gap: portrait ? 70 : 76}}>
      <KineticLines lines={title} f={f} inAt={-4} outAt={out} size={size} color={colors.white} align="center" />
      <div style={{display: 'flex', flexDirection: portrait ? 'column' : 'row', gap: portrait ? 34 : 40}}>
        {copy.benefits.items.map((it, i) => {
          const p = pop(f, 15 + i * 15, 13, 110), o = prog(f, out - 2 + i * 2, out + 10 + i * 2);
          const v = typeof it.value === 'number' ? Math.max(1, Math.round(it.value * prog(f, 17 + i * 15, 43 + i * 15))) : it.value;
          return (
            <div key={it.label} style={{width: portrait ? 860 : 500, boxSizing: 'border-box', padding: portrait ? '40px 48px' : '46px 44px', borderRadius: 34, background: 'linear-gradient(150deg, rgba(255,255,255,.13), rgba(255,255,255,.04))', border: '1.5px solid rgba(255,255,255,.17)', backdropFilter: 'blur(20px)', boxShadow: '0 40px 90px rgba(0,0,0,.4)', opacity: Math.min(1, p) * (1 - o), transform: `translateY(${(1 - p) * 140 + float(f, 8, 130, i * 1.3) - o * 60}px) scale(${0.85 + p * 0.15})`, display: 'flex', flexDirection: portrait ? 'row' : 'column', alignItems: portrait ? 'center' : 'flex-start', gap: portrait ? 40 : 14}}>
              <div style={{...displayStyle, fontSize: portrait ? 150 : 170, lineHeight: 1.05, minWidth: portrait ? 210 : undefined, paddingRight: 8, backgroundImage: gradient, backgroundClip: 'text', WebkitBackgroundClip: 'text', color: 'transparent'}}>{v}</div>
              <div style={{fontFamily: fonts.ui, fontWeight: 600, fontSize: portrait ? 42 : 36, lineHeight: 1.28, color: colors.white}}>{it.label}</div>
            </div>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};
